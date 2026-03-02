// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SpotifyLyrics",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SpotifyLyrics",
            path: "Sources/SpotifyLyrics",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/SpotifyLyrics/Info.plist"])
            ]
        )
    ]
)
