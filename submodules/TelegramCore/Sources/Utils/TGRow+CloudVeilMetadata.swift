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
            case .creator:
                self.isCreatorAdmin = true
            case .admin:
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

    /// Unix time (seconds) of the most recent trustworthy info about this peer:
    /// last message date. Drafts are excluded. Returns untrustworthy if the
    /// client is no longer in the chat.
    func applyCloudVeilLastUpdated(chatListTimestamp: Int32?, peer: Peer?) {
        if let channel = peer as? TelegramChannel, channel.participationStatus != .member {
            self.lastUpdated = TGRow.lastUpdateUntrustworthy
            return
        }
        if let group = peer as? TelegramGroup, group.membership != .Member {
            self.lastUpdated = TGRow.lastUpdateUntrustworthy
            return
        }
        if let timestamp = chatListTimestamp, timestamp > 0 {
            let nowSec = Int64(Date().timeIntervalSince1970)
            self.lastUpdated = min(Int64(timestamp), nowSec)
        } else {
            self.lastUpdated = TGRow.lastUpdateUnknown
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
