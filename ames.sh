#!/usr/bin/env bash
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
set -euo pipefail

AUDIO_FIELD="audio"
SCREENSHOT_FIELD="image"
# leave OUTPUT_MONITOR blank to autoselect a monitor.
OUTPUT_MONITOR=""
AUDIO_BITRATE="64k"
AUDIO_FORMAT="opus"
IMAGE_FORMAT="webp"

CONFIG_FILE_PATH="$HOME/.config/ames/config"

if [[ -f "$CONFIG_FILE_PATH" ]]; then
    source "$CONFIG_FILE_PATH"
fi

usage() {
    echo "-h: display this help message"
    echo "-r: record audio toggle"
    echo "-s: interactive screenshot"
    echo "-a: screenshot same region again (defaults to -s if no region)"
    echo "-w: screenshot currently active window (xdotool)"
}

notify_screenshot_add() {
    if [[ "$LANG" == en* ]]; then
        notify-send --hint=int:transient:1 -t 500 -u normal "Screenshot added"
    fi
    if [[ "$LANG" == ja* ]]; then
        notify-send --hint=int:transient:1 -t 500 -u normal "スクリーンショット付けました"
    fi
}

get_last_id() {
   local new_card_request='{
        "action": "findNotes",
        "version": 6,
        "params": {
        "query": "added:1"
        }
    }'
    local new_card_response=$(curl localhost:8765 -X POST -d "$new_card_request" --silent)
    local list=$(echo $new_card_response | cut -d "[" -f2 | cut -d "]" -f1)
    IFS=',' read -ra ids <<< $list
    newest_card_id=${ids[0]}
    for n in "${ids[@]}" ; do
        [[ "$n" > "$newest_card_id" ]] && newest_card_id=$n
    done
    return 0
}

store_file() {
    local -r dir=${1:?}
    local -r name=$(basename $dir)
    local request='{
        "action": "storeMediaFile",
        "version": 6,
        "params": {
            "filename": "<name>",
            "path": "<dir>"
        }
    }'
    request=${request//<name>/$name}
    request=${request/<dir>/$dir}
    curl localhost:8765 -X POST -d "$request" --silent >> /dev/null
}

update_img() {
    get_last_id
    local update_request='{
        "action": "updateNoteFields",
        "version": 6,
        "params": {
            "note": {
                "id": <id>,
                "fields": { "<SCREENSHOT_FIELD>": "<img src=\"<path>\">" }
            }
        }
    }'
    update_request=${update_request/<id>/$newest_card_id}
    update_request=${update_request/<SCREENSHOT_FIELD>/$SCREENSHOT_FIELD}
    update_request=${update_request/<path>/$1}
    local update_response=$(curl localhost:8765 -X POST -d "$update_request" --silent)
}

update_sound() {
    get_last_id
    local update_request='{
        "action": "updateNoteFields",
        "version": 6,
        "params": {
            "note": {
                "id": <id>,
                "fields": {
                    "<AUDIO_FIELD>":"[sound:<path>]"
                 }
            }
        }
    }'
    update_request=${update_request/<id>/$newest_card_id}
    update_request=${update_request/<AUDIO_FIELD>/$AUDIO_FIELD}
    update_request=${update_request/<path>/$1}
    local update_response=$(curl localhost:8765 -X POST -d "$update_request" --silent)
}

screenshot() {
    local geom=$(slop)
    local path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)

    maim $path -g $geom
    ffmpeg -i $path "/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT" -hide_banner -loglevel error
    rm $path
    path="/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT"
    echo "$geom" > /tmp/previous-maim-screenshot
    store_file "$path"
    update_img $(basename $path)
    notify_screenshot_add
}

again() {
    local path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)
    if [[ -f /tmp/previous-maim-screenshot ]]; then
        maim $path -g $(cat /tmp/previous-maim-screenshot)
        ffmpeg -i $path "/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT" -hide_banner -loglevel error
        rm $path
        path="/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT"

        store_file "$path"
        get_last_id
        update_img $(basename $path)
        notify_screenshot_add
    else
        screenshot
    fi
}

screenshot_window() {
    local path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)
    maim $path -i $(xdotool getactivewindow)
    ffmpeg -i $path "/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT" -hide_banner -loglevel error
    rm $path
    path="/tmp/$(basename $path | cut -d "." -f-2).$IMAGE_FORMAT"

    store_file "$path"
    update_img $(basename $path)
    notify_screenshot_add
}


record() {
    # this section is a heavily modified version of the linux audio script written by salamander on qm's animecards.
    local recordingToggle="/tmp/ffmpeg-recording-audio"
    if [[ ! -f /tmp/ffmpeg-recording-audio ]]; then
        local audioFile=$(mktemp "/tmp/ffmpeg-recording.XXXXXX.$AUDIO_FORMAT")
        echo "$audioFile" > "$recordingToggle"

        if [ "$OUTPUT_MONITOR" == "" ]; then
            local output=$(pactl info | grep 'Default Sink' | awk '{print $NF ".monitor"}')
        else
            local output="$OUTPUT_MONITOR"
        fi

        if [[ "$LANG" == en* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "Recording started..."
        fi
        if [[ "$LANG" == ja* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "録音しています..."
        fi

        ffmpeg -f pulse -i $output -ac 2 -af silenceremove=1:0:-50dB -ab $AUDIO_BITRATE -y "$audioFile" 1>/dev/null &
    else
        local audioFile="$(cat "$recordingToggle")"
        rm "$recordingToggle"
        killall ffmpeg

        store_file "${audioFile}"
        update_sound $(basename $audioFile)

        if [[ "$LANG" == en* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "Recording added"
        fi
        if [[ "$LANG" == ja* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "録音付けました"
        fi
    fi
}

while getopts 'hrsaw' flag; do
    case "${flag}" in
        h) usage ;;
        r) record ;;
        s) screenshot ;;
        a) again ;;
        w) screenshot_window ;;
    esac
done
