#!/usr/bin/env zsh


zinve-main-helper::version-info() {
    printf 'version=%s\n' "$ZINVE__CONST__VERSION_STR"
    printf 'revision=%s\n' "$ZINVE__CONST__GIT_REVISION"
}
_zinve-main-helper::list-commands() {
    local pfx='^zinve-main-cmd::'
    functions + \
        | sed -rn '/'$pfx'/ p' \
        | sed -r 's/'$pfx'//' \
        | grep -Ev '^debug'
}

zinve-main-helper::show-usage() {
    echo "Usage: zinve \$COMMAND \$COMMAND_ARG1 ... \$COMMAND_ARGN" ;
    printf '\n' ;
    echo "Commands: " ;
    _zinve-main-helper::list-commands | sed -r 's/^/        /' ;
    printf '\n\n' ;
}


zinve-error::unknown-command() {
    zinve-main-helper::show-usage >&2 ;
    [[ $# -gt 0 ]] || zinve-error::no-command ;
    local cmd=$1 ; shift ;
    local arg_str="''" ;
    [[ $# -lt 1 ]] || { arg_str="'$*'" ; shift $# ; }
    zinve::fatal  "Unknown command '$cmd'.  Input args were: $arg_str"
}

zinve-error::no-command() {
    zinve-main-helper::show-usage >&2 ;
    zinve::fatal "Expected a command"
}



