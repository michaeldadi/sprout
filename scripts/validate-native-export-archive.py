#!/usr/bin/env python3
"""Read back only the synthetic QA app's archive after a native export test."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shlex
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("platform", choices=["ios", "android"])
parser.add_argument("--private-dir", required=True, type=Path)
parser.add_argument("--device", required=True)
args = parser.parse_args()
directory = args.private_dir.resolve()
assert directory.stat().st_mode & 0o077 == 0
labels = json.loads((directory / "native-test-labels.json").read_text())
if args.platform == "ios":
    container = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", args.device, "com.michaeldadi.Sprout", "data"], text=True).strip())
    files = sorted((container / "tmp/sprout-exports").rglob("*.zip"), key=lambda p: p.stat().st_mtime, reverse=True)
    assert files, "The native app did not produce a ZIP"
    content = files[0].read_bytes()
else:
    adb = str(Path.home() / "Library/Android/sdk/platform-tools/adb")
    command = [adb, "-s", args.device]
    paths = subprocess.check_output(command + ["shell", shlex.join(["run-as", "com.michaeldadi.sprout", "find", "cache/sprout-exports", "-type", "f", "-name", "*.zip"])], text=True).splitlines()
    assert paths, "The native app did not produce a ZIP"
    # The UI test records only its newly generated archive, avoiding stale files.
    marker = subprocess.check_output(command + ["exec-out", "run-as", "com.michaeldadi.sprout", "cat", "files/sprout-export-accepted"], text=True).strip()
    assert marker.startswith("cache/sprout-exports/") and marker in paths
    content = subprocess.check_output(command + ["exec-out", "run-as", "com.michaeldadi.sprout", "cat", marker])
with zipfile.ZipFile(io.BytesIO(content)) as archive:
    assert archive.testzip() is None
    snapshot = json.loads(archive.read("sprout-export.json"))
    assert snapshot["schemaVersion"] == 1 and snapshot["records"]["transactions"]
    receipt_id = labels["exportReceiptId"]
    receipts = [r for r in snapshot["records"]["receipts"] if r["id"] == receipt_id and not r["deleted"]]
    assert len(receipts) == 1 and receipts[0]["data"]["status"] == "ready"
    image = archive.read(f"receipts/{receipt_id}.jpg")
    assert hashlib.sha256(image).hexdigest() == labels["exportReceiptSha256"] == receipts[0]["data"]["sha256"]
    assert len(image) == receipts[0]["data"]["bytes"]
    assert "README.txt" in archive.namelist()
report = {"platform": args.platform, "status": "passed", "archiveSha256": hashlib.sha256(content).hexdigest(), "bytes": len(content), "tests": ["native export produces a standard ZIP", "independent reader verifies CRCs", "financial JSON and retained synthetic image are present", "image checksum and size match snapshot references"]}
(directory / f"live-{args.platform}-export-archive-results.json").write_text(json.dumps(report, indent=2))
print("Verified native ZIP, financial snapshot and retained synthetic receipt.")
