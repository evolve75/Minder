#!/usr/bin/env python3

from os import path, environ
import shutil
import subprocess


def run(args):
    # Skip tools that are not available (e.g. update-mime-database on macOS)
    if shutil.which(args[0]) is None:
        print('Skipping %s (not found)' % args[0])
        return
    subprocess.call(args)


prefix = environ.get('MESON_INSTALL_PREFIX', '/usr/local')
schemadir = path.join(environ['MESON_INSTALL_PREFIX'], 'share', 'glib-2.0', 'schemas')
datadir = path.join(prefix, 'share')

if not environ.get('DESTDIR'):
    print('Compiling gsettings schemas…')
    run(['glib-compile-schemas', schemadir])
    print('Updating icon cache…')
    run(['gtk-update-icon-cache', '-qtf', path.join(datadir, 'icons', 'hicolor')])
    print('Compiling mime types…')
    run(['update-mime-database', path.join(datadir, 'mime')])
    print('Updating application database…')
    run(['update-desktop-database', path.join(datadir, 'applications')])
