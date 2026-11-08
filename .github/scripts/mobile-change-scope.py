#!/usr/bin/env python3
"""Emit which mobile checks a changed-file list requires."""

import os
import sys


paths = [path for path in sys.stdin.buffer.read().decode().split("\0") if path]
shared_contract = any(
    path.startswith("services/api/")
    or path.startswith("infra/lib/constructs/")
    or path in {
        "services/package.json",
        "infra/lib/sprout-stack.ts",
    }
    for path in paths
)
workflow = any(
    path in {".github/workflows/mobile-ci.yml", ".github/scripts/mobile-change-scope.py"}
    for path in paths
)
ios = shared_contract or workflow or any(path.startswith("apps/ios/") for path in paths)
android = shared_contract or workflow or any(path.startswith("apps/android/") for path in paths)

with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    output.write(f"ios={str(ios).lower()}\n")
    output.write(f"android={str(android).lower()}\n")
    output.write(f"shared_contract={str(shared_contract).lower()}\n")
