#!/usr/bin/env python3
"""Fingerprint the public source inputs used to build an OpenRight app."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent.parent
paths = [root / name for name in ['Package.swift', 'Package.resolved', 'scripts/build.sh', 'scripts/sign-app.sh', 'scripts/make-icon.swift']]
paths += list((root / 'Sources').rglob('*.swift'))
paths += [path for path in (root / 'Resources').rglob('*') if path.is_file()]
digest = hashlib.sha256()
for path in sorted(paths):
    relative = path.relative_to(root).as_posix().encode()
    contents = path.read_bytes()
    digest.update(len(relative).to_bytes(8, 'big'))
    digest.update(relative)
    digest.update(len(contents).to_bytes(8, 'big'))
    digest.update(contents)
print(digest.hexdigest())
