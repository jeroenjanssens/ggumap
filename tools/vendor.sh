#!/bin/sh
# Vendor the Rust dependencies for offline (CRAN) builds.
#
# `cargo vendor` would include every optional dependency in Cargo.lock,
# including the large WebGPU stack behind upstream's `gpu` feature, which this
# package never enables. cargo-vendor-filterer keeps only the crates needed for
# the default features on the platforms R runs on.
#
# Requires: cargo install cargo-vendor-filterer
set -eu
cd "$(dirname "$0")/../src/rust"

rm -rf vendor vendor.tar.xz
cargo vendor-filterer \
  --platform=x86_64-unknown-linux-gnu \
  --platform=aarch64-unknown-linux-gnu \
  --platform=x86_64-apple-darwin \
  --platform=aarch64-apple-darwin \
  --platform=x86_64-pc-windows-gnu \
  --platform=aarch64-pc-windows-gnullvm \
  --platform=wasm32-unknown-emscripten \
  --exclude-crate-path='*#tests' \
  --exclude-crate-path='*#benches' \
  --exclude-crate-path='*#examples' \
  vendor > /dev/null

cat > vendor-config.toml <<'TOML'
[source.crates-io]
replace-with = "vendored-sources"

[source."git+https://github.com/apple/embedding-atlas?rev=a0d0f0938db386a86dc855182df3432e1814891d"]
git = "https://github.com/apple/embedding-atlas"
rev = "a0d0f0938db386a86dc855182df3432e1814891d"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
TOML

# Deterministic, compressed archive.
LC_ALL=C tar --format=ustar -cf - vendor | xz -9e -T0 > vendor.tar.xz
rm -rf vendor
echo "vendor.tar.xz: $(du -h vendor.tar.xz | cut -f1)"
