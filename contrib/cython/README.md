# Recording Audio with PortAudio and Cython

This is a drop-in replacement for [audio-record](../python/src/audio-record),
replacing the Python library `sounddevice` which wraps
PortAudio with a direct Cython interface to PortAudio.
The rationale is that it might improve performance and stability.

### Requirements

The requirements are [Cython](https://cython.org/),
[cysignals](https://github.com/sagemath/cysignals),
[PortAudio](http://portaudio.com/) (for recording
audio), and [pydub](https://github.com/jiaaro/pydub/) (for saving recordings).
```console
pip install cython cysignals pydub
```
(Cython is packaged in Community as `cython`,
cysignals is packaged in Community as `python-cysignals`,
PortAudio is packaged in Community as `portaudio`,
and pydub is packaged in the AUR as `python-pydub`).

Once the dependencies have been installed, build the extension modules with
```console
python setup.py build_ext --inplace
```

### Caveats

The program only responds to `SIGINT` (2)
and not `SIGTERM` (15) to stop recording.

The program does not actually begin recording faster than its
Python counterpart since Python interpreter overhead is minimal;
the main startup costs are really in initializing PortAudio.
That is, there'll still be a ~0.25 second delay before the recording starts.

