#!/usr/bin/env bash

#
# Author: mail _^_ AT _^_ wangbo _^_ im
#

#
# Enable strict bash mode
set -euo pipefail
IFS=$'\t\n'

REMOTE_USER="${REMOTE_USER:-}"

PARALLELISM="${PARALLELISM:-4}"

SSH=(
    #"echo"
    "ssh"
    "-4"
    "-q"
    "-T"
)
SCP=(
    #"echo"
    "scp"
    "-4"
    "-q"
    # Limit QPS in 1024 Kbit/s
    # "-l" "1024"
)
RSYNC=(
    #"echo"
    "rsync"
    "-4"
    "-a"
    "-q"
    # "--bwlimit=1.5m"
)

LOG_LEVEL="${LOG_LEVEL:-WARN}"
export LOG_LEVEL

#
# Dirs
SCRIPT_FILE_PATH=`realpath $0`
SCRIPT_DIR_PATH=`dirname "${SCRIPT_FILE_PATH}"`
MAIN_SCRIPT_PATH="${SCRIPT_DIR_PATH}/main.script"

# source common config
for each_i in "${SCRIPT_DIR_PATH}"/include.*.conf; do
    if [ -f "$each_i" ]; then . "$each_i"; fi
done

__usage() {
    __warn ""
    __warn "Usage: ${SCRIPT_FILE_PATH##*/} COMMAND PATH_TO_TARGET_PROJECT_DIR [REMOTE_IP ...]"
    __warn ""
    __warn "\twhere COMMAND is one command listing here:"
    __warn "\t\tstart stop restart status sync run"
    __warn "\t      PATH_TO_TARGET_PROJECT_DIR is a symlink to or the directory for target project"
    __warn "\t      REMOTE_IP-s are ip for target hosts"
    __warn ""
    __warn "OR ${SCRIPT_FILE_PATH##*/} ssh exec [args ...]"
    __warn "OR ${SCRIPT_FILE_PATH##*/} scp file_to_scp_from_remote_to_local [more_files ...]"
    __warn ""
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
    __debug "Try to sync \"$d\" to remote hosts"
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    __info "Configured remote ip \"$each_i\" is of localhost, ignore it"
                    is_local="Y"
                fi
            done

            if [ -z "$is_local" ]; then
                local h="$remote_user@$each_i"

                __debug "Try to sync \"$d\" to remote host \"$h\""

                __debug "Syncing directory \"$deref_d\" to host \"$h\""
                "${RSYNC[@]}" "$deref_d/" "$h:$deref_d"
                __info "Syncing directory \"$deref_d\" to host \"$h\" --> DONE"
                if [ "$d" != "$deref_d" ]; then
                    __debug "Updating symlink \"$d\" to \"$deref_d\" on host \"$h\""
                    "${SSH[@]}" $h rm -f "$d"
                    "${SSH[@]}" $h ln -sf "$deref_d" "$d"
                    __info "Updating symlink \"$d\" to \"$deref_d\" on host \"$h\" --> DONE"
                fi

                __debug "Try to sync \"$d\" to remote host \"$h\" --> DONE"
            fi
        fi
    done
    __debug "Try to sync \"$d\" to remote hosts --> DONE"
}

#
# Executing command for project on localhost and remote hosts parallely.
#
# $1: target directory
# $2: command (start/stop/status/check)
__async_run() {
    local d="${1%%/}"
    local c="$2"

    local tmp_file=".tmp.$(date +%Y%m%dT%H%M%S.%N)"
    echo -n "" > $tmp_file
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    is_local="Y"
                fi
            done

            local h="$remote_user@$each_i"
            if [ -z "$is_local" ]; then
                # delay to run in xargs
                echo "${SSH[@]}" $h bash "$MAIN_SCRIPT_PATH" "$d/" "$c" >> $tmp_file
            else
                # delay to run in xargs
                echo bash "$MAIN_SCRIPT_PATH" "$d/" "$c" >> $tmp_file
            fi
        fi
    done
    echo "echo All Done !!!" >> $tmp_file

    __debug "Try to run \"$c\" for \"$d\" on all configured hosts"
    cat $tmp_file | xargs -I "{}" -n1 -P$PARALLELISM bash -c '{}'
    __info "Try to run \"$c\" for \"$d\" on all configured hosts --> DONE"

    rm -f $tmp_file
}

#
# Executing command for project on localhost and remote hosts one by one.
#
# $1: target directory
# $2: command (start/stop/status/check)
__sync_run() {
    local d="${1%%/}"
    local c="$2"
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    is_local="Y"
                fi
            done

            local h="$remote_user@$each_i"
            if [ -z "$is_local" ]; then
                __debug "Try to run \"$c\" for \"$d\" on remote host \"$h\""
                "${SSH[@]}" $h bash "$MAIN_SCRIPT_PATH" "$d/" "$c"
                __info "Try to run \"$c\" for \"$d\" on remote host \"$h\" --> DONE"
            else
                __debug "Try to run \"$c\" for \"$d\" on local host \"$h\""
                bash "$MAIN_SCRIPT_PATH" "$d/" "$c"
                __info "Try to run \"$c\" for \"$d\" on local host \"$h\" --> DONE"
            fi
        fi
    done
}

#
# Run SCP on localhost and remote hosts one by one.
#
# $@: files to be scp back
__scp() {
    local msg=""
    for each_f in "$@"; do
        local lf="${each_f##*/}"
        lf="${lf%%/}"
        for each_i in "${REMOTE_IPS[@]}"; do
            if [ -n "$each_i" ]; then
                is_local=""
                for each_j in "${local_ips[@]}"; do
                    if [ "$each_i" == "$each_j" ]; then
                        is_local="Y"
                    fi
                done

                local h="$remote_user@$each_i"

                local lff="${lf}_${each_i}"

                msg="Try to scp \"$each_f\" as \"$lff\""
                if [ -z "$is_local" ]; then
                    msg="$msg from remote host \"$h\""
                else
                    msg="$msg from localhost"
                fi
                __debug "$msg"

                if [ -z "$is_local" ]; then
                    "${SCP[@]}" "$h:$each_f" "${lff}"
                else
                    cp -f "$each_f" "${lff}"
                fi

                __info "$msg --> DONE"
            fi
        done
    done
}

#
# Run SSH on localhost and remote hosts one by one.
#
# $@: exec and args to be ran
__ssh() {
    local msg=""
    for each_i in "${REMOTE_IPS[@]}"; do
        if [ -n "$each_i" ]; then
            is_local=""
            for each_j in "${local_ips[@]}"; do
                if [ "$each_i" == "$each_j" ]; then
                    is_local="Y"
                fi
            done

            local h="$remote_user@$each_i"

            msg="Try to exec"
            for each_k in "$@"; do
                msg="$msg \"$each_k\""
            done

            if [ -z "$is_local" ]; then
                msg="$msg on remote host \"$h\""
            else
                msg="$msg on localhost"
            fi
            __debug "$msg"

            if [ -z "$is_local" ]; then
                "${SSH[@]}" $h "$@"
            else
                "$@"
            fi

            __info "$msg --> DONE"
        fi
    done
}

c="${1:-sync}"; shift || true

d="${1:-}"; shift || true
if [ -n "$d" ]; then d="$(realpath -s $d)"; fi

__assert_directory_exists_or_exit() {
    if [ -z "$1" ]; then
        __fatal "Project directory not specified"
        __usage
        exit 1
    elif [ ! -d "$1" ]; then
        __fatal "Project directory \"$1\" not exists"
        __usage
        exit 1
    fi
}

REMOTE_IPS=(""); tmp=0
for each_i in "$@"; do
    REMOTE_IPS[$((tmp++))]="$each_i"
done

__debug "Try to execute command \"$c\" for project \"$d\" onto \"${REMOTE_IPS[@]}\""
case "$c" in
    "start"|"stop"|"status"| "check")
        __assert_directory_exists_or_exit "$d"

        __sync_run "$d" "$c"
        ;;
    "restart")
        __assert_directory_exists_or_exit "$d"

        __sync_run "$d" stop
        __sync_run "$d" start
        ;;
    "sync")
        __assert_directory_exists_or_exit "$d"

        __sync "$d"
        ;;
    "run")
        __assert_directory_exists_or_exit "$d"

        __async_run "$d" run
        ;;
    "ssh "*)
        c="${c#ssh }"
        IFS=' '
        S=("")
        i=0
        for each_i in $c; do
            S[$((i++))]="$each_i"
        done
        IFS=$'\t\n'
        __ssh "${S[@]}"
        ;;
    "scp "*)
        c="${c#scp }"
        IFS=' '
        S=("")
        i=0
        for each_i in $c; do
            S[$((i++))]="$each_i"
        done
        IFS=$'\t\n'
        __scp "${S[@]}"
        ;;
    "help")
        __usage
        ;;
    *)
        __fatal "Unknown command \"$c\""
        __usage
        exit 1
        ;;
esac
__info "Try to execute command \"$c\" for project \"$d\" onto \"${REMOTE_IPS[@]}\" --> DONE"

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
