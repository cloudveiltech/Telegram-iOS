import Foundation
import Display
import AccountContext
import TelegramPresentationData
import AlertUI
import PresentationDataUtils
import CloudVeilSecurityManager

//CloudVeil start
func presentCloudVeilBlockedLinkAlert(context: AccountContext, navigationController: NavigationController?) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    var actions: [TextAlertAction] = [
        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
        }),
    ]
    if let orgId = CloudVeilSecurityController.shared.organizationId {
        actions.append(TextAlertAction(type: .defaultAction, title: "View Policy", action: {
            context.sharedContext.openExternalUrl(
                context: context, urlContext: .generic,
                url: "https://messenger.cloudveil.org/organization/policy/\(orgId)",
                forceExternal: false, presentationData: presentationData,
                navigationController: navigationController, dismissInput: {}
            )
        }))
    }

    context.sharedContext.presentGlobalController(textAlertController(context: context, title: "CloudVeil", text: "This link is permanently blocked and cannot be opened.", actions: actions, parseMarkdown: true), nil)
}
//CloudVeil end
