#!/usr/bin/env zsh

ds-zdot::noop() { true ; }

ds-zdot::noop ${DS__ZDOT__CORE_D:=${0:A:h}}

_ds-zdot::fallback-fatal-error() {
    local err_origin_arg=$1 ; shift ;
    local err_origin=$err_origin_arg ;
    if [[ ! -z ${ZDOTDIR+x} ]]; then
        typeset -aU zdot_replacers=( ${ZDOTDIR:A} ${ZDOTDIR} )
        local zdotrep
        for zdotrep in ${zdot_replacers[@]}; do
            err_origin=${err_origin_arg/#${zdotrep}/'$ZDOTDIR'}
            if [[ $err_origin != $err_origin_arg ]]; then
                break
            fi
        done
    fi
    local err_msg="$*" ; shift $# ;
    cat >&2 <<-EOD

!!!! ERROR !!!!
    FATAL FAILURE OCCURRED PRIOR TO LOGGING SETUP!

     ERR_ORIGIN: ${err_origin}
    ERR_MESSAGE: ${err_msg}

    ABORTING!

!!!! ERROR !!!!
EOD
    return 1 ;
}


declare -a _dsz_core_part_list=(
    'core-logging.zsh'
    'core-util.zsh'
)
_dsz_core_part=""
for _dsz_core_part in ${_dsz_core_part_list[@]}; do
    _dsz_core_part=${DS__ZDOT__CORE_D}/${_dsz_core_part}
    if [[ -e ${_dsz_core_part} ]]; then
        . ${_dsz_core_part} ; continue ;
    else
        _ds-zdot::fallback-fatal-error ${0:A} \
            "SOURCE TARGET '${_dsz_core_part}' DOES NOT EXIST!" ;
        return 1 ;
    fi
done
unset _dsz_core_part
unset _dsz_core_part_list

