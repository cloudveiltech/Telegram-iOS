# How to build debug simulator builds.

* Clone this repo (obviously).
* Run `git submodule update --init --recursive`.
* Create a directory at the path `../Provision` relative to `build.sh`.
* Create a json file named `configuration.json` in that directory with the CloudVeil Messenger build configuration.
  See `build-system/appstore-configuration.json` for example content.
* Install Xcode 15 and its command line tools.
* Install cocoapods.
* Use `./build.sh` to make a build. The IPA will be at `bazel-bin/Telegram/Telegram.ipa`.

# How to build appstore distribution builds.

* Follow the instructions for debug simulator builds.
* Create a directory at `../Provision/profiles`.
* Create an Apple Distribution certificate for the CloudVeil team, and import it in your keychain.
  If you don't know how to do this, use Google.
* Create provisioning profiles for the following App IDs, and put them at the following paths.
   - `../Provision/profiles/BroadcastUpload.mobileprovision`: `cvm BroadcastUpload (com.cloudveil.CloudVeilMessenger.BroadcastUpload)`
   - `../Provision/profiles/Intents.mobileprovision`: `XC com cloudveil CloudVeilMessenger SiriIntents (com.cloudveil.CloudVeilMessenger.SiriIntents)`
   - `../Provision/profiles/NotificationContent.mobileprovision`: `XC com cloudveil CloudVeilMessenger NotificationContent (com.cloudveil.CloudVeilMessenger.NotificationContent)`
   - `../Provision/profiles/NotificationService.mobileprovision`: `XC com cloudveil CloudVeilMessenger NotificationService (com.cloudveil.CloudVeilMessenger.NotificationService)`
   - `../Provision/profiles/Share.mobileprovision`: `XC com cloudveil CloudVeilMessenger Share (com.cloudveil.CloudVeilMessenger.Share)`
   - `../Provision/profiles/Telegram.mobileprovision`: `XC com cloudveil CloudVeilMessenger (com.cloudveil.CloudVeilMessenger)`
   - `../Provision/profiles/WatchApp.mobileprovision`: `XC com cloudveil CloudVeilMessenger watchkitapp (com.cloudveil.CloudVeilMessenger.watchkitapp)`
   - `../Provision/profiles/WatchExtension.mobileprovision`: `XC com cloudveil CloudVeilMessenger watchkitapp watchkitextension (com.cloudveil.CloudVeilMessenger.watchkitapp.watchkitextension)`
   - `../Provision/profiles/Widget.mobileprovision`: `XC com cloudveil CloudVeilMessenger Widget (com.cloudveil.CloudVeilMessenger.Widget)`
* Use `./build.sh --dev --release` to make a build. The IPA will be at `bazel-bin/Telegram/Telegram.ipa`.
