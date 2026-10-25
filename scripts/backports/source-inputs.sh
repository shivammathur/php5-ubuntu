#!/usr/bin/env bash
# Resolve backport branches once and verify each native job's inputs.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/backports/common.sh
. "$here/common.sh"
config="$here/sources.json"

archive_root() {
  local archive=$1 commit=$2 listing roots root
  listing=$(tar -tzf "$archive")
  [[ -n "$listing" ]] || fail "Empty source archive"
  if ! printf '%s\n' "$listing" | awk '
    /^\// { exit 1 }
    { n=split($0,parts,"/"); for (i=1;i<=n;i++) if (parts[i]=="..") exit 1 }
  '; then
    fail "Unsafe source archive path"
  fi
  roots=$(printf '%s\n' "$listing" | cut -d / -f 1 | sort -u)
  [[ "$roots" != *$'\n'* && "$roots" = *"$commit" ]] || fail "Unexpected source archive root"
  root=$roots
  printf '%s\n' "$root"
}

resolve() {
  local destination=$1 repository minor spec ref result commit actual_ref url archive hash root item name origin expected
  [[ ! -e "$destination" ]] || fail "Source destination already exists: $destination"
  mkdir -p "$destination/extensions"
  repository=$(jq -er .repository "$config")
  jq '{repository, sources: {}, extensions}' "$config" > "$destination/manifest.json"
  for minor in $(jq -r '.versions | keys[]' "$config"); do
    spec=$(jq -ec --arg minor "$minor" '.versions[$minor]' "$config")
    ref="refs/heads/$(jq -r .branch <<< "$spec")"
    result=$(git ls-remote --exit-code "https://github.com/$repository.git" "$ref")
    [[ "$result" != *$'\n'* ]] || fail "Ambiguous branch: $ref"
    IFS=$'\t' read -r commit actual_ref <<< "$result"
    [[ "$commit" =~ ^[0-9a-f]{40}$ && "$actual_ref" = "$ref" ]] || fail "Invalid branch: $ref"
    url="https://codeload.github.com/$repository/tar.gz/$commit"
    archive="$destination/php-$minor.tar.gz"
    download "$url" "$archive"
    hash=$(sha256 "$archive")
    root=$(archive_root "$archive" "$commit")
    jq --arg minor "$minor" --argjson spec "$spec" --arg commit "$commit" --arg url "$url" \
      --arg sha "$hash" --arg archive "php-$minor.tar.gz" --arg root "$root" \
      '.sources[$minor] = ($spec + {commit: $commit, url: $url, sha256: $sha, archive: $archive, root: $root})' \
      "$destination/manifest.json" > "$destination/manifest.tmp"
    mv "$destination/manifest.tmp" "$destination/manifest.json"
  done
  while IFS= read -r item; do
    name=$(jq -r .name <<< "$item"); origin=$(jq -r .origin <<< "$item"); expected=$(jq -r .sha256 <<< "$item")
    download "$origin" "$destination/extensions/$name" "$expected"
    [[ -n "$(tar -tzf "$destination/extensions/$name")" ]] || fail "Empty extension archive: $name"
  done < <(jq -c '.extensions[]' "$config")
  cat "$destination/manifest.json"
}

write_env() {
  [[ "$2" != *$'\n'* && "$2" != *$'\r'* ]] || fail "Invalid environment value: $1"
  printf '%s=%s\n' "$1" "$2" >> "${GITHUB_ENV:?}"
}

activate() {
  local directory=$1 minor=$2 manifest source repository commit archive item name expected root
  directory=$(cd "$directory" && pwd)
  manifest="$directory/manifest.json"
  repository=$(jq -er .repository "$config")
  jq -e --slurpfile config "$config" --arg minor "$minor" '
    .repository == $config[0].repository and
    .extensions == $config[0].extensions and
    ($config[0].versions | has($minor)) and
    (.sources[$minor] as $source | $config[0].versions[$minor] | to_entries | all(.[]; $source[.key] == .value))
  ' "$manifest" >/dev/null || fail "Source configuration mismatch"
  source=$(jq -ec --arg minor "$minor" '.sources[$minor]' "$manifest")
  commit=$(jq -er .commit <<< "$source")
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || fail "Invalid source revision"
  [[ "$(jq -r .url <<< "$source")" = "https://codeload.github.com/$repository/tar.gz/$commit" ]] || fail "Unexpected source URL"
  archive="$directory/php-$minor.tar.gz"
  verify_sha256 "$archive" "$(jq -r .sha256 <<< "$source")"
  root=$(archive_root "$archive" "$commit")
  [[ "$(jq -r .root <<< "$source")" = "$root" ]] || fail "Source root mismatch"
  while IFS= read -r item; do
    name=$(jq -r .name <<< "$item"); expected=$(jq -r .sha256 <<< "$item")
    verify_sha256 "$directory/extensions/$name" "$expected"
  done < <(jq -c '.extensions[]' "$config")
  write_env PHP_VERSION "$minor"
  write_env PHP_FULL_VERSION "$(jq -r .version <<< "$source")"
  write_env SOURCE_ARCHIVE "$archive"
  write_env SOURCE_SHA256 "$(jq -r .sha256 <<< "$source")"
  write_env SOURCE_COMMIT "$commit"
  write_env SOURCE_ROOT "$root"
  write_env PHP_EXTENSION_SOURCE_DIR "$directory/extensions"
  write_env PECL_TEST_ARCHIVE "$directory/extensions/msgpack-0.5.7.tgz"
  write_env MONGO_ARCHIVE "$directory/extensions/mongo-1.6.16.tgz"
  jq . <<< "$source"
}

case "${1:-}" in
  resolve) [[ $# = 2 ]] || fail 'Usage: source-inputs.sh resolve DIRECTORY'; resolve "$2" ;;
  activate) [[ $# = 4 && "$3" = --minor ]] || fail 'Usage: source-inputs.sh activate DIRECTORY --minor VERSION'; activate "$2" "$4" ;;
  *) fail 'Expected resolve or activate' ;;
esac
