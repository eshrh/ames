# cython: profile=False
from libc.stdlib cimport malloc, free
from cysignals.signals cimport (
    sig_on, sig_on_no_except, sig_off, cython_check_exception,
)
from portaudio cimport (
    Pa_Initialize,
    Pa_Terminate,
    Pa_Sleep,
    # error handling
    paNoError,
    PaError,
    Pa_GetErrorText,
    # device handling
    PaDeviceIndex,
    PaDeviceInfo,
    Pa_GetDeviceCount,
    Pa_GetDefaultInputDevice,
    Pa_GetDeviceInfo,
    # callback
    paContinue,
    PaStreamCallbackTimeInfo,
    PaStreamCallbackFlags,
    # stream
    paInt32,
    PaTime,
    paFramesPerBufferUnspecified,
    paNoFlag,
    PaStreamParameters,
    PaStream,
    Pa_OpenStream,
    Pa_StartStream,
    Pa_AbortStream,
    Pa_GetStreamInfo,
)
from cbackend cimport (
    copy_array,
    to_bytes,
    # queue data structure for "malloc" without dynamic memory allocation
    Node,
    LinkedList,
    linkedlist_init,
    linkedlist_dealloc,
    linkedlist_fill,
    linkedlist_get,
)

cdef PaDeviceIndex NOT_FOUND = -1

cdef struct UserData:
    int channels
    LinkedList *queue

cdef double actual_samplerate = 0
cdef size_t recording_size = 0
cdef char *recording_data = NULL

def get_recording():
    """ Return the recording data as bytes. """
    if recording_data == NULL:
        raise ValueError("Empty recording. \
Please wait for at least ~0.25 seconds.")
    # return without copying, memoryview
    return (actual_samplerate, <char[:recording_size:1]> recording_data)

cdef void __raise_error(PaError error):
    """ Raise an error if necessary. """
    if error != paNoError:
        raise ValueError(f"PortAudio error: {Pa_GetErrorText(error)}")

cdef PaDeviceIndex __get_device_by_name(char *name):
    """ Get the integer device index by a string name. """
    cdef:
        PaDeviceIndex device
        const PaDeviceInfo *info

    for device in range(Pa_GetDeviceCount()):
        info = Pa_GetDeviceInfo(device)
        if name in info.name:
            return device
    return NOT_FOUND

def get_device(device_name: None | int | str) -> int:
    """ Get the device index from a Python object. """
    cdef:
        PaDeviceIndex device

    # use default device
    if device_name is None:
        device = Pa_GetDefaultInputDevice()
    # device index already provided
    elif isinstance(device_name, int):
        device = device_name
    # device name, look for substring
    else:
        device = __get_device_by_name(device_name.encode())
    if device == NOT_FOUND:
        raise ValueError(f"Device {device_name} not found.")
    return device

def get_latency(suggested_latency: str,
                low_latency: float, high_latency: float) -> int:
    """ Get the device index from a Python object. """
    # use preferred latency from device
    if suggested_latency.lower() == "low":
        return low_latency
    elif suggested_latency.lower() == "high":
        return high_latency
    # latency already provided
    else:
        return float(suggested_latency)

cdef int stream_callback(const void* in_buffer,
                         void* out_buffer,
                         unsigned long frame_count,
                         const PaStreamCallbackTimeInfo* time_info,
                         PaStreamCallbackFlags status_flags,
                         void* user_data) nogil:
    """ Callback for each audio block while recording. """
    cdef:
        UserData *data
        Node *node

    data = <UserData *> user_data
    node = linkedlist_get(data.queue, data.channels*frame_count)
    copy_array(<const int *> in_buffer, node)

    return paContinue

cdef int __record(double samplerate,
                  PaDeviceIndex device,
                  int channels,
                  PaTime latency) except -1 nogil:
    """ Recording connection to PortAudio. """
    global actual_samplerate, recording_size, recording_data
    cdef:
        PaStreamParameters *input_params
        PaStream *stream
        UserData *user_data

    input_params = <PaStreamParameters *> malloc(sizeof(PaStreamParameters))
    input_params.device = device
    input_params.channelCount = channels
    input_params.sampleFormat = paInt32
    input_params.suggestedLatency = latency
    input_params.hostApiSpecificStreamInfo = NULL

    user_data = <UserData *> malloc(sizeof(UserData))
    user_data.channels = channels
    # the optimal size may vary between devices, tune to your circumstances
    user_data.queue = linkedlist_init(node_size=2048, buffer=1024)

    Pa_OpenStream(
        &stream,                      # pointer to stream
        input_params,                 # input parameters
        NULL,                         # output parameters
        samplerate,                   # sample rate
        paFramesPerBufferUnspecified, # frames per buffer
        paNoFlag,                     # flags
        stream_callback,              # callback function
        <void *> user_data,           # user data
    )
    # actual sample rate can slightly differ from
    # provided rate due to hardware limitations
    # http://files.portaudio.com/docs/v19-doxydocs/structPaStreamInfo.html
    actual_samplerate = Pa_GetStreamInfo(stream).sampleRate
    # cleanup
    # https://cysignals.readthedocs.io/en/latest/sigadvanced.html#advanced-sig
    if not sig_on_no_except():
        # unsafe to raise errors within a sig_on() ... sig_off() block
        # and impossible in the nogil context anyways
        Pa_AbortStream(stream)
        Pa_Terminate()

        recording_data = to_bytes(user_data.queue, &recording_size)

        free(input_params)
        linkedlist_dealloc(user_data.queue)

        cython_check_exception()

    # begin recording
    Pa_StartStream(stream)
    while True:
        # add back dynamically allocated memory while blocked
        linkedlist_fill(user_data.queue)
        Pa_Sleep(1000)

    sig_off()

def record(sample_rate: float,
           device_name: None | int | str,
           num_channels: int,
           suggested_latency: str) -> None:
    """ Start recording. """
    cdef:
        PaDeviceIndex device
        const PaDeviceInfo *info
        int channels
        PaTime latency

    __raise_error(Pa_Initialize())

    device = get_device(device_name)
    info = Pa_GetDeviceInfo(device)
    samplerate = sample_rate if sample_rate > 0 else info.defaultSampleRate
    channels = num_channels
    if info.maxInputChannels < channels:
        raise ValueError(f"Input only has {info.maxInputChannels} channels, " \
f"requested {channels}.")
    latency = get_latency(suggested_latency,
                          info.defaultLowInputLatency,
                          info.defaultHighInputLatency)

    # not sure if releasing the GIL does anything here but it can't hurt
    with nogil:
        __record(
            samplerate,
            device,
            channels,
            latency,
        )

