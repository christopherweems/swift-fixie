// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-fixie",
    platforms: [
        .macOS(.v15),
        
    ],
    products: [
        .executable(name: "fixie", targets: ["Fixie"]),
        
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.2.0"),
        
    ],
    targets: [
        .executableTarget(
            name: "Fixie",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
            
            ],
        ),
        
        .testTarget(
            name: "FixieTests",
            dependencies: [
                "Fixie",
                
            ],
        )
    ]
)
