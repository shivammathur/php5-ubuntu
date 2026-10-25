#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/backports/common.sh
. "$here/common.sh"
# Fail on platform patch errors or changed patch-command structure.
# shellcheck disable=SC2016
replace_once "$1" 'patch -d "$source_path" -N -p1 -s < $patch' \
  'patch --batch --fuzz=0 -d "$source_path" -N -p1 < "$patch" || return 1'
