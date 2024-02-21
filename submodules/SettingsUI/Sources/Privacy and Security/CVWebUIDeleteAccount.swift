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
        let _ = logoutFromAccount(
            id: self.context.account.id,
            accountManager: self.context.sharedContext.accountManager,
            alreadyLoggedOutRemotely: false).start()
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
    CloudVeilSecurityController.shared.blacklistUser(userId)
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
