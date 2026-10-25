#!/usr/bin/env bash
set -euo pipefail
umask 022
here=$(cd "$(dirname "$0")" && pwd)
[[ "$(uname -m)" = "$EXPECTED_ARCHITECTURE" || ( "$(uname -m)" = aarch64 && "$EXPECTED_ARCHITECTURE" = arm64 ) ]]
command -v zstd >/dev/null || sudo apt-get install -y zstd
mkdir -p "$BUILD_REPOSITORY/backport-input"
cp "$SOURCE_ARCHIVE" "$BUILD_REPOSITORY/backport-input/source.tar.gz"
cp -R "$PHP_EXTENSION_SOURCE_DIR" "$BUILD_REPOSITORY/backport-input/extensions"
cd "$BUILD_REPOSITORY"
image="php5-backports-${PHP_VERSION//./}-${EXPECTED_ARCHITECTURE}"
container="$image-copy"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true; docker image rm -f "$image" >/dev/null 2>&1 || true' EXIT
base=ubuntu:trusty
[[ "$EXPECTED_ARCHITECTURE" = arm64 ]] && base=arm64v8/ubuntu:trusty
# Build the selected native architecture from the verified branch source.
docker build --no-cache --progress=plain --build-arg "UBUNTU_VERSION=$base" --build-arg "PHP_VERSION=$PHP_VERSION" \
  --build-arg "PHP_BACKPORT_SOURCE_SHA256=$SOURCE_SHA256" -t "$image" .
docker run --name "$container" "$image" bash -eu -c '
  p=/usr/local/php/$PHP_VERSION
  "$p/bin/php" -v
  "$p/bin/php" -m
  find "$p" -type d -exec chmod go-w {} +
  find "$p" -type f -exec chmod go-w {} +
'
docker cp "$container:/usr/local/php/$PHP_VERSION" "$BACKPORT_TASK_DIR/runtime"
suffix='';[[ "$EXPECTED_ARCHITECTURE" = arm64 ]] && suffix=-arm64
mkdir -p "$BACKPORT_TASK_DIR/package-root"
mv "$BACKPORT_TASK_DIR/runtime" "$BACKPORT_TASK_DIR/package-root/$PHP_VERSION"
bash "$here/check-runtime.sh" "$BACKPORT_TASK_DIR/package-root/$PHP_VERSION" "$EXPECTED_ARCHITECTURE" > "$REPORT_DIR/runtime-inspection.json"
tar -C "$BACKPORT_TASK_DIR/package-root" -cf - "$PHP_VERSION" | zstd -19 -T0 -o "$OUTPUT_DIR/php-$PHP_VERSION-build$suffix.tar.zst"
bash scripts/version-files.sh "$PHP_VERSION"
bash scripts/stage.sh "$PHP_VERSION"
cp "$OUTPUT_DIR/php-$PHP_VERSION-build$suffix.tar.zst" "php-$PHP_VERSION/"
find "php-$PHP_VERSION" -type d -exec chmod go-w {} +
find "php-$PHP_VERSION" -type f -exec chmod go-w {} +
XZ_OPT=-6 tar -cJf "$OUTPUT_DIR/php-$PHP_VERSION$suffix.tar.xz" "php-$PHP_VERSION"
tar -cf - "php-$PHP_VERSION" | zstd -19 -T0 -o "$OUTPUT_DIR/php-$PHP_VERSION$suffix.tar.zst"
cp Dockerfile "$REPORT_DIR/Dockerfile.backports"
