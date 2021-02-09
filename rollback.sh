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

usage() {
    echo ""
    echo "Usage: ${SCRIPT_FILE_PATH##*/} project_dir"
    echo ""
}

if [ $# -eq 1 ]; then
    target_dir="$1"

    if [ -d "$target_dir" ]; then
        bash "$MAIN_SCRIPT_PATH" "$target_dir" rollback

        echo ""
        echo "Note that target project service is not restarted"
        echo "You should restarted it manually against \"$target_dir\""
    else
        echo "Project directory \"$target_dir\" not exists"
        usage
        exit 1
    fi
else
    echo "Incorrect number of arguments"
    usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
