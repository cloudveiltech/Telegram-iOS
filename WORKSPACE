load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

http_archive(
    name = "bazel_features",
    sha256 = "9fcb3d7cbe908772462aaa52f02b857a225910d30daa3c252f670e3af6d8036d",
    strip_prefix = "bazel_features-1.0.0",
    url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.0.0/bazel_features-v1.0.0.tar.gz",
)
load("@bazel_features//:deps.bzl", "bazel_features_deps")
bazel_features_deps()

local_repository(
    name = "build_bazel_rules_apple",
    path = "build-system/bazel-rules/rules_apple",
)

local_repository(
    name = "build_bazel_rules_swift",
    path = "build-system/bazel-rules/rules_swift",
)

local_repository(
    name = "build_bazel_apple_support",
    path = "build-system/bazel-rules/apple_support",
)

local_repository(
    name = "rules_xcodeproj",
    path = "build-system/bazel-rules/rules_xcodeproj",
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
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

load(
    "@rules_xcodeproj//xcodeproj:repositories.bzl",
    "xcodeproj_rules_dependencies",
)

xcodeproj_rules_dependencies()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

http_file(
    name = "cmake_tar_gz",
    urls = ["https://github.com/Kitware/CMake/releases/download/v3.23.1/cmake-3.23.1-macos-universal.tar.gz"],
    sha256 = "f794ed92ccb4e9b6619a77328f313497d7decf8fb7e047ba35a348b838e0e1e2",
)

http_archive(
    name = "appcenter_sdk",
    urls = ["https://github.com/microsoft/appcenter-sdk-apple/releases/download/4.1.1/AppCenter-SDK-Apple-4.1.1.zip"],
    sha256 = "032907801dc7784744a1ca8fd40d3eecc34a2e27a93a4b3993f617cca204a9f3",
    build_file = "@//third-party/AppCenter:AppCenter.BUILD",
)

load("@build_bazel_rules_apple//apple:apple.bzl", "provisioning_profile_repository")

provisioning_profile_repository(
    name = "local_provisioning_profiles",
)

# CloudVeil start
# For if you have CloudVeil-securityManager-ios checked out locally. Update the
# path to where you have it checked out.
#local_repository(
#    name = "CloudVeilSecurityManager",
#    path = "../CloudVeil-securityManager-ios",
#)

# For fetching CloudVeil-securityManager-ios from GitHub. Comment this out if
# you have it checked out locally.
http_archive(
    name = "CloudVeilSecurityManager",
    strip_prefix = "CloudVeil-securityManager-ios-31fc79ac61463bf4834f1f0943dbcef59bcea4d6",
    urls = ["https://github.com/cloudveiltech/CloudVeil-securityManager-ios/archive/31fc79ac61463bf4834f1f0943dbcef59bcea4d6.zip"],
    sha256 = "88e149f54d407b898a39b04d99a208ada05957e4dace818788d84ea06364d65d",
)

http_archive(
    name = "rules_pods",
    urls = ["https://github.com/pinterest/PodToBUILD/releases/download/6.3.2-370b622/PodToBUILD.zip"],
    sha256 = "ffdfe8c7a4c73cca5d7b7a67daa6ccdd046355637dbdb9b1366d021b4ad339b5",
)

load("@rules_pods//BazelExtensions:workspace.bzl", "new_pod_repository")

new_pod_repository(
    name = "Sentry",
    url = "https://github.com/getsentry/sentry-cocoa/archive/8.13.1.zip",
)

new_pod_repository(
    name = "SentryPrivate",
    url = "https://github.com/getsentry/sentry-cocoa/archive/8.13.1.zip",
)

new_pod_repository(
    name = "ObjectMapper",
    url = "https://github.com/tristanhimmelman/ObjectMapper/archive/3.3.0.zip",
)

new_pod_repository(
    name = "Alamofire",
    url = "https://github.com/Alamofire/Alamofire/archive/4.9.1.zip",
)
# CloudVeil end
