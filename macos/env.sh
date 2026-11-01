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
# Export PKG_CONFIG_PATH entries for keg-only Homebrew libraries needed to
# build Minder on macOS. Source this file; do not execute it.
#
# Usage: source macos/env.sh

_brew_prefix="$(brew --prefix)"
for _pkg in libarchive libxml2; do
  _dir="${_brew_prefix}/opt/${_pkg}/lib/pkgconfig"
  if [[ -d "${_dir}" ]]; then
    export PKG_CONFIG_PATH="${_dir}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  fi
done

# Lasem (LaTeX formulas), built by macos/build-lasem.sh, is not in Homebrew
_deps="${MINDER_DEPS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/build-deps}"
if [[ -d "${_deps}/prefix/lib/pkgconfig" ]]; then
  export PKG_CONFIG_PATH="${_deps}/prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  export MINDER_LASEM_LIB="${_deps}/prefix/lib"
fi
unset _brew_prefix _pkg _dir _deps
