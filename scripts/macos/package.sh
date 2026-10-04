#!/bin/bash
# Assemble the versioned release archive plus manifest and provenance.
# usage: package.sh <repo-root> <build-dir> <out-dir>
set -euo pipefail
. "$(dirname "$0")/env.sh"
SRC="$(cd "$1" && pwd)"; BUILD="$(cd "$2" && pwd)"; mkdir -p "$3"; OUT="$(cd "$3" && pwd)"
STAGE="$OUT/stage/$PKG_NAME"
rm -rf "$OUT/stage"; mkdir -p "$STAGE"/{lib,share,python/khaiii,include,licenses}

# library: dereference the CMake symlink chain, expose it under the name the python wrapper loads
cp -L "$BUILD/lib/libkhaiii.dylib" "$STAGE/lib/libkhaiii.dylib"
chmod u+w "$STAGE/lib/libkhaiii.dylib"
strip -S -x "$STAGE/lib/libkhaiii.dylib"                    # drop debug map (-g) so no runner paths leak
install_name_tool -id "@rpath/libkhaiii.dylib" "$STAGE/lib/libkhaiii.dylib"
codesign --force --sign - "$STAGE/lib/libkhaiii.dylib"      # ad-hoc only (arm64 requires some signature)

cp -R "$BUILD/share/khaiii" "$STAGE/share/khaiii"
cp -R "$SRC/include/khaiii" "$STAGE/include/khaiii"
cp "$SRC/src/main/python/khaiii/khaiii.py" "$STAGE/python/khaiii/khaiii.py"
# the configured __init__.py (upstream generates it from __init__.py.in with the version)
sed "s/@KHAIII_VERSION@/$KHAIII_VERSION/g; s/@CPACK_PACKAGE_DESCRIPTION_SUMMARY@/Kakao Hangul Analyzer III/g; s/@CPACK_PACKAGE_VENDOR@/Kakao Corp./g" \
    "$SRC/src/main/python/khaiii/__init__.py.in" > "$STAGE/python/khaiii/__init__.py"
! grep -q '@[A-Z_]*@' "$STAGE/python/khaiii/__init__.py" || { echo "FATAL: unresolved @VAR@ in __init__.py" >&2; exit 1; }
cp "$SRC/LICENSE" "$SRC/NOTICE.md" "$STAGE/licenses/"
cp "$SRC/scripts/macos/INSTALL.md" "$STAGE/INSTALL.md"

# provenance
FORK_COMMIT="$(git -C "$SRC" rev-parse HEAD)"
PATCHES="$(git -C "$SRC" log --format='%H %s' "$UPSTREAM_COMMIT"..HEAD 2>/dev/null | python3 -c 'import json,sys; print(json.dumps([l.rstrip() for l in sys.stdin]))')"
python3 - "$STAGE" "$BUILD" <<PY
import json, subprocess, sys, os, glob, hashlib
stage, build = sys.argv[1:3]
def sh(c): return subprocess.run(c, shell=True, capture_output=True, text=True).stdout.strip()
def sha(p): return hashlib.sha256(open(p,'rb').read()).hexdigest()
rsc = sorted(glob.glob(stage + '/share/khaiii/*'))
h = hashlib.sha256()
for p in rsc: h.update(os.path.basename(p).encode() + b'\0' + bytes.fromhex(sha(p)))
cfg = open(build + '/cmake-configure.log').read()
json.dump({
  'upstream': {'repo': '$UPSTREAM_REPO', 'tag': '$UPSTREAM_TAG', 'commit': '$UPSTREAM_COMMIT'},
  'fork_commit': '$FORK_COMMIT',
  'fork_commits_on_top_of_upstream': json.loads('''$PATCHES'''),
  'model': 'base (rsc/src/base.model.pickle, unchanged from upstream v0.4)',
  'build': {'cmake_flags': '-DFMA=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0',
            'hunter': 'v0.23.34 SHA1 70287b1ffa810ee4e952052a9adff9b4856d0d54 (from CMakeLists.txt)',
            'cmake': sh('cmake --version | head -1'), 'clang': sh('clang --version | head -1'),
            'xcode': sh('xcodebuild -version | tr "\\\\n" " "'), 'macos': sh('sw_vers -productVersion'),
            'python': sh('python3 --version'), 'uname': sh('uname -srm'),
            'runner_image': os.environ.get('ImageVersion', 'unknown')},
  'digests_sha256': {'lib/libkhaiii.dylib': sha(stage + '/lib/libkhaiii.dylib'),
                     'share/khaiii (combined: sorted name+sha256)': h.hexdigest()},
  'github': {k: os.environ.get(k, '') for k in ('GITHUB_REPOSITORY', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_SHA', 'GITHUB_SERVER_URL')},
  'signing': 'ad-hoc codesign only. NOT Developer-ID signed, NOT notarized.',
}, open(stage + '/PROVENANCE.json', 'w'), indent=2, ensure_ascii=False)
PY

# manifest of every file in the bundle (excluding itself)
# (paths relative to the package root so `shasum -c MANIFEST.sha256` works from inside it)
( cd "$STAGE" && find . -type f ! -name MANIFEST.sha256 | LC_ALL=C sort | xargs shasum -a 256 > MANIFEST.sha256 )

# archive (+ checksum of the archive, kept outside the archive)
( cd "$OUT/stage" && tar -czf "$OUT/$PKG_NAME.tar.gz" "$PKG_NAME" )
( cd "$OUT" && shasum -a 256 "$PKG_NAME.tar.gz" > "$PKG_NAME.tar.gz.sha256" && cp "$STAGE/PROVENANCE.json" "$PKG_NAME.provenance.json" )
cat "$OUT/$PKG_NAME.tar.gz.sha256"
