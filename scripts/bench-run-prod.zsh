#!/usr/bin/env zsh

set -euo pipefail



ROOT_D=${0:A:h:h}

__runit() {
    typeset -a args_in=() ; args_in+=( $@ ) ; shift $# ;

    pushd $ROOT_D > /dev/null ;
    local plog=tmp/perf.log
    ZINVE__PERFLOG=$plog ./scripts/run-prod-zinve ${args_in[@]} ;
    typeset -a dummy ;
    echo "ARGS: [" ${(j:, :)${${(A)dummy::=\"${^args_in}\"}}} "]"
    echo "ELAPSED" ;
    {
        echo '8k' ;
        sed -r 's/^.*=//' < $plog | tac ;
        echo " - f"
    } | dc ;

}
__runit $@ ;

