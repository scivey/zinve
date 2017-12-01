#!/usr/bin/env zsh

zinve::noop ${ZINVE__LOG_NAME:="zinve"}
zinve::noop ${ZINVE__LOG_LVL_DEBUG:='DEBUG'}
zinve::noop ${ZINVE__LOG_LVL_INFO:='INFO'}
zinve::noop ${ZINVE__LOG_LVL_WARN:='WARN'}
zinve::noop ${ZINVE__LOG_LVL_FATAL:='FATAL'}

typeset -rgx _ZINVE__LOG_DEFAULT_LVL='INFO'

zinve::noop ${ZINVE__CONFIG__LOG_LEVEL:="${_ZINVE__LOG_DEFAULT_LVL}"}

typeset -Agx _ZINVE_LOG_LVL_TO_NUMS ;

_ZINVE_LOG_LVL_TO_NUMS=(
    FATAL 1000
    WARN 2000
    INFO 5000
    DEBUG 10000
)
_zinve::log::log-with-level-unguarded() {
    local lvl=$1 ; shift ;
    local name="$ZINVE__LOG_NAME" ;
    printf '[ %s ] %s  -  %s\n' "$name" "$lvl" "$*" >&2 ;
}
_zinve::log::err-invalid-level-common() {
    _zinve::log::log-with-level-unguarded 'FATAL' "Invalid log level '$1'"
    zinve::die-impl ;
    return 1;
}

_zinve::log::err-invalid-level-arg() {
    local lvl=$1 ; shift ;
    local errmsg="Invalid log level '$lvl' for message '$*'"
    _zinve::log::log-with-level-unguarded 'WARN' $errmsg
    _zinve::log::err-invalid-level-common $lvl ;
}

_zinve::log::err-invalid-level-config() {
    local param_lvl=$1 ; shift ;
    local msg_lvl=$1 ; shift ;
    local ngl='_zinve::log::log-with-level-unguarded'
    typeset -a nglw=( $ngl 'WARN' )

    ${nglw[@]} "Invalid logging configuration."
    ${nglw[@]} "Key ZINVE__CONFIG__LOG_LEVEL has invalid level '$param_lvl'" ;
    local lmsg="''" ;
    if [[ $# -gt 0 ]]; then
        lmsg="'$*'" ; shift $# ;
    fi
    ${nglw[@]} "I was trying to log the following with level $msg_lvl:"
    echo $lmsg | sed -r 's/^/  | /g' >&2 ;
    printf '\n' >&2 ;
    _zinve::log::err-invalid-level-common $param_lvl ;
}

_zinve::log::log-with-level() {
    local lvl=${1:u} ; shift ;
    typeset -i lvl_score=0
    local lvl_score_str="" ;
    lvl_score_str=${_ZINVE_LOG_LVL_TO_NUMS[$lvl]:-""}
    if [[ $lvl_score_str == "" ]]; then
        _zinve::log::err-invalid-level-arg $lvl $@ ; return 1 ;
    fi
    lvl_score=$lvl_score_str
    local lvl_param_str=${ZINVE__CONFIG__LOG_LEVEL:-""}
    if [[ $lvl_param_str == "" ]]; then
        lvl_param_str=${_ZINVE__LOG_DEFAULT_LVL} ;
    fi
    typeset -i lvl_param_no=0
    local lvl_param_no_str=""
    lvl_param_no_str=${_ZINVE_LOG_LVL_TO_NUMS[$lvl_param_str]:-""}
    if [[ $lvl_param_no_str == "" ]]; then
        local inval_p='_zinve::log::err-invalid-level-config'
        $inval_p $lvl_param_str $lvl $@ ; return 1 ;
    fi
    lvl_param_no=$lvl_param_no_str
    if [[ $lvl_score -le $lvl_param_no_str ]]; then
        _zinve::log::log-with-level-unguarded $lvl $@
    fi
}

zinve::log::info() {
    _zinve::log::log-with-level ${ZINVE__LOG_LVL_INFO} $@
}

zinve::log::warn() {
    _zinve::log::log-with-level ${ZINVE__LOG_LVL_WARN} $@
}

zinve::log::debug() {
    _zinve::log::log-with-level ${ZINVE__LOG_LVL_DEBUG} $@
}

zinve::log::fatal() {
    _zinve::log::log-with-level ${ZINVE__LOG_LVL_FATAL} $@
    zinve::die-impl ;
}

alias zinve::info='zinve::log::info'
alias zinve::warn='zinve::log::warn'
alias zinve::fatal='zinve::log::fatal'
alias zinve::debug='zinve::log::fatal'


