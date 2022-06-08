# ames-wlrots
anki media extractor script for wlroots (ames-wlrots): Update anki cards with desktop audio, screenshots, and clipboard sentences on GNU/linux. This script is a rewrite of [ames](https://github.com/eshrh/ames) for wlroots-based compositors, with first-class support for Sway. **The `-w` option, which relies on `swaymsg`, is only supported on Sway.**

ames-wlrots automates the process of adding information and media to your latest added Anki card; making immersion mining smoother and more efficient.

## Requirements
+ A bash interpreter
+ Anki and [AnkiConnect](https://ankiweb.net/shared/info/2055492159). *Note that Anki must be running*.
+ A wlroots-based compositor, specifically `sway` (GNOME doesn't support the screenshot protocol extentions that `grim`/`slurp` use)
+ `pulseaudio` and `pactl`: detecting and recording from audio monitors. `pipewire-pulse` is also supported.
+ `ffmpeg`: encoding desktop audio
+ `grim`: screenshots
+ `slurp`: select a region
+ `jq`: processing JSON data for active window selection
+ `libnotify`: sending notifications
+ `wl-clipboard`: pasting clipboard content

## Installation
### General
1. Download the ames-wlrots.sh script somewhere safe
2. Edit the script and change the first two lines to match the names of your Anki model image and audio fields.
3. Bind the following commands to any key using a method your compositor supports. FOr Sway, this is in the config file, which can be specified in various directories including `~/.config/sway/config` using the `bindsym` command. See `man 5 sway` for more details on how to use the config file.
    * `sh ~/path/to/ames-wlrots.sh -r`: press once to start recording, and again to stop and export the audio clip to your latest-created Anki card.
    * `sh ~/path/to/ames-wlrots.sh -s`: prompt for an interactive screenshot selection
    * `sh ~/path/to/ames-wlrots.sh -a`: repeat the previous screenshot selection. If there is no previous selection, default to -s.
    * `sh ~/path/to/ames-wlrots.sh -w`: screenshot the currently active window (requires xdotool)
    * `sh ~/path/to/ames-wlrots.sh -c`: pastes the currently copied sentence in the clipboard (requires xsel)

## Notes
+ You may also define config options in `~/.config/ames-wlrots/config`. These must be bash variable declarations, with no spaces like in the script.
+ ames-wlrots tries to pick the right output monitor automatically. If this doesn't work for you, you can first list monitor sinks with `pactl list | grep -A2 '^Source #'` and then redefine the `OUTPUT_MONITOR` variable in the script or a config file with the name of the correct sink.
+ By default, images are scaled to a height of 300px
+ Prefix your ames-wlrots command with `LANG=ja` for japanese notifications to achieve *maximum immersion*
+ The most common issue is not matching up the names of your Anki model's image, audio, and sentence fields with the ones configured in ames-wlrots, so if your card isn't being updated, check that these field names are set correctly in `~/.config/ames-wlrots/config` or directly in the script's variables.
