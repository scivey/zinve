#!/usr/bin/env zsh

ds-zdot::noop ${DS__ZDOT__LOG_DEFAULT_NAME:="ds-zdot"}
ds-zdot::noop ${DS__ZDOT__LOG_INFO:='INFO'}
ds-zdot::noop ${DS__ZDOT__LOG_WARN:='WARN'}
ds-zdot::noop ${DS__ZDOT__LOG_FATAL:='FATAL'}

_ds-zdot::log::log-2-nl() {
    local name=$1 lvl=$2 ; shift 2 ;
    printf '[ %s ] %s  -  %s\n' "$name" "$lvl" "$*" >&2 ;
}
_ds-zdot::log::log-2-ln() {
    local lvl=$1 name=$2 ; shift 2 ;
    _ds-zdot::log::log-2-nl $name $lvl $@
}

_ds-zdot::log::log-1() {
    _ds-zdot::log::log-2-nl ${DS__ZDOT__LOG_DEFAULT_NAME} $@
}

ds-zdot::log::info2() {
    _ds-zdot::log::log-2-ln ${DS__ZDOT__LOG_INFO} $@
}
ds-zdot::log::info() {
    _ds-zdot::log::log-1 ${DS__ZDOT__LOG_INFO} $@
}

ds-zdot::log::warn2() {
    _ds-zdot::log::log-2-ln ${DS__ZDOT__LOG_WARN} $@
}
ds-zdot::log::warn() {
    _ds-zdot::log::log-1 ${DS__ZDOT__LOG_WARN} $@
}

ds-zdot::log::fatal2() {
    _ds-zdot::log::log-2-ln ${DS__ZDOT__LOG_FATAL} $@
}

ds-zdot::log::fatal() {
    _ds-zdot::log::log-1 ${DS__ZDOT__LOG_FATAL} $@
}


alias dsz::info2='ds-zdot::log::info2'
alias dsz::info='ds-zdot::log::info'
alias dsz::warn2='ds-zdot::log::warn2'
alias dsz::warn='ds-zdot::log::warn'
alias dsz::fatal2='ds-zdot::log::fatal2'
alias dsz::fatal='ds-zdot::log::fatal'

