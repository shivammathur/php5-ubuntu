#!/usr/bin/env bash

fail() { printf '%s\n' "$*" >&2; exit 1; }
sha256() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
file_size() { wc -c < "$1" | tr -d '[:space:]'; }

verify_sha256() {
  [[ "$(sha256 "$1")" = "$2" ]] || fail "SHA256 mismatch: $1"
}

download() {
  curl --fail --location --silent --show-error --retry 3 \
    --proto '=https' --proto-redir '=https' "$1" --output "$2"
  [[ -z "${3:-}" ]] || verify_sha256 "$2" "$3"
}

# Match literal text exactly once, preserving patch context and shell quoting.
replace_once() {
  local file=$1 old=$2 new=$3 temp
  temp=$(mktemp "${file}.XXXXXX")
  if ! REPLACE_OLD="$old" REPLACE_NEW="$new" awk '
    BEGIN { old=ENVIRON["REPLACE_OLD"]; new=ENVIRON["REPLACE_NEW"]; count=0 }
    {
      rest=$0; output=""
      while ((pos=index(rest,old)) > 0) {
        output=output substr(rest,1,pos-1) new
        rest=substr(rest,pos+length(old)); count++
      }
      print output rest
    }
    END { if (count != 1) { print "Expected exactly one replacement, found " count > "/dev/stderr"; exit 1 } }
  ' "$file" > "$temp"; then
    rm -f "$temp"
    fail "Unexpected file content: $file"
  fi
  # Preserve the mode, but replace any symlink rather than editing its target.
  if [[ "$(uname -s)" = Darwin ]]; then
    chmod "$(stat -Lf %Lp "$file")" "$temp"
  else
    chmod "$(stat -Lc %a "$file")" "$temp"
  fi
  mv "$temp" "$file"
}
