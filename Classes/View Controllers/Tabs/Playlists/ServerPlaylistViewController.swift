//
//  LocalPlaylistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

@objc final class ServerPlaylistViewController: UIViewController {
    @Injected private var store: Store
    
    private var serverPlaylistLoader: ServerPlaylistLoader?
    private var serverPlaylist: ServerPlaylist
    
    private let tableView = UITableView()
    
    @objc init(serverPlaylist: ServerPlaylist) {
        self.serverPlaylist = serverPlaylist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = serverPlaylist.name
        setupDefaultTableView(tableView)
        tableView.refreshControl = RefreshControl { [unowned self] in
            loadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addShowPlayerButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelLoad()
    }
    
    private func loadData() {
        cancelLoad()
        let serverId = serverPlaylist.serverId
        let serverPlaylistId = serverPlaylist.id
        serverPlaylistLoader = ServerPlaylistLoader(serverPlaylistId: serverPlaylistId)
        serverPlaylistLoader?.callback = { [unowned self] (success, error) in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    if Settings.shared().isPopupsEnabled {
                        let message = "There was an error loading the playlist.\n\nError %\(error.code): \(error.localizedDescription)"
                        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                        alert.addCancelAction(title: "OK")
                        present(alert, animated: true, completion: nil)
                    }
                } else {
                    // Reload the server playlist to get the updated loaded song count
                    if let serverPlaylist = store.serverPlaylist(serverId: serverId, id: serverPlaylistId) {
                        self.serverPlaylist = serverPlaylist
                    }
                    tableView.reloadData()
                }
                ViewObjects.shared().hideLoadingScreen()
                self.tableView.refreshControl?.endRefreshing()
            }
        }
        serverPlaylistLoader?.startLoad()
        ViewObjects.shared().showAlbumLoadingScreen(self.view, sender: self)
    }
    
    @objc func cancelLoad() {
        serverPlaylistLoader?.cancelLoad()
        serverPlaylistLoader?.callback = nil
        serverPlaylistLoader = nil
        ViewObjects.shared().hideLoadingScreen()
        self.tableView.refreshControl?.endRefreshing()
    }
}
 
extension ServerPlaylistViewController: UITableViewConfiguration {
    private func song(indexPath: IndexPath) -> Song? {
        return store.song(serverPlaylist: serverPlaylist, position: indexPath.row)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverPlaylist.loadedSongCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: true, number: true, art: true, secondary: true, duration: true)
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
        DispatchQueue.userInitiated.async { [unowned self] in
            let song = store.playSongFromServerPlaylist(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: indexPath.row)
            
            DispatchQueue.main.async {
                ViewObjects.shared().hideLoadingScreen()
                if let song = song, !song.isVideo {
                    showPlayer()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
