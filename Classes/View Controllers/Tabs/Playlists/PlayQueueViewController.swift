//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class PlayQueueViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var jukebox: Jukebox
    @Injected private var playQueue: PlayQueue
    
    private let saveEditHeader = SaveEditHeader(saveType: "playlist", countType: "song", pluralizeClearType: false, isLargeCount: false)
    private let tableView = UITableView()
        
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.bassInitialized)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.bassFreed)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxSongInfoUpdated), name: Notifications.jukeboxSongInfo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songsQueued), name: Notifications.currentPlaylistSongsQueued)
    }
    
    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.bassInitialized)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.bassFreed)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.jukeboxSongInfo)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistSongsQueued)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Play Queue"
        
        if isModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismiss(sender:)))
        }
        
        registerForNotifications()
        
        saveEditHeader.delegate = self
        saveEditHeader.count = playQueue.count
        view.addSubview(saveEditHeader)
        saveEditHeader.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.leading.trailing.top.equalToSuperview()
        }
        
        tableView.allowsMultipleSelectionDuringEditing = true
        setupDefaultTableView(tableView) { make in
            make.top.equalTo(self.saveEditHeader.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectRow()
        Flurry.logEvent(isModal ? "PlayerPlayQueue" : "PlayQueueTab")
        if settings.isJukeboxEnabled {
            jukebox.getInfo()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
        if isEditing {
            setEditing(false, animated: true)
        }
    }
    
    @objc private func selectRow() {
        tableView.reloadData()
        let currentIndex = playQueue.currentIndex
        if currentIndex >= 0 && currentIndex < playQueue.count {
            tableView.selectRow(at: IndexPath(row: currentIndex, section: 0), animated: false, scrollPosition: .top)
        }
    }
    
    @objc private func jukeboxSongInfoUpdated() {
        saveEditHeader.count = playQueue.count
        tableView.reloadData()
        selectRow()
    }
    
    @objc private func songsQueued() {
        saveEditHeader.count = playQueue.count
        tableView.reloadData()
    }
    
    @objc private func dismiss(sender: Any) {
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
        
        if isEditing {
            // Deselect all the rows
            for i in 0..<playQueue.count {
                tableView.deselectRow(at: IndexPath(row: i, section: 0), animated: false)
            }
        } else {
            selectRow()
        }
        saveEditHeader.selectedCount = 0
    }
    
    var selectedRows: [Int] {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            return indexPathsForSelectedRows.map { $0.row }
        }
        return []
    }
    
    var selectedRowsCount: Int {
        return tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    private func showSavePlaylistAlert(isLocal: Bool) {
        let alert = UIAlertController(title: "Save Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Playlist name"
        }
        alert.addAction(title: "Save", style: .default, handler: { _ in
            guard let name = alert.textFields?.first?.text else { return }
            if isLocal || self.settings.isOfflineMode {
                // TODO: optimize this in the store to not require loading each song object
                // TODO: Add error handling
                HUD.show()
                DispatchQueue.userInitiated.async {
                    let localPlaylist = LocalPlaylist(id: self.store.nextLocalPlaylistId(), name: name, songCount: 0)
                    if self.store.add(localPlaylist: localPlaylist) {
                        for i in 0..<self.playQueue.count {
                            if let song = self.playQueue.song(index: i) {
                                _ = self.store.add(song: song, localPlaylistId: localPlaylist.id)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        HUD.hide()
                    }
                }
                
            } else {
                self.uploadPlaylist(name: name)
            }
        })
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    private func updateTableCellNumbers() {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            for indexPath in indexPathsForSelectedRows {
                if let cell = tableView.cellForRow(at: indexPath) as? UniversalTableViewCell {
                    cell.number = indexPath.row + 1
                }
            }
        }
    }
    
    private func uploadPlaylist(name: String) {
        // TODO: implement this
        //    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
        //    NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
        //    NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        //    NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        //    NSString *table = playQueue.isShuffle ? shufTable : currTable;
        //
        //    [databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
        //         for (int i = 0; i < self.currentPlaylistCount; i++) {
        //             @autoreleasepool {
        //                 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
        //                 [songIds addObject:n2N(aSong.songId)];
        //             }
        //         }
        //     }];
        //    [parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
        //
        //    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
        //    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //        [EX2Dispatch runInMainThreadAsync:^{
        //            if (error) {
        //                // Inform the user that the connection failed.
        //                if (settingsS.isPopupsEnabled) {
        //                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
        //                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        //                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        //                    [self presentViewController:alert animated:YES completion:nil];
        //                }
        //
        //                self.tableView.scrollEnabled = YES;
        //                [HUD hide];
        //            } else {
        //                RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
        //                if (!root.isValid) {
        //                    NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        //                    [self subsonicErrorCode:nil message:error.description];
        //                } else {
        //                    RXMLElement *error = [root child:@"error"];
        //                    if (error.isValid)
        //                    {
        //                        NSString *code = [error attribute:@"code"];
        //                        NSString *message = [error attribute:@"message"];
        //                        [self subsonicErrorCode:code message:message];
        //                    }
        //                }
        //
        //                self.tableView.scrollEnabled = YES;
        //                [HUD hide];
        //            }
        //        }];
        //    }];
        //    [dataTask resume];
        //
        //    self.tableView.scrollEnabled = NO;
        //    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    }
    
    //- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    //    DDLogError(@"[CurrentPlaylistViewController] subsonic error %@: %@", errorCode, message);
    //    if (settingsS.isPopupsEnabled) {
    //        [EX2Dispatch runInMainThreadAsync:^{
    //            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    //            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    //            [self presentViewController:alert animated:YES completion:nil];
    //        }];
    //    }
    //}
    
    
}

extension PlayQueueViewController: SaveEditHeaderDelegate {
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if saveEditHeader.deleteLabel.isHidden {
            if !isEditing {
                if settings.isOfflineMode {
                    showSavePlaylistAlert(isLocal: true)
                } else {
                    let message = "Would you like to save this playlist to your device or to your Subsonic server?"
                    let alert = UIAlertController(title: "Playlist Location", message: message, preferredStyle: .alert)
                    alert.addAction(title: "Local", style: .default, handler: { _ in
                        self.showSavePlaylistAlert(isLocal: true)
                    })
                    alert.addAction(title: "Server", style: .default, handler: { _ in
                        self.showSavePlaylistAlert(isLocal: false)
                    })
                    alert.addCancelAction()
                    present(alert, animated: true, completion: nil)
                }
            }
        } else {
            unregisterForNotifications()
            
            if selectedRowsCount == 0 {
                // Select all the rows
                for i in 0..<playQueue.count {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                saveEditHeader.selectedCount = playQueue.count
            } else {
                // Delete action
                playQueue.removeSongs(indexes: selectedRows)
                saveEditHeader.count = playQueue.count
                tableView.deleteRows(at: tableView.indexPathsForSelectedRows ?? [], with: .automatic)
                updateTableCellNumbers()
                setEditing(false, animated: true)
            }
            
            if !settings.isJukeboxEnabled {
                NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistOrderChanged)
            }
            
            registerForNotifications()
        }
    }
    
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!self.isEditing, animated: true)
    }
}

extension PlayQueueViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playQueue.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.number = indexPath.row + 1
        cell.show(cached: true, number: true, art: true, secondary: true, duration: true)
        cell.update(model: playQueue.song(index: indexPath.row))
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        _ = playQueue.moveSong(fromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        
        if isModal {
            dismiss(sender: self)
            DispatchQueue.main.async(after: 0.5) {
                self.playQueue.playSong(position: indexPath.row)
            }
        } else {
            playQueue.playSong(position: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = playQueue.song(index: indexPath.row), !song.isVideo {
            return SwipeAction.downloadQueueAndDeleteConfig(model: song) { [unowned self] in
                playQueue.removeSongs(indexes: [indexPath.row])
                self.saveEditHeader.count = playQueue.count
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
        return nil
    }
}
