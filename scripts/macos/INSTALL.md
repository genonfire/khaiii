# khaiii v0.4 for macOS arm64 (native, no Docker, no build)

Upstream-derived binary of Kakao's official khaiii v0.4 built with build-compatibility
fixes only. It is **not** a new morphological model; the model is the unchanged upstream
`base` model. See `PROVENANCE.json` for exact source commit, toolchain and digests.

## Requirements
- macOS on Apple Silicon (arm64). Built with deployment target 14.0, **tested only on macOS 15** (GitHub `macos-15` runner).
- Python 3 with `ctypes` (pure-Python upstream wrapper; no extra packages). CI smoke test uses Python 3.12.

## Install
```sh
shasum -a 256 -c khaiii-0.4-macos-arm64.tar.gz.sha256
tar -xzf khaiii-0.4-macos-arm64.tar.gz
( cd khaiii-0.4-macos-arm64 && shasum -a 256 -c MANIFEST.sha256 )
```
If a browser-downloaded archive is quarantined: `xattr -dr com.apple.quarantine khaiii-0.4-macos-arm64`
(the library is only ad-hoc signed; **it is not Developer-ID signed and not Apple-notarized**).

## Use
```python
import sys
root = 'khaiii-0.4-macos-arm64'
sys.path.insert(0, root + '/python')
from khaiii import KhaiiiApi
api = KhaiiiApi(lib_path=root + '/lib/libkhaiii.dylib', rsc_dir=root + '/share/khaiii')
print(api.version())                         # 0.4
for word in api.analyze('책을 읽었다.'):
    print(word.lex, [(m.lex, m.tag) for m in word.morphs])
```

## Layout
`lib/libkhaiii.dylib` · `share/khaiii/` (model + resources) · `python/khaiii/` (upstream binding) ·
`include/khaiii/` · `licenses/` (Apache-2.0 LICENSE, third-party NOTICE.md) · `MANIFEST.sha256` · `PROVENANCE.json`
