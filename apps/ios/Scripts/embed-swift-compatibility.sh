#!/bin/bash
set -euo pipefail
# Xcode 27's default lookup omits the Swift 6.2 Span compatibility library.
# Use Apple's stdlib tool and shipped runtime; never vendor a binary in the repo.
case "${PLATFORM_NAME}" in iphoneos|iphonesimulator) ;; *) exit 0 ;; esac
binary="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
debug_binary="$(dirname "$binary")/${EXECUTABLE_NAME}.debug.dylib"
if [[ -f "$debug_binary" ]]; then binary="$debug_binary"; fi
if ! /usr/bin/otool -L "$binary" | /usr/bin/grep -F '@rpath/libswiftCompatibilitySpan.dylib' > /dev/null; then exit 0; fi
runtime="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"
if [[ ! -f "$runtime/libswiftCompatibilitySpan.dylib" ]]; then runtime="${DT_TOOLCHAIN_DIR}/usr/lib/swift-6.2/${PLATFORM_NAME}"; fi
if [[ ! -f "$runtime/libswiftCompatibilitySpan.dylib" ]]; then
  echo 'Required Swift Span compatibility runtime is missing from this toolchain.' >&2
  exit 1
fi
args=(--copy --scan-executable "$binary" --platform "$PLATFORM_NAME" --source-libraries "$runtime" --destination "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}")
if [[ "${CODE_SIGNING_ALLOWED:-NO}" == YES && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then args+=(--sign "$EXPANDED_CODE_SIGN_IDENTITY"); fi
/usr/bin/xcrun swift-stdlib-tool "${args[@]}"
test -f "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/libswiftCompatibilitySpan.dylib"

# Run after Xcode's CopySwiftLibs, which otherwise removes this compatibility
# library when filtering standard libraries already supplied by the selected SDK.
if [[ "${CODE_SIGNING_ALLOWED:-NO}" == YES && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --preserve-metadata=identifier,entitlements,requirements,flags,runtime "${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
  /usr/bin/codesign --verify --strict "${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
fi
