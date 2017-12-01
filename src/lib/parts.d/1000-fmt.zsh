#!/usr/bin/env zsh

zinve::noop ${ZINVE__CONFIG__WANT_COLOR:="1"}

zinve::noop ${ZINVE__CONFIG__HAVE_COLOR:=""}

if [[ ${ZINVE__CONFIG__HAVE_COLOR} == "" ]]; then
    if [[ ${ZINVE__CONFIG__WANT_COLOR} == "1" ]]; then
        if autoload -Uz colors && colors; then
            ZINVE__CONFIG__HAVE_COLOR="1"
        else
            ZINVE__CONFIG__HAVE_COLOR="0"
        fi
    else
        ZINVE__CONFIG__HAVE_COLOR="0"
    fi
fi

_zinve::fmt::use-colors() {
    [[ ${ZINVE__CONFIG__WANT_COLOR:-""} == "1" ]] || return 1 ;
    [[ ${ZINVE__CONFIG__HAVE_COLOR:-""} == "1" ]] || return 1 ;
}

# adapted from https://github.com/Tarrasch/zsh-colors
zinve::fmt::fg() {
    local ison=false
    ! _zinve::fmt::use-colors || ison=true ;
    local fg_color=$1 ; shift ;
    [ $ison = false ] || printf %s "$fg[$fg_color]"

    if [[ $# -lt 1 ]]; then
        cat
    else
        print "$@"
    fi
    [ $ison = false ] || printf %s "$reset_color"

}

