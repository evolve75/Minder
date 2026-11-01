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
# Notarize and staple a Minder.app that was signed with a Developer ID identity.
#
# One-time setup (stores the credentials in the login keychain):
#   xcrun notarytool store-credentials minder-notary \
#     --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>
#
# Usage: MINDER_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" macos/make-app.sh
#        macos/notarize.sh [path/to/Minder.app] [keychain-profile]

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-${repo}/build-app/Minder.app}"
profile="${2:-minder-notary}"
zip="${app%.app}.zip"

if [[ ! -d "${app}" ]]; then
  echo "error: ${app} not found; run macos/make-app.sh first" >&2
  exit 1
fi

if ! codesign -dv "${app}" 2>&1 | grep -q "flags=.*runtime"; then
  echo "error: ${app} is not signed with the hardened runtime." >&2
  echo "       Build it with MINDER_SIGN_IDENTITY set to a Developer ID identity." >&2
  exit 1
fi

echo "==> Submitting for notarization (profile: ${profile})"
ditto -c -k --keepParent "${app}" "${zip}"
xcrun notarytool submit "${zip}" --keychain-profile "${profile}" --wait

echo "==> Stapling the ticket"
xcrun stapler staple "${app}"
xcrun stapler validate "${app}"

echo "==> Gatekeeper assessment"
spctl --assess --type execute --verbose "${app}"
