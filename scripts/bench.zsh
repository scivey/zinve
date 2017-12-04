#!/usr/bin/env zsh

set -euo pipefail


exec ${0:A:h}/bench-run-prod.zsh 'exec' \
    -p python3.6 \
    --venv-dir tmp/venvs/vx12 \
    -r testing/more-reqs.txt -- python -c 'print("ok")'


