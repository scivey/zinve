#!/usr/bin/env zsh

zinve::noop() { true ; }

zinve::die-impl() {
    [[ $- == *'i'* ]] || exit 1 ;
    return 1 ;
}

_ZINVE__LOADER_SCRIPT_FPATH=${0:A}

zinve::config::build-type::is-prod() {
    [[ ${ZINVE__CONFIG__IS_PROD_BUNDLE:-""} == "1" ]] || return 1 ;
}

zinve::config::build-type::is-dev() {
    if zinve::config::build-type::is-prod; then return 1; fi
}

_zinve::loader::fatal-fallback() {
    local err_origin='loader.zsh'
    local err_msg="$*" ; shift $# ;
    cat >&2 <<-EOD

!!!! ERROR !!!!
    FATAL FAILURE OCCURRED PRIOR TO LOGGING SETUP!

     ERR_ORIGIN: ${err_origin}
    ERR_MESSAGE: ${err_msg}

    ABORTING!

!!!! ERROR !!!!
EOD
    zinve::die-impl ;
}

_zinve::loader::fatal() {
    if type 'zinve::fatal' &>/dev/null; then
        zinve::fatal $@ ;
    else
        _zinve::loader::fatal-fallback $@ ;
    fi
}

function zinve::loader::source() {
    local fname=$1 ;
    if [[ -e "$fname" ]]; then
        # shellcheck source=/dev/null
        if ! . "$fname" ; then
            _zinve::loader::fatal "error sourcing '$fname'"
        fi
    else
        _zinve::loader::fatal "source target '$fname' does not exist"
    fi
}


function zinve::loader::source-dir() {
    local dname
    if [[ $# -lt 1 ]]; then
        _zinve::loader::fatal "$0 requires a directory"
        return 1
    fi
    dname="$1"; shift
    if [[ ! -d "$dname" ]]; then
        local emsg="target directory '$dname' does not exist"
        emsg+=" or is not a directory."
        _zinve::loader::fatal $emsg
        return 1
    fi
    local fname
    while read -r fname; do
        case ${fname:t} in
            *'.disabled' | '_'* ) continue ;;
            *) { zinve::loader::source $fname ; } ;;
        esac
    done < <( find -L "$dname" -maxdepth 1 -mindepth 1 -type f | sort )
}

function zinve::loader::load-all-libs() {
    if zinve::config::build-type::is-dev; then
        zinve::loader::source-dir ${_ZINVE__LOADER_SCRIPT_FPATH:h}/lib
    fi
}

