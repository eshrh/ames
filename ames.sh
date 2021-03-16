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
# -2 to calculate dimension while preserving aspect ratio.
IMAGE_WIDTH="-2"
IMAGE_HEIGHT="300"

CONFIG_FILE_PATH="$HOME/.config/ames/config"

if [[ -f "$CONFIG_FILE_PATH" ]]; then
    # shellcheck disable=SC1090
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

maxn() {
    tr -d ' ' | tr ',' '\n' | awk '
    BEGIN {
        max = 0
    }
    {
        if ($0 > max) {
            max = $0
        }
    }
    END {
        print max
    }
    '
}

get_last_id() {
    local new_card_request='{
        "action": "findNotes",
        "version": 6,
        "params": {
        "query": "added:1"
        }
    }'
    local new_card_response list

    new_card_response=$(ankiconnect_request "$new_card_request")
    list=$(echo "$new_card_response" | cut -d "[" -f2 | cut -d "]" -f1)
    newest_card_id=$(echo "$list" | maxn)
}

store_file() {
    local -r dir=${1:?}
    local -r name=$(basename -- "$dir")
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
    ankiconnect_request "$request" >>/dev/null
}

gui_browse() {
    local -r query=${1:-nid:1}
    local request='{
        "action": "guiBrowse",
        "version": 6,
        "params": {
            "query": "<QUERY>"
        }
    }'
    request=${request/<QUERY>/$query}
    ankiconnect_request "$request"
}

ankiconnect_request() {
    curl --silent localhost:8765 -X POST -d "${1:?}"
}

safe_request() {
    gui_browse "nid:1"
    ankiconnect_request "${1:?}"
    gui_browse "nid:${newest_card_id:?Newest card is not known.}"
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

    safe_request "$update_request"
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

    safe_request "$update_request"
}

screenshot() {
    local -r geom=$(slop)
    local -r path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)
    local -r converted_path="/tmp/$(basename -- "$path" | cut -d "." -f-2).$IMAGE_FORMAT"

    maim "$path" -g "$geom"
    ffmpeg -nostdin \
        -hide_banner \
        -loglevel error \
        -i "$path" \
        -vf scale="$IMAGE_WIDTH:$IMAGE_HEIGHT" \
        "$converted_path"

    rm "$path"
    echo "$geom" >/tmp/previous-maim-screenshot
    store_file "$converted_path"
    update_img "$(basename -- "$converted_path")"
    notify_screenshot_add
}

again() {
    local -r path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)
    local -r converted_path="/tmp/$(basename -- "$path" | cut -d "." -f-2).$IMAGE_FORMAT"

    if [[ -f /tmp/previous-maim-screenshot ]]; then
        maim "$path" -g "$(cat /tmp/previous-maim-screenshot)"
        ffmpeg -nostdin \
            -hide_banner \
            -loglevel error \
            -i "$path" \
            -vf scale="$IMAGE_WIDTH:$IMAGE_HEIGHT" \
            "$converted_path"

        rm "$path"
        store_file "$converted_path"
        get_last_id
        update_img "$(basename -- "$converted_path")"
        notify_screenshot_add
    else
        screenshot
    fi
}

screenshot_window() {
    local -r path=$(mktemp /tmp/maim-screenshot.XXXXXX.png)
    local -r converted_path="/tmp/$(basename -- "$path" | cut -d "." -f-2).$IMAGE_FORMAT"

    maim "$path" -i "$(xdotool getactivewindow)"
    ffmpeg -nostdin \
        -hide_banner \
        -loglevel error \
        -i "$path" \
        -vf scale="$IMAGE_WIDTH:$IMAGE_HEIGHT" \
        "$converted_path"

    rm "$path"
    store_file "$converted_path"
    update_img "$(basename -- "$converted_path")"
    notify_screenshot_add
}

record() {
    # this section is a heavily modified version of the linux audio script written by salamander on qm's animecards.
    local -r recordingToggle="/tmp/ffmpeg-recording-audio"

    if [[ ! -f /tmp/ffmpeg-recording-audio ]]; then
        local -r audioFile=$(mktemp "/tmp/ffmpeg-recording.XXXXXX.$AUDIO_FORMAT")
        echo "$audioFile" >"$recordingToggle"

        if [ "$OUTPUT_MONITOR" == "" ]; then
            local -r output=$(pactl info | grep 'Default Sink' | awk '{print $NF ".monitor"}')
        else
            local -r output="$OUTPUT_MONITOR"
        fi

        ffmpeg -nostdin \
            -y \
            -loglevel error \
            -f pulse \
            -i "$output" \
            -ac 2 \
            -af 'silenceremove=1:0:-50dB' \
            -ab $AUDIO_BITRATE \
            "$audioFile" 1>/dev/null &

        if [[ "$LANG" == en* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "Recording started..."
        fi
        if [[ "$LANG" == ja* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "録音しています..."
        fi

        echo "Started recording."
    else
        local -r audioFile="$(cat "$recordingToggle")"
        rm "$recordingToggle"
        killall ffmpeg
        store_file "${audioFile}"
        update_sound "$(basename -- "$audioFile")"

        if [[ "$LANG" == en* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "Recording added"
        fi
        if [[ "$LANG" == ja* ]]; then
            notify-send --hint=int:transient:1 -t 500 -u normal "録音付けました"
        fi
    fi
}

if [[ -z ${1-} ]]; then
    usage
    exit 1
fi

while getopts 'hrsaw' flag; do
    case "${flag}" in
        h) usage ;;
        r) record ;;
        s) screenshot ;;
        a) again ;;
        w) screenshot_window ;;
        *) ;;
    esac
done
