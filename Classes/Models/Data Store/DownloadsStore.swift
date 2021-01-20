//
//  DownloadsStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension DownloadedSong: FetchableRecord, PersistableRecord {
    struct Table {
        static let downloadQueue = "downloadQueue"
    }
    
    enum Column: String, ColumnExpression {
        case serverId, songId, path, isFinished, isPinned, size, cachedDate, playedDate
    }
    enum RelatedColumn: String, ColumnExpression {
        case queuedDate
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSong.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.column(Column.path, .integer).notNull()
            t.column(Column.isFinished, .boolean).notNull()
            t.column(Column.isPinned, .boolean).notNull()
            t.column(Column.size, .integer).notNull()
            t.column(Column.cachedDate, .datetime)
            t.column(Column.playedDate, .datetime)
            t.primaryKey([Column.serverId, Column.songId])
        }
        
        try db.create(table: Table.downloadQueue) { t in
            t.autoIncrementedPrimaryKey(GRDB.Column.rowID)
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.songId, .integer).notNull()
            t.column(RelatedColumn.queuedDate, .datetime).notNull()
            t.uniqueKey([Column.serverId, Column.songId])
        }
    }
    
    static func fetchOne(_ db: Database, serverId: Int, songId: Int) throws -> DownloadedSong? {
        try DownloadedSong.filter(literal: "serverId = \(serverId) AND songId = \(songId)").fetchOne(db)
    }
}

extension DownloadedSongPathComponent: FetchableRecord, PersistableRecord {
    enum Column: String, ColumnExpression {
        case level, maxLevel, pathComponent, parentPathComponent, serverId, songId
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: DownloadedSongPathComponent.databaseTableName) { t in
            t.column(Column.serverId, .integer).notNull()
            t.column(Column.level, .integer).notNull()
            t.column(Column.maxLevel, .integer).notNull()
            t.column(Column.pathComponent, .text).notNull()
            t.column(Column.parentPathComponent, .text)
            t.column(Column.songId, .integer).notNull()
        }
        // TODO: Implement correct indexes
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.serverId, Column.songId])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.serverId, Column.level, Column.pathComponent])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.level, Column.pathComponent])
//        try db.create(indexOn: DownloadedSongPathComponent.databaseTableName, columns: [Column.level, Column.maxLevel, Column.pathComponent])
    }
    
    static func addDownloadedSongPathComponents(_ db: Database, downloadedSong: DownloadedSong) throws {
        let serverId = downloadedSong.serverId
        let songId = downloadedSong.songId
        let pathComponents = NSString(string: downloadedSong.path).pathComponents
        let maxLevel = pathComponents.count - 1
        var parentPathComponent: String?
        for (level, pathComponent) in pathComponents.enumerated() {
            let record = DownloadedSongPathComponent(level: level, maxLevel: maxLevel, pathComponent: pathComponent, parentPathComponent: parentPathComponent, serverId: serverId, songId: songId)
            try record.save(db)
            parentPathComponent = record.pathComponent
        }
    }
}

extension DownloadedFolderArtist: FetchableRecord, PersistableRecord {
}

extension DownloadedFolderAlbum: FetchableRecord, PersistableRecord {
}

extension DownloadedTagArtist: FetchableRecord, PersistableRecord {
}

extension DownloadedTagAlbum: FetchableRecord, PersistableRecord {
}

extension Store {
//    func downloadedFolderArtists() -> [DownloadedFolderArtist] {
//        do {
//            return try pool.read { db in
//                let sql: SQLLiteral = """
//                    SELECT serverId, pathComponent AS name
//                    FROM \(DownloadedSongPathComponent.self)
//                    WHERE level = 0
//                    GROUP BY pathComponent
//                    """
//                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select all downloaded folder artists: \(error)")
//            return []
//        }
//    }
    
    func downloadedFolderArtists(serverId: Int) -> [DownloadedFolderArtist] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT serverId, pathComponent AS name
                    FROM \(DownloadedSongPathComponent.self)
                    WHERE serverId = \(serverId) AND level = 0
                    GROUP BY pathComponent
                    ORDER BY pathComponent COLLATE NOCASE
                    """
                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded folder artists for server \(serverId): \(error)")
            return []
        }
    }
    
//    func downloadedFolderAlbums(level: Int) -> [DownloadedFolderArtist] {
//        do {
//            return try pool.read { db in
//                let sql: SQLLiteral = """
//                    SELECT serverId, level, pathComponent AS name
//                    FROM \(DownloadedSongPathComponent.self)
//                    WHERE serverId = \(serverId) AND level = \(level)
//                    GROUP BY pathComponent
//                    """
//                return try SQLRequest<DownloadedFolderArtist>(literal: sql).fetchAll(db)
//            }
//        } catch {
//            DDLogError("Failed to select all downloaded folder artists for server \(serverId): \(error)")
//            return []
//        }
//    }
    
    func downloadedFolderAlbums(serverId: Int, level: Int, parentPathComponent: String) -> [DownloadedFolderAlbum] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(DownloadedSongPathComponent.self).serverId,
                        \(DownloadedSongPathComponent.self).level,
                        \(DownloadedSongPathComponent.self).pathComponent AS name,
                        \(Song.self).coverArtId
                    FROM \(DownloadedSongPathComponent.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSongPathComponent.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSongPathComponent.self).songId = \(Song.self).id
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                        AND \(DownloadedSongPathComponent.self).level = \(level)
                        AND \(DownloadedSongPathComponent.self).maxLevel != \(level)
                        AND \(DownloadedSongPathComponent.self).parentPathComponent = \(parentPathComponent)
                    GROUP BY \(DownloadedSongPathComponent.self).pathComponent
                    ORDER BY \(DownloadedSongPathComponent.self).pathComponent COLLATE NOCASE
                    """
                return try SQLRequest<DownloadedFolderAlbum>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded folder albums for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return []
        }
    }
    
    // TODO: Check query plan and try different join orders and group by tables to see which is fastest (i.e. TagArtist.id vs Song.tagArtistId)
    func downloadedTagArtists(serverId: Int) -> [DownloadedTagArtist] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(TagArtist.self).*
                    FROM \(DownloadedSong.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    JOIN \(TagArtist.self)
                    ON \(DownloadedSong.self).serverId = \(TagArtist.self).serverId
                        AND \(Song.self).tagArtistId = \(TagArtist.self).id
                    WHERE \(DownloadedSong.self).serverId = \(serverId)
                    GROUP BY \(TagArtist.self).id
                    ORDER BY \(TagArtist.self).name COLLATE NOCASE ASC
                    """
                return try SQLRequest<DownloadedTagArtist>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded tag artists for server \(serverId): \(error)")
            return []
        }
    }
    
    // TODO: Check query plan and try different join orders and group by tables to see which is fastest (i.e. TagAlbum.id vs Song.tagAlbumId)
    func downloadedTagAlbums(serverId: Int) -> [DownloadedTagAlbum] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT \(TagAlbum.self).*
                    FROM \(DownloadedSong.self)
                    JOIN \(Song.self)
                    ON \(DownloadedSong.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSong.self).songId = \(Song.self).id
                    JOIN \(TagAlbum.self)
                    ON \(DownloadedSong.self).serverId = \(TagAlbum.self).serverId
                        AND \(Song.self).tagAlbumId = \(TagAlbum.self).id
                    WHERE \(DownloadedSong.self).serverId = \(serverId)
                    GROUP BY \(TagAlbum.self).id
                    ORDER BY \(TagAlbum.self).name COLLATE NOCASE ASC
                    """
                return try SQLRequest<DownloadedTagAlbum>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded tag artists for server \(serverId): \(error)")
            return []
        }
    }
    
    @objc func song(downloadedSong: DownloadedSong) -> Song? {
        return song(serverId: downloadedSong.serverId, id: downloadedSong.songId)
    }
    
    @objc func songsRecursive(serverId: Int, level: Int, parentPathComponent: String) -> [Song] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN \(DownloadedSongPathComponent.self)
                    ON \(DownloadedSongPathComponent.self).serverId = \(Song.self).serverId
                        AND \(DownloadedSongPathComponent.self).songId = \(Song.self).id
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                        AND  \(DownloadedSongPathComponent.self).level >= \(level)
                    GROUP BY \(Song.self).serverId, \(Song.self).id
                    """
                return try SQLRequest<Song>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all songs recursively for server \(serverId) level \(level) parent \(parentPathComponent): \(error)")
            return []
        }
    }
    
    func songsRecursive(downloadedFolderArtist: DownloadedFolderArtist) -> [Song] {
        return songsRecursive(serverId: downloadedFolderArtist.serverId, level: 0, parentPathComponent: downloadedFolderArtist.name)
    }
    
    func songsRecursive(downloadedFolderAlbum: DownloadedFolderAlbum) -> [Song] {
        return songsRecursive(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level, parentPathComponent: downloadedFolderAlbum.name)
    }
    
    @objc func downloadedSongsCount() -> Int {
        do {
            return try pool.read { db in
                try DownloadedSong.filter(literal: "isFinished = 1").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count: \(error)")
            return 0
        }
    }
    
    @objc func downloadedSongsCount(serverId: Int) -> Int {
        do {
            return try pool.read { db in
                try DownloadedSong.filter(literal:"serverId = \(serverId) AND isFinished = 1").fetchCount(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs count for server \(serverId): \(error)")
            return 0
        }
    }
    
    @objc func downloadedSongs(serverId: Int, level: Int, parentPathComponent: String) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    JOIN \(DownloadedSongPathComponent.self)
                    ON \(DownloadedSong.self).serverId = \(DownloadedSongPathComponent.self).serverId
                        AND \(DownloadedSong.self).songID = \(DownloadedSongPathComponent.self).songId
                    WHERE \(DownloadedSongPathComponent.self).serverId = \(serverId)
                        AND \(DownloadedSongPathComponent.self).level = \(level)
                        AND \(DownloadedSongPathComponent.self).maxLevel = \(level)
                        AND \(DownloadedSongPathComponent.self).parentPathComponent = \(parentPathComponent)
                    ORDER BY \(DownloadedSongPathComponent.self).pathComponent COLLATE NOCASE
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select downloaded songs at level \(level) for server \(serverId): \(error)")
            return []
        }
    }
    
    @objc func downloadedSongs(serverId: Int) -> [DownloadedSong] {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    ORDER BY \(DownloadedSong.self).cachedDate COLLATE NOCASE DESC
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all downloaded songs for server \(serverId): \(error)")
            return []
        }
    }
    
    @objc func downloadedSong(serverId: Int, songId: Int) -> DownloadedSong? {
        do {
            return try pool.read { db in
                try DownloadedSong.fetchOne(db, serverId: serverId, songId: songId)
            }
        } catch {
            DDLogError("Failed to select downloaded song \(songId) for server \(serverId): \(error)")
            return nil
        }
    }
    
    // TODO: Confirm if LIMIT 1 makes any performance difference when using fetchOne()
    // NOTE: Excludes pinned songs
    @objc func oldestDownloadedSongByCachedDate() -> DownloadedSong? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    WHERE isFinished = 1 AND isPinned = 0
                    ORDER BY cachedDate ASC
                    LIMIT 1
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select oldest downloaded song by cached date: \(error)")
            return nil
        }
    }
    
    // NOTE: Excludes pinned songs
    @objc func oldestDownloadedSongByPlayedDate() -> DownloadedSong? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(DownloadedSong.self)
                    WHERE isFinished = 1 AND isPinned = 0
                    ORDER BY playedDate ASC
                    LIMIT 1
                    """
                return try SQLRequest<DownloadedSong>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select oldest downloaded song by cached date: \(error)")
            return nil
        }
    }
    
    @objc func deleteDownloadedSong(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded song record for server \(serverId) and song \(songId): \(error)")
            return false
        }
    }
    
    @objc func delete(downloadedSong: DownloadedSong) -> Bool {
        return deleteDownloadedSong(serverId: downloadedSong.serverId, songId: downloadedSong.songId);
    }
    
    @objc func deleteDownloadedSongs(serverId: Int, level: Int) -> Bool {
        do {
            return try pool.write { db in
                let songIdsSql: SQLLiteral = """
                    SELECT songId
                    FROM \(DownloadedSongPathComponent.self)
                    WHERE serverId = \(serverId) AND level = \(level)
                    GROUP BY serverId, songId
                    """
                let songIds = try SQLRequest<Int>(literal: songIdsSql).fetchAll(db)
                for songId in songIds {
                    try db.execute(literal: "DELETE FROM \(DownloadedSong.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                    try db.execute(literal: "DELETE FROM \(DownloadedSongPathComponent.self) WHERE serverId = \(serverId) AND songId = \(songId)")
                }
                return true
            }
        } catch {
            DDLogError("Failed to delete downloaded songs for server \(serverId) and level \(level): \(error)")
            return false
        }
    }
    
    func deleteDownloadedSongs(downloadedFolderArtist: DownloadedFolderArtist) -> Bool {
        return deleteDownloadedSongs(serverId: downloadedFolderArtist.serverId, level: 0)
    }
    
    func deleteDownloadedSongs(downloadedFolderAlbum: DownloadedFolderAlbum) -> Bool {
        return deleteDownloadedSongs(serverId: downloadedFolderAlbum.serverId, level: downloadedFolderAlbum.level)
    }
    
    @objc func add(downloadedSong: DownloadedSong) -> Bool {
        do {
            return try pool.write { db in
                try downloadedSong.save(db)
                return true
            }
        } catch {
            DDLogError("Failed to insert downloaded song \(downloadedSong): \(error)")
            return false
        }
    }
    
    @objc func update(playedDate: Date, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET playedDate = \(playedDate)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to update played date \(playedDate) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    @objc func update(playedDate: Date, song: Song) -> Bool {
        return update(playedDate: playedDate, serverId: song.serverId, songId: song.id)
    }
    
    @objc func update(downloadFinished: Bool, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET isFinished = \(downloadFinished)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                
                // If the download finished, add the path components
                if downloadFinished, let downloadedSong = try DownloadedSong.fetchOne(db, serverId: serverId, songId: songId) {
                    try DownloadedSongPathComponent.addDownloadedSongPathComponents(db, downloadedSong: downloadedSong)
                }
                return true
            }
        } catch {
            DDLogError("Failed to update download finished \(downloadFinished) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    @objc func update(downloadFinished: Bool, song: Song) -> Bool {
        return update(downloadFinished: downloadFinished, serverId: song.serverId, songId: song.id)
    }
    
    @objc func update(isPinned: Bool, serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    UPDATE \(DownloadedSong.self)
                    SET isPinned = \(isPinned)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to update download is pinned \(isPinned) for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    @objc func update(isPinned: Bool, song: Song) -> Bool {
        return update(isPinned: isPinned, serverId: song.serverId, songId: song.id)
    }
    
    @objc func isDownloadFinished(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT isFinished
                    FROM \(DownloadedSong.self)
                    WHERE serverId = \(serverId) AND songId = \(songId)
                    """
                return try SQLRequest<Bool>(literal: sql).fetchOne(db) ?? false
            }
        } catch {
            DDLogError("Failed to select download finished for song \(songId) server \(serverId): \(error)")
            return false
        }
    }
    
    @objc func isDownloadFinished(song: Song) -> Bool {
        return isDownloadFinished(serverId: song.serverId, songId: song.id)
    }
    
    @objc func addToDownloadQueue(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    INSERT OR IGNORE INTO downloadQueue (serverId, songId, queuedDate)
                    VALUES (\(serverId), \(songId), \(Date())
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to add song \(songId) server \(serverId) to download queue: \(error)")
            return false
        }
    }
    
    @objc func addToDownloadQueue(song: Song) -> Bool {
        return addToDownloadQueue(serverId: song.serverId, songId: song.id)
    }
    
    @objc func addToDownloadQueue(serverId: Int, songIds: [Int]) -> Bool {
        do {
            return try pool.write { db in
                for songId in songIds {
                    let sql: SQLLiteral = """
                        INSERT OR IGNORE INTO downloadQueue (serverId, songId)
                        VALUES (\(serverId), \(songId)
                        """
                    try db.execute(literal: sql)
                }
                return true
            }
        } catch {
            DDLogError("Failed to add songIds \(songIds) server \(serverId) to download queue: \(error)")
            return false
        }
    }
    
    @objc func removeFromDownloadQueue(serverId: Int, songId: Int) -> Bool {
        do {
            return try pool.write { db in
                let sql: SQLLiteral = """
                    DELETE FROM downloadQueue
                    WHERE serverId = (\(serverId) AND songId = \(songId)
                    """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to remove song \(songId) server \(serverId) from download queue: \(error)")
            return false
        }
    }
    
    @objc func removeFromDownloadQueue(song: Song) -> Bool {
        return removeFromDownloadQueue(serverId: song.serverId, songId: song.id)
    }
    
    @objc func songFromDownloadQueue(position: Int) -> Song? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT *
                    FROM \(Song.self)
                    JOIN downloadQueue
                    ON \(Song.self).serverId = downloadQueue.serverId AND \(Song.self).id = downloadQueue.songId
                    ORDER BY downloadQueue.rowid ASC
                    LIMIT 1 OFFSET \(position)
                    """
                return try SQLRequest<Song>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song download queue at position \(position): \(error)")
            return nil
        }
    }
    
    @objc func queuedDateForSongFromDownloadQueue(position: Int) -> Date? {
        do {
            return try pool.read { db in
                let sql: SQLLiteral = """
                    SELECT queuedDate
                    FROM downloadQueue
                    ORDER BY downloadQueue.rowid ASC
                    LIMIT 1 OFFSET \(position)
                    """
                return try SQLRequest<Date>(literal: sql).fetchOne(db)
            }
        } catch {
            DDLogError("Failed to select song download queued date at position \(position): \(error)")
            return nil
        }
    }
    
    @objc func firstSongInDownloadQueue() -> Song? {
        return songFromDownloadQueue(position: 0)
    }
    
    @objc func downloadQueueCount() -> Int {
        do {
            return try pool.read { db in
                return try SQLRequest<Int>(literal: "SELECT COUNT(*) FROM downloadQueue").fetchOne(db) ?? 0
            }
        } catch {
            DDLogError("Failed to select download queue count: \(error)")
            return 0
        }
    }
}
