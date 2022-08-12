# cython: profile=False
from fileio cimport open as c_open, close, dup, dup2, O_WRONLY
from cysignals.signals cimport (
    sig_check, sig_on, sig_on_no_except, sig_off, cython_check_exception
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
    PaStreamInfo,
    Pa_OpenStream,
    Pa_StartStream,
    Pa_AbortStream,
    Pa_IsStreamActive,
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

cdef PaStream *stream
cdef PaStreamParameters input_params
cdef UserData user_data

cdef double actual_samplerate
cdef size_t recording_size
cdef char *recording_data

def get_recording() -> tuple[float, bytes]:
    """ Return the recording data as bytes. """
    if recording_size <= 0 or recording_data is NULL:
        raise ValueError("Empty recording. "
                         "Please wait for at least ~0.25 seconds.")
    # return without copying, memoryview
    return (actual_samplerate, <char[:recording_size:1]> recording_data)

def raise_error(error: PaError) -> PaError:
    """ Raise an error if necessary. """
    if error < paNoError:
        raise ValueError(f"PortAudio error: {Pa_GetErrorText(error)}")
    return error

def initialize_portaudio() -> None:
    """ Initialize PortAudio with silent stderr and handle SIGINT. """
    cdef:
        int stderr_copy, devnull

    # temporarily silence stderr: https://stackoverflow.com/questions/5081657/
    import sys, os
    stderr_copy = dup(2)
    devnull = c_open("/dev/null", O_WRONLY)
    dup2(devnull, 2)
    close(devnull)
    # allow Python to still write to stderr
    sys.stderr = os.fdopen(stderr_copy, "w")
    # PortAudio initialization can be noisy
    raise_error(Pa_Initialize())
    sig_check()
    # restore original stderr
    dup2(stderr_copy, 2)
    close(stderr_copy)
    sys.stderr = sys.__stderr__

cdef PaDeviceIndex __get_device_by_name(char *name):
    """ Get the integer device index by a string name. """
    cdef:
        PaDeviceIndex device
        const PaDeviceInfo *info

    for device in range(Pa_GetDeviceCount()):
        info = Pa_GetDeviceInfo(device)
        if info != NULL:
            if name in info.name:
                return device
    return NOT_FOUND

def get_device(device_name: None | int | str) -> int:
    """ Get the device index from a Python object. """
    cdef:
        PaDeviceIndex device

    # use default device
    if device_name is None:
        device = raise_error(Pa_GetDefaultInputDevice())
    # device index already provided
    elif isinstance(device_name, int):
        device = device_name
        max_index = raise_error(Pa_GetDeviceCount()) - 1
        if device < 0 or device > max_index:
            raise ValueError(f"Device index {device} "
                             f"out of the bounds [0, {max_index}].")
    # device name, look for substring
    else:
        device = __get_device_by_name(device_name.encode())
        if device == NOT_FOUND:
            raise ValueError(f"Device {device_name} not found.")
    return device

def get_latency(suggested_latency: str,
                low_latency: PaTime, high_latency: PaTime) -> PaTime:
    """ Get the latency from a Python object. """
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

def record(sample_rate: float,
           device_name: None | int | str,
           num_channels: int,
           suggested_latency: str) -> None:
    """ Start recording. """
    global stream, input_params, user_data
    global actual_samplerate, recording_size, recording_data
    cdef:
        PaDeviceIndex device
        const PaDeviceInfo *device_info
        int channels
        PaTime latency
        const PaStreamInfo *stream_info

    initialize_portaudio()
    device = get_device(device_name)
    device_info = Pa_GetDeviceInfo(device)
    if device_info == NULL:
        raise ValueError(f"Error retrieving information for {device_name}.")
    samplerate = sample_rate if sample_rate > 0 else \
        device_info.defaultSampleRate
    channels = num_channels
    if channels <= 0 or device_info.maxInputChannels < channels:
        raise ValueError(f"Input only has {device_info.maxInputChannels} "
                         f"channels, requested {channels}.")
    latency = get_latency(suggested_latency,
                          device_info.defaultLowInputLatency,
                          device_info.defaultHighInputLatency)

    input_params.device = device
    input_params.channelCount = channels
    input_params.sampleFormat = paInt32
    input_params.suggestedLatency = latency
    input_params.hostApiSpecificStreamInfo = NULL

    user_data.channels = channels
    # the optimal size may vary between devices, tune to your circumstances
    user_data.queue = linkedlist_init(node_size=2048, buffer=1024)

    Pa_OpenStream(
        &stream,                      # pointer to stream
        &input_params,                # input parameters
        NULL,                         # output parameters
        samplerate,                   # sample rate
        paFramesPerBufferUnspecified, # frames per buffer
        paNoFlag,                     # flags
        stream_callback,              # callback function
        <void *> &user_data,          # user data
    )
    # actual sample rate can slightly differ from
    # provided rate due to hardware limitations
    # http://files.portaudio.com/docs/v19-doxydocs/structPaStreamInfo.html
    stream_info = Pa_GetStreamInfo(stream)
    if stream_info != NULL:
        actual_samplerate = stream_info.sampleRate

    # not sure if releasing the GIL does anything here but it can't hurt
    with nogil:
        # begin recording
        Pa_StartStream(stream)

        # cleanup: https://cysignals.readthedocs.io/en/latest/sigadvanced.html
        if not sig_on_no_except():
            # unsafe to raise errors within a sig_on() ... sig_off() block
            # and impossible in the nogil context anyways
            if Pa_IsStreamActive(stream) > paNoError:
                Pa_AbortStream(stream)
            Pa_Terminate()

            recording_data = to_bytes(user_data.queue, &recording_size)

            linkedlist_dealloc(user_data.queue)
            cython_check_exception()

        # block indefinitely in main loop
        while True:
            # add back dynamically allocated memory while blocked
            linkedlist_fill(user_data.queue)
            Pa_Sleep(1000)

        sig_off()

