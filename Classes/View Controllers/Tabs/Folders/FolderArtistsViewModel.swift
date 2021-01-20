//
//  FolderArtistsViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class FolderArtistsViewModel: ArtistsViewModel {
    @Injected private var store: Store
    
    weak var delegate: APILoaderDelegate?
    var serverId = Settings.shared().currentServerId
    var mediaFolderId: Int {
        didSet {
            loadFromCache()
        }
    }
    
    private var metadata: RootListMetadata?
    var tableSections = [TableSection]()
    
    var isCached: Bool { metadata != nil }
    var count: Int { metadata?.itemCount ?? 0 }
    var searchCount: Int { searchFolderArtistIds.count }
    var reloadDate: Date? { metadata?.reloadDate }
    
    private var loader: RootFoldersLoader?
    private var folderArtistIds = [Int]()
    private var searchFolderArtistIds = [Int]()
    private let searchLimit = 100
    private var searchName: String?
    private(set) var shouldContinueSearch = true
    
    init(mediaFolderId: Int, delegate: APILoaderDelegate? = nil) {
        self.mediaFolderId = mediaFolderId
        self.delegate = delegate
    }
    
    deinit {
        cancelLoad()
    }
    
    private func loadFromCache() {
        metadata = store.folderArtistMetadata(serverId: serverId, mediaFolderId: mediaFolderId)
        if metadata != nil {
            tableSections = store.folderArtistSections(serverId: serverId, mediaFolderId: mediaFolderId)
            folderArtistIds = store.folderArtistIds(serverId: serverId, mediaFolderId: mediaFolderId)
        } else {
            tableSections.removeAll()
            folderArtistIds.removeAll()
        }
    }
    
    func reset() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
        
        metadata = nil
        tableSections.removeAll()
        folderArtistIds.removeAll()
        searchFolderArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
        
        loadFromCache()
    }
    
    func artist(indexPath: IndexPath) -> Artist? {
        let index = tableSections[indexPath.section].position + indexPath.row
        guard index < folderArtistIds.count else { return nil }
        
        return store.folderArtist(serverId: serverId, id: folderArtistIds[index])
    }
    
    func artistInSearch(indexPath: IndexPath) -> Artist? {
        guard indexPath.row < searchFolderArtistIds.count else { return nil }
        return store.folderArtist(serverId: serverId, id: searchFolderArtistIds[indexPath.row])
    }
    
    func clearSearch() {
        searchFolderArtistIds.removeAll()
        searchName = nil
        shouldContinueSearch = true
    }
    
    func search(name: String) {
        searchName = name
        searchFolderArtistIds = store.search(folderArtistName: name, serverId: serverId, mediaFolderId: mediaFolderId, offset: 0, limit: searchLimit)
    }
    
    func continueSearch() {
        if let searchName = searchName, shouldContinueSearch {
            let folderIds = store.search(folderArtistName: searchName, serverId: serverId, mediaFolderId: mediaFolderId, offset: searchFolderArtistIds.count, limit: searchLimit)
            shouldContinueSearch = (folderIds.count == searchLimit)
            searchFolderArtistIds.append(contentsOf: folderIds)
        }
    }
}

extension FolderArtistsViewModel: APILoaderManager {
    func startLoad() {
        cancelLoad()
        
        loader = RootFoldersLoader(delegate: self)
        loader?.mediaFolderId = mediaFolderId
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension FolderArtistsViewModel: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        if let loader = loader as? RootFoldersLoader {
            metadata = loader.metadata
            tableSections = loader.tableSections
            folderArtistIds = loader.folderArtistIds
        }
        
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(loader: nil)
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(loader: nil, error: error)
    }
}
