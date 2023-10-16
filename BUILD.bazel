load("@build_bazel_rules_apple//apple:ios.bzl", "ios_framework")

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CloudVeilSecurityManager",
    module_name = "CloudVeilSecurityManager",
    srcs = glob(["Sources/CloudVeilSecurityManager/**/*.swift"]),
    visibility = ["//visibility:public"],
    deps = [
        "@Alamofire//:Alamofire",
        "@ObjectMapper//:ObjectMapper",
    ],
)
