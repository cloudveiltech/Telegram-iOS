# How to build debug simulator builds.

* Clone this repo (obviously).

* Run `git submodule update --init --recursive`.

* Create a directory at the path `provisioning/dev` inside the repository.

* Create a json file named `configuration.json` in that directory with the CloudVeil Messenger build configuration.

  Example contents:
  ```json
    {
  	"bundle_id": "com.cloudveil.CloudVeilMessenger",
  	"api_id": "{- get from my.telgram.org/apps -}",
  	"api_hash": "{- get from my.telgram.org/apps -}",
    "team_id": "L95C8867HX",
    "app_center_id": "0",
    "appstore_id": "27095",
    "app_specific_url_scheme": "tg",
    "premium_iap_product_id": "org.telegram.telegramPremium.monthly",
    "enable_siri": false,
    "enable_icloud": true,
    "is_internal_build": "true",
    "is_appstore_build": "true",
    "cloudveil_shiplogs": false,
    "telegram_use_xcode_managed_codesigning": "true"
  }
```

* Create a json file named `make.json` in the repository root.

  Example contents:

  ```json
  {
  	"ipa-archive-path": "build-archives/CVM_{{.BuildNumber}}_{{.Version}}_{{.BuildFor}}_{{.BuildMode}}.ipa",
  	"dsyms-archive-path": "build-archives/CVM_{{.BuildNumber}}_{{.Version}}_{{.BuildFor}}_{{.BuildMode}}.dSYMs",
  	"dev-provisioning-path": "provisioning/cvm/dev",
  	"dist-provisioning-path": "provisioning/cvm/dist",
  	"adhoc-provisioning-path": "provisioning/cvm/adhoc"
  }
  ```

* Install Xcode 16 and its command line tools. Download at least one iPhone Simulator Runtime. ie: iOS 18.

* Install homebrew

* Install rvm and install ruby >= 3.0.1 `rvm install 3.0.1`

* Install cocoapods.

* Install bazel using balzelish https://bazel.build/install/bazelisk
  
* Update bazel version in `.bazelversion` if needed. More details https://github.com/bazelbuild/bazelisk

* Install go `brew install go`

* Update bazel version in `build-system/NewMake/main.go` if needed

* Select XCode `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` to prevent any `xcodebuild` fail error.

* Run `go build -C build-system/NewMake && mv build-system/NewMake/NewMake make` from the repository root.

* Use `./make build -for sim -mode debug` to make a build.

* [Optional] If you want to build from XCode, run `./make project`, after that open XCode project in the Telegram folder.

# How to build appstore distribution builds.

* Follow the instructions for debug simulator builds.

* Create a directory at `provisioning/dist`.

* Copy `provisioning/dist/configuration.json` to `provisioning/dist`.

* Create an Apple Distribution certificate for the CloudVeil team, and import it in your keychain.
  If you don't know how to do this, use Google.

* Create provisioning profiles for the following App IDs, and put them at the following paths.
   - `provisioning/dist/BroadcastUpload.mobileprovision`: `cvm BroadcastUpload (com.cloudveil.CloudVeilMessenger.BroadcastUpload)`
   - `provisioning/dist/Intents.mobileprovision`: `XC com cloudveil CloudVeilMessenger SiriIntents (com.cloudveil.CloudVeilMessenger.SiriIntents)`
   - `provisioning/dist/NotificationContent.mobileprovision`: `XC com cloudveil CloudVeilMessenger NotificationContent (com.cloudveil.CloudVeilMessenger.NotificationContent)`
   - `provisioning/dist/NotificationService.mobileprovision`: `XC com cloudveil CloudVeilMessenger NotificationService (com.cloudveil.CloudVeilMessenger.NotificationService)`
   - `provisioning/dist/Share.mobileprovision`: `XC com cloudveil CloudVeilMessenger Share (com.cloudveil.CloudVeilMessenger.Share)`
   - `provisioning/dist/Telegram.mobileprovision`: `XC com cloudveil CloudVeilMessenger (com.cloudveil.CloudVeilMessenger)`
   - `provisioning/dist/WatchApp.mobileprovision`: `XC com cloudveil CloudVeilMessenger watchkitapp (com.cloudveil.CloudVeilMessenger.watchkitapp)`
   - `provisioning/dist/WatchExtension.mobileprovision`: `XC com cloudveil CloudVeilMessenger watchkitapp watchkitextension (com.cloudveil.CloudVeilMessenger.watchkitapp.watchkitextension)`
   - `provisioning/dist/Widget.mobileprovision`: `XC com cloudveil CloudVeilMessenger Widget (com.cloudveil.CloudVeilMessenger.Widget)`

* Use `./make build -for dist -mode release` to make a build.

# Build number
- Create a file `buildNumber.txt` at root folder
- Put the build number on this before start a new build