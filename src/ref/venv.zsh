#!/usr/bin/env zsh

[[ $- == *"i"* ]] || set -euo pipefail ;

. ${0:A:h}/_base.zsh
setopt localoptions

ca-sha256() { sha256sum $1 | cut -d ' ' -f 1 ; }


ca-venv-ensure() {
    local h_d=$TMP_HASH_D ;
    local digf=$h_d/reqs.sha256
    local reqs=$ROOT_D/requirements.txt
    local upit=true
    local curr_hash ; read -r curr_hash < <( ca-sha256 $reqs ) ;
    mkdir -p $h_d ;
    local prev_hash=""
    if [[ ! -d $VENV_D ]]; then
        virtualenv -p python2.7 $VENV_D
        $VENV_D/bin/pip install --upgrade pip
        # ca-sha256
        upit=true ;
    elif [[ -e $digf ]]; then
        read -r prev_hash < $digf
        if [[ ${prev_hash// /} == ${curr_hash// /} ]]; then
            upit=false
        fi
    fi
    if [ $upit = true ]; then
        $VENV_D/bin/pip install -r $reqs ;
        local tmpf="${digf}.tmp~"
        rm -f $tmpf ; echo "$curr_hash" > $tmpf ;
        mv -f $tmpf $digf ;
    fi
}

ca-venv-activate() {
    ca-venv-ensure ;
    set +u
    . $VENV_D/bin/activate ;
}

ca-venv-exec() {
    ca-venv-ensure ;
    local bin_name=$1 ; shift ;
    exec $VENV_D/bin/$bin_name $@
}

ca-venv-exec-in-app-dir() {
    pushd $ROOT_D
    export PYTHONPATH=$ROOT_D
    ca-venv-exec $@
}

