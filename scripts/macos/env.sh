# Shared settings for the macOS ARM64 build. Sourced by the other scripts.
# Upstream kakao/khaiii v0.4 (tag object e21a5f06..., commit below).
export UPSTREAM_REPO="https://github.com/kakao/khaiii"
export UPSTREAM_TAG="v0.4"
export UPSTREAM_COMMIT="fa5fbd10aeddfe97cd7aa87faee39628e5e9c18a"
# CMake is pinned: Hunter v0.23.34 sub-builds need CMake < 4.0 (policy minimum < 3.5).
export CMAKE_PIN="3.31.6"
export KHAIII_VERSION="0.4"
export PKG_NAME="khaiii-${KHAIII_VERSION}-macos-arm64"
