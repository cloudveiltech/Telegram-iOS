load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_configuration//:variables.bzl",
    "cloudveil_shiplogs",
)

swift_library(
    name = "CloudVeil",
    module_name = "CloudVeil",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ] + ["-D", "CLOUDVEIL_SHIPLOGS"] if cloudveil_shiplogs else [],
    deps = [],
    visibility = [
        "//visibility:public",
    ],
)
