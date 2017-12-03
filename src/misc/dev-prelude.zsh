#!/usr/bin/env zsh

setopt errexit
setopt localtraps
set -uo pipefail

__TEMP_SELF_D=${0:A:h}
_dev-get-rev-helper() {
    pushd ${__TEMP_SELF_D} > /dev/null ;
    git describe $@ --always --abbrev=40 --dirty
    popd > /dev/null
}
_dev-get-rev-hash() {
    _dev-get-rev-helper --match=NeVeRmAtCh
}
_dev-get-rev-tag() {
    local vstr=""
    read -r vstr < <( _dev-get-rev-helper )
    vstr+="-dev"
    echo $vstr ;
}

__TEMP_REV=""
read -r __TEMP_REV < <( _dev-get-rev-hash ) ;
typeset -gxr ZINVE__CONST__GIT_REVISION="${__TEMP_REV}"
read -r __TEMP_REV < <( _dev-get-rev-tag ) ;
typeset -gxr ZINVE__CONST__VERSION_STR="${__TEMP_REV}"
unfunction _dev-get-rev-helper _dev-get-rev-hash _dev-get-rev-tag;
unset __TEMP_REV __TEMP_SELF_D ;

