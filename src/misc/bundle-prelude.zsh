#!/usr/bin/env zsh

setopt errexit
setopt localtraps
set -uo pipefail

typeset -gxr ZINVE__CONFIG__IS_PROD_BUNDLE="1"

typeset -gxr ZINVE__CONST__VERSION_STR="@@ZINVE_VERSION_STR@@"
typeset -gxr ZINVE__CONST__GIT_REVISION="@@ZINVE_GIT_REVISION@@"


