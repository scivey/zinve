#!/usr/bin/env zsh

function ds-zdot::source() {
    local fname=$1 ;
    if [[ -e "$fname" ]]; then
        # shellcheck source=/dev/null
        if ! . "$fname" ; then
            ds-zdot::warn "error sourcing '$fname'"
        fi
    else
        ds-zdot::warn "source target '$fname' does not exist"
    fi
}


function ds-zdot::source-all() {
    local dname
    if [[ $# -lt 1 ]]; then
        ds-zdot::warn "z-source-all requires a directory"
        return 1
    fi
    dname="$1"; shift
    if [[ ! -d "$dname" ]]; then
        ds-zdot::warn "target directory '$dname' does not exist or is not a directory."
        return 1
    fi
    local fname
    while read -r fname; do
        if [[ "$fname" == *".disabled."* ]]; then
            continue
        fi
        ds-zdot::source $fname ;
    done < <( find -L "$dname" -maxdepth 1 -mindepth 1 -type f | sort )
}


