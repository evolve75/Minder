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
# Make TeX's Computer Modern math fonts usable on macOS for Lasem's square
# roots, big operators and stretched brackets.  Reads the Type 1 fonts from the
# local TeX distribution (MacTeX) and converts them to TrueType in
# build-deps/fonts (git-ignored); macos/make-app.sh bundles them if present.
#
# Needs MacTeX (for the fonts) and network access once, to install the
# fonttools Python package into a virtual environment under build-deps/.
# The converted fonts keep TeX's names, which are Reserved Font Names under the
# SIL OFL: use the resulting app locally, do not redistribute it.
#
# Usage: macos/build-tex-fonts.sh   (MINDER_DEPS_DIR overrides the location)

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deps="${MINDER_DEPS_DIR:-${repo}/build-deps}"
venv="${deps}/venv"
export PATH="/Library/TeX/texbin:${PATH}"

command -v kpsewhich >/dev/null || { echo "MacTeX (kpsewhich) not found" >&2; exit 1; }

pfbs=()
for f in cmr10 cmmi10 cmex10 cmsy10; do
  path="$(kpsewhich "${f}.pfb")"
  [[ -n "${path}" ]] || { echo "${f}.pfb not found in the TeX tree" >&2; exit 1; }
  pfbs+=("${path}")
done

mkdir -p "${deps}"
if [[ ! -x "${venv}/bin/python" ]]; then
  echo "==> Creating Python environment"
  python3 -m venv "${venv}"
  "${venv}/bin/python" -m pip install --quiet fonttools
fi

echo "==> Converting ${#pfbs[@]} fonts"
"${venv}/bin/python" "${repo}/macos/convert-tex-fonts.py" "${deps}/fonts" "${pfbs[@]}"
