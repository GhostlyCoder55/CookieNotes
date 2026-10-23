//
//  AdPlacement.swift
//  CookieNotes
//

import Foundation

enum AdSlot: Equatable {
    case item(Int)
    case advertisement(Int)
}

struct AdFeedBlock: Equatable, Identifiable {
    enum Kind: Equatable {
        case items([Int])
        case advertisement
    }

    let id: Int
    let kind: Kind
}

/// Decides where a banner can sit without attaching it to navigation or empty screens.
enum AdPlacement {
    static func browsingSlots(itemCount: Int, adsEnabled: Bool, chunkSize: Int = 6, maxAds: Int = 2) -> [AdSlot] {
        guard itemCount > 0 else { return [] }

        var slots: [AdSlot] = []
        var adsInserted = 0
        var adID = 0
        var index = 0

        while index < itemCount {
            let end = min(index + chunkSize, itemCount)
            for offset in index..<end {
                slots.append(.item(offset))
            }
            let moreRemain = end < itemCount
            if adsEnabled && moreRemain && adsInserted < maxAds {
                slots.append(.advertisement(adID))
                adID += 1
                adsInserted += 1
            }
            index = end
        }

        if adsEnabled && adsInserted == 0 {
            slots.append(.advertisement(adID))
        }
        return slots
    }

    static func searchSlots(itemCount: Int, adsEnabled: Bool) -> [AdSlot] {
        guard itemCount > 0 else { return [] }
        var slots: [AdSlot] = []
        for index in 0..<itemCount {
            slots.append(.item(index))
            let afterFourthResult = index == 3
            let afterShortList = itemCount < 4 && index == itemCount - 1
            if adsEnabled && (afterFourthResult || afterShortList) {
                slots.append(.advertisement(0))
            }
        }
        return slots
    }

    static func blocks(from slots: [AdSlot]) -> [AdFeedBlock] {
        var blocks: [AdFeedBlock] = []
        var pending: [Int] = []
        var nextID = 0

        func flushItems() {
            guard !pending.isEmpty else { return }
            // Include first index in the id so SwiftUI does not reuse a stale grid
            // after recipes are deleted and indices shrink.
            let blockID = nextID * 1_000 + (pending.first ?? 0)
            blocks.append(AdFeedBlock(id: blockID, kind: .items(pending)))
            nextID += 1
            pending.removeAll()
        }

        for slot in slots {
            switch slot {
            case .item(let index):
                pending.append(index)
            case .advertisement:
                flushItems()
                blocks.append(AdFeedBlock(id: nextID * 1_000 + 900, kind: .advertisement))
                nextID += 1
            }
        }
        flushItems()
        return blocks
    }

    static func showsContentBanner(adsEnabled: Bool, hasContent: Bool) -> Bool {
        adsEnabled && hasContent
    }
}
