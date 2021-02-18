#!/usr/bin/env bash

#
# Author: mail _^_ AT _^_ wangbo _^_ im
#

#
# Enable strict bash mode
set -euo pipefail
IFS=$'\t\n'

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
    __warn "Usage: ${SCRIPT_FILE_PATH##*/} COMMAND PATH_TO_TARGET_PROJECT_DIR"
    __warn ""
    __warn -e "\twhere COMMAND is one command listing here:"
    __warn -e "\t\tstart stop restart status"
    __warn -e "\t      PATH_TO_TARGET_PROJECT_DIR is a symlink to or a directory for target project"
    __warn ""
}

if [ $# -eq 2 ]; then
    d="$2"
    d="${d%%/}/"
    if [ -d "$d" ]; then
        case "$1" in
            "run"|"start"|"stop"|"check"|"status")
                bash "$MAIN_SCRIPT_PATH" "$d" "$1"
                ;;
            "restart")
                bash "$MAIN_SCRIPT_PATH" "$d" stop start
                ;;
            "help")
                __usage
                ;;
            *)
                __fatal "Unknown command \"$1\""
                __usage
                exit 1
                ;;
        esac
    else
        __fatal "Project directory \"$d\" not exists"
        __usage
        exit 1
    fi
else
    __fatal "Incorrect number of arguments"
    __usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
