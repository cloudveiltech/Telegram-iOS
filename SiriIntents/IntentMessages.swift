import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import Intents

func unreadMessages(account: Account) -> Signal<[INMessage], NoError> {
    return account.postbox.tailChatListView(groupId: .root, count: 20, summaryComponents: ChatListEntrySummaryComponents())
    |> take(1)
    |> mapToSignal { view -> Signal<[INMessage], NoError> in
        var signals: [Signal<[INMessage], NoError>] = []
        for entry in view.0.entries {
            if case let .MessageEntry(index, _, readState, notificationSettings, _, _, _, _) = entry {
                var hasUnread = false
                if let readState = readState {
                    hasUnread = readState.count != 0
                }
                var isMuted = false
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                        isMuted = true
                    }
                }
                
                if !isMuted && hasUnread {
                    signals.append(account.postbox.aroundMessageHistoryViewForLocation(.peer(index.messageIndex.id.peerId), anchor: .upperBound, count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tagMask: nil, orderStatistics: .combinedLocation)
                    |> take(1)
                    |> map { view -> [INMessage] in
                        var messages: [INMessage] = []
                        for entry in view.0.entries {
                            if !entry.isRead {
                                if let message = messageWithTelegramMessage(entry.message, account: account) {
                                    messages.append(message)
                                }
                            }
                        }
                        return messages
                    })
                }
            }
        }
        
        if signals.isEmpty {
            return .single([])
        } else {
            return combineLatest(signals)
            |> map { results -> [INMessage] in
                return results.flatMap { $0 }.sorted(by: { $0.dateSent!.compare($1.dateSent!) == ComparisonResult.orderedDescending })
            }
        }
    }
}

struct CallRecord {
    let identifier: String
    let date: Date
    let caller: INPerson
    let duration: Int32?
    let unseen: Bool
    
    @available(iOSApplicationExtension 11.0, *)
    var intentCall: INCallRecord {
        return INCallRecord(identifier: self.identifier, dateCreated: self.date, caller: self.caller, callRecordType: .missed, callCapability: .audioCall, callDuration: self.duration.flatMap(Double.init), unseen: self.unseen)
    }
}

func missedCalls(account: Account) -> Signal<[CallRecord], NoError> {
    return account.viewTracker.callListView(type: .missed, index: MessageIndex.absoluteUpperBound(), count: 30)
    |> take(1)
    |> map { view -> [CallRecord] in
        var calls: [CallRecord] = []
        for entry in view.entries {
            switch entry {
                case let .message(_, messages):
                    for message in messages {
                        if let call = callWithTelegramMessage(message, account: account) {
                            calls.append(call)
                        }
                    }
                default:
                    break
            }
        }
        return calls.sorted(by: { $0.date.compare($1.date) == ComparisonResult.orderedDescending })
    }
}

private func callWithTelegramMessage(_ telegramMessage: Message, account: Account) -> CallRecord? {
    guard let author = telegramMessage.author, let user = telegramMessage.peers[author.id] as? TelegramUser else {
        return nil
    }
    
    let identifier = "\(telegramMessage.id.peerId.toInt64())_\(telegramMessage.id.namespace)_\(telegramMessage.id.id)"
    let personHandle: INPersonHandle
    if #available(iOSApplicationExtension 10.2, *) {
        var type: INPersonHandleType
        var label: INPersonHandleLabel?
        if let username = user.username {
            label = INPersonHandleLabel(rawValue: "@\(username)")
            type = .unknown
        } else if let phone = user.phone {
            label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
            type = .phoneNumber
        } else {
            label = nil
            type = .unknown
        }
        personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
    } else {
        personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
    }
    
    let caller = INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.displayTitle, image: nil, contactIdentifier: nil, customIdentifier: "tg\(user.id.toInt64())")
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    var duration: Int32?
    for media in telegramMessage.media {
        if let action = media as? TelegramMediaAction, case let .phoneCall(_, _, callDuration) = action.action {
            duration = callDuration
        }
    }
    
    return CallRecord(identifier: identifier, date: date, caller: caller, duration: duration, unseen: true)
}

private func messageWithTelegramMessage(_ telegramMessage: Message, account: Account) -> INMessage? {
    guard let author = telegramMessage.author, let user = telegramMessage.peers[author.id] as? TelegramUser else {
        return nil
    }
    
    let identifier = "\(telegramMessage.id.peerId.toInt64())_\(telegramMessage.id.namespace)_\(telegramMessage.id.id)"
    let personHandle: INPersonHandle
    if #available(iOSApplicationExtension 10.2, *) {
        var type: INPersonHandleType
        var label: INPersonHandleLabel?
        if let username = user.username {
            label = INPersonHandleLabel(rawValue: "@\(username)")
            type = .unknown
        } else if let phone = user.phone {
            label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
            type = .phoneNumber
        } else {
            label = nil
            type = .unknown
        }
        personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
    } else {
        personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
    }
    
    let sender = INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.displayTitle, image: nil, contactIdentifier: nil, customIdentifier: "tg\(user.id.toInt64())")
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    let message: INMessage
    if #available(iOSApplicationExtension 11.0, *) {
        var messageType: INMessageType = .text
        loop: for media in telegramMessage.media {
            if media is TelegramMediaImage {
                messageType = .mediaImage
                break loop
            }
            else if let file = media as? TelegramMediaFile {
                if file.isVideo {
                    messageType = .mediaVideo
                    break loop
                } else if file.isMusic {
                    messageType = .mediaAudio
                    break loop
                } else if file.isVoice {
                    messageType = .audio
                    break loop
                } else if file.isSticker || file.isAnimatedSticker {
                    messageType = .sticker
                    break loop
                } else if file.isAnimated {
                    messageType = .mediaVideo
                    break loop
                }
            } else if media is TelegramMediaMap {
                messageType = .mediaLocation
                break loop
            } else if media is TelegramMediaContact {
                messageType = .mediaAddressCard
                break loop
            }
        }
    
        message = INMessage(identifier: identifier, conversationIdentifier: "\(telegramMessage.id.peerId.toInt64())", content: telegramMessage.text, dateSent: date, sender: sender, recipients: [], groupName: nil, messageType: messageType)
    } else {
        message = INMessage(identifier: identifier, content: telegramMessage.text, dateSent: date, sender: sender, recipients: [])
    }
    
    return message
}
