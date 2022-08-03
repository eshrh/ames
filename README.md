# ames

Anki media extractor script (ames): Update Anki cards with
desktop audio, screenshots, and clipboard sentences on GNU/Linux.

Ames automates the process of adding information and media to your latest
added Anki card, making immersion mining smoother and more efficient.

## Requirements

+ A Bash interpreter.
+ Anki and [AnkiConnect](https://ankiweb.net/shared/info/2055492159).
  *Note that Anki must be running*.
+ X11: Wayland version (wlroots) on this
  [branch](https://github.com/eshrh/ames/tree/wlroots).
+ `pactl`: detecting and recording from audio monitors
  (`pulseaudio` and `pipewire-pulse` tested).
+ `ffmpeg`: encoding desktop audio.
+ `maim`: screenshots.
+ `xdotool`: detecting active windows.
+ `libnotify`: sending notifications.
+ `xsel`: pasting clipboard content.

## Installation

### General

1. Download the [ames.sh](https://github.com/eshrh/ames/blob/master/ames.sh)
   script somewhere safe.
2. Edit the script and change the first two lines to match
   the names of your Anki model image and audio fields.
3. Bind the following commands to any key
   in your DE, WM, sxhkd, xbindkeysrc, etc.
    * `bash ~/path/to/ames.sh -r`: press once to start recording, and again
       to stop and export the audio clip to your latest-created Anki card.
    * `bash ~/path/to/ames.sh -s`: prompt for an interactive
       screenshot selection.
    * `bash ~/path/to/ames.sh -a`: repeat the previous screenshot selection.
      If there is no previous selection, default to `-s`.
    * `bash ~/path/to/ames.sh -w`: screenshot the currently active window
      (requires xdotool).
    * `bash ~/path/to/ames.sh -c`: exports the currently copied
       text in the clipboard to the sentence field (requires xsel).

### Arch users

1. Install the `ames` package from the AUR.
2. Copy the default config:
```bash
mkdir -p ~/.config/ames/ && cp /usr/share/ames/config ~/.config/ames/config
```
3. Edit the config file however you like, but make
   sure your Anki image and audio fields are correct.
4. Bind the same commands however you want, but now the `ames`
   command should be in your `PATH`, so you can bind, for
   example, `ames -s` instead of `bash ~/path/to/ames.sh -s`.

## Notes

+ You may also define config options in `~/.config/ames/config`. These must
  be Bash variable declarations, with no spaces like in the script or in the
  [sample configuration](https://github.com/eshrh/ames/blob/master/config).
+ ames tries to pick the right output monitor automatically. If this doesn't
  work for you, you can first list monitor sinks with `pactl list | grep -A2
  '^Source #'` and then redefine the `OUTPUT_MONITOR` variable with the name
  of the correct sink.
+ By default, images are scaled to a height of 300px.
+ Prefix your ames command with `LANG=ja` for
  Japanese notifications to achieve *maximum immersion*.

