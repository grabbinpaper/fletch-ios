// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FieldWork",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "FieldWork", targets: ["FieldWork"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "FieldWork",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "FieldWork"
        )
    ]
)
