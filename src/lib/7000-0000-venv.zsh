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
    local failmsg="$0 - don't know what to do with '$pybase' ('$pybin')"
    if [[ $pybase != python* ]]; then
        zinve::fatal $failmsg ; return 1 ;
    fi
    if [[ $pybase =~ ^python[0-9].* ]]; then
        echo ${pybase##python} ; return ;
    fi
    if [[ $pybase != 'python' ]]; then
        zinve::fatal $failmsg ; return 1 ;
    fi
    local bin_d=""
    if [[ ${pybin} == '/'* ]]; then
        bin_d=${pybin:h}
    else
        read -r bin_d < <( whence -p $pybase ) ;
        bin_d=${bin_d:h}
    fi
    # since the user didn't specify a point version, we just match
    # on major
    _zinve::venv::get-version-from-bin-dir $bin_d \
        | sed -r 's/\..*//'
}

_zinve::venv::exec-in-venv-unchecked() {
    local venv_dir=$1 ; shift ;
    PATH="${venv_dir}/bin:${PATH}" VIRTUAL_ENV="$venv_dir" exec $@
}

_zinve::venv::run-in-venv-unchecked() {
    local venv_dir=$1 ; shift ;
    PATH="${venv_dir}/bin:${PATH}" VIRTUAL_ENV="$venv_dir" $@
}

zinve::venv::ensure-by-path() {
    typeset -a reqs=()
    typeset -a adef=()
    typeset -a force_list=()
    typeset -a pybin_list=()
    typeset -a dir_list=()
    zparseopts -a adef r+:=reqs \
            f=force_list -force=force_list \
            p:=pybin_list -python:=pybin_list \
            d:=dir_list -venv-dir:=dir_list

    local venv_d=""
    local kcfn='zinve::key-coalesce'
    if [[ ${#dir_list} -ge 2 ]]; then
        venv_d=${dir_list[2]}
    else
        zinve::fatal "Specify target directory with -d / --venv-dir." ;
    fi
    if [[ ${#pybin_list} -ge 2 ]]; then
        pybin=${pybin_list[2]}
    else
        pybin='python'
    fi
    typeset -a bad_elems=( '-r' )
    reqs=( ${reqs:|bad_elems} )

    local is_force=false ;
    if [[ ${#force_list} -gt 0 ]]; then
        is_force=true ;
    fi

    local venv_z_state_d=$venv_d/.zinve
    local upit=false
    local bin_d=$venv_d/bin
    local msg=""
    if [[ -d $venv_d ]]; then
        # if the venv dir exists, we want to make sure that:
        #   - it's actually a virtualenv.
        #   - its python version matches the one specified
        #     by the -p / --python CLI flag.
        #
        # currently the first check is handled by looking for
        # $venv_d/bin/python.
        #
        if [[ -d $bin_d ]] && [[ -e $bin_d/python ]] then
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
                true
                # zinve::info "versions match : '$current_v' == '$wanted_v'"
            else
                msg="python version '$current_v' in '$venv_d' does not"
                msg+=" match target version '$wanted_v'."
                zinve::warn $msg ;
                msg=""
                if ( $is_force ); then
                    msg="Because -f (force) is enabled, I'm killing $venv_d"
                    msg+=" and rebuilding."
                    zinve::warn $msg ;
                    rm -rf $venv_d ;
                    zinve::warn "( removed $venv_d )"
                else
                    msg="Aborting. If you want me to rebuild $venv_d with"
                    msg+=" version '$wanted_v', pass the -f (force) flag."
                    zinve::fatal "$msg" ; return 1 ;
                fi
            fi
        else
            # $venv_d/bin/python does not exist.
            zinve::warn "'$venv_d' doesn't seem to be a valid virtualenv."
            if zinve::try-rmdir $venv_d ; then
                msg="Target '$venv_d' existed but wasn't a virtualenv."
                msg+=" It was empty, so I removed it."
                zinve::warn $msg ;
            else
                if ( $is_force ); then
                    msg="Existing target '$venv_d' is invalid and -f (force)"
                    msg+=" is enabled: removing '$venv_d' and rebuilding."
                    zinve::warn $msg ;
                    rm -rf $venv_d ;
                else
                    msg="Target dir '$venv_d' exists and is non-empty, but it"
                    msg+=" doesn't look like a virtualenv dir."
                    msg+=" If you want me to fix it, pass -f (force)."
                    zinve::fatal $msg ; return 1 ;
                fi
            fi
        fi
    fi

    if [[ ! -d $venv_d ]]; then
        mkdir -p ${venv_d:h} ;
        virtualenv -p ${pybin} $venv_d ;
        _zinve::run-in-venv-unchecked $venv_d \
            ${venv_d}/bin/pip install --upgrade pip
        upit=true
    fi

    local dig_d=$venv_z_state_d/digest
    local dig_tmp_d=$venv_z_state_d/tmp/digest/
    mkdir -p $dig_d $dig_tmp_d;
    typeset -a needed_req_files=()
    typeset -A output_digests; output_digests=() ;
    local curr_reqf
    local dig_fn dig_suffix
    read -r dig_fn dig_suffix < <( zinve::digest::choose-fn-and-suffix )
    for curr_reqf in ${reqs[@]}; do
        curr_reqf=${curr_reqf:A}
        local dig_key;
        read -r dig_key < <( zinve::make-fs-cache-key $curr_reqf ) ;
        local dig_f="${dig_d}/${dig_key}${dig_suffix}"
        local curr_dig; read -r curr_dig < <( $dig_fn $curr_reqf )
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

    # none of the requirements digests have changed.
    if (! $upit); then return 0 ; fi

    if [[ ${#needed_req_files} -gt 0 ]]; then
        typeset -a pip_call=(
            _zinve::run-in-venv-unchecked $venv_d
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
    typeset -a dir_list=() ;
    typeset -A optmap2 ; optmap2=() ;
    zparseopts -D -E -a nothing d:=dir_list -venv-dir:=dir_list

    local venv_d=""
    [[ ${#dir_list} -ge 2 ]] || zinve::fatal "$0 unspecified venv dir" ;
    venv_d=${dir_list[2]}

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



    local runner=""
    case $zinve_cmd_name in
        CMD_RUN) runner='_zinve::venv::run-in-venv-unchecked' ;;
        CMD_EXEC) runner='_zinve::venv::exec-in-venv-unchecked' ;;
        *) { zinve::fatal "$0 invalid command '$cmd_name'" ; } ;;
    esac

    typeset -a fin_call=(
        $runner $venv_d $bin_fpath
    )
    [[ ${#cmd_parts} -lt 1 ]] || fin_call+=( ${cmd_parts[@]} ) ;

    zinve::perfstamp "END"
    ${fin_call[@]}
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


