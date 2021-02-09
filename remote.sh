#!/usr/bin/env bash

#
# Author: mail _^_ AT _^_ wangbo _^_ im
#

#
# Enable strict bash mode
set -euo pipefail
IFS=$'\t\n'

REMOTE_IPS=(
"127.0.0.1"
"227.0.0.1"
)

REMOTE_USER=""

SSH=(
    "echo"
    "ssh"
    "-4"
    "-T"
)
RSYNC=(
    "echo"
    "rsync"
    "-4"
    "-a"
)

#
# Dirs
SCRIPT_FILE_PATH=`realpath $0`
SCRIPT_DIR_PATH=`dirname "${SCRIPT_FILE_PATH}"`
MAIN_SCRIPT_PATH="${SCRIPT_DIR_PATH}/main.script"

__usage() {
    echo ""
    echo "Usage: ${SCRIPT_FILE_PATH##*/} PATH_TO_TARGET_PROJECT_DIR COMMAND"
    echo ""
    echo -e "\twhere COMMAND is one command listing here:"
    echo -e "\t\tstart stop restart status"
    echo -e "\t      PATH_TO_TARGET_PROJECT_DIR is a symlink to or the directory for target project"
    echo ""
}


local_ips=("")
while read each_i; do
    ip4=$(echo "$each_i" | sed -n 's/.*inet \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    if [ -n "$ip4" ]; then local_ips[${#local_ips[@]}]=$ip4; fi
done < <(ip -4 addr)

remote_user="$REMOTE_USER"
if [ -z "$remote_user" ]; then
    remote_user="$(who am i | awk '{print $1}')"
fi

#
# Rsync directory from localhost to remote hosts.
#
# $1: directory to rsync
__sync() {
    local d="${1%%/}"
    local deref_d="$(realpath $d)"
    echo "Try to sync \"$d\" to remote hosts"
    for each_i in "${REMOTE_IPS[@]}"; do
        is_local=""
        for each_j in "${local_ips[@]}"; do
            if [ "$each_i" == "$each_j" ]; then
                echo "Configured remote ip \"$each_i\" is of localhost, ignore it"
                is_local="Y"
            fi
        done

        if [ -z "$is_local" ]; then
            local i=1
            local h="$remote_user@$each_i"

            echo "$((i++)). Sync directory \"$deref_d\" to host \"$h\""
            "${RSYNC[@]}" "$deref_d/" "$h:$deref_d"
            if [ "$d" != "$deref_d" ]; then
                "${SSH[@]}" $h rm -f "$d"
                "${SSH[@]}" $h ln -sf "$deref_d" "$d"
                echo "$((i++)). Update symlink \"$d\" to \"$deref_d\" on host \"$h\""
            fi

            deref_d="${SCRIPT_DIR_PATH%%/}"
            echo "$((i++)). Sync directory \"$deref_d\" to host \"$h\""
            "${RSYNC[@]}" "$deref_d/" "$h:$deref_d"

            echo "Sync directory \"$d\" to host \"$h\" finished"
        fi
    done
    echo "Try to sync \"$d\" to remote hosts --> DONE"
}

#
# Start project on localhost and remote hosts
#
# $1: target directory
# $2: command (start/stop/status/check)
__rrun() {
    local d="${1%%/}"
    local c="$2"
    echo "Try to run \"$c\" for \"$d\" on remote hosts"
    for each_i in "${REMOTE_IPS[@]}"; do
        is_local=""
        for each_j in "${local_ips[@]}"; do
            if [ "$each_i" == "$each_j" ]; then
                echo "Configured remote ip \"$each_i\" is of localhost, ignore it"
                is_local="Y"
            fi
        done

        if [ -z "$is_local" ]; then
            local i=1
            local h="$remote_user@$each_i"

            echo "$((i++)). run \"$c\" for \"$d\" on host \"$h\""
            "${SSH[@]}" $h bash "$MAIN_SCRIPT_PATH" "$d/" "$c"
        fi
    done
    echo "Try to run \"$c\" for \"$d\" on remote hosts --> DONE"
}

d="${1:-}"; shift
if [ ! -d "$d" ]; then
    echo "Project directory not exists"
    __usage
    exit 1
fi
d="$(realpath -s $d)"

if [ $# -gt 0 ]; then
    for each_i in "$@"; do
        echo "Try to execute command \"$each_i\" for project \"$d\""
        case "$each_i" in
            "start"|"stop"|"status"| "check")
                __rrun "$d" "$each_i"
                ;;
            "restart")
                __rrun "$d" stop
                __rrun "$d" start
                ;;
            "sync")
                __sync "$d"
                ;;
            "help")
                __usage
                ;;
            *)
                echo "Unknown command \"$each_i\""
                __usage
                exit 1
                ;;
        esac
        echo "Try to execute command \"$each_i\" for project \"$d\" --> DONE"
    done
else
    __sync "$d"
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
