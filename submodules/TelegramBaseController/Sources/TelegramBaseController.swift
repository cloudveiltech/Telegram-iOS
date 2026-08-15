import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import UniversalMediaPlayer
import AccountContext
import OverlayStatusController
import PresentationDataUtils
import TelegramCallsUI
import UndoUI
import CloudVeilSecurityManager
import MessageUI
import SafariServices

private func presentLiveLocationController(context: AccountContext, peerId: PeerId, controller: ViewController) {
    let presentImpl: (EngineMessage?) -> Void = { [weak controller] message in
        if let message = message, let strongController = controller {
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                controller?.view.endEditing(true)
            }, present: { c, a, _ in
                controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { _, _, _ in
                return nil
            }, addToTransitionSurface: { _ in
            }, openUrl: { _ in
            }, openPeer: { peer, navigation in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in
            }, enqueueMessage: { message in
                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in
            }, chatAvatarHiddenMedia: { _, _ in
            }))
        }
    }
    if let id = context.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
        |> deliverOnMainQueue).start(next: presentImpl)
    } else if let liveLocationManager = context.liveLocationManager {
        let _ = (liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
        |> take(1)
        |> map { peersAndMessages -> EngineMessage? in
            return peersAndMessages?.first?.1
        } |> deliverOnMainQueue).start(next: presentImpl)
    }
}

open class TelegramBaseController: ViewController, KeyShortcutResponder {
    private let context: AccountContext
    
    public var accessoryPanelContainer: ASDisplayNode?
    public private(set) var accessoryPanelContainerHeight: CGFloat = 0.0
    
    public var tempHideAccessoryPanels: Bool = false
    
    private var giftAuctionAccessoryPanel: GiftAuctionAccessoryPanel?
    private var giftAuctionStates: [GiftAuctionContext.State] = []
    private var giftAuctionDisposable: Disposable?
    
    private var dismissingPanel: ASDisplayNode?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    override open var additionalNavigationBarHeight: CGFloat {
        return 0.0
    }
    
    public init(context: AccountContext, navigationBarPresentationData: NavigationBarPresentationData?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.presentationDataDisposable = (self.updatedPresentationData.1
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        })
    }
    
    open var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.context.sharedContext.presentationData)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0
    private var additionalNavigationBarCutout: CGSize?

    override open func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        var additionalHeight: CGFloat = 0.0
        var panelStartY: CGFloat = 0.0
        
        if !self.giftAuctionStates.isEmpty {
            let panelHeight: CGFloat = 56.0
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: panelStartY), size: CGSize(width: layout.size.width, height: panelHeight))
            additionalHeight += panelHeight
            panelStartY += panelHeight
            
            let giftAuctionAccessoryPanel: GiftAuctionAccessoryPanel
            if let current = self.giftAuctionAccessoryPanel {
                giftAuctionAccessoryPanel = current
                transition.updateFrame(node: giftAuctionAccessoryPanel, frame: panelFrame)
                giftAuctionAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, isHidden: !self.displayNavigationBar, transition: transition)
            } else {
                giftAuctionAccessoryPanel = GiftAuctionAccessoryPanel(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, tapAction: { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.giftAuctionStates.count == 1, let gift = self.giftAuctionStates.first?.gift, case let .generic(gift) = gift {
                        if let giftAuctionsManager = self.context.giftAuctionsManager {
                            let _ = (giftAuctionsManager.auctionContext(for: .giftId(gift.id))
                            |> deliverOnMainQueue).start(next: { [weak self] auction in
                                guard let self, let auction else {
                                    return
                                }
                                let controller = self.context.sharedContext.makeGiftAuctionBidScreen(context: self.context, toPeerId: auction.currentBidPeerId ?? self.context.account.peerId, text: nil, entities: nil, hideName: false, auctionContext: auction, acquiredGifts: nil)
                                self.push(controller)
                            })
                        }
                    } else {
                        let controller = self.context.sharedContext.makeGiftAuctionActiveBidsScreen(context: self.context)
                        self.push(controller)
                    }
                })
                if let accessoryPanelContainer = self.accessoryPanelContainer {
                    accessoryPanelContainer.addSubnode(giftAuctionAccessoryPanel)
                } else {
                    self.navigationBar?.additionalContentNode.addSubnode(giftAuctionAccessoryPanel)
                }
                self.giftAuctionAccessoryPanel = giftAuctionAccessoryPanel
                giftAuctionAccessoryPanel.frame = panelFrame

                giftAuctionAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, isHidden: !self.displayNavigationBar, transition: .immediate)
                if transition.isAnimated {
                    giftAuctionAccessoryPanel.animateIn(transition)
                }
            }
            giftAuctionAccessoryPanel.update(states: self.giftAuctionStates)
        } else if let giftAuctionAccessoryPanel = self.giftAuctionAccessoryPanel {
            self.giftAuctionAccessoryPanel = nil
            if transition.isAnimated {
                giftAuctionAccessoryPanel.animateOut(transition, completion: { [weak giftAuctionAccessoryPanel] in
                    giftAuctionAccessoryPanel?.removeFromSupernode()
                })
            } else {
                giftAuctionAccessoryPanel.removeFromSupernode()
            }
        }

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: transition)
        }
        
        self.accessoryPanelContainerHeight = additionalHeight
    }
    
    open var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
    
    open func joinGroupCall(peerId: PeerId, invite: String?, activeCall: EngineGroupCallDescription) {
        let context = self.context
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        self.view.endEditing(true)
        
        self.context.joinGroupCall(peerId: peerId, invite: invite, requestJoinAsPeerId: { completion in
            let currentAccountPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                if let peer {
                    return .single(peer)
                } else {
                    return .never()
                }
            }
            |> map { peer in
                return [FoundPeer(peer: peer, subscribers: nil)]
            }
            
            let _ = (combineLatest(
                currentAccountPeer,
                context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.CallJoinAsPeerId(id: peerId))
            )
            |> map { currentAccountPeer, availablePeers, callJoinAsPeerId -> ([FoundPeer], EnginePeer.Id?) in
                var result = currentAccountPeer
                result.append(contentsOf: availablePeers)
                return (result, callJoinAsPeerId)
            }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] peers, callJoinAsPeerId in
                guard let strongSelf = self else {
                    return
                }
                
                let defaultJoinAsPeerId: PeerId? = callJoinAsPeerId
                                
                if peers.count == 1, let peer = peers.first {
                    completion(peer.peer.id)
                } else {
                    if let defaultJoinAsPeerId = defaultJoinAsPeerId {
                        completion(defaultJoinAsPeerId)
                    } else {
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        
                        var items: [ActionSheetItem] = []
                        var isGroup = false
                        for peer in peers {
                            if case .legacyGroup = peer.peer {
                                isGroup = true
                                break
                            } else if case let .channel(channel) = peer.peer, case .group = channel.info {
                                isGroup = true
                                break
                            }
                        }
                            
                        items.append(VoiceChatAccountHeaderActionSheetItem(title: presentationData.strings.VoiceChat_SelectAccount, text: isGroup ? presentationData.strings.VoiceChat_DisplayAsInfoGroup : presentationData.strings.VoiceChat_DisplayAsInfo))
                        for peer in peers {
                            var subtitle: String?
                            if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                                subtitle = presentationData.strings.VoiceChat_PersonalAccount
                            } else if let subscribers = peer.subscribers {
                                if case let .channel(channel) = peer.peer, case .broadcast = channel.info {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                                } else {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                                }
                            }
                            
                            items.append(VoiceChatPeerActionSheetItem(context: context, peer: peer.peer, title: peer.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), subtitle: subtitle ?? "", action: {
                                dismissAction()
                                completion(peer.peer.id)
                            }))
                        }
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        strongSelf.present(controller, in: .window(.root))
                    }
                }
            })
        }, activeCall: activeCall)
    }
    
    //CloudVeil start
    public static func checkPeerIsAllowed(peerId: PeerId, controller: ViewController, context: AccountContext, presentationData: PresentationData, attemption: Int = 0, showPolicyAlerts: Bool = true, callback: @escaping (Bool) -> ()) {
        let account = context.account
        let peerView = account.viewTracker.peerView(peerId)
        
        var disposable: Disposable? = nil
        var didComplete = false
        disposable = peerView.start(next: { peerResult in
            if disposable == nil { return }
            if didComplete { return }
            didComplete = true
            
            let peerView = peerViewMainPeer(peerResult)
            
            var isDialogAllowed: Bool? = true
            var isGroup = false
            var isChannel = false
            var isBot = false
            var isUser = false
            let row = TGRow()
            
            let (_, objectID) = readPeerTypeAndId(peerView: peerView!)
            row.objectID = objectID
            row.title = (peerView?.debugDisplayTitle ?? "") as NSString
            var userNames = peerView?.usernames.map({ $0.username }) ?? []
            var userName = ""
            // this logic is extract from InviteLinkEditorController::L693
            // and PeerInfoScreen::L2303
            // addressName is the active username of the peer if it has many usernames, default is username
            let isPublic = !(peerView?.addressName?.isEmpty ?? true)
            row.isPublic = isPublic
            
            if peerId.namespace == Namespaces.Peer.SecretChat && !CloudVeilSecurityController.shared.isSecretChatAvailable {
                isDialogAllowed = false
            } else if let peer = peerView as? TelegramChannel, case .group = peer.info {
                // megagroups
                isDialogAllowed = CloudVeilSecurityController.shared.isAvailable(groupID: objectID)
                isGroup = true
                row.isMegagroup = true
                userName = (peer.username ?? "")
                if let cachedChannelData = peerResult.cachedData as? CachedChannelData,
                   let migratedFromId = cachedChannelData.migrationReference?.maxMessageId.peerId.id._internalGetInt64Value() {
                    row.migratedFromTelegramId = NSInteger(-migratedFromId)
                }
                row.applyCloudVeilChatMetadata(from: peer)
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                // chats (groups which aren't megagroups)
                isDialogAllowed = CloudVeilSecurityController.shared.isAvailable(groupID: objectID)
                isGroup = true
                if let cloudPeer = peerView {
                    row.applyCloudVeilChatMetadata(from: cloudPeer)
                }
            } else if let peer = peerView as? TelegramChannel, case .broadcast = peer.info {
                // channels
                isDialogAllowed = CloudVeilSecurityController.shared.isAvailable(channelID: objectID)
                isChannel = true
                userName = (peer.username ?? "")
                row.applyCloudVeilChatMetadata(from: peer)
            } else if let user = peerView as? TelegramUser, let _ = user.botInfo {
                // bots
                isDialogAllowed = CloudVeilSecurityController.shared.isAvailable(botID: objectID)
                isBot = true
                row.applyCloudVeilBotMetadata(from: user)
                userName = (user.username ?? "")
            } else if let user = peerView as? TelegramUser {
                // users
                isDialogAllowed = CloudVeilSecurityController.shared.isAvailable(userID: objectID)
                isUser = true
                row.applyCloudVeilBotMetadata(from: user)
                userName = (user.username ?? "")
            }
            
            if userName != "" && !userNames.contains(userName) {
                userNames.append(userName)
            }
            row.userNames = userNames

            if isDialogAllowed == nil {
                if isBot {
                    CloudVeilSecurityController.shared.replayRequestWithBot(bot: row)
                } else if isChannel {
                    CloudVeilSecurityController.shared.replayRequestWithChannel(channel: row)
                } else if isGroup {
                    CloudVeilSecurityController.shared.replayRequestWithGroup(group: row)
                } else if isUser {
                    CloudVeilSecurityController.shared.replayRequestWithUser(user: row)
                }
                DispatchQueue.main.async {
                    let appState = UIApplication.shared.applicationState
                    if showPolicyAlerts, appState != UIApplication.State.background {
                        TelegramBaseController.showWaitingPopup(peerView: peerView!, context: context, controller: controller, presentationData: presentationData)
                    }
                    callback(false)
                    disposable?.dispose()
                }
            } else if !isDialogAllowed! {
                DispatchQueue.main.async {
                    let appState = UIApplication.shared.applicationState
                    if showPolicyAlerts, appState != UIApplication.State.background {
                        TelegramBaseController.showBlockedPopup(peerView: peerView!, context: context, controller: controller, presentationData: presentationData)
                    }
                    callback(false)
                    disposable?.dispose()
                }
            } else {
                DispatchQueue.main.async {
                    callback(true)
                    // This delay is a temporary solution.
                    // The infinite loading issue might be related to how the database is being accessed.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        disposable?.dispose()
                    }
                }
            }
        })
    }

    public static func showWaitingPopup(peerView: Peer, context: AccountContext, controller: ViewController, presentationData: PresentationData) {
        let (type, _) = readPeerTypeAndId(peerView: peerView)
        let message = "Checking server policy for \(type). Try again in a few seconds."
        
        let alert = standardTextAlertController(
            theme: AlertControllerTheme(presentationData: presentationData),
            title: "CloudVeil", text: message,
            actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})])
        controller.present(alert, in: .window(.root))
    }
    
    public static func showBlockedPopup(peerView: Peer, context: AccountContext, controller: ViewController, presentationData: PresentationData) {
        let (type, _) = readPeerTypeAndId(peerView: peerView)
        let message = "This \(type) is blocked by server policy. Please fill out the form to request it be unblocked."
    
        let alert = standardTextAlertController(
            theme: AlertControllerTheme(presentationData: presentationData),
            title: "CloudVeil", text: message,
            actions: [
                TextAlertAction(type: .defaultAction, title: "Cancel", action: {}),
                TextAlertAction(type: .defaultAction, title: "Continue", action: {
                    TelegramBaseController.openUnblockRequest(
                        peerView: peerView, context: context, controller: controller,
                        presentationData: presentationData)
                })])
        controller.present(alert, in: .window(.root))
    }
    
    private static func openUnblockRequest(peerView: Peer, context: AccountContext, controller: ViewController, presentationData: PresentationData) {
        let (_, peerId) = readPeerTypeAndId(peerView: peerView)
        let userId = TGUserController.userID
        let url = "https://messenger.cloudveil.org/unblock/\(userId)/\(peerId)"

        context.sharedContext.openExternalUrl(
            context: context, urlContext: .generic, url: url, forceExternal: false,
            presentationData: presentationData,
            navigationController: controller.navigationController as? NavigationController,
            dismissInput: {})
    }
    
    public func dismissCurrent() {
        if attemptNavigation({
            self.navigationController?.popViewController(animated: true)
        }) {
            navigationController?.popViewController(animated: true)
        }
    }
    
    private static func readPeerTypeAndId(peerView: Peer) -> (String, NSInteger) {
        let peerId = peerView.id.id._internalGetInt64Value()
        let negativePeerId = -peerId
        let contextId: Int64
        let type: String
        if let peer = peerView as? TelegramChannel, case .group = peer.info {
            type = "group"
            contextId = negativePeerId
        } else if peerView.id.namespace == Namespaces.Peer.CloudGroup {
            type = "group"
            contextId = negativePeerId
        } else if let peer = peerView as? TelegramChannel, case .broadcast = peer.info {
            type = "channel"
            contextId = negativePeerId
        } else if let user = peerView as? TelegramUser, let _ = user.botInfo {
            type = "bot"
            contextId = peerId
        } else if peerView is TelegramUser {
            type = "user"
            contextId = peerId
        } else {
            type = "secret chat"
            contextId = peerId
        }
        return (type, NSInteger(contextId))
    }
    //CloudVeil end
    open func joinConferenceCall(message: EngineMessage) {
        var action: TelegramMediaAction?
        for media in message.media {
            if let media = media as? TelegramMediaAction {
                action = media
                break
            }
        }
        guard case let .conferenceCall(conferenceCall) = action?.action else {
            return
        }
        
        if let currentGroupCallController = self.context.sharedContext.currentGroupCallController as? VoiceChatController, case let .group(groupCall) = currentGroupCallController.call, let currentCallId = groupCall.callId, currentCallId == conferenceCall.callId {
            self.context.sharedContext.navigateToCurrentCall()
            return
        }
        
        let signal = self.context.engine.peers.joinCallInvitationInformation(messageId: message.id)
        let _ = (signal
        |> deliverOnMainQueue).startStandalone(next: { [weak self] resolvedCallLink in
            guard let self else {
                return
            }
            
            let _ = (self.context.engine.calls.getGroupCallPersistentSettings(callId: resolvedCallLink.id)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] value in
                guard let self else {
                    return
                }
                
                let value: PresentationGroupCallPersistentSettings = value?.get(PresentationGroupCallPersistentSettings.self) ?? PresentationGroupCallPersistentSettings.default
                
                self.context.joinConferenceCall(call: resolvedCallLink, isVideo: conferenceCall.flags.contains(.isVideo), unmuteByDefault: value.isMicrophoneEnabledByDefault)
            })
        }, error: { [weak self] error in
            guard let self else {
                return
            }
            switch error {
            case .doesNotExist:
                self.context.sharedContext.openCreateGroupCallUI(context: self.context, peerIds: conferenceCall.otherParticipants, parentController: self)
            default:
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                self.present(textAlertController(context: self.context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        })
    }
}
