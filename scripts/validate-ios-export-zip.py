#!/usr/bin/env python3
"""Check the shipping Swift ZIP writer with Python's independent ZIP reader."""
import pathlib
import subprocess
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="sprout-export-zip-") as work:
    directory = pathlib.Path(work)
    source = directory / "main.swift"
    source.write_text('''import Foundation
var archive = MoneyExportArchive.ZIP()
try archive.append(name: "sprout-export.json", data: Data("{\\"schemaVersion\\":1}".utf8))
try archive.append(name: "README.txt", data: Data("Public synthetic interoperability fixture".utf8))
try archive.append(name: "receipts/12345678-1234-1234-1234-123456789abc.jpg", data: Data([255,216,255,1,2,3,255,217]))
try archive.finish().write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
''')
    binary = directory / "writer"
    subprocess.run(["swiftc", str(root / "apps/ios/Sprout/Features/Money/MoneyExportArchive.swift"), str(source), "-o", str(binary)], check=True)
    target = directory / "export.zip"
    subprocess.run([str(binary), str(target)], check=True)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == 3
        assert archive.read("sprout-export.json") == b'{"schemaVersion":1}'
        assert archive.read("receipts/12345678-1234-1234-1234-123456789abc.jpg") == bytes([255,216,255,1,2,3,255,217])
    print("Swift ZIP interoperates with Python: JSON, image, CRCs and central directory verified.")
