#!/usr/bin/env python3
"""Run opt-in native acceptance against synthetic staging identities.

Credentials are read from a private directory, never passed through Gradle or
compiled into either app. Build the staging simulator/test APKs first.
"""
import argparse
import glob
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import sqlite3
import subprocess
import time
import threading

parser = argparse.ArgumentParser()
parser.add_argument("platform", choices=["ios", "android"])
parser.add_argument("--private-dir", required=True, type=Path)
parser.add_argument("--derived-data", type=Path, default=Path("/tmp/sprout-ai-native-derived"))
parser.add_argument("--device")
parser.add_argument("--release-apk", type=Path)
parser.add_argument("--release-ios-app", type=Path, help="Optimized app from a separate Release DerivedData directory; keep the Debug test runner in --derived-data")
parser.add_argument("--configuration", choices=["Debug", "Release"], default="Debug")
parser.add_argument("--phase", choices=["capture", "roundtrip", "offline", "recovery", "shortcut", "export", "goals", "goalroundtrip", "deletion", "realtime", "sdk-auth", "budgets", "budgetconflict", "deletionlostresponse", "navigation", "receipt-ocr", "release-smoke", "import", "receipt-retention", "preferences", "preferences-roundtrip", "expenseconflict", "goalconflict", "weekly", "password"], default="capture")
args = parser.parse_args()
edit_kind = {"expenseconflict": "expense", "goalconflict": "goal"}.get(args.phase)
edit_suffix = "ExpenseConflict" if edit_kind == "expense" else "GoalConflict"
marker_prefix = "sprout-edit" if edit_kind else "sprout-budget" if args.phase == "budgetconflict" else "sprout-realtime"
directory = args.private_dir.resolve()
assert directory.is_dir() and directory.stat().st_mode & 0o077 == 0, "Use a private directory (0700)."
root = Path(__file__).resolve().parent.parent
original_identity = json.loads((directory / "test-identities.json").read_text())[0]
if args.phase == "password":
    subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "security-setup"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory), SPROUT_TEST_PLATFORM=args.platform), check=True, capture_output=True)
    identity = json.loads((directory / "native-security-identities.json").read_text())[0 if args.platform == "ios" else 1]
else:
    identity = json.loads((directory / ("native-privacy-identities.json" if args.phase in ("deletion", "sdk-auth", "deletionlostresponse") else "test-identities.json")).read_text())[1 if args.phase in ("deletion", "deletionlostresponse") and args.platform == "android" else 0]
stamp = str(int(time.time()))
log_path = directory / f"{args.platform}-live-{args.phase}-{stamp}.log"
if args.phase == "weekly":
    subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "weekly-setup"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory)), check=True, capture_output=True)
if edit_kind:
    subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "edit-conflict-setup"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory), SPROUT_TEST_PLATFORM=args.platform, SPROUT_TEST_EDIT_KIND=edit_kind), check=True, capture_output=True)
if args.phase == "export":
    subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "native-export-setup"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory)), check=True, capture_output=True)
if args.phase in ("preferences", "budgets", "budgetconflict"):
    subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "preferences-setup" if args.phase == "preferences" else "budget-setup" if args.phase == "budgets" else "budget-conflict-setup"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory), SPROUT_TEST_PLATFORM=args.platform), check=True, capture_output=True)


if args.platform == "ios":
    assert args.phase in ("capture", "roundtrip", "shortcut", "export", "goals", "goalroundtrip", "deletion", "realtime", "sdk-auth", "budgets", "budgetconflict", "release-smoke", "import", "offline", "receipt-retention", "preferences", "preferences-roundtrip", "expenseconflict", "goalconflict", "weekly", "password")
    products = args.derived_data / "Build/Products"
    assert not args.release_ios_app or args.configuration == "Release"
    app_bundle = args.release_ios_app.resolve() if args.release_ios_app else products / f"{args.configuration}-iphonesimulator/Sprout.app"
    assert args.configuration != "Release" or args.phase == "release-smoke", "The release acceptance uses the explicit release journey."
    info = plistlib.loads((app_bundle / "Info.plist").read_bytes())
    assert info["SPROUT_APPWRITE_PROJECT_ID"] == "6af0f72200383d2f1084"
    assert info["SPROUT_APPWRITE_ENDPOINT"] == "https://nyc.cloud.appwrite.io/v1"
    debug_binary = app_bundle / "Sprout.debug.dylib"
    executable = debug_binary if debug_binary.exists() else app_bundle / "Sprout"
    libraries = subprocess.check_output(["otool", "-L", str(executable)], text=True)
    assert "@rpath/libswiftCompatibilitySpan.dylib" not in libraries or (app_bundle / "Frameworks/libswiftCompatibilitySpan.dylib").exists(), "Required Swift compatibility runtime is missing; rebuild with the shared Sprout CI scheme."
    source = Path(glob.glob(str(products / "*.xctestrun"))[0])
    settings = plistlib.loads(source.read_bytes())
    labels_path = directory / "native-test-labels.json"
    labels = json.loads(labels_path.read_text()) if labels_path.exists() else {}
    receipt_photo_created_at = ""
    if args.phase == "receipt-retention":
        labels["iosReceiptMerchant"] = "iOS Receipt " + stamp
        labels_path.write_text(json.dumps(labels))
        fixture = directory / "synthetic-receipt.jpg"
        assert fixture.is_file(), "Supply a synthetic receipt JPEG for the system photo picker."
        device = args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6"
        media = Path.home() / "Library/Developer/CoreSimulator/Devices" / device / "data/Media/DCIM"
        expected = hashlib.sha256(fixture.read_bytes()).hexdigest()
        # Reimporting an already published fixture can stall Photos while an
        # earlier system picker remains open. Reuse only exact fixture bytes;
        # the test still has to choose the image through the real picker.
        present = media.is_dir() and any(item.is_file() and item.stat().st_size == fixture.stat().st_size and hashlib.sha256(item.read_bytes()).hexdigest() == expected for item in media.rglob("*"))
        if not present:
            subprocess.run(["xcrun", "simctl", "addmedia", device, str(fixture)], check=True, capture_output=True, timeout=120)
        # Fixture setup only: locate the exact imported bytes, then use their
        # creation instant to disambiguate native photo-picker accessibility.
        # No application or financial database is read or modified here.
        names = [item.name for item in media.rglob("*") if item.is_file() and item.stat().st_size == fixture.stat().st_size and hashlib.sha256(item.read_bytes()).hexdigest() == expected]
        library = media.parent / "PhotoData/Photos.sqlite"
        with sqlite3.connect(library.as_uri() + "?mode=ro", uri=True) as photos:
            for name in names:
                row = photos.execute("SELECT ZDATECREATED FROM ZASSET WHERE ZFILENAME = ?", (name,)).fetchone()
                if row:
                    receipt_photo_created_at = str(float(row[0]) + 978307200)
                    break
        assert receipt_photo_created_at, "The exact synthetic photo must be published before native acceptance."
    if args.phase == "offline":
        labels["iosOfflineMerchant"] = "iOS Offline " + stamp
        labels_path.write_text(json.dumps(labels))
    if args.phase == "import":
        labels["iosImportMerchant"] = "iOS Import " + stamp
        labels_path.write_text(json.dumps(labels))
    if args.phase == "release-smoke":
        labels["iosReleaseMerchant"] = "iOS Release " + stamp
        labels_path.write_text(json.dumps(labels))
    if args.phase == "realtime":
        labels["iosRealtimeMerchant"] = "iOS Remote Change " + stamp
        labels_path.write_text(json.dumps(labels))
    if args.phase == "shortcut":
        labels["iosShortcutMerchant"] = "iOS Shortcut Lunch " + stamp
        labels_path.write_text(json.dumps(labels))
    if args.phase == "goals":
        labels["iosGoal"] = "iOS Emergency Goal " + stamp
        labels_path.write_text(json.dumps(labels))
    def replace(value):
        if isinstance(value, str): return value.replace("__TESTROOT__", str(products))
        if isinstance(value, list): return [replace(item) for item in value]
        if isinstance(value, dict): return {key: replace(item) for key, item in value.items()}
        return value
    settings = replace(settings)
    for configuration in settings["TestConfigurations"]:
        for target in configuration["TestTargets"]:
            if target["BlueprintName"] == "SproutUITests" and args.configuration == "Release":
                target["UITargetAppPath"] = str(app_bundle)
                target["DependentProductPaths"] = [str(app_bundle) if value == str(products / "Debug-iphonesimulator/Sprout.app") else value for value in target.get("DependentProductPaths", [])]
            if target["BlueprintName"] in ("SproutUITests", "SproutTests"):
                target.setdefault("EnvironmentVariables", {}).update(SPROUT_LIVE_TEST_EMAIL=identity["email"], SPROUT_LIVE_TEST_PASSWORD=identity["password"], SPROUT_LIVE_TEST_PHASE=args.phase, SPROUT_LIVE_SECURITY_NEXT_PASSWORD=identity.get("temporaryPassword", ""), SPROUT_LIVE_RETURN_EMAIL=original_identity["email"], SPROUT_LIVE_RETURN_PASSWORD=original_identity["password"], SPROUT_LIVE_WEEK=labels.get("weeklyWeek", ""), SPROUT_LIVE_WEEK_SPENDING=labels.get("weeklySpending", ""), SPROUT_LIVE_WEEK_INCOME=labels.get("weeklyIncome", ""), SPROUT_LIVE_EDIT_NAME=labels.get("ios"+edit_suffix+"Name", ""), SPROUT_LIVE_EDIT_ID=labels.get("ios"+edit_suffix+"Id", ""), SPROUT_LIVE_RECEIPT_MERCHANT=labels.get("iosReceiptMerchant", ""), SPROUT_LIVE_RECEIPT_PHOTO_CREATED_AT=receipt_photo_created_at, SPROUT_LIVE_RELEASE_MERCHANT=labels.get("iosReleaseMerchant", ""), SPROUT_LIVE_IMPORT_MERCHANT=labels.get("iosImportMerchant", ""), SPROUT_LIVE_OFFLINE_MERCHANT=labels.get("iosOfflineMerchant", ""), SPROUT_LIVE_BUDGET_CONFLICT_CATEGORY=labels.get("iosBudgetConflictCategory", ""), SPROUT_LIVE_BUDGET_CONFLICT_MONTH=labels.get("iosBudgetConflictMonth", ""), SPROUT_LIVE_BUDGET_CATEGORY=labels.get("iosBudgetCategory", ""), SPROUT_LIVE_BUDGET_PRIOR_MONTH=labels.get("iosBudgetPriorMonth", ""), SPROUT_LIVE_REALTIME_MERCHANT=labels.get("iosRealtimeMerchant", ""), SPROUT_LIVE_PRIVACY_MERCHANT=identity.get("merchant", ""), SPROUT_LIVE_GOAL_NAME=labels.get("iosGoal", ""), SPROUT_LIVE_ANDROID_MERCHANT=labels.get("androidMerchant", ""), SPROUT_LIVE_SHORTCUT_MERCHANT=labels.get("iosShortcutMerchant", ""))
    configured = directory / "live-staging.xctestrun"
    configured.write_bytes(plistlib.dumps(settings)); configured.chmod(0o600)
    bundle = directory / f"ios-live-{args.phase}-{stamp}.xcresult"
    test = {"password":"testLivePasswordChangeAndAccountIsolation", "weekly":"testLiveWeeklyReviewWithoutNotificationOptIn", "expenseconflict":"testLiveReviewedEditConflict", "goalconflict":"testLiveReviewedEditConflict", "preferences":"testLiveNotificationPreferences", "preferences-roundtrip":"testLiveNotificationPreferencesRoundtrip", "receipt-retention":"testLiveReceiptPhotoOptInPreviewAndRemoval", "capture":"testLiveOnboardingExpenseAndRestoration", "roundtrip":"testLiveCrossPlatformEditAndDelete", "shortcut":"testLiveShortcutOpensReviewAndSaves", "export":"testLiveExportAutomaticallyBecomesDownloadable", "goals":"testLiveGoalAllocationAndAcknowledgment", "goalroundtrip":"testLiveGoalEditedOnAndroid", "deletion":"testLiveDeletionRevokesAccessAndRestoresProgress", "realtime":"testLiveRemoteChangeAppearsWithoutRefresh", "sdk-auth":"testLiveSDKEmailAuthentication", "budgets":"testLiveCurrentAndHistoricalBudgetEdits", "budgetconflict":"testLiveCompetingBudgetRequiresExplicitReview", "release-smoke":"testLiveReleaseReviewedExpense", "import":"testLiveCSVReviewImportAndRestoration", "offline":"testLiveOfflineSaveColdRestoreAndReconnect"}[args.phase]
    subprocess.run(["xcrun", "simctl", "install", args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6", str(app_bundle)], check=True, capture_output=True)
    subprocess.run(["xcrun", "simctl", "uninstall", args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6", "com.michaeldadi.SproutUITests.xctrunner"], capture_output=True)
    test_class = "SproutTests/MoneyDomainTests" if args.phase == "sdk-auth" else "SproutUITests/MoneyLiveAcceptanceTests"
    command = ["xcodebuild", "test-without-building", "-xctestrun", str(configured), "-destination", f"platform=iOS Simulator,id={args.device or 'AE9767BE-CAA3-4000-837B-8666AA6E20D6'}", "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "300", "-maximum-test-execution-time-allowance", "600", f"-only-testing:{test_class}/{test}", "-resultBundlePath", str(bundle)]
else:
    device = args.device or "emulator-5554"
    assert re.fullmatch(r"emulator-\d+", device), "This runner targets emulators only."
    sdk = Path(os.environ.get("ANDROID_HOME", str(Path.home() / "Library/Android/sdk")))
    adb = [str(sdk / "platform-tools/adb"), "-s", device]
    deadline = time.monotonic() + 180
    while subprocess.run(adb + ["shell", "getprop", "sys.boot_completed"], capture_output=True, text=True, timeout=10).stdout.strip() != "1":
        if time.monotonic() > deadline:
            raise RuntimeError("The QA emulator did not finish booting before APK installation.")
        time.sleep(1)
    app_apk = root / "apps/android/app/build/outputs/apk/debug/app-debug.apk"
    if args.phase == "release-smoke":
        assert args.release_apk and args.release_apk.resolve().is_file(), "Supply the locally signed minified release APK."
        app_apk = args.release_apk.resolve()
        generated = (root / "apps/android/app/build/generated/source/buildConfig/release/com/michaeldadi/sprout/BuildConfig.java").read_text()
        assert 'SPROUT_APPWRITE_PROJECT_ID = "6af0f72200383d2f1084"' in generated
        assert 'SPROUT_APPWRITE_ENDPOINT = "https://nyc.cloud.appwrite.io/v1"' in generated
        assert 'DEBUG = false' in generated
    test_package = "com.michaeldadi.sprout.test"
    packages = ["com.michaeldadi.sprout", test_package]
    apks = [app_apk, root / "apps/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"]
    if args.phase == "release-smoke":
        test_package = "com.michaeldadi.sprout.acceptance.test"
        packages = ["com.michaeldadi.sprout", "com.michaeldadi.sprout.acceptance", test_package]
        apks = [app_apk, root / "apps/android/acceptance/build/outputs/apk/debug/acceptance-debug.apk", root / "apps/android/acceptance/build/outputs/apk/androidTest/debug/acceptance-debug-androidTest.apk"]
    for apk in apks:
        subprocess.run(adb + ["install", "-r", str(apk)], check=True, capture_output=True)
    # API 37 can exhaust its bind deadline while verifying an instrumented
    # debug APK after replacement. Compile both installed packages first.
    for package in packages:
        subprocess.run(adb + ["shell", "cmd", "package", "compile", "-m", "speed", "-f", package], check=True, capture_output=True, timeout=180)
    labels_path = directory / "native-test-labels.json"
    labels = json.loads(labels_path.read_text()) if labels_path.exists() else {}
    if args.phase == "receipt-retention": labels["androidReceiptMerchant"] = "Android Receipt " + stamp
    if args.phase == "import": labels["androidImportMerchant"] = "Android Import " + stamp
    if args.phase == "release-smoke": labels["androidReleaseMerchant"] = "Android Release " + stamp
    if args.phase == "realtime": labels["androidRealtimeMerchant"] = "Android Remote Change " + stamp
    if args.phase == "goals": labels["androidGoal"] = "Android Travel Goal " + stamp
    if args.phase == "capture": labels["androidMerchant"] = "Android Live Lunch " + stamp
    if args.phase == "offline": labels["offlineMerchant"] = "Offline Live Draft " + stamp
    if args.phase == "shortcut": labels["androidShortcutMerchant"] = "Android Shortcut Lunch " + stamp
    labels_path.write_text(json.dumps(labels))
    merchant = labels["androidReceiptMerchant"] if args.phase == "receipt-retention" else labels["androidImportMerchant"] if args.phase == "import" else labels["androidReleaseMerchant"] if args.phase == "release-smoke" else labels["androidRealtimeMerchant"] if args.phase == "realtime" else identity["merchant"] if args.phase in ("deletion", "deletionlostresponse") else labels["offlineMerchant" if args.phase in ("offline", "recovery") else "androidShortcutMerchant" if args.phase == "shortcut" else "androidMerchant"]
    methods = {"password":"livePasswordChangeAndAccountIsolation", "weekly":"liveWeeklyReviewWithoutNotificationOptIn", "expenseconflict":"liveReviewedEditConflict", "goalconflict":"liveReviewedEditConflict", "preferences":"liveNotificationPreferencesCrossPlatform", "receipt-retention":"liveReceiptPhotoOptInPreviewAndRemoval", "import":"liveCsvReviewImportAndRestoration", "capture": "liveAuthenticationCrossPlatformReadAndExpenseSave", "roundtrip": "liveCrossPlatformEditAndDeletionReadback", "offline": "liveOfflineDraftSurvivesRecreation", "recovery": "liveOfflineDraftAcknowledgesAfterReconnect", "shortcut":"liveShortcutOpensReviewAndSaves", "export":"liveExportDownloadsPrivateJson", "goals":"liveGoalCrossPlatformEditAndCreate", "deletion":"liveDeletionRevokesAccessAndRestoresProgress", "realtime":"liveRemoteChangeAppearsWithoutRefresh", "budgets":"liveCurrentAndHistoricalBudgetEdits", "budgetconflict":"liveCompetingBudgetRequiresExplicitReview", "deletionlostresponse":"liveDeletionLostResponseRestoresSavedReceipt", "navigation":"liveColdSubscriptionBackStackAndRestoration", "receipt-ocr":"onDeviceReceiptOcrReadsPixelsBeforeReview"}
    test_class = "com.michaeldadi.sprout.acceptance.MoneyReleaseSmokeTest#minifiedReleaseRestoresAndSavesReviewedExpense" if args.phase == "release-smoke" else "com.michaeldadi.sprout.MoneyLiveAcceptanceTest#" + methods[args.phase]
    instrument = ["am", "instrument", "-w", "-r", "-e", "class", test_class, "-e", "sproutEmail", identity["email"], "-e", "sproutPassword", identity["password"], "-e", "sproutNextPassword", identity.get("temporaryPassword", ""), "-e", "sproutReturnEmail", original_identity["email"], "-e", "sproutReturnPassword", original_identity["password"], "-e", "sproutMerchant", merchant, "-e", "sproutPrivacyOwner", identity["id"], "-e", "sproutWeek", labels.get("weeklyWeek", ""), "-e", "sproutWeekSpending", labels.get("weeklySpending", ""), "-e", "sproutWeekIncome", labels.get("weeklyIncome", ""), "-e", "sproutEditKind", edit_kind or "", "-e", "sproutEditName", labels.get("android"+edit_suffix+"Name", ""), "-e", "sproutEditId", labels.get("android"+edit_suffix+"Id", ""), "-e", "sproutBudgetConflictCategory", labels.get("androidBudgetConflictCategory", ""), "-e", "sproutBudgetConflictMonth", labels.get("androidBudgetConflictMonth", ""), "-e", "sproutBudgetCategory", labels.get("androidBudgetCategory", ""), "-e", "sproutBudgetPriorMonth", labels.get("androidBudgetPriorMonth", ""), "-e", "sproutIosGoal", labels.get("iosGoal", ""), "-e", "sproutAndroidGoal", labels.get("androidGoal", ""), test_package + "/androidx.test.runner.AndroidJUnitRunner"]
    command = adb + ["shell", shlex.join(instrument)]

stop_remote = threading.Event()
remote_result = []
def remote_change():
    # Readiness comes from the test process after initial sync is idle. This
    # prevents a slow emulator startup from masquerading as realtime delivery.
    expected = labels[args.platform + (edit_suffix+"Name" if edit_kind else "BudgetConflictCategory" if args.phase == "budgetconflict" else "RealtimeMerchant")]
    deadline = time.monotonic() + 240
    while not stop_remote.is_set() and time.monotonic() < deadline:
        try:
            value = remote_ready_value()
        except (subprocess.TimeoutExpired, OSError):
            value = ""
        if value == expected: break
        if stop_remote.wait(1): return
    else: return
    # Let the subscription finish opening after initial cursor synchronization.
    if stop_remote.wait(2): return
    env = dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory), SPROUT_TEST_PLATFORM=args.platform, SPROUT_TEST_EDIT_KIND=edit_kind or "")
    with (directory / f"{args.platform}-remote-write-{stamp}.log").open("w") as log:
        remote_result.append(subprocess.call(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "edit-conflict-remote" if edit_kind else "budget-conflict-remote" if args.phase == "budgetconflict" else "realtime"], cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT))

    if (edit_kind or args.phase == "budgetconflict") and remote_result == [0]:
        if args.platform == "android":
            subprocess.run(adb + ["shell", shlex.join(["sh", "-c", f'printf %s "$1" > /sdcard/Android/data/com.michaeldadi.sprout/files/{marker_prefix}-remote-done', "sprout", expected])], check=True, capture_output=True)
        else:
            container = subprocess.check_output(["xcrun", "simctl", "get_app_container", args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6", "com.michaeldadi.SproutUITests.xctrunner", "data"], text=True).strip()
            (Path(container) / f"Documents/{marker_prefix}-remote-done").write_text(expected)

def remote_ready_value():
    if args.platform == "android":
        ready = subprocess.run(adb + ["shell", "cat", f"/sdcard/Android/data/com.michaeldadi.sprout/files/{marker_prefix}-ready"], capture_output=True, text=True, timeout=30)
        value = ready.stdout.strip() if ready.returncode == 0 else ""
    else:
        container = subprocess.run(["xcrun", "simctl", "get_app_container", args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6", "com.michaeldadi.SproutUITests.xctrunner", "data"], capture_output=True, text=True, timeout=30)
        marker = Path(container.stdout.strip()) / f"Documents/{marker_prefix}-ready" if container.returncode == 0 else None
        value = marker.read_text().strip() if marker and marker.exists() else ""
    return value
remote_thread = threading.Thread(target=remote_change) if args.phase in ("realtime", "budgetconflict", "expenseconflict", "goalconflict") else None
if remote_thread: remote_thread.start()
try:
    if args.platform == "android" and args.phase in ("offline", "receipt-ocr"):
        for action in [["cmd", "connectivity", "airplane-mode", "enable"], ["svc", "wifi", "disable"], ["svc", "data", "disable"]]:
            subprocess.run(adb + ["shell", shlex.join(action)], check=True, capture_output=True)
    with log_path.open("w") as log:
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            # XCTest may include a truncated secure-field input in its own log.
            line = (line.split("Type '", 1)[0] + "Typed input [redacted]\n") if "Type '" in line and " into " in line else line
            for sensitive in (identity["password"], identity["email"], identity.get("temporaryPassword", ""), original_identity["email"], original_identity["password"]):
                if not sensitive: continue
                line = line.replace(sensitive, "[redacted]")
                if len(sensitive) >= 12: line = line.replace(sensitive[:12], "[redacted-prefix]")
            log.write(line); log.flush()
        process.wait()
        result = subprocess.CompletedProcess(command, process.returncode)
finally:
    stop_remote.set()
    if remote_thread: remote_thread.join(timeout=30)
    if args.platform == "android" and args.phase in ("offline", "receipt-ocr"):
        for action in [["cmd", "connectivity", "airplane-mode", "disable"], ["svc", "wifi", "enable"], ["svc", "data", "enable"]]:
            subprocess.run(adb + ["shell", shlex.join(action)], check=True, capture_output=True)
passed = result.returncode == 0 and (args.phase not in ("realtime", "budgetconflict", "expenseconflict", "goalconflict") or remote_result == [0])
if args.platform == "android": passed = passed and "OK (1 test)" in log_path.read_text()
else:
    summary_result = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle), "--format", "json"], capture_output=True, text=True)
    try: summary = json.loads(summary_result.stdout) if summary_result.returncode == 0 else {}
    except json.JSONDecodeError: summary = {}
    passed = passed and summary.get("totalTestCount") == 1 and summary.get("passedTests") == 1 and summary.get("skippedTests") == 0
if passed and (args.phase in ("budgets", "budgetconflict", "release-smoke", "import", "receipt-retention", "preferences", "preferences-roundtrip", "expenseconflict", "goalconflict", "weekly", "password") or args.platform == "ios" and args.phase == "offline"):
    readback = subprocess.run(["yarn", "workspace", "@sprout/services", "exec", "tsx", "../scripts/validate-live-workflows.ts", "security-readback" if args.phase == "password" else "weekly-readback" if args.phase == "weekly" else "edit-conflict-readback" if edit_kind else "preferences-roundtrip-readback" if args.phase == "preferences-roundtrip" else "preferences-readback" if args.phase == "preferences" else "receipt-readback" if args.phase == "receipt-retention" else "ios-offline-readback" if args.phase == "offline" else "import-readback" if args.phase == "import" else "release-readback" if args.phase == "release-smoke" else "budget-readback" if args.phase == "budgets" else "budget-conflict-readback"], cwd=root, env=dict(os.environ, SPROUT_DEPLOYMENT_REPORT_DIR=str(directory), SPROUT_TEST_PLATFORM=args.platform, SPROUT_TEST_EDIT_KIND=edit_kind or ""), capture_output=True, text=True)
    passed = readback.returncode == 0
report = {"platform": args.platform, "phase": args.phase, "status": "passed" if passed else "failed", "log": str(log_path)}
if passed and args.phase == "export":
    readback = subprocess.run(["python3", "scripts/validate-native-export-archive.py", args.platform, "--private-dir", str(directory), "--device", args.device or ("emulator-5554" if args.platform == "android" else "AE9767BE-CAA3-4000-837B-8666AA6E20D6")], cwd=root, capture_output=True, text=True)
    passed = readback.returncode == 0
    report["status"] = "passed" if passed else "failed"
    if not passed:
        (directory / f"{args.platform}-export-archive-readback.log").write_text(readback.stdout + readback.stderr)
if args.platform == "android":
    report["device"] = args.device or "emulator-5554"
    report["appApkSha256"] = hashlib.sha256(app_apk.read_bytes()).hexdigest()
    if args.phase == "release-smoke":
        report["variant"] = "minified release, local test signature"
        report["mappingSha256"] = hashlib.sha256((root / "apps/android/app/build/outputs/mapping/release/mapping.txt").read_bytes()).hexdigest()
if args.platform == "ios":
    report["resultBundle"] = str(bundle)
    report["tests"] = {"executed": summary.get("totalTestCount", 0), "passed": summary.get("passedTests", 0), "skipped": summary.get("skippedTests", 0)}
    report["device"] = args.device or "AE9767BE-CAA3-4000-837B-8666AA6E20D6"
    artifact = app_bundle / "Sprout.debug.dylib"
    if not artifact.exists(): artifact = app_bundle / "Sprout"
    if artifact.exists():
        digest = hashlib.sha256()
        with artifact.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""): digest.update(chunk)
        report["appCodeSha256"] = digest.hexdigest()
        if args.configuration == "Release":
            installed = Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", report["device"], "com.michaeldadi.Sprout", "app"], text=True, timeout=30).strip())
            installed_hash = hashlib.sha256((installed / "Sprout").read_bytes()).hexdigest()
            passed = passed and installed_hash == report["appCodeSha256"] and not (installed / "Sprout.debug.dylib").exists()
            report["installedCodeSha256"] = installed_hash
            report["configuration"] = "Release"
            report["status"] = "passed" if passed else "failed"
    if not summary: report["failureReason"] = "No readable test result summary; no passing test is counted."
(directory / f"{args.platform}-latest-result.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
raise SystemExit(0 if passed else 1)
