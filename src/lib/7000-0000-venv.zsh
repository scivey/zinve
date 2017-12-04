#!/usr/bin/env zsh

setopt errexit
set -uo pipefail

zinve::make-fs-cache-key() {
    local bad_pat='[/.}{?\!]'
    echo ${1//${~bad_pat}/_}
}

zinve::venv::ensure-by-path() {
    typeset -A optmap
    typeset -a reqs=()
    typeset -a adef=()
    zparseopts -a adef -A optmap r+:=reqs p: -python: d: -venv-dir:
    local venv_d=""
    read -r venv_d < <( zinve::key-coalesce optmap '-d' '--venv-dir' )
    local pybin=""
    if ! read -r pybin < <( zinve::key-coalesce optmap '-p' '--python' ); then
        pybin='python'
    fi
    typeset -a bad_elems=( '-r' )
    reqs=( ${reqs:|bad_elems} )
    local venv_z_state_d=$venv_d/.zinve
    local upit=false
    if [[ ! -d $venv_d ]]; then
        mkdir -p ${venv_d:h} ;
        virtualenv -p ${pybin} $venv_d ;
        ${venv_d}/bin/pip install --upgrade pip
        upit=true
    fi
    local dig_d=$venv_z_state_d/digest
    local dig_tmp_d=$venv_z_state_d/tmp/digest/
    mkdir -p $dig_d $dig_tmp_d;
    typeset -a needed_req_files=()
    typeset -A output_digests; output_digests=() ;
    local curr_reqf
    for curr_reqf in ${reqs[@]}; do
        curr_reqf=${curr_reqf:A}
        local dig_key;
        read -r dig_key < <( zinve::make-fs-cache-key $curr_reqf ) ;
        local dig_f="${dig_d}/$dig_key.sha256.asc"
        local curr_dig; read -r curr_dig < <( zinve::sha256 $curr_reqf )
        curr_dig="${curr_dig// /}"
        local prev_dig=""
        if [[ -e $dig_f ]]; then
            read -r prev_dig < $dig_f ;
            prev_dig="${prev_dig// /}"
        fi
        if [[ $prev_dig == $curr_dig ]]; then
            continue
        fi
        upit=true
        output_digests+=( $dig_f $curr_dig )
        needed_req_files+=( $curr_reqf )
    done
    if (! $upit); then return 0 ; fi

    if [[ ${#needed_req_files} -gt 0 ]]; then
        typeset -a pip_call=(
            "$venv_d/bin/pip" install
        )
        for curr_reqf in ${needed_req_files[@]}; do
            pip_call+=( '-r' $curr_reqf )
        done
        if ! ${pip_call[@]}; then
            zinve::fatal "call failed: '${pip_call[*]}'"
            return 1 ;
        fi
    fi
    for digf digv in ${(kv)output_digests}; do
        local tempf="${dig_tmp_d}/${digf:t}.tmp~"
        rm -f $tempf ; echo $digv > $tempf ;
        mv -f $tempf $digf ;
    done
}

_zinve::venv::run-or-exec-in-venv() {
    local zinve_cmd_name=${1:u} ; shift ;
    zinve::venv::ensure-by-path $@ || zinve::fatal "venv check failed" ;
    typeset -a nothing=()
    typeset -A optmap2 ; optmap2=() ;
    zparseopts -D -E -a nothing -A optmap2 d: -venv-dir:
    local venv_d=""
    read -r venv_d < <( zinve::key-coalesce optmap2 '-d' '--venv-dir' )

    typeset -a cmd_parts=() ; local curr ;
    while [[ $# -gt 0 ]]; do
        curr=$1 ; shift ;
        case $curr in
            -- ) { cmd_parts+=( $@ ) ; shift $# ; break ; } ;;
            *) { continue ; }
        esac
    done
    local bin_d=$venv_d/bin
    local default_bin="python"
    [[ ! -e $bin_d/ipython ]] || default_bin=ipython ;

    local bin_name=""
    local bin_fpath=""
    typeset -a bin_args=() ;
    if [[ ${#cmd_parts} -lt 1 ]]; then
        bin_name=$default_bin
    else
        bin_name=${cmd_parts[1]} ;
        cmd_parts[1]=() ;
    fi

    bin_fpath=${bin_d}/${bin_name}
    if [[ ! -e $bin_fpath ]]; then
        zinve::fatal "Can't find '$bin_name'. Expected at path '$bin_fpath'" ;
        return 1 ; # not reached
    fi

    typeset -a fin_call=( $bin_fpath )
    [[ ${#cmd_parts} -lt 1 ]] || fin_call+=( ${cmd_parts[@]} ) ;

    case $zinve_cmd_name in
        CMD_EXEC) { exec ${fin_call[@]} ; } ;;
        CMD_RUN) { ${fin_call[@]} ; return ; } ;;
        *) { zinve::fatal "$0 invalid command '$cmd_name'" ; } ;;
    esac
}



zinve::venv::run-in-venv() {
    _zinve::venv::run-or-exec-in-venv 'CMD_EXEC' $@ ;
}

zinve::venv::exec-in-venv() {
    _zinve::venv::run-or-exec-in-venv 'CMD_RUN' $@ ;
}

zinve::venv::debug() {
    echo "VARS: " ;
    printf -- '%*s\n\n' 32 "" ;

    typeset -p | sort | ansifilter | sed -r 's/^/      | /' ;
    printf '\n' ;
    printf -- '%*s\n' 32 "" ;
}


