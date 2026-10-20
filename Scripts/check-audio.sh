#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTC="${SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
IOS_SDK="${IOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk}"
MACOS_SDK="${MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}"
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/airstrum-audio.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT

printf '%s\n' 'Typechecking production sources against the iOS SDK (no xcodebuild or license changes).'
"$SWIFTC" -frontend -typecheck -warnings-as-errors -target arm64-apple-ios17.0 \
    -sdk "$IOS_SDK" "$ROOT/AirStrum/ChordAudioEngine.swift" "$ROOT/Shared/Chord.swift"

printf '%s\n' 'Compiling the actual engine with macOS offline checks; AVAudioSession is iOS-only.'
"$SWIFTC" -warnings-as-errors -sdk "$MACOS_SDK" \
    "$ROOT/AirStrum/ChordAudioEngine.swift" "$ROOT/Shared/Chord.swift" \
    "$ROOT/Tests/AudioVoiceChecks.swift" -o "$BUILD/audio-voice-checks"
"$BUILD/audio-voice-checks"
