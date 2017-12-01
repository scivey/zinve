#!/usr/bin/env zsh

zinve::sha256() { sha256sum $1 | cut -d ' ' -f 1 ; }


