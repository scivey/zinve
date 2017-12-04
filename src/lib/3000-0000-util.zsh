#!/usr/bin/env zsh

zinve::sha256() { sha256sum $1 | cut -d ' ' -f 1 ; }
zinve::has-key() { [[ "${${(P)1}[$2]:-""}" != "" ]] || return 1 ; }
zinve::isdef() { [[ ! -z ${${(P)1}+x} ]] || return 1 ; }

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


