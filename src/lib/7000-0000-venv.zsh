#!/usr/bin/env zsh

setopt errexit
set -uo pipefail

zinve::make-fs-cache-key() {
    local bad_pat='[/.}{?\!]'
    echo ${1//${~bad_pat}/_}
}
zinve::try-rmdir() {
    if ! rmdir $1 &>/dev/null; then return 1; fi
}

_zinve::venv::find-py-bins() {
    local dname=$1 ; shift ;
    find $dname \( -type f -o -type l \) -a -name 'python*' -printf '%P\n' \
        | sed -rn '/^python[0-9]/ p'
}

_zinve::version-str::has-minor() {
    [[ ${1// /} =~ ^[0-9]+.[0-9]+ ]] || return 1
}

_zinve::venv::get-version-from-bin-dir() {
    local curr="";
    local bin_dir=$1 ;
    [[ -d $bin_dir ]] || zinve::fatal "'$bin_dir' is not a directory" ;
    local vstr=""
    while read -r curr ; do
        if _zinve::version-str::has-minor $curr ; then
            vstr=$curr ; break ;
        elif [[ $vstr == "" ]]; then
            vstr=$curr ;
        fi
    done < <( _zinve::venv::find-py-bins $bin_d | sed -r 's/python//' )
    if [[ $vstr == "" ]] ; then
        zinve::warn "couldn't determine python version in ${bin_d}"
        return 1 ;
    fi
    echo $vstr ;
}

_zinve::venv::find-wanted-python-version() {
    local pybin=$1 ; shift ;
    local pybase=${pybin:t}
    if [[ $pybase != python* ]]; then
        zinve::fatal "$0 - don't know what to do with '$pybase' ('$pybin')"
    fi
    if [[ $pybase =~ ^python[0-9].* ]]; then
        echo ${pybase##python}
    else
        local bin_d=""
        if [[ ${pybin} == '/'* ]]; then
            bin_d=$pybin
        else
            read -r bin_d < <( whence -p $pybase ) ;
            bin_d=${bin_d:h}
        fi
        _zinve::venv::get-version-from-bin-dir $bin_d ;
    fi
}

zinve::venv::ensure-by-path() {
    typeset -A optmap
    typeset -a reqs=()
    typeset -a adef=()
    zparseopts -a adef -A optmap r+:=reqs \
            p: -python: d: -venv-dir: \
            f -force

    local venv_d=""
    read -r venv_d < <( zinve::key-coalesce optmap '-d' '--venv-dir' )
    local pybin=""
    if ! read -r pybin < <( zinve::key-coalesce optmap '-p' '--python' ); then
        pybin='python'
    fi
    local is_force=false ;
    typeset -a bad_elems=( '-r' )
    reqs=( ${reqs:|bad_elems} )
    local venv_z_state_d=$venv_d/.zinve
    local upit=false
    local bin_d=$venv_d/bin
    local msg=""
    if [[ -d $venv_d ]]; then
        if [[ -d $bin_d ]]; then
            local wanted_v="" ;
            read -r wanted_v < <( {
                _zinve::venv::find-wanted-python-version $pybin
            } )
            local current_v=""
            read -r current_v < <( {
                _zinve::venv::get-version-from-bin-dir $bin_d
            } )
            local vmatch=true ;
            if [[ $wanted_v == *'.'* ]]; then
                if [[ $wanted_v != $current_v ]]; then
                    vmatch=false ;
                fi
            else
                if [[ $current_v != "$wanted_v"* ]]; then
                    vmatch=false
                fi
            fi
            if ( $vmatch ); then
                zinve::info "versions match : '$current_v' == '$wanted_v'"
            else
                msg="python version '$current_v' in '$venv_d' does not"
                msg+=" match target version '$wanted_v'."
                vinve::warn $msg ;
                msg=""
                if ( $is_force ); then
                    msg="Because --force is enabled, I'm killing $venv_d"
                    msg+=" and rebuilding."
                    zinve::warn $msg ;
                    rm -rf $venv_d ;
                    zinve::warn "( removed $venv_d )"
                else
                    msg="Aborting. If you want me to rebuild $venv_d with"
                    msg+=" version '$wanted_v', pass the --force flag."
                    zinve::fatal "$msg" ; return 1 ;
                fi
            fi
        else
            zinve::warn "'$venv_d' doesn't seem to be a valid virtualenv."
            if zinve::try-rmdir $venv_d ; then
                msg="Target '$venv_d' existed but wasn't a virtualenv."
                msg+=" It was empty, so I removed it."
                zinve::warn $msg ;
            else
                if ( $is_force ); then
                    msg="Existing target '$venv_d' is invalid and --force"
                    msg+=" is enabled: removing '$venv_d' and rebuilding."
                    zinve::warn $msg ;
                    rm -rf $venv_d ;
                else
                    msg="Target dir '$venv_d' exists and is non-empty, but it"
                    msg+=" doesn't look like a virtualenv dir."
                    msg+=" If you want me to fix it, pass --force."
                    zinve::fatal $msg ; return 1 ;
                fi
            fi
        fi
    fi

    if [[ -d $venv_d ]]; then
        true
    else
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


