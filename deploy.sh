#!/usr/bin/env bash

#
# Author: mail _^_ AT _^_ wangbo _^_ im
#

#
# Enable strict bash mode
set -euo pipefail
IFS=$'\t\n'

#
# Dirs
SCRIPT_FILE_PATH=`realpath $0`
SCRIPT_DIR_PATH=`dirname "${SCRIPT_FILE_PATH}"`
MAIN_SCRIPT_PATH="${SCRIPT_DIR_PATH}/main.script"

__usage() {
    echo ""
    echo "Usage: ${SCRIPT_FILE_PATH##*/} artifact_file project_dir"
    echo "   OR: ${SCRIPT_FILE_PATH##*/} project_dir artifact_file"
    echo ""
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
        echo "No artifact file specified"
        __usage
        exit 1
    fi

    bash "$MAIN_SCRIPT_PATH" "$target_dir" deploy "$artifact_file"

    echo ""
    echo "Note that target project service is not restarted"
    echo "You should restarted it manually against \"$target_dir\""
else
    echo "Incorrect number of arguments"
    __usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
