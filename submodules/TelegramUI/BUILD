load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_configuration//:variables.bzl",
    "telegram_bundle_id",
)


filegroup(
    name = "TelegramUIResources",
    srcs = glob([
        "Sounds/**/*",
        "Resources/**/*",
    ], exclude = ["Sounds/**/.*", "Resources/**/.*"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "TelegramUIAssets",
    srcs = glob(["Images.xcassets/**"]),
    visibility = ["//visibility:public"],
)

#filegroup(
#    name = "Icons",
#    srcs = glob([
#        "Telegram-iOS/Icons.xcassets/**/*",
#    ], exclude = ["Telegram-iOS/Icons.xcassets/**/.*"]),
#)

internal_bundle_ids = [
    "org.telegram.Telegram-iOS",
]

available_appcenter_targets = [
    "@appcenter_sdk//:AppCenter",
    "@appcenter_sdk//:AppCenterCrashes",
]

appcenter_targets = available_appcenter_targets if telegram_bundle_id in internal_bundle_ids else []

swift_library(
    name = "TelegramUI",
    module_name = "TelegramUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        #CloudVeil start
        "//Telegram:CloudVeilSecurityManager",
        "//Telegram:CloudVeilSentry",
        #CloudVeil end
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/lottie-ios:Lottie",
        "//submodules/FFMpegBinding:FFMpegBinding",
        "//submodules/WebPBinding:WebPBinding",
        "//submodules/RMIntro:RMIntro",
        "//submodules/GZip:GZip",
        "//submodules/TelegramCallsUI:TelegramCallsUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/TelegramVoip:TelegramVoip",
        "//submodules/DeviceAccess:DeviceAccess",
        "//submodules/WatchCommon/Host:WatchCommon",
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/BuildConfigExtra:BuildConfigExtra",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/TelegramUpdateUI:TelegramUpdateUI",
        "//submodules/MergeLists:MergeLists",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/DeviceLocationManager:DeviceLocationManager",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/LiveLocationManager:LiveLocationManager",
        "//submodules/LiveLocationTimerNode:LiveLocationTimerNode",
        "//submodules/TemporaryCachedPeerDataManager:TemporaryCachedPeerDataManager",
        "//submodules/ShareController:ShareController",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/PeerOnlineMarkerNode:PeerOnlineMarkerNode",
        "//submodules/PeerPresenceStatusManager:PeerPresenceStatusManager",
        "//submodules/ChatListSearchRecentPeersNode:ChatListSearchRecentPeersNode",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/ContextUI:ContextUI",
        "//submodules/MediaResources:MediaResources",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/Tuples:Tuples",
        "//submodules/TextFormat:TextFormat",
        "//submodules/SwitchNode:SwitchNode",
        "//submodules/StickerResources:StickerResources",
        "//submodules/SelectablePeerNode:SelectablePeerNode",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/ListSectionHeaderNode:ListSectionHeaderNode",
        "//submodules/HorizontalPeerItem:HorizontalPeerItem",
        "//submodules/CheckNode:CheckNode",
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ActionSheetPeerItem:ActionSheetPeerItem",
        "//submodules/ComposePollUI:ComposePollUI",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TouchDownGesture:TouchDownGesture",
        "//submodules/SwipeToDismissGesture:SwipeToDismissGesture",
        "//submodules/DirectionalPanGesture:DirectionalPanGesture",
        "//submodules/UndoUI:UndoUI",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/TinyThumbnail:TinyThumbnail",
        "//submodules/ImageTransparency:ImageTransparency",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/TelegramPermissions:TelegramPermissions",
        "//submodules/GameUI:GameUI",
        "//submodules/WebUI:WebUI",
        "//submodules/PassportUI:PassportUI",
        "//submodules/PhoneInputNode:PhoneInputNode",
        "//submodules/CountrySelectionUI:CountrySelectionUI",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/TelegramUniversalVideoContent:TelegramUniversalVideoContent",
        "//submodules/WebsiteType:WebsiteType",
        "//submodules/ScreenCaptureDetection:ScreenCaptureDetection",
        "//submodules/OpenInExternalAppUI:OpenInExternalAppUI",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/ImageCompression:ImageCompression",
        "//submodules/DateSelectionUI:DateSelectionUI",
        "//submodules/PasswordSetupUI:PasswordSetupUI",
        "//submodules/Pdf:Pdf",
        "//submodules/InstantPageUI:InstantPageUI",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/LiveLocationPositionNode:LiveLocationPositionNode",
        "//submodules/MosaicLayout:MosaicLayout",
        "//submodules/LocationUI:LocationUI",
        "//submodules/Stripe:Stripe",
        "//submodules/BotPaymentsUI:BotPaymentsUI",
        "//submodules/LocalAuth:LocalAuth",
        "//submodules/ContactListUI:ContactListUI",
        "//submodules/SearchUI:SearchUI",
        "//submodules/ChatListSearchItemHeader:ChatListSearchItemHeader",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ContactsPeerItem:ContactsPeerItem",
        "//submodules/ChatListSearchItemNode:ChatListSearchItemNode",
        "//submodules/TelegramPermissionsUI:TelegramPermissionsUI",
        "//submodules/PeersNearbyIconNode:PeersNearbyIconNode",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/PasscodeUI:PasscodeUI",
        "//submodules/CallListUI:CallListUI",
        "//submodules/ChatListUI:ChatListUI",
        "//submodules/ChatTitleActivityNode:ChatTitleActivityNode",
        "//submodules/DeleteChatPeerActionSheetItem:DeleteChatPeerActionSheetItem",
        "//submodules/LanguageSuggestionUI:LanguageSuggestionUI",
        "//submodules/TextSelectionNode:TextSelectionNode",
        "//submodules/PlatformRestrictionMatching:PlatformRestrictionMatching",
        "//submodules/HashtagSearchUI:HashtagSearchUI",
        "//submodules/ItemListAvatarAndNameInfoItem:ItemListAvatarAndNameInfoItem",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/StickerPackPreviewUI:StickerPackPreviewUI",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/JoinLinkPreviewUI:JoinLinkPreviewUI",
        "//submodules/LanguageLinkPreviewUI:LanguageLinkPreviewUI",
        "//submodules/WebSearchUI:WebSearchUI",
        "//submodules/LegacyMediaPickerUI:LegacyMediaPickerUI",
        "//submodules/MimeTypes:MimeTypes",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/PeersNearbyUI:PeersNearbyUI",
        "//submodules/Geocoding:Geocoding",
        "//submodules/PeerInfoUI:PeerInfoUI",
        "//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUI",
        "//submodules/Emoji:Emoji",
        "//submodules/ItemListStickerPackItem:ItemListStickerPackItem",
        "//submodules/NotificationMuteSettingsUI:NotificationMuteSettingsUI",
        "//submodules/SinglePhoneInputNode:SinglePhoneInputNode",
        "//submodules/MapResourceToAvatarSizes:MapResourceToAvatarSizes",
        "//submodules/NotificationSoundSelectionUI:NotificationSoundSelectionUI",
        "//submodules/EncryptionKeyVisualization:EncryptionKeyVisualization",
        "//submodules/ItemListAddressItem:ItemListAddressItem",
        "//submodules/DeviceProximity:DeviceProximity",
        "//submodules/RaiseToListen:RaiseToListen",
        "//submodules/OpusBinding:OpusBinding",
        "//third-party/opus:opus",
        "//submodules/WatchBridgeAudio:WatchBridgeAudio",
        "//submodules/WatchBridge:WatchBridge",
        "//submodules/ShareItems:ShareItems",
        "//submodules/ShareItems/Impl:ShareItemsImpl",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/UrlHandling:UrlHandling",
        "//submodules/HexColor:HexColor",
        "//submodules/QrCode:QrCode",
        "//submodules/WallpaperResources:WallpaperResources",
        "//submodules/AuthorizationUI:AuthorizationUI",
        "//submodules/CounterContollerTitleView:CounterContollerTitleView",
        "//submodules/GridMessageSelectionNode:GridMessageSelectionNode",
        "//submodules/InstantPageCache:InstantPageCache",
        "//submodules/PersistentStringHash:PersistentStringHash",
        "//submodules/SegmentedControlNode:SegmentedControlNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Markdown:Markdown",
        "//submodules/SearchPeerMembers:SearchPeerMembers",
        "//submodules/WidgetItems:WidgetItems",
        "//submodules/WidgetItemsUtils:WidgetItemsUtils",
        "//submodules/OpenSSLEncryptionProvider:OpenSSLEncryptionProvider",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/AppLock:AppLock",
        "//submodules/NotificationsPresentationData:NotificationsPresentationData",
        "//submodules/UrlWhitelist:UrlWhitelist",
        "//submodules/TelegramIntents:TelegramIntents",
        "//submodules/LocationResources:LocationResources",
        "//submodules/ItemListVenueItem:ItemListVenueItem",
        "//submodules/SemanticStatusNode:SemanticStatusNode",
        "//submodules/AccountUtils:AccountUtils",
        "//submodules/Svg:Svg",
        "//submodules/ManagedAnimationNode:ManagedAnimationNode",
        "//submodules/TooltipUI:TooltipUI",
        "//submodules/AuthTransferUI:AuthTransferUI",
        "//submodules/ListMessageItem:ListMessageItem",
        "//submodules/FileMediaResourceStatus:FileMediaResourceStatus",
        "//submodules/ChatMessageInteractiveMediaBadge:ChatMessageInteractiveMediaBadge",
        "//submodules/GalleryData:GalleryData",
        "//submodules/ChatInterfaceState:ChatInterfaceState",
        "//submodules/AnimatedCountLabelNode:AnimatedCountLabelNode",
        "//submodules/AnimatedAvatarSetNode:AnimatedAvatarSetNode",
        "//submodules/SlotMachineAnimationNode:SlotMachineAnimationNode",
        "//submodules/AnimatedNavigationStripeNode:AnimatedNavigationStripeNode",
        "//submodules/AudioBlob:AudioBlob",
        "//Telegram:GeneratedSources",
        "//third-party/ZipArchive:ZipArchive",
        "//submodules/ChatImportUI:ChatImportUI",
        "//submodules/DatePickerNode:DatePickerNode",
        "//submodules/ConfettiEffect:ConfettiEffect",
        "//submodules/Speak:Speak",
        "//submodules/PeerInfoAvatarListNode:PeerInfoAvatarListNode",
        "//submodules/DebugSettingsUI:DebugSettingsUI",
        "//submodules/ImportStickerPackUI:ImportStickerPackUI",
        "//submodules/GradientBackground:GradientBackground",
        "//submodules/WallpaperBackgroundNode:WallpaperBackgroundNode",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/AdUI:AdUI",
        "//submodules/SparseItemGrid:SparseItemGrid",
        "//submodules/CalendarMessageScreen:CalendarMessageScreen",
        "//submodules/LottieMeshSwift:LottieMeshSwift",
        "//submodules/MeshAnimationCache:MeshAnimationCache",
        "//submodules/DirectMediaImageCache:DirectMediaImageCache",
        "//submodules/CodeInputView:CodeInputView",
        "//submodules/Components/ReactionButtonListComponent:ReactionButtonListComponent",
        "//submodules/InvisibleInkDustNode:InvisibleInkDustNode",
        "//submodules/QrCodeUI:QrCodeUI",
        "//submodules/Components/ReactionListContextMenuContent:ReactionListContextMenuContent",
        "//submodules/Components/ReactionImageComponent:ReactionImageComponent",
        "//submodules/TabBarUI:TabBarUI",
        "//submodules/SoftwareVideo:SoftwareVideo",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/FetchManagerImpl:FetchManagerImpl",
        "//submodules/AttachmentUI:AttachmentUI",
        "//submodules/AttachmentTextInputPanelNode:AttachmentTextInputPanelNode",
        "//submodules/ChatPresentationInterfaceState:ChatPresentationInterfaceState",
        "//submodules/Pasteboard:Pasteboard",
        "//submodules/ChatSendMessageActionUI:ChatSendMessageActionUI",
        "//submodules/ChatTextLinkEditUI:ChatTextLinkEditUI",
        "//submodules/MediaPickerUI:MediaPickerUI",
        "//submodules/ChatMessageBackground:ChatMessageBackground",
        "//submodules/PeerInfoUI/CreateExternalMediaStreamScreen:CreateExternalMediaStreamScreen",
        "//submodules/TranslateUI:TranslateUI",
        "//submodules/BrowserUI:BrowserUI",
        "//submodules/PremiumUI:PremiumUI",
        "//submodules/Components/HierarchyTrackingLayer:HierarchyTrackingLayer",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/InAppPurchaseManager:InAppPurchaseManager",
        "//submodules/TelegramUI/Components/AudioTranscriptionButtonComponent:AudioTranscriptionButtonComponent",
        "//submodules/TelegramUI/Components/AudioTranscriptionPendingIndicatorComponent:AudioTranscriptionPendingIndicatorComponent",
        "//submodules/TelegramUI/Components/AudioWaveformComponent:AudioWaveformComponent",
        "//submodules/TelegramUI/Components/EditableChatTextNode:EditableChatTextNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboard",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/LottieAnimationCache:LottieAnimationCache",
        "//submodules/TelegramUI/Components/VideoAnimationCache:VideoAnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/ChatInputPanelContainer:ChatInputPanelContainer",
        "//submodules/TelegramUI/Components/TextNodeWithEntities:TextNodeWithEntities",
        "//submodules/TelegramUI/Components/EmojiSuggestionsComponent:EmojiSuggestionsComponent",
        "//submodules/TelegramUI/Components/EmojiStatusSelectionComponent:EmojiStatusSelectionComponent",
        "//submodules/TelegramUI/Components/EmojiStatusComponent:EmojiStatusComponent",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/Media/ConvertOpusToAAC:ConvertOpusToAAC",
        "//submodules/Media/LocalAudioTranscription:LocalAudioTranscription",
        "//submodules/Components/PagerComponent:PagerComponent",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
        "//submodules/TelegramUI/Components/NotificationExceptionsScreen:NotificationExceptionsScreen",
        "//submodules/TelegramUI/Components/ForumCreateTopicScreen:ForumCreateTopicScreen",
        "//submodules/TelegramUI/Components/ChatTitleView",
        "//submodules/InviteLinksUI:InviteLinksUI",
        "//submodules/TelegramUI/Components/NotificationPeerExceptionController",
        "//submodules/MediaPasteboardUI:MediaPasteboardUI",
    ] + select({
        "@build_bazel_rules_apple//apple:ios_armv7": [],
        "@build_bazel_rules_apple//apple:ios_arm64": appcenter_targets,
        "//build-system:ios_sim_arm64": [],
        "@build_bazel_rules_apple//apple:ios_x86_64": [],
    }),
    visibility = [
        "//visibility:public",
    ],
)
