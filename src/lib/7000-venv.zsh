#!/usr/bin/env zsh

setopt errexit
set -uo pipefail


zinve::venv::get-named-venv-dir() {
    local name=$1 pybin=$2 ; shift 2 ;
    local res=$ZINVE__PARAM__VENVS_BASEDIR/${${pybin:t}//./_}/${name// /}
    echo ${res:A}
}
zinve::venv::get-named-venv-cache-dir() {
    local venvd ;
    read -r venvd < <( zinve::venv::get-named-venv-dir $@ ) ;
    echo $venvd/$ZINVE__CONST__CACHE_DIR_REL_VENV
}
zinve::venv::get-named-venv-digest-dir() {
    local venvd ;
    read -r venvd < <( zinve::venv::get-named-venv-dir $@ ) ;
    echo $venvd/$ZINVE__CONST__DIGEST_DIR_REL_VENV
}
zinve::make-fs-cache-key() {
    local bad_pat='[/.}{?\!]'
    echo ${1//${~bad_pat}/_}
}
# zinve::venv::ensure-venv-by-path() {
#     local venv_d=$1 pybin=$2 ; shift 2;
# }

zinve::venv::ensure-named-venv() {
    local name=$1 ; shift ;
    local pybin=$1 ; shift ;
    local venv_d ;
    read -r venv_d < <( zinve::venv::get-named-venv-dir $name $pybin )
    local upit=false
    typeset -A req_path_to_hash_path; req_path_to_hash_path=() ;
    typeset -A req_path_to_digest; req_path_to_digest=();
    typeset -A hash_path_to_digest; hash_path_to_digest=() ;
    if [[ ! -d $venv_d ]]; then
        mkdir -p ${venv_d:h} ;
        virtualenv -p ${pybin} $venv_d ;
        ${venv_d}/bin/pip install --upgrade pip
        upit=true
    fi
    local dig_d=$venv_d/$ZINVE__CONST__DIGEST_DIR_REL_VENV
    [[ -d $dig_d ]] || mkdir -p $dig_d ;
    typeset -a all_req_files=()
    typeset -a needed_req_files=()
    typeset -A output_digests; output_digests=() ;
    local curr_reqf
    for curr_reqf in ${ZINVE__PARAM__TARGET_REQUIREMENTS_FILES[@]}; do
        curr_reqf=${curr_reqf:A}
        all_req_files+=( $curr_reqf )
        local digk; read -r digk < <( zinve::make-fs-cache-key $curr_reqf ) ;
        local digf="${dig_d}/$digk.sha256.asc"
        local curr_dig; read -r curr_dig < <( zinve::sha256 $curr_reqf )
        curr_dig="${curr_dig// /}"
        local prev_dig=""
        if [[ -e $digf ]]; then
            read -r prev_dig < $digf ;
            prev_dig="${prev_dig// /}"
        fi
        if [[ $prev_dig == $curr_dig ]]; then
            continue
        fi
        upit=true
        output_digests+=( $digf $curr_dig )
        needed_req_files+=( $curr_reqf )
    done
    if [ $upit = true ]; then
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
            local tempf="${digf}.tmp~"
            rm -f $tempf ; echo $digv > $tempf ;
            mv -f $tempf $digf ;
        done
    fi
}


_zinve::venv::run-or-exec-in-venv-explicit() {
    zinve::info "$0: args='$*'"
    local cmd_name=${1:u} ; shift ;
    local venv_name=$1 ; shift ;
    local python_bin=$1 ; shift ;
    zinve::venv::ensure-named-venv $venv_name $python_bin ;
    local venv_d ;
    read -r venv_d < <(
        zinve::venv::get-named-venv-dir $venv_name $python_bin
    ) ;
    local targ_name=$1 ; shift ;
    local targ_fpath=$venv_d/bin/$targ_name
    if [[ ! -e $targ_fpath ]]; then
        zinve::fatal "Can't find '$targ_name'. Expected at path '$targ_fpath'" ;
        return 1 ; # not reached
    fi
    case $cmd_name in
        CMD_EXEC) { exec $targ_fpath $@ ; } ;;
        CMD_RUN) { $targ_fpath $@ ; return ; } ;;
        *) { zinve::fatal "$0 invalid command '$cmd_name'" ; } ;;
    esac
}



zinve::venv::run-in-venv-explicit() {
    zinve::info "$0 : args='$*'"
    _zinve::venv::run-or-exec-in-venv-explicit 'CMD_EXEC' $@ ;
}

zinve::venv::exec-in-venv-explicit() {
    zinve::info "$0 : args='$*'"
    _zinve::venv::run-or-exec-in-venv-explicit 'CMD_RUN' $@ ;
}

zinve::venv::run-in-venv-implicit() {
    local vname=${ZINVE__PARAM__TARGET_NAME}
    local pname=${ZINVE__PARAM__TARGET_PYTHON_BIN}
    zinve::venv::run-in-venv-explicit $vname $pname $@ ;
}

zinve::venv::exec-in-venv-implicit() {
    local vname=${ZINVE__PARAM__TARGET_NAME}
    local pname=${ZINVE__PARAM__TARGET_PYTHON_BIN}
    zinve::venv::exec-in-venv-explicit $vname $pname $@ ;
}
zinve::venv::debug() {
    echo "VARS: " ;
    printf -- '%*s\n\n' 32 "" ;

    typeset -p | sort | ansifilter | sed -r 's/^/      | /' ;
    printf '\n' ;
    printf -- '%*s\n' 32 "" ;
}


