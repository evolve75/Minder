#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
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
unset _brew_prefix _pkg _dir
