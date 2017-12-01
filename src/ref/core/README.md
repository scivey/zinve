# $ZDOTDIR/core

Files in this directory define functions that are used heavily by other parts
of `$ZDOTDIR`.  Because these are used during startup, they need to be sourced
at a specific time. In general that time is "early": prior to anything in
`$ZDOTDIR/detail`.

Note:
* Unlike `$ZDOTDIR/detail/*` and friends, these files are not automatically
  sourced.
* `core-all.zsh` is special: it's supposed to source any other files in this
  directory.  Importantly, it's supposed to know of and respect dependencies
  between those files.

As of this sentence's commit ref, `core-all.zsh` is sourced by `.zshrc` as one
of its first few commands.



