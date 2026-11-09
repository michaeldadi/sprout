#!/usr/bin/env python3
"""Create a reproducible, untracked Appwrite Function code archive."""

from __future__ import annotations

import gzip
import io
import tarfile
from pathlib import Path

root = Path(__file__).resolve().parents[3]
source = root / "services/appwrite/manual-transactions"
target = root / "infra/appwrite/.artifacts/manual-transactions-v1.tar.gz"
files = ("index.ts", "package.json", "package-lock.json", "tsconfig.json")

buffer = io.BytesIO()
with tarfile.open(fileobj=buffer, mode="w", format=tarfile.USTAR_FORMAT) as archive:
    for name in files:
        content = (source / name).read_bytes()
        info = tarfile.TarInfo(name)
        info.size = len(content)
        info.mode = 0o644
        info.uid = info.gid = info.mtime = 0
        archive.addfile(info, io.BytesIO(content))

target.parent.mkdir(parents=True, exist_ok=True)
with target.open("wb") as output:
    with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as zipped:
        zipped.write(buffer.getvalue())
print(target)
