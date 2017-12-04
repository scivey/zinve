#!/usr/bin/env zsh

zinve-main-cmd::exec() {
    zinve::venv::exec-in-venv $@ ;
}
zinve-main-cmd::run() {
    zinve::venv::run-in-venv $@ ;
}

zinve-main-cmd::debug2() {
    zinve::venv::debug $@ ;
}

zinve-main-cmd::debug() {
    echo "VARS: " ;
    printf -- '%*s\n\n' 32 "" ;

    typeset -p | sort | ansifilter | sed -r 's/^/      | /' ;
    printf '\n' ;
    printf -- '%*s\n' 32 "" ;
}

zinve-main-cmd::help() {
    local vstr="$ZINVE__CONST__VERSION_STR"
    printf 'zinve-%s\n\n' $vstr ;
    _zinve-main-helper::show-usage ;
    printf '\n' ;
}

zinve-main-cmd::version() {
    _zinve-main-helper::version-info ;
}

zinve-main-dispatch() {
    local cmdname=""
    typeset -a orig_args=()
    [[ $# -lt 1 ]] || orig_args+=( $@ ) ;
    if [[ $# -eq 1 ]] && [[ $1 == '-'* ]]; then
        case $1 in
            -h | --help ) { cmdname='help' ; shift ; } ;;
            -v | --version) { cmdname='version' ; shift ; } ;;
        esac
    fi
    if [[ $cmdname == "" ]] && [[ $# -gt 0 ]] && [[ $1 != '-'* ]]; then
        cmdname=$1 ; shift ;
    fi
    [[ $cmdname != "" ]] || zinve-error::no-command ;
    local cmd_func="zinve-main-cmd::${cmdname}"
    if ! type $cmd_func &>/dev/null; then
        zinve-error::unknown-command $cmdname ${orig_args[@]} ;
    fi
    ${cmd_func} $@ ;
}

