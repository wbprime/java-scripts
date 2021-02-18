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
    __warn "Usage: ${SCRIPT_FILE_PATH##*/} project_dir"
    __warn ""
}

if [ $# -eq 1 ]; then
    target_dir="$1"

    if [ -d "$target_dir" ]; then
        bash "$MAIN_SCRIPT_PATH" "$target_dir" rollback

        __warn ""
        __warn "Note that target project service is not restarted"
        __warn "You should restarted it manually against \"$target_dir\""
        __warn ""
    else
        __fatal "Project directory \"$target_dir\" not exists"
        __usage
        exit 1
    fi
else
    __fatal "Incorrect number of arguments"
    __usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
