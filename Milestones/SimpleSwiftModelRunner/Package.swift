// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SimpleSwiftModelRunner",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "simple-model-server", targets: ["SimpleModelRunner"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift",
            revision: "72f3c3ad8aeee39bfc94f8fbeb446cac89e3a798"
        ),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm",
            revision: "14414441fa44f45eee35a61e9fa0bab577cf9734",
            traits: []
        ),
        .package(
            url: "https://github.com/huggingface/swift-huggingface",
            exact: "0.9.0"
        ),
        .package(
            url: "https://github.com/huggingface/swift-transformers",
            exact: "1.3.3"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            exact: "2.101.3"
        ),
    ],
    targets: [
        .executableTarget(
            name: "SimpleModelRunner",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        )
    ]
)
