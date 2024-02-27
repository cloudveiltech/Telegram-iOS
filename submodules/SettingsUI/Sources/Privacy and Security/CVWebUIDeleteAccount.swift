import Foundation
import UIKit
import SafariServices

import TelegramPresentationData
import AccountContext
import TelegramCore
import Display

import CloudVeilSecurityManager

@objc fileprivate class AccountDeleteDelegate: NSObject, SFSafariViewControllerDelegate {
    private let context: AccountContext
    fileprivate var refCycle: AccountDeleteDelegate?

    init(_ context: AccountContext) {
        self.context = context
        super.init()
    }

    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // make sure the change org popup appears promptly
        if let userDefaults = UserDefaults(suiteName: "group.com.cloudveil.CloudVeilMessenger") {
            userDefaults.set(0.0, forKey: "organization_alert_shown_time")
        }
        // update SecurityManager user state
        let peerViewSignal = self.context.account.viewTracker.peerView(self.context.account.peerId)
        let _ = peerViewSignal.start(next: { peerView in
            if let peer = peerViewMainPeer(peerView) as? TelegramUser {
                TGUserController.withLock({
                    $0.set(userID: NSInteger(peer.id.toInt64()))
                    $0.set(userName: (peer.username ?? "") as NSString)
                    $0.set(userPhoneNumber: (peer.phone ?? "") as NSString)
                })
                // force sync now
                CloudVeilSecurityController.shared.getSettings()
            }
        })
        self.refCycle = nil
    }
}

public func CVPresentWebUIAccountDelete(
        navigationController: NavigationController, context: AccountContext,
        presentationData: PresentationData) {
    guard let root = navigationController.view.window?.rootViewController else {
        return
    }
    let userId = context.account.peerId.toInt64()
    CloudVeilSecurityController.shared.withDeleteAccountUrl(userId) { url in
        DispatchQueue.main.async {
            let safari = SFSafariViewController(url: url)
            let delegate = AccountDeleteDelegate(context)
            delegate.refCycle = delegate
            safari.preferredBarTintColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
            safari.preferredControlTintColor = presentationData.theme.rootController.navigationBar.accentTextColor
            safari.delegate = delegate
            root.present(safari, animated: true)
        }
    }

}
