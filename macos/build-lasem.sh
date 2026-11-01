#!/usr/bin/env bash
# Copyright (C) 2026 Anupam Sengupta <anupamsg@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
#
# Authored by: Anupam Sengupta <anupamsg@gmail.com>
#
# Build and install Lasem (MathML/LaTeX renderer, used for formulas in nodes)
# into a local prefix, so the app can be built with -Dlatex=true.  Lasem is not
# in Homebrew and its upstream has been quiet since 2020, so a known commit is
# pinned here.
#
# Usage: macos/build-lasem.sh            (installs under build-deps/)
#        MINDER_DEPS_DIR=/some/dir macos/build-lasem.sh
#
# Afterwards: source macos/env.sh  (it adds the prefix to PKG_CONFIG_PATH)

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deps="${MINDER_DEPS_DIR:-${repo}/build-deps}"
src="${deps}/src/lasem"
prefix="${deps}/prefix"
stubs="${deps}/tools"
url="https://gitlab.gnome.org/GNOME/lasem.git"
commit="d47c0aa127880e964b376ec2f2747b5e1f324de8"

mkdir -p "${deps}/src" "${prefix}" "${stubs}/m4" "${stubs}/bin"

echo "==> Fetching Lasem ${commit:0:8}"
if [[ ! -d "${src}/.git" ]]; then
  git clone --quiet "${url}" "${src}"
fi
git -C "${src}" fetch --quiet origin
git -C "${src}" checkout --quiet --force "${commit}"
git -C "${src}" clean --quiet -dfx

# The configure script calls gtk-doc and GObject Introspection macros that are
# not installed with Homebrew's autotools; neither is needed here, so provide
# no-op versions instead of changing Lasem's sources.
cat > "${stubs}/m4/minder-stubs.m4" <<'M4'
AC_DEFUN([GTK_DOC_CHECK], [enable_gtk_doc=no])
AC_DEFUN([GOBJECT_INTROSPECTION_CHECK], [AM_CONDITIONAL([HAVE_INTROSPECTION], [false])])
M4
# autogen.sh looks for libtoolize, which Homebrew installs as glibtoolize
ln -sf "$(command -v glibtoolize)" "${stubs}/bin/libtoolize"

echo "==> Generating the build system"
(
  cd "${src}"
  export PATH="${stubs}/bin:${PATH}"
  NOCONFIGURE=1 ACLOCAL_FLAGS="-I ${stubs}/m4" ./autogen.sh >/dev/null 2>"${deps}/autogen.log"
)

echo "==> Configuring and building (log: ${deps}/build.log)"
(
  cd "${src}"
  {
    ./configure --prefix="${prefix}" --disable-static --disable-gtk-doc \
      --disable-introspection --disable-nls
    make -j"$(sysctl -n hw.ncpu)"
    make install
    # This commit's Makefile installs only the DOM headers; the MathML and SVG
    # ones (including the generated enum headers) are needed to use the library.
    incdir="$(echo "${prefix}"/include/lasem-*)"
    install -m 644 src/lsmmathml*.h src/lsmsvg*.h "${incdir}/"
  } >"${deps}/build.log" 2>&1 || { tail -n 30 "${deps}/build.log"; exit 1; }
)

echo "==> Done: $(PKG_CONFIG_PATH="${prefix}/lib/pkgconfig" pkg-config --modversion lasem-0.6) in ${prefix}"
