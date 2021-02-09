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
    echo "Usage: ${SCRIPT_FILE_PATH##*/} COMMAND PATH_TO_TARGET_PROJECT_DIR"
    echo ""
    echo -e "\twhere COMMAND is one command listing here:"
    echo -e "\t\tstart stop restart status"
    echo -e "\t      PATH_TO_TARGET_PROJECT_DIR is a symlink to or a directory for target project"
    echo ""
}

if [ $# -eq 2 ]; then
    d="$2"
    d="${d%%/}/"
    if [ -d "$d/" ]; then
        case "$1" in
            "start"|"stop"|"check"|"status")
                bash "$MAIN_SCRIPT_PATH" "$2" "$1"
                ;;
            "restart")
                bash "$MAIN_SCRIPT_PATH" "$2" stop start
                ;;
            "help")
                usage
                ;;
            *)
                echo "Unknown command \"$1\""
                usage
                exit 1
                ;;
        esac
    else 
        echo "Project directory not exists"
        usage
        exit 1
    fi
else
    echo "Incorrect number of arguments"
    usage
    exit 1
fi

# vim:set nu rnu list et sr ts=4 sw=4 ft=sh:
