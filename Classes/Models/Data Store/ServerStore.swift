//
//  ServerStore.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

extension Server: FetchableRecord, MutablePersistableRecord {
    enum Column: String, ColumnExpression {
        case id, type, url, username, password, path, isVideoSupported, isNewSearchSupported
    }
    
    static func createInitialSchema(_ db: Database) throws {
        try db.create(table: Server.databaseTableName) { t in
            t.autoIncrementedPrimaryKey(Column.id).notNull()
            t.column(Column.type, .text).notNull()
            t.column(Column.url, .text).notNull()
            t.column(Column.username, .text).notNull()
            t.column(Column.password, .text).notNull()
            t.column(Column.path, .text).notNull()
            t.column(Column.isVideoSupported, .boolean).notNull()
            t.column(Column.isNewSearchSupported, .boolean).notNull()
        }
    }
    
    func didInsert(with rowID: Int64, for column: String?) {
        id = Int(rowID)
    }
}

@objc extension Store {
    @objc func servers() -> [Server] {
        do {
            return try mainDb.read { db in
                try Server.fetchAll(db)
            }
        } catch {
            DDLogError("Failed to select all servers: \(error)")
            return []
        }
    }
    
    @objc func server(id: Int) -> Server? {
        do {
            return try mainDb.read { db in
                try Server.fetchOne(db, key: id)
            }
        } catch {
            DDLogError("Failed to select servers \(id): \(error)")
            return nil
        }
    }
    
    @objc func add(server: Server) -> Server? {
        do {
            var mutableServer = server
            return try mainDb.write { db in
                try mutableServer.save(db)
                return mutableServer
            }
        } catch {
            DDLogError("Failed to insert server \(server): \(error)")
            return nil
        }
    }
    
    @objc func deleteServer(id: Int) -> Bool {
        do {
            return try mainDb.write { db in
                let sql: SQLLiteral = """
                DELETE FROM \(Server.self)
                WHERE id = \(id)
                """
                try db.execute(literal: sql)
                return true
            }
        } catch {
            DDLogError("Failed to delete server \(id): \(error)")
            return false
        }
    }
}
