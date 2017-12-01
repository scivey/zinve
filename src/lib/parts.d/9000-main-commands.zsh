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

zinve-main-dispatch() {
    local cmdname=""
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
    if [[ $cmdname != "" ]] || zinve::fatal "Expected a command." ;
    [[ $base_d == "" ]] || ZINVE__PARAM__VENVS_BASEDIR=$base_d ;
    [[ $p_name == "" ]] || ZINVE__PARAM__TARGET_PYTHON_BIN=$p_name ;
    [[ $venv_name == "" ]] || ZINVE__PARAM__TARGET_NAME=$venv_name ;
    for curr in ${req_files[@]}; do
        ZINVE__PARAM__TARGET_REQUIREMENTS_FILES+=( $curr )
    done
    local cmd_func="zinve-main-cmd::${cmdname}"
    ${cmd_func} ${py_call[@]}
}



