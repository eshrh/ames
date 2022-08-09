cdef extern from "portaudio.h":
    ctypedef int PaError
    ctypedef int PaDeviceIndex
    ctypedef int PaHostApiIndex
    ctypedef double PaTime
    ctypedef unsigned long PaSampleFormat
    ctypedef unsigned long PaStreamFlags
    ctypedef unsigned long PaStreamCallbackFlags
    ctypedef void PaStream
    ctypedef int PaStreamCallback(
        const void *input, void *output,
        unsigned long frameCount,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags,
        void *userData)

    enum PaErrorCode:
        paNoError

    enum PaStreamCallbackResult:
        paContinue
        paComplete
        paAbort

    enum:
        paFramesPerBufferUnspecified

    struct PaDeviceInfo:
        int structVersion
        const char *name
        PaHostApiIndex hostApi

        int maxInputChannels
        int maxOutputChannels

        PaTime defaultLowInputLatency
        PaTime defaultLowOutputLatency

        PaTime defaultHighInputLatency
        PaTime defaultHighOutputLatency

        double defaultSampleRate

    struct PaStreamCallbackTimeInfo:
        PaTime inputBufferAdcTime
        PaTime currentTime
        PaTime outputBufferDacTime

    struct PaStreamParameters:
        PaDeviceIndex device;
        int channelCount;
        PaSampleFormat sampleFormat;
        PaTime suggestedLatency;
        void *hostApiSpecificStreamInfo;

    struct PaStreamInfo:
        int structVersion
        PaTime inputLatency
        PaTime outputLatency
        double sampleRate

    PaError Pa_Initialize()
    PaError Pa_Terminate() nogil

    const char *Pa_GetErrorText(PaError errorCode)

    void Pa_Sleep(long msec) nogil

    # devices
    PaDeviceIndex paNoDevice

    PaDeviceIndex Pa_GetDeviceCount()
    PaDeviceIndex Pa_GetDefaultInputDevice()
    PaDeviceIndex Pa_GetDefaultOutputDevice()
    const PaDeviceInfo* Pa_GetDeviceInfo(PaDeviceIndex device)

    # streams
    PaSampleFormat paFloat32
    PaSampleFormat paInt32
    PaStreamFlags paNoFlag

    PaError Pa_OpenStream(PaStream** stream,
                          const PaStreamParameters *inputParameters,
                          const PaStreamParameters *outputParameters,
                          double sampleRate,
                          unsigned long framesPerBuffer,
                          PaStreamFlags streamFlags,
                          PaStreamCallback *streamCallback,
                          void *userData) nogil

    PaError Pa_StartStream(PaStream *stream) nogil
    PaError Pa_StopStream(PaStream *stream)
    PaError Pa_AbortStream(PaStream *stream) nogil
    const PaStreamInfo* Pa_GetStreamInfo(PaStream *stream) nogil

