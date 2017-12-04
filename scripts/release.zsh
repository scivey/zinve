#!/usr/bin/env zsh
#
set -euo pipefail

REPO='zinve'
ARTIFACT_NAME='zinve'
ROOT_D="" ; read -r ROOT_D < <( git rev-parse --show-toplevel )
ARTIFACT_PATH=$ROOT_D/build/bin/zinve


__is-dirty() {
    git describe --always --dirty --abbrev=40 --match=never \
        | grep -E dirty &>/dev/null ;
}

__runit() {
    pushd $ROOT_D ;
    if __is-dirty; then
        echo "ERROR: repo is dirty." >&2 ; return 1 ;
    fi
    typeset -a tag_list=()
    zparseopts -D -E t:=tag_list -tag:=tag_list ;
    if [[ ${#tag_list} -lt 2 ]]; then
        echo "Specify a tag (-t / --tag)." >&2 ;
        return 1 ;
    fi
    local tag=""
    tag=${tag_list[2]}
    tag=${tag// /}
    if ! git tag -a -m "${tag}" "$tag" ; then
        echo "ERROR: tagging failed!" >&2 ; return 1 ;
    fi
    git push origin --tags ;
    make ;
    typeset -a ghr_args=( -r $REPO )
    ds-gh-release release -r $REPO -t $tag ;
    ds-gh-release upload -r $REPO \
        --name $ARTIFACT_NAME \
        -f $ARTIFACT_PATH \
        -l $ARTIFACT_NAME \
        -t "$tag" ;
}

__runit $@

