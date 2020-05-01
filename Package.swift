// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CloudVeil-securityManager-ios",
    platforms: [
           .iOS(.v10),
       ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CloudVeil-securityManager-ios",
            type: .dynamic,
            targets: ["CloudVeilSecurityManager"]),
    ],
    dependencies: [
         .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "4.9.0")),
         .package(url: "https://github.com/patriciy/ObjectMapper.git", .upToNextMajor(from: "3.5.5")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CloudVeilSecurityManager",
            dependencies: ["Alamofire", "ObjectMapper"]),
    ]
)
