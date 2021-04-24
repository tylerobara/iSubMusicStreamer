//
//  TagArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import InflectorKit

struct TagArtist: Artist, Codable, Equatable {
    let serverId: Int
    let id: String
    let name: String
    let coverArtId: String?
    let artistImageUrl: String?
    let albumCount: Int
    let starredDate: Date?
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").stringXML
        self.name = element.attribute("name").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.artistImageUrl = element.attribute("artistImageUrl").stringXMLOptional
        self.albumCount = element.attribute("albumCount").intXML
        self.starredDate = element.attribute("starred").dateXMLOptional
    }
    
    static func ==(lhs: TagArtist, rhs: TagArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension TagArtist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { "\(albumCount) \("Album".pluralize(amount: albumCount))" }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    
    var tagArtistId: String? { nil }
    var tagAlbumId: String? { nil }
    var parentFolderId: String? { nil }
    
    func download() { SongsHelper.downloadAll(serverId: serverId, tagArtistId: id) }
    func queue() { SongsHelper.queueAll(serverId: serverId, tagArtistId: id) }
    func queueNext() { SongsHelper.queueAllNext(serverId: serverId, tagArtistId: id) }
}
