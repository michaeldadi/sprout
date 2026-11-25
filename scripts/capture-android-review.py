#!/usr/bin/env python3
"""Capture installed Debug review screens, waiting for fresh accessibility state."""
import argparse
import pathlib
import re
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument("--adb", required=True)
parser.add_argument("--serial", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--dark", action="store_true")
parser.add_argument("--keyboard", action="store_true", help="Review a typed amount in the expense sheet with the system keyboard open")
parser.add_argument("frames", nargs="+")
args = parser.parse_args()
if not args.serial.startswith("emulator-"):
    raise SystemExit("This fixture capture command is restricted to an emulator.")
ready = {
    "welcome": ["Make room for"], "connect-bank": ["A clearer picture starts"],
    "subscriptions-found": ["Estimated monthly cost", "Track 1 and continue"], "your-plan": ["Your monthly spending target"],
    "home": ["Based on saved spending"], "budget": ["Remaining monthly target"],
    "activity": ["This month", "All time", "Search your activity"],
    "subscriptions": ["Monthly equivalent", "Stream Club"], "subscription-detail": ["Charge history"],
    "insights": ["Feed", "Chat", "Your subscriptions and renewals"],
    "add-expense": ["Save to Activity", "Amount in USD"], "profile": ["Membership", "Lock on this device"],
}
adb = [args.adb, "-s", args.serial]
output = pathlib.Path(args.output); output.mkdir(parents=True, exist_ok=True)
for frame in args.frames:
    if frame not in ready: raise SystemExit("Unknown frame: " + frame)
    subprocess.run(adb + ["shell", "am", "force-stop", "com.michaeldadi.sprout"], check=True, capture_output=True, timeout=15)
    subprocess.run(adb + ["shell", "am", "start", "-n", "com.michaeldadi.sprout/.money.MoneyDesignReviewActivity", "--es", "frame", frame, "--ez", "dark", str(args.dark).lower()], check=True, capture_output=True, timeout=15)
    for attempt in range(12):
        remote = "/sdcard/sprout-review-" + uuid.uuid4().hex + ".xml"
        try:
            subprocess.run(adb + ["shell", "uiautomator", "dump", remote], check=True, capture_output=True, timeout=15)
            xml = subprocess.run(adb + ["shell", "cat", remote], check=True, capture_output=True, text=True, timeout=10).stdout
            root = ET.fromstring(xml)
            text = "\n".join(node.get("text", "") + " " + node.get("content-desc", "") for node in root.iter())
            if all(fragment in text for fragment in ready[frame]): break
        except (subprocess.SubprocessError, ET.ParseError):
            pass
        finally:
            subprocess.run(adb + ["shell", "rm", "-f", remote], capture_output=True, timeout=10)
        time.sleep(1)
    else: raise SystemExit("Native review did not become ready: " + frame)
    if "isn't responding" in text or "keeps stopping" in text:
        raise SystemExit("System or app failure blocks visual acceptance: " + frame)
    name = "android-" + frame + ("-dark" if args.dark else "")
    if args.keyboard and frame in ["add-expense", "insights"]:
        if frame == "insights":
            chat = next(node for node in root.iter() if node.get("text") == "Chat")
            left, top, right, bottom = map(int, re.findall(r"\d+", chat.get("bounds", "")))
            subprocess.run(adb + ["shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2)], check=True, capture_output=True, timeout=15)
            remote = "/sdcard/sprout-review-" + uuid.uuid4().hex + ".xml"
            try:
                subprocess.run(adb + ["shell", "uiautomator", "dump", remote], check=True, capture_output=True, timeout=15)
                xml = subprocess.run(adb + ["shell", "cat", remote], check=True, capture_output=True, text=True, timeout=10).stdout
                root = ET.fromstring(xml)
            finally:
                subprocess.run(adb + ["shell", "rm", "-f", remote], capture_output=True, timeout=10)
        field = next(node for node in root.iter() if node.get("class") == "android.widget.EditText")
        left, top, right, bottom = map(int, re.findall(r"\d+", field.get("bounds", "")))
        subprocess.run(adb + ["shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2)], check=True, capture_output=True, timeout=15)
        entry = "12.50" if frame == "add-expense" else "Review my budget"
        subprocess.run(adb + ["shell", "input", "text", entry.replace(" ", "%s")], check=True, capture_output=True, timeout=15)
        remote = "/sdcard/sprout-review-" + uuid.uuid4().hex + ".xml"
        try:
            subprocess.run(adb + ["shell", "uiautomator", "dump", remote], check=True, capture_output=True, timeout=15)
            xml = subprocess.run(adb + ["shell", "cat", remote], check=True, capture_output=True, text=True, timeout=10).stdout
            root = ET.fromstring(xml)
            if not any(node.get("class") == "android.widget.EditText" and node.get("text") == entry for node in root.iter()):
                raise SystemExit("Reviewed input did not reach the editor")
            keyboard = subprocess.run(adb + ["shell", "dumpsys", "input_method"], check=True, capture_output=True, text=True, timeout=15).stdout
            if "mInputShown=true" not in keyboard or "mIsInputViewShown=true" not in keyboard:
                raise SystemExit("System keyboard was not shown by the input method service")
        finally:
            subprocess.run(adb + ["shell", "rm", "-f", remote], capture_output=True, timeout=10)
        name += "-keyboard"
    # Accessibility can publish before a Material window transition finishes.
    # Keep the accepted image consistent with a fresh, settled UI hierarchy.
    time.sleep(0.75)
    remote = "/sdcard/sprout-review-" + uuid.uuid4().hex + ".xml"
    try:
        subprocess.run(adb + ["shell", "uiautomator", "dump", remote], check=True, capture_output=True, timeout=15)
        xml = subprocess.run(adb + ["shell", "cat", remote], check=True, capture_output=True, text=True, timeout=10).stdout
        if "isn&apos;t responding" in xml or "isn't responding" in xml or "keeps stopping" in xml:
            raise SystemExit("A stalled system surface cannot count as visual acceptance")
    finally:
        subprocess.run(adb + ["shell", "rm", "-f", remote], capture_output=True, timeout=10)
    (output / (name + ".xml")).write_text(xml)
    (output / (name + ".png")).write_bytes(subprocess.run(adb + ["exec-out", "screencap", "-p"], check=True, capture_output=True, timeout=15).stdout)
    print(name + " ready", flush=True)
