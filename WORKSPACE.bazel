load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_apple",
    sha256 = "20da675977cb8249919df14d0ce6165d7b00325fb067f0b06696b893b90a55e8",
    url = "https://github.com/bazelbuild/rules_apple/releases/download/3.0.0/rules_apple.3.0.0.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

http_archive(
    name = "rules_pods",
    urls = ["https://github.com/pinterest/PodToBUILD/releases/download/6.3.2-370b622/PodToBUILD.zip"],
    sha256 = "ffdfe8c7a4c73cca5d7b7a67daa6ccdd046355637dbdb9b1366d021b4ad339b5",
)

load("@rules_pods//BazelExtensions:workspace.bzl", "new_pod_repository")

new_pod_repository(
    name = "ObjectMapper",
    url = "https://github.com/tristanhimmelman/ObjectMapper/archive/3.3.0.zip",
)

new_pod_repository(
    name = "Alamofire",
    url = "https://github.com/Alamofire/Alamofire/archive/4.9.1.zip",
)
