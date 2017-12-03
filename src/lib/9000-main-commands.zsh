#!/usr/bin/env zsh


zinve-main-cmd::exec() {
    zinve::venv::exec-in-venv-implicit $@ ;
}
zinve-main-cmd::run() {
    zinve::venv::run-in-venv-implicit $@ ;
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

_zinve-main-helper::version-info() {
    printf ' Version: %s\n' "$ZINVE__CONST__VERSION_STR"
    printf 'Revision: %s\n' "$ZINVE__CONST__GIT_REVISION"
}
_zinve-main-helper::list-commands() {
    local pfx='^zinve-main-cmd::'
    functions + \
        | sed -rn '/'$pfx'/ p' \
        | sed -r 's/'$pfx'//'
}
_zinve-main-helper::show-usage() {
    echo "Usage: zinve \$COMMAND \$COMMAND_ARG1 ... \$COMMAND_ARGN" ;
    printf '\n' ;
    echo "Commands: " ;
    _zinve-main-helper::list-commands | sed -r 's/^/      - /' ;
    printf -- '\n----\n\n' ;
}

zinve-main-cmd::help() {
    printf 'zinve\n\n' ;
    _zinve-main-helper::version-info ;
    printf '\n' ;
    _zinve-main-helper::show-usage ;
}

_zinve-error::unknown-command() {
    _zinve-main-helper::show-usage >&2 ;
    [[ $# -gt 0 ]] || _zinve-error::no-command ;
    local cmd=$1 ; shift ;
    local arg_str="''" ;
    [[ $# -lt 1 ]] || { arg_str="'$*'" ; shift $# ; }
    zinve::fatal  "Unknown command '$cmd'.  Input args were: $arg_str"
}

_zinve-error::no-command() {
    _zinve-main-helper::show-usage >&2 ;
    zinve::fatal "Expected a command"
}

zinve-main-dispatch() {
    local cmdname=""
    typeset -a orig_args=()
    [[ $# -lt 1 ]] || orig_args+=( $@ ) ;
    typeset -a py_call=()
    local venv_name="" ;
    local p_name=""
    local base_d=""
    typeset -a req_files=()
    local curr ;
    while [[ $# -gt 0 ]]; do
        curr=$1 ; shift ;
        if [[ $curr == '--' ]]; then
            py_call+=( $@ ) ; shift $# ; break ;
        fi
        if [[ $curr == '-'* ]]; then
            case $curr in
                -p | --python ) { p_name=$1 ; shift ; continue ; } ;;
                -n | --name ) { venv_name=$1 ; shift ; continue ; } ;;
                -b | --base-dir ) { base_d=$1 ; shift ; continue ; } ;;
                -r ) { req_files+=( $1 ) ; shift ; continue ; } ;;
                * ) { zinve::fatal "unknown flag '$curr'" ; exit 1 ; } ;;
            esac
        else
            if [[ $cmdname == "" ]]; then
                cmdname=$curr ; continue ;
            fi
            zinve::fatal "unexpected argument '$curr'" ;
        fi
    done
    [[ $cmdname != "" ]] || _zinve-error::no-command ;
    [[ $base_d == "" ]] || ZINVE__PARAM__VENVS_BASEDIR=$base_d ;
    [[ $p_name == "" ]] || ZINVE__PARAM__TARGET_PYTHON_BIN=$p_name ;
    [[ $venv_name == "" ]] || ZINVE__PARAM__TARGET_NAME=$venv_name ;
    for curr in ${req_files[@]}; do
        ZINVE__PARAM__TARGET_REQUIREMENTS_FILES+=( $curr )
    done
    local cmd_func="zinve-main-cmd::${cmdname}"
    if ! type $cmd_func &>/dev/null; then
        _zinve-error::unknown-command $cmdname ${orig_args[@]} ;
    fi
    ${cmd_func} ${py_call[@]}
}



