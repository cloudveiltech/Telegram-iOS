import Foundation
import Postbox
import CloudVeilSecurityManager

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

// CloudVeil: shared sticker-whitelist helpers.
//
// These mirror the unwrap/deny-by-default semantics of
// ChatMessageItemImpl.patchForbiddenStickerData() so that every surface that
// independently inspects a message's media (chat list snippet, push
// notification, inline bot results, search grid, etc.) can enforce the same
// org whitelist without duplicating the attribute-unwrapping logic.

/// Returns whether the given media file is allowed by the CloudVeil sticker
/// whitelist. Non-sticker files are always allowed. Animoji (stickers with an
/// empty associated text) are always allowed. A sticker whose pack is not
/// explicitly whitelisted is blocked (deny-by-default), matching the behavior
/// of patchForbiddenStickerData().
public func isStickerMediaAllowed(_ file: TelegramMediaFile) -> Bool {
    if !(file.isSticker || file.isAnimatedSticker) {
        return true
    }

    for attribute in file.attributes {
        if case let .Sticker(text, packReference, _) = attribute {
            let isAnimoji = text.isEmpty
            if isAnimoji {
                return true
            }

            if case let .id(id, _) = packReference {
                if CloudVeilSecurityController.shared.isStickerAvailable(stickerId: NSInteger(id)) {
                    return true
                }
            }

            return false
        }
    }

    // Sticker file with no .Sticker attribute — nothing to block on.
    return true
}

/// Returns whether the sticker pack with the given id is allowed by the CloudVeil
/// sticker whitelist. `packId` is the raw `ItemCollectionId.id` value
/// (`info.id.id`). Kept as a plain `Int64` so the signature exposes no Postbox
/// type to consumers.
public func isStickerPackAllowed(packId: Int64) -> Bool {
    return CloudVeilSecurityController.shared.isStickerAvailable(stickerId: NSInteger(packId))
}
