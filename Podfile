# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
workspace 'Telegram-iOS.xcworkspace'
project 'Telegram-iOS'
project 'submodules/TelegramUI/TelegramUI_Xcode'
project 'submodules/AvatarNode/AvatarNode_Xcode'
project 'submodules/StickerResources/StickerResources_Xcode'
project 'submodules/TelegramCallsUI/TelegramCallsUI_Xcode'
project 'submodules/TelegramBaseController/TelegramBaseController_Xcode'
project 'submodules/PeerAvatarGalleryUI/PeerAvatarGalleryUI_Xcode'

target 'PeerAvatarGalleryUI' do
	project 'submodules/PeerAvatarGalleryUI/PeerAvatarGalleryUI_Xcode'

  use_frameworks!

  pod 'CloudVeilSecurityManager'  
end

target 'TelegramBaseController' do
	project 'submodules/TelegramBaseController/TelegramBaseController_Xcode'

  use_frameworks!

  pod 'CloudVeilSecurityManager'  
end

target 'TelegramCallsUI' do
	project 'submodules/TelegramCallsUI/TelegramCallsUI_Xcode'

  use_frameworks!

  pod 'CloudVeilSecurityManager'  
end

target 'StickerResources' do
  project 'submodules/StickerResources/StickerResources_Xcode'

  use_frameworks!

  pod 'CloudVeilSecurityManager'  
end


target 'AvatarNode' do
  project 'submodules/AvatarNode/AvatarNode_Xcode'

  use_frameworks!

  pod 'CloudVeilSecurityManager'  
end

target 'TelegramUI' do
  project 'submodules/TelegramUI/TelegramUI_Xcode'

  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Telegram-iOS  
  pod 'CloudVeilSecurityManager'  
  pod 'Fabric' 
  pod 'Crashlytics'
end

target 'Telegram-iOS' do

project 'Telegram-iOS'

  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Telegram-iOS  
  pod 'CloudVeilSecurityManager'
end


#target 'Share' do
#  use_frameworks!
#
#  pod 'CloudVeilSecurityManager'
#end
