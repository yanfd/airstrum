#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
developer="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="${SWIFTC:-$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
ios_sdk="$developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
watch_sdk="$developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/airstrum-connectivity.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
"$compiler" -frontend -typecheck -warnings-as-errors -swift-version 5 -target arm64-apple-ios17.0 -sdk "$ios_sdk" \
    "$root/Shared/Chord.swift" "$root/Shared/WatchMessage.swift" \
    "$root/AirStrum/ChordAudioEngine.swift" "$root/AirStrum/AirStrumSession.swift"
"$compiler" -frontend -typecheck -warnings-as-errors -swift-version 5 -target arm64-apple-watchos10.0 -sdk "$watch_sdk" \
    "$root/Shared/Chord.swift" "$root/Shared/WatchMessage.swift" "$root/AirStrumWatch/WatchMotionController.swift"
"$compiler" -parse-as-library -swift-version 5 -D CONNECTIVITY_CHECKS -sdk "$sdk" \
    "$root/Shared/Chord.swift" "$root/Shared/WatchMessage.swift" \
    "$root/AirStrum/AirStrumSession.swift" \
    "$root/AirStrumWatch/WatchMotionController.swift" \
    "$root/Tests/ConnectivityChecks.swift" -o "$temporary/check-connectivity"
"$temporary/check-connectivity"
