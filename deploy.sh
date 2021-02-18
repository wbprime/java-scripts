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
    __warn "Usage: ${SCRIPT_FILE_PATH##*/} artifact_file project_dir"
    __warn "   OR: ${SCRIPT_FILE_PATH##*/} project_dir artifact_file"
    __warn ""
}

if [ $# -eq 2 ]; then
    a="$1"
    b="$2"

    artifact_file=""
    target_dir=""

    if [ -f "$a" ]; then
        artifact_file="$a"
        target_dir="${b%%/}"
    elif [ -f "$b" ]; then
        artifact_file="$b"
        target_dir="${a%%/}"
    else
        __fatal "No artifact file specified"
        __usage
        exit 1
    fi

    bash "$MAIN_SCRIPT_PATH" "$target_dir" deploy "$artifact_file"

    __warn ""
    __warn "Note that target project service is not restarted"
    __warn "You should restarted it manually against \"$target_dir\""
else
    __fatal "Incorrect number of arguments"
    __usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
