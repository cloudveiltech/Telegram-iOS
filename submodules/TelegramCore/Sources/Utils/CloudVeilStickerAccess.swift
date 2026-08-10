import Foundation
import CloudVeilSecurityManager

// Not dead code — keeps this file from being dead-code-stripped by the linker,
// since it otherwise only exports free functions. Repo-wide pattern, see MD5.swift.
private final class LinkHelperClass: NSObject {
}

// CloudVeil: adapter file — NOT the source of truth for the whitelist.
//
// The whitelist data and allow/deny decision live in CloudVeil's own
// CloudVeilSecurityController (see isStickerAvailable(stickerId:)).
// This file only unwraps TelegramCore types into the plain Int64 that
// controller expects, then calls straight through.
//
// Why the logic can't just live on CloudVeilSecurityController directly:
//
//   CloudVeil/SecurityManager  --------->  TelegramCore
//   (CloudVeilSecurityController)          (this file)
//
//   - SecurityManager imports UIKit, knows nothing about Postbox/
//     TelegramCore types (TelegramMediaFile, sticker attributes, etc).
//   - TelegramCore already depends on SecurityManager (arrow above).
//   - TelegramCore may not import UIKit, so the dependency can't run
//     the other way — SecurityManager can't reach back into TelegramCore.
//
// Net effect: the type-unwrapping has to happen on the TelegramCore side
// of that arrow. That's what these two functions do.
//
// Looking for the actual whitelist logic? Go to CloudVeilSecurityController.
//
// These also mirror the unwrap/deny-by-default semantics of
// ChatMessageItemImpl.patchForbiddenStickerData() so that every surface that
// independently inspects a message's media (chat list snippet, push
// notification, inline bot results, search grid, etc.) can enforce the same
// org whitelist without duplicating the attribute-unwrapping logic.

/// Returns whether the given media file is allowed by the CloudVeil sticker
/// whitelist. Non-sticker files are always allowed. Animoji (stickers with an
/// empty associated text) are always allowed. A sticker whose pack is not
/// explicitly whitelisted is blocked (deny-by-default), matching the behavior
/// of patchForbiddenStickerData().
///
/// Delegates to CloudVeilSecurityController.isStickerAvailable(stickerId:) —
/// this function only unwraps the file's pack id for it.
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
///
/// Delegates to CloudVeilSecurityController.isStickerAvailable(stickerId:) —
/// this function only forwards the id.
public func isStickerPackAllowed(packId: Int64) -> Bool {
    return CloudVeilSecurityController.shared.isStickerAvailable(stickerId: NSInteger(packId))
}
