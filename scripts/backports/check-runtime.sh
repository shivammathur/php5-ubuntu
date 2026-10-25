#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/backports/common.sh
. "$here/common.sh"
root=$(cd "$1" && pwd)
arch=$2
case "$arch" in arm64) expected=183 ;; x86_64) expected=62 ;; *) fail "Unknown architecture: $arch" ;; esac
writable=$(find "$root" ! -type l \( -perm -002 -o -perm -020 \) -print -quit)
[[ -z "$writable" ]] || fail "Writable payload: $writable"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
find "$root" -type f -print0 > "$temp/files"
: > "$temp/elf.jsonl"
while IFS= read -r -d '' file; do
  read -r -a header <<< "$(od -An -N20 -v -tu1 "$file" | tr '\n' ' ')"
  [[ "${header[0]:-} ${header[1]:-} ${header[2]:-} ${header[3]:-}" = '127 69 76 70' ]] || continue
  [[ ${#header[@]} = 20 && ${header[4]} = 2 ]] || fail "Invalid ELF header: $file"
  case "${header[5]}" in
    1) machine=$((header[18] + 256 * header[19])) ;;
    2) machine=$((256 * header[18] + header[19])) ;;
    *) fail "Invalid ELF byte order: $file" ;;
  esac
  [[ "$machine" = "$expected" ]] || fail "Wrong ELF architecture ($machine): $file"
  jq -nc --arg path "${file#"$root"/}" '$path' >> "$temp/elf.jsonl"
done < "$temp/files"
jq -se 'index("bin/php") != null and any(.[]; endswith(".so"))' "$temp/elf.jsonl" >/dev/null || fail 'Runtime executables or modules missing'
jq -n --arg arch "$arch" --slurpfile files "$temp/elf.jsonl" \
  '{architecture: $arch, elf_files: $files, permissions: "passed"}'
