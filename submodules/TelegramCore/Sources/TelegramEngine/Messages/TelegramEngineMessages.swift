import SwiftSignalKit
import Postbox
import SyncCore

public extension TelegramEngine {
    final class Messages {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func clearCloudDraftsInteractively() -> Signal<Void, NoError> {
        	return _internal_clearCloudDraftsInteractively(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId)
        }

        public func applyMaxReadIndexInteractively(index: MessageIndex) -> Signal<Void, NoError> {
            return _internal_applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: index)
        }

        public func sendScheduledMessageNowInteractively(messageId: MessageId) -> Signal<Never, NoError> {
            return _internal_sendScheduledMessageNowInteractively(postbox: self.account.postbox, messageId: messageId)
        }

        public func requestMessageActionCallbackPasswordCheck(messageId: MessageId, isGame: Bool, data: MemoryBuffer?) -> Signal<Never, MessageActionCallbackError> {
            return _internal_requestMessageActionCallbackPasswordCheck(account: self.account, messageId: messageId, isGame: isGame, data: data)
        }

        public func requestMessageActionCallback(messageId: MessageId, isGame: Bool, password: String?, data: MemoryBuffer?) -> Signal<MessageActionCallbackResult, MessageActionCallbackError> {
            return _internal_requestMessageActionCallback(account: self.account, messageId: messageId, isGame: isGame, password: password, data: data)
        }

        public func requestMessageActionUrlAuth(subject: MessageActionUrlSubject) -> Signal<MessageActionUrlAuthResult, NoError> {
            _internal_requestMessageActionUrlAuth(account: self.account, subject: subject)
        }

        public func acceptMessageActionUrlAuth(subject: MessageActionUrlSubject, allowWriteAccess: Bool) -> Signal<MessageActionUrlAuthResult, NoError> {
            return _internal_acceptMessageActionUrlAuth(account: self.account, subject: subject, allowWriteAccess: allowWriteAccess)
        }

        public func searchMessages(location: SearchMessagesLocation, query: String, state: SearchMessagesState?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
            return _internal_searchMessages(account: self.account, location: location, query: query, state: state, limit: limit)
        }

        public func downloadMessage(messageId: MessageId) -> Signal<Message?, NoError> {
            return _internal_downloadMessage(postbox: self.account.postbox, network: self.account.network, messageId: messageId)
        }

        public func searchMessageIdByTimestamp(peerId: PeerId, threadId: Int64?, timestamp: Int32) -> Signal<MessageId?, NoError> {
            return _internal_searchMessageIdByTimestamp(account: self.account, peerId: peerId, threadId: threadId, timestamp: timestamp)
        }

        public func deleteMessages(transaction: Transaction, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageId, Int, Int) -> Void)? = nil) {
            return _internal_deleteMessages(transaction: transaction, mediaBox: self.account.postbox.mediaBox, ids: ids, deleteMedia: deleteMedia, manualAddMessageThreadStatsDifference: manualAddMessageThreadStatsDifference)
        }

        public func deleteAllMessagesWithAuthor(transaction: Transaction, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
            return _internal_deleteAllMessagesWithAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, authorId: authorId, namespace: namespace)
        }

        public func deleteAllMessagesWithForwardAuthor(transaction: Transaction, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
            return _internal_deleteAllMessagesWithForwardAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, forwardAuthorId: forwardAuthorId, namespace: namespace)
        }

        public func clearCallHistory(forEveryone: Bool) -> Signal<Never, ClearCallHistoryError> {
            return _internal_clearCallHistory(account: self.account, forEveryone: forEveryone)
        }

        public func deleteMessagesInteractively(messageIds: [MessageId], type: InteractiveMessagesDeletionType, deleteAllInGroup: Bool = false) -> Signal<Void, NoError> {
            return _internal_deleteMessagesInteractively(account: self.account, messageIds: messageIds, type: type, deleteAllInGroup: deleteAllInGroup)
        }

        public func clearHistoryInteractively(peerId: PeerId, type: InteractiveHistoryClearingType) -> Signal<Void, NoError> {
            return _internal_clearHistoryInteractively(postbox: self.account.postbox, peerId: peerId, type: type)
        }

        public func clearAuthorHistory(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_clearAuthorHistory(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func requestEditMessage(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute? = nil, disableUrlPreview: Bool = false, scheduleTime: Int32? = nil) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
            return _internal_requestEditMessage(account: self.account, messageId: messageId, text: text, media: media, entities: entities, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime)
        }

        public func requestEditLiveLocation(messageId: MessageId, stop: Bool, coordinate: (latitude: Double, longitude: Double, accuracyRadius: Int32?)?, heading: Int32?, proximityNotificationRadius: Int32?) -> Signal<Void, NoError> {
            return _internal_requestEditLiveLocation(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, messageId: messageId, stop: stop, coordinate: coordinate, heading: heading, proximityNotificationRadius: proximityNotificationRadius)
        }
    }
}
