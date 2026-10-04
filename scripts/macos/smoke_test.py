#!/usr/bin/env python3
"""Smoke test of an EXTRACTED khaiii macOS arm64 archive (no build, no repo checkout).

usage: smoke_test.py <extracted-dir> <expected-version>
"""
import os
import platform
import shutil
import sys
import tempfile

root, expected_version = os.path.abspath(sys.argv[1]), sys.argv[2]
assert platform.system() == 'Darwin' and platform.machine() == 'arm64', platform.platform()
sys.path.insert(0, os.path.join(root, 'python'))      # only the packaged binding
import khaiii                                          # noqa: E402
assert os.path.realpath(khaiii.__file__).startswith(os.path.realpath(root)), khaiii.__file__
from khaiii import KhaiiiApi, KhaiiiExcept             # noqa: E402

LIB = os.path.join(root, 'lib', 'libkhaiii.dylib')
RSC = os.path.join(root, 'share', 'khaiii')


def analyze(api, text):
    morphs = [(m.lex, m.tag, m.begin, m.length) for w in api.analyze(text) for m in w.morphs]
    print('%s -> %s' % (text, ' '.join('%s/%s' % (lex, tag) for lex, tag, _, _ in morphs)))
    return morphs


api = KhaiiiApi(lib_path=LIB, rsc_dir=RSC)
print('library version:', api.version())
assert api.version() == expected_version, api.version()

# structure: spans lie within the sentence and are ordered; tags are non-empty
for text in ('책을 읽었다.', '예쁜 꽃이 피었다.', '아버지가 방에 들어가신다.',
             '그는 학교에 갔지만 친구를 만나지 못했습니다.'):
    morphs = analyze(api, text)
    assert morphs, text
    last = 0
    for lex, tag, begin, length in morphs:
        assert lex and tag and 0 <= begin and length > 0 and begin + length <= len(text), (text, lex)
        assert begin >= last - 0, (text, lex)   # non-decreasing begin offsets
        last = begin

# representative POS checks (prefix match keeps this robust to benign tagging detail)
def tags(text):
    return [(lex, tag) for lex, tag, _, _ in analyze(api, text)]


t = tags('책을 읽었다.')
assert ('책', 'NNG') in t and ('을', 'JKO') in t, t                       # noun + object particle
assert any(lex == '읽' and tag == 'VV' for lex, tag in t), t              # verb stem
assert any(tag == 'EP' for _, tag in t) and any(tag == 'EF' for _, tag in t), t   # tense, ending
t = tags('예쁜 꽃이 피었다.')
assert any(tag == 'VA' for _, tag in t), t                                # adjective
assert any(lex == '꽃' and tag == 'NNG' for lex, tag in t), t
assert any(tag == 'ETM' for _, tag in t), t                               # adnominal ending
t = tags('아버지가 방에 들어가신다.')
assert any(tag == 'VV' for _, tag in t) and any(lex == '시' and tag == 'EP' for lex, tag in t), t
api.close()

# failure paths must raise understandable errors, not crash
tmp = tempfile.mkdtemp()
try:
    for name, mutate in (
            ('missing dir', lambda d: shutil.rmtree(d)),
            ('missing config.json', lambda d: os.remove(os.path.join(d, 'config.json'))),
            ('missing embed.bin', lambda d: os.remove(os.path.join(d, 'embed.bin'))),
            ('corrupt config.json', lambda d: open(os.path.join(d, 'config.json'), 'w').write('{broken'))):
        bad = os.path.join(tmp, name.replace(' ', '_'))
        shutil.copytree(RSC, bad)
        mutate(bad)
        try:
            KhaiiiApi(lib_path=LIB, rsc_dir=bad)
        except KhaiiiExcept as exc:
            assert str(exc), name
            print('OK %-20s -> KhaiiiExcept: %s' % (name, exc))
        else:
            raise AssertionError('no error for: ' + name)
finally:
    shutil.rmtree(tmp)
print('SMOKE TEST PASSED')
