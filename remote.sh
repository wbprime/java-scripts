#!/usr/bin/env bash

#
# Author: mail _^_ AT _^_ wangbo _^_ im
#

#
# Enable strict bash mode
set -euo pipefail
IFS=$'\t\n'

#REMOTE_IPS=("")

REMOTE_USER="${REMOTE_USER:-}"

PARALLELISM="${PARALLELISM:-4}"

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
    echo "Usage: ${SCRIPT_FILE_PATH##*/} COMMAND PATH_TO_TARGET_PROJECT_DIR [REMOTE_IP ...]"
    echo ""
    echo -e "\twhere COMMAND is one command listing here:"
    echo -e "\t\tstart stop restart status sync run"
    echo -e "\t      PATH_TO_TARGET_PROJECT_DIR is a symlink to or the directory for target project"
    echo -e "\t      REMOTE_IP-s are ip for target hosts"
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
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    echo "Configured remote ip \"$each_i\" is of localhost, ignore it"
                    is_local="Y"
                fi
            done

            if [ -z "$is_local" ]; then
                local h="$remote_user@$each_i"

                echo "Try to sync \"$d\" to remote host \"$h\""

                echo "Syncing directory \"$deref_d\" to host \"$h\""
                "${RSYNC[@]}" "$deref_d/" "$h:$deref_d"
                echo "Syncing directory \"$deref_d\" to host \"$h\" --> DONE"
                if [ "$d" != "$deref_d" ]; then
                    echo "Updating symlink \"$d\" to \"$deref_d\" on host \"$h\""
                    "${SSH[@]}" $h rm -f "$d"
                    "${SSH[@]}" $h ln -sf "$deref_d" "$d"
                    echo "Updating symlink \"$d\" to \"$deref_d\" on host \"$h\" --> DONE"
                fi

                echo "Try to sync \"$d\" to remote host \"$h\" --> DONE"
            fi
        fi
    done
    echo "Try to sync \"$d\" to remote hosts --> DONE"
}

#
# Executing command for project on localhost and remote hosts parallely.
#
# $1: target directory
# $2: command (start/stop/status/check)
__async_run() {
    local d="${1%%/}"
    local c="$2"
    echo "Try to run \"$c\" for \"$d\" on remote hosts"

    local tmp_file=".tmp.$(date +%Y%m%dT%H%M%S.%N)"
    echo -n "" > $tmp_file
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    echo "Configured remote ip \"$each_i\" is of localhost, ignore it"
                    is_local="Y"
                fi
            done

            if [ -z "$is_local" ]; then
                local h="$remote_user@$each_i"

                # delay to run in xargs
                echo "${SSH[@]}" $h bash "$MAIN_SCRIPT_PATH" "$d/" "$c" >> $tmp_file
            else
                # delay to run in xargs
                echo bash "$MAIN_SCRIPT_PATH" "$d/" "$c" >> $tmp_file
            fi
        fi
    done
    echo "echo All Done !!!" >> $tmp_file

    cat $tmp_file | xargs -I "{}" -n1 -P$PARALLELISM bash -c '{}'

    echo rm -f $tmp_file

    echo "Try to run \"$c\" for \"$d\" on remote hosts --> DONE"
}

#
# Executing command for project on localhost and remote hosts one by one.
#
# $1: target directory
# $2: command (start/stop/status/check)
__sync_run() {
    local d="${1%%/}"
    local c="$2"
    echo "Try to run \"$c\" for \"$d\" on remote hosts"
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    echo "Configured remote ip \"$each_i\" is of localhost, ignore it"
                    is_local="Y"
                fi
            done

            if [ -z "$is_local" ]; then
                local h="$remote_user@$each_i"

                "${SSH[@]}" $h bash "$MAIN_SCRIPT_PATH" "$d/" "$c"
            else
                echo bash "$MAIN_SCRIPT_PATH" "$d/" "$c"
            fi
        fi
    done
    echo "Try to run \"$c\" for \"$d\" on remote hosts --> DONE"
}

c="${1:-sync}"; shift || true

d="${1:-}"; shift || true
if [ ! -d "$d" ]; then
    echo "Project directory not exists \"$d\""
    __usage
    exit 1
fi
d="$(realpath -s $d)"

REMOTE_IPS=("")
for each_i in "$@"; do
    REMOTE_IPS[${#REMOTE_IPS[@]}]="$each_i"
done

echo "Try to execute command \"$c\" for project \"$d\" onto \"${REMOTE_IPS[@]}\""
case "$c" in
    "start"|"stop"|"status"| "check")
        __sync_run "$d" "$c"
        ;;
    "restart")
        __sync_run "$d" stop
        __sync_run "$d" start
        ;;
    "sync")
        __sync "$d"
        ;;
    "run")
        __async_run "$d" run
        ;;
    "help")
        __usage
        ;;
    *)
        echo "Unknown command \"$c\""
        __usage
        exit 1
        ;;
esac
echo "Try to execute command \"$c\" for project \"$d\" onto \"${REMOTE_IPS[@]}\" --> DONE"

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
