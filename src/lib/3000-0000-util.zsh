#!/usr/bin/env zsh



zinve::nth() { cut -d ' ' -f $1 ; }
zinve::digest::sha256() { sha256sum $1 | zinve::nth 1 ; }

zinve::noop ${ZINVE__XXHASH_BASENAME:=xxhsum}
zinve::digest::xxhash() { $ZINVE__XXHASH_BASENAME $1 | zinve::nth 1 ; }

zinve::digest::have-xxhash() {
    if ! whence -p $ZINVE__XXHASH_BASENAME &>/dev/null; then
        return 1
    fi
}

zinve::digest::choose-fn-and-suffix() {
    local fname='zinve::digest'
    local suffix='.asc'

    if zinve::digest::have-xxhash ; then
        fname+='::xxhash'
        suffix=".xxhash${suffix}"
    else
        fname+='::sha256'
        suffix=".sha256${suffix}"
    fi
    echo $fname $suffix ;

}


zinve::has-key() { [[ "${${(P)1}[$2]:-""}" != "" ]] || return 1 ; }
zinve::isdef() { [[ ! -z ${${(P)1}+x} ]] || return 1 ; }
zinve::has-any-key() {
    local aname=$1 ; shift ;
    local kname ;
    for kname in $@; do
        if zinve::has-key $aname $kname; then return ; fi
    done
    return 1
}
zinve::key-coalesce() {
    local name=$1 ; shift ;
    local keyk ;
    zinve::isdef $name || return 1 ;
    for keyk in $@; do
        if zinve::has-key $name $keyk ; then
            echo ${${(P)name}[$keyk]} ; return ;
        fi
    done
    return 1 ;
}


