import Foundation
import Postbox
import CloudVeilSecurityManager

public extension TGRow {
    func applyCloudVeilChatMetadata(from peer: Peer) {
        switch peer {
        case let channel as TelegramChannel:
            if channel.flags.contains(.isCreator) || channel.adminRights != nil {
                self.isCreatorAdmin = true
            }
            if channel.flags.contains(.isForum) {
                self.isForum = true
            }
            if Self.channelHasCloudVeilRestriction(channel) {
                self.isRestricted = true
            }
        case let group as TelegramGroup:
            switch group.role {
            case let .creator(_):
                self.isCreatorAdmin = true
            case let .admin(_, _):
                self.isCreatorAdmin = true
            case .member:
                break
            }
        default:
            break
        }
    }

    func applyCloudVeilBotMetadata(from user: TelegramUser) {
        if user.botInfo?.flags.contains(.canEdit) == true {
            self.isCreatorAdmin = true
        }
        if let restrictionInfo = user.restrictionInfo, !restrictionInfo.rules.isEmpty {
            self.isRestricted = true
        }
    }

    private static func channelHasCloudVeilRestriction(_ channel: TelegramChannel) -> Bool {
        guard let restrictionInfo = channel.restrictionInfo else {
            return false
        }
        if !restrictionInfo.rules.isEmpty {
            return true
        }
        return false
    }
}
