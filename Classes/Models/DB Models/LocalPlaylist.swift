//
//  LocalPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class LocalPlaylist: Codable, CustomStringConvertible {
    struct Default {
        static let playQueueId = 1
        static let shuffleQueueId = 2
        static let jukeboxPlayQueueId = 3
        static let jukeboxShuffleQueueId = 4
        static let maxDefaultId = jukeboxShuffleQueueId
    }
    
    let id: Int
    var name: String
    var songCount: Int
    
    init(id: Int, name: String, songCount: Int) {
        self.id = id
        self.name = name
        self.songCount = songCount
    }
    
    static func ==(lhs: LocalPlaylist, rhs: LocalPlaylist) -> Bool {
        return lhs === rhs || (lhs.id == rhs.id)
    }
}

extension LocalPlaylist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { songCount == 1 ? "1 song" : "\(songCount) songs" }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { false }
    func download() {
        let store: Store = Resolver.resolve()
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.download()
        }
    }
    
    func queue() {
        let store: Store = Resolver.resolve()
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.queue()
        }
    }
}
