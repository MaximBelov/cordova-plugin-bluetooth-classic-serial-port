#!/usr/bin/env bash
# XCTest with code coverage, and the coverage of the plugin's own sources (src/ios) as a llvm-cov summary in coverage/ios.json.
# Run from test/ios (`npm run test:ios:coverage`).
set -euo pipefail

derived=.build/derived-data
rm -rf "$derived"
xcodebuild test -scheme BluetoothClassicSerial -destination "platform=iOS Simulator,name=$(node simulator.mjs)" \
  -enableCodeCoverage YES -derivedDataPath "$derived"

profile=$(ls -t "$derived"/Build/ProfileData/*/Coverage.profdata | head -1)
binary="$derived/Build/Products/Debug-iphonesimulator/BluetoothClassicSerialTests.xctest/BluetoothClassicSerialTests"
mkdir -p ../../coverage
# only the plugin's sources: not the tests, and not cordova-ios
xcrun llvm-cov export -summary-only -instr-profile="$profile" "$binary" \
  -ignore-filename-regex='(Tests|\.build|node_modules)' > ../../coverage/ios.json
