# shellcheck shell=bash
# Use only the verified branch archive; never fall back to an old release tarball.
install_package_from_backports() {
  local source_path="$PHP_BUILD_TMPDIR/source/$DEFINITION"
  printf '%s  %s\n' "${PHP_BACKPORT_SOURCE_SHA256:?}" "${PHP_BACKPORT_SOURCE_ARCHIVE:?}" | sha256sum --check -
  rm -rf "$source_path"
  mkdir -p "$source_path"
  tar -xzf "$PHP_BACKPORT_SOURCE_ARCHIVE" --strip-components=1 -C "$source_path"
  (cd "$source_path" && build_package)
}
