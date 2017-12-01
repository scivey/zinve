#!/usr/bin/env python3

from __future__ import print_function

import os
import sys
import errno
import functools
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
def _bundler_for_fpath(fpath):
    with open(fpath, 'w') as fout:
        bundler = Bundler(fout)
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

    def __init__(self, out_fobj):
        self._out_fobj = out_fobj

    def add_part(self, in_fobj, skip_shebang=True):
        with ensure_input_fileobj(in_fobj) as ensured:
            line1 = ensured.readline()
            if not line1.startswith('#!') or not skip_shebang:
                self._out_fobj.writelines([line1])
            self._out_fobj.writelines(ensured.readlines())

    def add_body_part(self, in_fobj):
        self.add_part(in_fobj,skip_shebang=True)

    @classmethod
    def for_path(cls, out_fpath):
        return _bundler_for_fpath(out_fpath)



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


@path_func
def in_build_dir():
    return in_root_dir('build')


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


def main():
    fdest = in_build_dir('bin', 'zinve')
    say("destination: %r", fdest)
    mkdir_p(os.path.dirname(fdest))
    if os.path.exists(fdest):
        os.unlink(fdest)
    sources = list(map(in_src_dir, [
        'misc/bundle-prelude.zsh',
        'lib-loader.zsh'
    ]))
    sources.extend(ls_dir(in_src_dir('lib')))
    sources.append(in_src_dir('misc/bundle-run-main.zsh'))

    with Bundler.for_path(fdest) as bundler:
        src_iter = iter(sources)
        log1 = lambda x: say("adding part: %r", x)
        part_src = next(src_iter)
        log1(part_src)
        bundler.add_part(part_src, skip_shebang=False)
        for part_src in src_iter:
            log1(part_src)
            bundler.add_body_part(part_src)
    os.chmod(fdest, 0o755)


if __name__ == '__main__':
    main()

