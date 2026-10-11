// swift-tools-version:5.9

// The plugin's Objective-C sources, built against cordova-ios and tested with XCTest on an iOS simulator:
//   cd test/ios && xcodebuild test -scheme BluetoothClassicSerial -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
// (`npm run test:ios`). Sources/BluetoothClassicSerial is a link to src/ios, so the tests build what the plugin ships.

import PackageDescription

let package = Package(
    name: "BluetoothClassicSerial",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BluetoothClassicSerial", targets: ["BluetoothClassicSerial"])
    ],
    dependencies: [
        .package(path: "../../node_modules/cordova-ios")
    ],
    targets: [
        .target(
            name: "BluetoothClassicSerial",
            dependencies: [.product(name: "Cordova", package: "cordova-ios")],
            path: "Sources/BluetoothClassicSerial",
            publicHeadersPath: "."
        ),
        .testTarget(
            name: "BluetoothClassicSerialTests",
            dependencies: ["BluetoothClassicSerial"],
            path: "Tests"
        )
    ]
)
