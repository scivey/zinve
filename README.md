## zinve
A poorly documented script for running things in Python virtualenvs.

It's more or less [inve](https://gist.github.com/datagrok/2199506), which is where
the name comes from. The `z` is because this is written in zsh, and
anything related to zsh must have a name starting in `z-`. I don't make the
rules, so my hands are tied here.

Compared to `inve`, the main purpose here is to provide a fast path: we
track the sha1 digests of requirements files, and we only `pip install -r`
them when necessary. Because pip is very slow, this makes a noticeable difference.

## Installation
Download a tagged release from the [releases page](https://github.com/scivey/zinve/releases). (Even though it's a shell script, there's a mini build process.)

Alternately:
```shell
git clone git@github.com:scivey/zinve
pushd zinve
make
./build/bin/zinve help
```

## Usage
The main command is `zinve exec`. It takes:
* a path to use as a virtualenv dir
* a python interpreter
* any number of requirements files
* a command to run in the virtualenv

```shell
zinve exec -d ./.env \
    -p python3.6 \
    -r ./requirements.txt \
    -r ./requirements-dev.txt -- ipython
```

If the virtualenv doesn't exist, it's created with the given interpreter.
On creation, any requirements files are also installed with `pip install -r`.
On subsequent calls, `pip install` is re-run if any of the requirements files
have changed (SHA1 digests are stored).
If the virtualenv already exists and requirements haven't changed, `pip install`
is skipped.

Once this is done, the given command is executed in the virtual environment.
As with `inve`, this doesn't affect your current shell. (The virtualenv
is only activated in a subshell).



