#!/usr/bin/env python3

from __future__ import print_function

import os
import sys
import errno
import functools
import subprocess
import argparse
from contextlib import contextmanager

PY3 = sys.version_info[0] >= 3
if PY3:
    text_type = str
else:
    try:
        text_type = unicode
    except NameError:
        # static analyzer is static
        pass


def thunk(func, *args):
    @functools.wraps(func)
    def wrapper():
        returnfunc(*args)
    return wrapper

class StupidFuture(object):
    _NOTHING = object()
    _value = _NOTHING

    def __init__(self, func):
        self._func = func

    def get(self):
        if self._value is self._NOTHING:
            self._value = self._func()
        return self._value


def open_write(fpath):
    return open(fpath, 'w')


@contextmanager
def _bundler_for_fpath(fpath, vars=None):
    with open(fpath, 'w') as fout:
        bundler = Bundler(fout, vars=vars)
        yield bundler
        fout.flush()





@contextmanager
def ident_ctx(x):
    yield x

import contextlib
def open_read_closing(fpath):
    return contextlib.closing(open(fpath, 'r'))

def ensure_input_fileobj(maybe_file):
    if isinstance(maybe_file, text_type):
        return open_read_closing(maybe_file)
    return ident_ctx(maybe_file)

class Bundler(object):

    def __init__(self, out_fobj, vars=None):
        self._out_fobj = out_fobj
        self._vars = vars or {}

    def _expand(self, text):
        for key, val in self.vars.items():
            if key in text:
                text = text.replace(key, val)
        return text
    def add_part(self, in_fobj, skip_shebang=True):
        with ensure_input_fileobj(in_fobj) as ensured:
            line1 = ensured.readline()
            if not line1.startswith('#!') or not skip_shebang:
                self._out_fobj.writelines([self._expand(line1)])
            self._out_fobj.write(self._expand(ensured.read()))

    def add_body_part(self, in_fobj):
        self.add_part(in_fobj, skip_shebang=True)

    @classmethod
    def for_path(cls, out_fpath, vars=None):
        return _bundler_for_fpath(out_fpath, vars=vars)

    @property
    def vars(self):
        return self._vars


def path_func(func):
    @functools.wraps(func)
    def wrapper(*parts):
        base = func()
        if not parts:
            return base
        return os.path.realpath(os.path.join(base, *parts))
    return wrapper


@path_func
def in_scripts_dir():
    return os.path.dirname(os.path.realpath(__file__))


@path_func
def in_root_dir():
    return in_scripts_dir('../')


@path_func
def in_src_dir():
    return in_root_dir('src')


def mkdir_p(dpath):
    try:
        os.makedirs(dpath)
    except OSError as err:
        if err.errno != errno.EEXIST:
            raise

def ls_dir(dpath):
    for child in os.listdir(dpath):
        yield os.path.join(dpath, child)


SCRIPT_BASENAME = os.path.basename(__file__).split('.')[0]

def say(fmt, *args):
    msg = fmt
    if args:
        msg %= args
    print('[ %s ] INFO - %s' % (SCRIPT_BASENAME, msg), file=sys.stderr)


def run(cmd_args, **flags):
    defaults = {
        'shell': False,
        'check': True
    }
    popen_kwargs = defaults
    popen_kwargs.update(flags)
    return subprocess.run(cmd_args, **popen_kwargs)

def git(*args):
    cmd = ['git'] + list(args)
    return run(cmd, stdout=subprocess.PIPE, encoding='utf8').stdout.strip()

def git_describe(match=None):
    args = ['describe', '--always']
    if match:
        args.append('--match=%s' % (match,))
    args.extend(['--abbrev=40', '--dirty'])
    return git(*args)

def load_vars():
    rev = git_describe(match='neverMatchThis')
    version = git_describe()
    keys = {'VERSION_STR': version, 'GIT_REVISION': rev}
    return {('@@ZINVE_%s@@' % (k,)) : v for k, v in keys.items()}

def sort_by_basename(fnames):
    out = list(fnames)
    def _keyfn(val):
        base = os.path.basename(val)
        parts = [part for part in base.split('-') if part.isdecimal()]
        if not parts:
            return 0
        return int(''.join(parts))

    out.sort(key=_keyfn)
    return out


def get_sources():
    sources = list(map(in_src_dir, [
        'misc/bundle-prelude.zsh',
        'lib-loader.zsh'
    ]))
    sources.extend(sort_by_basename(ls_dir(in_src_dir('lib'))))
    sources.append(in_src_dir('misc/bundle-run-main.zsh'))
    return sources

def make_bundle(options):

    def _verb(fmt, *args):
        if options.verbose:
            say(fmt, *args)

    def _log1(part):
        _verb("adding part: %r", part)

    fdest = os.path.realpath(options.output)
    _verb("destination: %r", fdest)

    mkdir_p(os.path.dirname(fdest))
    if os.path.exists(fdest):
        os.unlink(fdest)
    vars = load_vars()
    with Bundler.for_path(fdest, vars=vars) as bundler:
        src_iter = iter(get_sources())
        part_src = next(src_iter)
        _log1(part_src)
        bundler.add_part(part_src, skip_shebang=False)
        for part_src in src_iter:
            _log1(part_src)
            bundler.add_body_part(part_src)
    os.chmod(fdest, 0o755)
    say(" -> %s", fdest)


def main():
    parser = argparse.ArgumentParser(os.path.basename(__file__))
    parser.add_argument('-v', '--verbose', action='store_true', default=False)
    parser.add_argument('-o', '--output', required=True)
    opts = parser.parse_args()
    make_bundle(opts)

if __name__ == '__main__':
    main()

