# Python backend for ames

Thanks to the modularity of ames, binaries for the various functionalities
(screenshot, recording audio, clipboard) can be easily replaced
with Python backends, allowing more platforms to be supported.
See the sample [config](./config).

## Screenshots

The primary benefit of the Python screenshot backend is
to support different platforms (e.g. Wayland) easily.

### Requirements

The only requirement for screenshots (other than a Python 3 interpreter)
is either [pyscreenshot](https://github.com/ponty/pyscreenshot)
or [Pillow](https://github.com/python-pillow/Pillow).
It is more likely that you have Pillow installed already, but
`pyscreenshot` works in more situations, e.g. on Wayland.
```console
pip install pyscreenshot
```
(pyscreenshot is packaged in Community as `python-pyscreenshot`).

or
```console
pip install Pillow
```
(Pillow is packaged in Community as `python-pillow`).

### Caveats

Neither `pyscreenshot` nor Pillow are aware of the current
window, so they cannot directly support `ames -w`.
However, it is possible to pass the window from `xdotool
getactivewindow` to `xdotool getwindowgeometry` to get out a region
(bounding box) and then take a screenshot of the region as usual.
For different platforms like Wayland, something like `swaymsg -t get_tree`
can be used instead of `xdotool` (see the Wayland [config](../wayland)):
```bash
swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"'
```

If there is no easy way to automatically get the geometry
of the current window, it's always possible to screenshot
the entire screen which is a reasonable default.
In addition, one can use `ames.sh -s` to manually outline the window
once and then `ames.sh -a` will remember the window size and location.

## Recording Audio

Many issues have been observed using `ffmpeg` to record audio:
- Noticeable delay before stopping.

  You may have noticed that starting to record audio by `ames.sh
  -r` sends a notification almost immediately but there can some
  varying delay (~1 second) between running `ames.sh -r` again and
  the notification indicating the recording has stopped.
  Indeed, the delay is not just for notifications, the recorded
  audio can go on for longer than when you stopped it.
  FFmpeg seems to prefer recording lengths that are an even integer number of
  seconds (2 seconds, 4, 6, 8, etc.) and will round up to the nearest even
  integer (e.g. stopping after 2.5 seconds will actually continue recording
  until 4 seconds).
  We're not sure of the cause right now, we suspect it may
  be some sort of internal buffering with a buffer size
  of 2 seconds (which seems to differ between computers).
  Regardless, the rounding behavior also explains why the delay can
  change (if stopped after 1.99 seconds, almost no delay, if after
  2.01 seconds, 2 seconds of delay, assuming uniformly distributed
  recording lengths this averages to around 1 second of delay).

  Commit [`be01c3f`](
https://github.com/eshrh/ames/commit/be01c3ff56a93bdff67f736bf9043b5af2562275)
  solves the issue of the recorded audio being longer than intended by
  storing the start and end times to precisely calculate the intended duration
  and trims the recorded audio to the intended duration.
  The notification will still be delayed, which is
  unavoidable (we must wait for FFmpeg to finish recording).
- If the recording length is less than around 2
  seconds, then the saved recording is empty.

  This is probably related to the delay issue since the minimum
  recording duration is also the smallest size that FFmpeg prefers.

  Commit [`7792384`](https://github.com/eshrh/ames/commit/7792384c9b289fd692277cd61c1cff1cc45bb34d)
  fixes this issue by continuing to record until a minimum duration is reached.
  This does not change the actual length of the recorded
  audio by the same post-processing trimming to fix delay.

- Noise/crackling/audio glitches in recorded audio.

  Using the `pulse` (PulseAudio) backend to
  record sometimes has various audio glitches.

  Currently, we're not sure how to fix this.

Using the [PortAudio](http://portaudio.com/) library to record
audio instead of FFmpeg pretty much fixes all these issues.

### Requirements

The requirements are [numpy](https://numpy.org/),
[sounddevice](https://python-sounddevice.readthedocs.io/en/0.4.4/index.html)
(PortAudio wrapper for recording), and
[pydub](https://github.com/jiaaro/pydub/) (for saving recordings).
```console
pip install numpy sounddevice pydub
```
(numpy is packaged in Community as `python-numpy`,
sounddevice is packaged in Community as `python-sounddevice`,
and pydub is packaged in the AUR as `python-pydub`).

### Caveats

- Need to manually set device.

  If the `OUTPUT_MONITOR` variable is empty, `ames` will
  automatically select an appropriate `pulseaudio`/`pipewire-pulse`
  monitor from `pactl list | grep -A2 '^Source #'`, e.g.
  ```text
  Source #55
      State: SUSPENDED
      Name: alsa_output.pci-0000_04_00.6.analog-stereo.monitor
  --
  Source #56
      State: SUSPENDED
      Name: alsa_input.pci-0000_04_00.6.analog-stereo
  --
  Source #65
      State: IDLE
      Name: bluez_output.{MAC_ADDRESS}.a2dp-sink.monitor
  ```

  The devices used in `sounddevice` are different,
  for example, `python -m sounddevice` shows
  ```text
      0 HD-Audio Generic: HDMI 0 (hw:0,3), ALSA (0 in, 8 out)
      1 HD-Audio Generic: ALC269VC Analog (hw:1,0), ALSA (2 in, 2 out)
      2 hdmi, ALSA (0 in, 8 out)
      3 jack, ALSA (2 in, 2 out)
      4 pipewire, ALSA (64 in, 64 out)
      5 pulse, ALSA (32 in, 32 out)
   *  6 default, ALSA (64 in, 64 out)
      7 Family 17h/19h HD Audio Controller Analog Stereo, JACK Audio Connection Kit (2 in, 2 out)
      8 C* Music Player, JACK Audio Connection Kit (2 in, 0 out)
      9 WH-1000XM4, JACK Audio Connection Kit (0 in, 2 out)
     10 WH-1000XM4 Monitor, JACK Audio Connection Kit (2 in, 0 out)
     11 Family 17h/19h HD Audio Controller Analog Stereo Monitor, JACK Audio Connection Kit (2 in, 0 out)
  ```
  A device can be specified in `OUTPUT_MONITOR` with either
  its index (e.g. `8` for the C* Music Player) or a substring
  of its name (e.g. `WH-1000XM4 Monitor` for the headphones).
  It's preferable to use a string identifier since it's
  more intuitive to read, and if a new device shows up,
  for example, if I start playing audio from Firefox:
  ```text
    ...
      8 C* Music Player, JACK Audio Connection Kit (2 in, 0 out)
  >>> 9 Firefox, JACK Audio Connection Kit (2 in, 0 out) <<<
     10 WH-1000XM4, JACK Audio Connection Kit (0 in, 2 out)
     11 WH-1000XM4 Monitor, JACK Audio Connection Kit (2 in, 0 out)
     12 Family 17h/19h HD Audio Controller Analog Stereo Monitor, JACK Audio Connection Kit (2 in, 0 out)
  ```
  then the indices of all devices past
  Firefox are shifted, changing their values.

  `sounddevice` also stores a default device.
  This default device _cannot_ be accessed with `OUTPUT_MONITOR=""` since
  `ames` will attempt to infer a monitor with `pactl` which will not work.
  Instead, `sounddevice`'s default device
  can be accessed with a value of `none`.
  This default device often is not actually the desired device, so it is
  likely you will need to manually set the value of `OUTPUT_MONITOR`.

- Noticeable delay before starting.

  Unfortunately, Python has the opposite problem as FFmpeg --- relying on
  the Python interpreter means there's a relatively high startup cost, so
  the start of the recording is delayed. The major costs are:
  - ~0.11 seconds to import sounddevice
  - ~0.05 seconds to import numpy
  - ~0.07 Python interpreter warmup (time until the file is ran)

  for a total of about ~0.25 seconds lost from the start of the recording.
  In practice, since this is a fixed (near-constant) delay,
  so it is possible to anticipate and press the start
  button consistently slightly earlier than one thinks.
  The major problem with FFmpeg delay is that it is
  variable and therefore impossible to anticipate.

  In principle, this could be mitigated by writing Cython
  or C/C++ code to directly interface with PortAudio.

## Clipboard

Using the Python clipboard backend supports different
platforms (e.g. Wayland) with a single command.

### Requirements

The only requirement is [pyclip](https://github.com/spyoungtech/pyclip).
```console
pip install pyclip
```
(pyclip is packaged in the AUR as `python-pyclip`).

The contents of the clipboard are accessed with `python -m pyclip paste`.

### Caveats

None! Except it's a bit unnecessary to wrap shell scripts with Python...
