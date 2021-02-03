# ames
anki media extractor script(ames): Update anki cards with desktop audio and image on GNU/linux

Ames automates the process of adding screenshots and desktop audio clips to your latest added Anki card; making immersion mining smoother and more efficient.

## Requirements
+ A bash interpreter
+ Anki and [AnkiConnect](https://ankiweb.net/shared/info/2055492159). *Note that Anki must be running*.
+ `pulseaudio` and `pactl`: detecting and recording from audio monitors
+ `ffmpeg`: encoding desktop audio
+ `maim`: screenshots
+ `xdotool`: detecting active windows


## Installation
1. Download the ames.sh script somewhere safe
2. Edit the script and change the first two lines to match the names of your Anki model image and audio fields.
3. Bind the following commands to any key in your DE, WM, sxhkd, xbindkeysrc, etc.
    * `sh ames.sh -r`: press once to start recording, and again to stop and export the audio clip to your latest-created Anki card.
    * `sh ames.sh -s`: prompt for an interactive screenshot selection
    * `sh ames.sh -a`: repeat the previous screenshot selection. If there is no previous selection, default to -s.
    * `sh ames.sh -w`: screenshot the currently active window (requires xdotool)
  
