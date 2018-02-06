//
//  ViewController.swift
//  Premiumize
//
//  Created by Tim Haug on 30.01.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import MediaPlayer
import AVKit

class CloudViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(CloudViewController.handleRefresh),
                                 for: UIControlEvents.valueChanged)
        //        refreshControl.extendedLayoutIncludesOpaqueBars = YES
        return refreshControl
    }()
    
    var unsortedFiles: [File]?
    var files: [File]?
    var playedFiles: [File]?
    var unplayedFiles: [File]?
    var folderId: String?
    var folderName: String?
//    let defaults = UserDefaults.standard
    let keyStore = NSUbiquitousKeyValueStore()
    var sortKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //        let add = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(sortButtonPressed))
        //        let play = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(sortButtonPressed))
        let image = UIImage(named: "sort")?.withRenderingMode(.alwaysOriginal)
        let sortButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(sortButtonPressed))
        
        navigationItem.rightBarButtonItems = [sortButton]
        
        self.tableView.refreshControl = refreshControl
        
        guard let items = tabBarController?.tabBar.items else { return }
        items[0].title = "Cloud"
        items[1].title = "Downloader"
        items[2].title = "Offline"
        items[3].title = "Profile"
        
        
        if let sortKey = keyStore.string(forKey: "sortKey") {
            self.sortKey = sortKey
        } else {
            keyStore.set("original", forKey: "sortKey")
        }
        keyStore.synchronize()
        loadData()
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.indexPathsForSelectedRows?.forEach {
            tableView.deselectRow(at: $0, animated: true)
        }
        
        // show large navigation bar header introduced in iOS 11 on the first screen
        if folderId == nil {
            self.navigationController?.navigationBar.prefersLargeTitles = true
        } else {
            self.navigationController?.navigationBar.prefersLargeTitles = false
        }
        
        //         sort if user changed sortKey and goes back to ViewController
        if let files = files, let sortKey = self.keyStore.string(forKey: "sortKey") {
            self.files = self.sortData(files: files, key: sortKey)
        }
        
        if self.keyStore.bool(forKey: "onlyPlayableBool"), let files = self.files {
            print("before only playable filter files count \(files.count)")
            self.files = files.filter {
                $0.type == FileType.folder || $0.streamLink != nil
            }
            print("after only playable filter files count \(files.count)")
        }
        
        tableView.reloadData()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        let urlString: String?
        if let folderId = folderId, let folderName = folderName {
            urlString = "https://www.premiumize.me/api/folder/list?id=\(folderId)&customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
            self.title = folderName
        } else {
            urlString = "https://www.premiumize.me/api/folder/list?customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
            self.title = "Cloud"
        }
        
        if let urlString = urlString {
            guard let url = URL(string: urlString) else { return }
            
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error != nil {
                    print(error!.localizedDescription)
                    DispatchQueue.main.async {
                        print(self.tableView.separatorStyle)
                        TableViewHelper.EmptyMessage(message: error!.localizedDescription, tableView: self.tableView)
                        print(self.tableView.separatorStyle)
                    }
                } else {
                    guard let data = data else { return }
                    
                    do {
                        //Decode retrived data with JSONDecoder and assing type of Article object
                        let result = try JSONDecoder().decode(Result.self, from: data)
                        self.files = result.fileList
                        self.unsortedFiles = result.fileList
                        
                        
                        
                        
                        //Get back to the main queue
                        DispatchQueue.main.async {
                            if let files = self.files, let sortKey = self.keyStore.string(forKey: "sortKey") {
                                self.files = self.sortData(files: files, key: sortKey)
                            }
                            
                            if self.keyStore.bool(forKey: "onlyPlayableBool"), let files = self.files {
                                self.files = files.filter {
                                    $0.type == FileType.folder || $0.streamLink != nil
                                }
                            }
                            
                            self.tableView?.reloadData()
                            self.refreshControl.endRefreshing()
                        }
                        //
                    } catch let jsonError {
                        print(jsonError)
                    }
                }
                }.resume()
        }
        
        // necessary to allow audio playback when silent mode is turned on
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    
    func sortData(files: [File], key: String) -> [File] {
        keyStore.set(key, forKey: "sortKey")
        keyStore.synchronize()
        
        switch key {
        case "original":
            return self.unsortedFiles ?? []
//            self.files = self.unsortedFiles
//            self.tableView.reloadData()
        case "name":
            return files.sorted(by: { $0.name < $1.name })
//            if let files = self.files {
//                self.files = files.sorted(by: { $0.name < $1.name })
//                self.tableView.reloadData()
//            }
        case "size":
            var folders = [File]()
            var dataFiles = [File]()
            for item in files {
                if item.size != nil {
                    dataFiles.append(item)
                } else {
                    folders.append(item)
                }
            }
            let sortedDataFiles = dataFiles.sorted(by: {
                if let size0 = $0.size, let size1 = $1.size {
                    return size0 > size1
                } else {
                    return $0.name < $1.name
                }
            })
            let sortedFolders = folders.sorted(by: {$0.name < $1.name })
            var allSortedFiles = [File]()
            allSortedFiles.append(contentsOf: sortedDataFiles)
            allSortedFiles.append(contentsOf: sortedFolders)
            return allSortedFiles
//            if let files = self.files {
//                var folders = [File]()
//                var dataFiles = [File]()
//                for item in files {
//                    if item.size != nil {
//                        dataFiles.append(item)
//                    } else {
//                        folders.append(item)
//                    }
//                }
//                let sortedDataFiles = dataFiles.sorted(by: {
//                    if let size0 = $0.size, let size1 = $1.size {
//                        return size0 > size1
//                    } else {
//                        return $0.name < $1.name
//                    }
//                })
//                let sortedFolders = folders.sorted(by: {$0.name < $1.name })
//                var allSortedFiles = [File]()
//                allSortedFiles.append(contentsOf: sortedDataFiles)
//                allSortedFiles.append(contentsOf: sortedFolders)
//                print(allSortedFiles)
//                self.files = allSortedFiles
//                self.tableView.reloadData()
//            }
        case "createdAt":
            var folders = [File]()
            var dataFiles = [File]()
            for item in files {
                if item.size != nil {
                    dataFiles.append(item)
                } else {
                    folders.append(item)
                }
            }
            let sortedDataFiles = dataFiles.sorted(by: {
                if let size0 = $0.createdAt, let size1 = $1.createdAt {
                    return size0 > size1
                } else {
                    return $0.name < $1.name
                }
            })
            let sortedFolders = folders.sorted(by: {$0.name < $1.name })
            var allSortedFiles = [File]()
            allSortedFiles.append(contentsOf: sortedDataFiles)
            allSortedFiles.append(contentsOf: sortedFolders)
            return allSortedFiles
//            if let files = self.files {
//                var folders = [File]()
//                var dataFiles = [File]()
//                for item in files {
//                    if item.size != nil {
//                        dataFiles.append(item)
//                    } else {
//                        folders.append(item)
//                    }
//                }
//                let sortedDataFiles = dataFiles.sorted(by: {
//                    if let size0 = $0.createdAt, let size1 = $1.createdAt {
//                        return size0 > size1
//                    } else {
//                        return $0.name < $1.name
//                    }
//                })
//                let sortedFolders = folders.sorted(by: {$0.name < $1.name })
//                var allSortedFiles = [File]()
//                allSortedFiles.append(contentsOf: sortedDataFiles)
//                allSortedFiles.append(contentsOf: sortedFolders)
//                self.files = allSortedFiles
//                self.tableView.reloadData()
//            }
        case "lastPlayed":
            var folders = [File]()
            var allDataFiles = [File]()
            var unplayedDataFiles = [File]()
            var playedDataFiles = [File]()
            
            for item in files {
                if item.type == FileType.file {
                    allDataFiles.append(item)
                } else {
                    folders.append(item)
                }
            }
            for item in allDataFiles {
                if self.keyStore.object(forKey: item.id) as? [String: Double] != nil {
                    playedDataFiles.append(item)
                } else {
                    unplayedDataFiles.append(item)
                }
            }
            
            let sortedPlayedDataFiles = playedDataFiles.sorted(by: {
                if let savedItem0 = self.keyStore.object(forKey: $0.id) as? [String: Double], let savedItem1 = self.keyStore.object(forKey: $1.id) as? [String: Double] {
                    if let lastPlayedItem0 = savedItem0["lastPlayed"], let lastPlayedItem1 = savedItem1["lastPlayed"] {
                        return lastPlayedItem0 < lastPlayedItem1
                    }
                }
                return $0.name < $1.name
            })
            
            let sortedUnplayedDataFiles = unplayedDataFiles.sorted(by: {$0.name < $1.name})
            let sortedFolders = folders.sorted(by: {$0.name < $1.name })
            var allSortedFiles = [File]()
            allSortedFiles.append(contentsOf: sortedPlayedDataFiles)
            allSortedFiles.append(contentsOf: sortedUnplayedDataFiles)
            allSortedFiles.append(contentsOf: sortedFolders)
            return allSortedFiles
//            if let files = self.files {
//                var folders = [File]()
//                var allDataFiles = [File]()
//                var unplayedDataFiles = [File]()
//                var playedDataFiles = [File]()
//
//                for item in files {
//                    if item.type == FileType.file {
//                        allDataFiles.append(item)
//                    } else {
//                        folders.append(item)
//                    }
//                }
//                for item in allDataFiles {
//                    if self.keyStore.object(forKey: item.id) as? [String: Double] != nil {
//                        playedDataFiles.append(item)
//                    } else {
//                        unplayedDataFiles.append(item)
//                    }
//                }
//
//                let sortedPlayedDataFiles = playedDataFiles.sorted(by: {
//                    if let savedItem0 = self.keyStore.object(forKey: $0.id) as? [String: Double], let savedItem1 = self.keyStore.object(forKey: $1.id) as? [String: Double] {
//                        if let lastPlayedItem0 = savedItem0["lastPlayed"], let lastPlayedItem1 = savedItem1["lastPlayed"] {
//                            return lastPlayedItem0 < lastPlayedItem1
//                        }
//                    }
//                    return $0.name < $1.name
//                })
//
//                let sortedUnplayedDataFiles = unplayedDataFiles.sorted(by: {$0.name < $1.name})
//                let sortedFolders = folders.sorted(by: {$0.name < $1.name })
//                var allSortedFiles = [File]()
//                allSortedFiles.append(contentsOf: sortedPlayedDataFiles)
//                allSortedFiles.append(contentsOf: sortedUnplayedDataFiles)
//                allSortedFiles.append(contentsOf: sortedFolders)
//                self.files = allSortedFiles
//                self.tableView.reloadData()
//            }
        default:
            return files
        }
    }
    
    func deleteData(id: String, fileType: FileType) {
        var urlString: String?
        if fileType == FileType.folder {
            urlString = "https://www.premiumize.me/api/folder/delete?id=\(id)&customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        } else if fileType == FileType.file {
            urlString = "https://www.premiumize.me/api/item/delete?id=\(id)&type=file&customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        }
        
        if let urlString = urlString {
            guard let url = URL(string: urlString) else { return }
            
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error != nil {
                    DispatchQueue.main.async {
                        print(error!.localizedDescription)
                        let alertController = UIAlertController(title: "Error while deletion", message: error!.localizedDescription, preferredStyle: .alert)
                        let OKAction = UIAlertAction(title: "OK", style: .default) { action in}
                        alertController.addAction(OKAction)
                        self.present(alertController, animated: true) {}
                    }
                } else {
                    guard let data = data, let response = response else { return }
                    print(response)
                    do {
                        let result = try JSONDecoder().decode(Response.self, from: data)
                        print(result)
                        
                        //Get back to the main queue
                        DispatchQueue.main.async {
                            if result.status == Status.success {
                                
                                self.loadData()
                            } else {
                                let alertController = UIAlertController(title: "Unknown error while deletion", message: nil, preferredStyle: .alert)
                                let OKAction = UIAlertAction(title: "OK", style: .default) { action in}
                                alertController.addAction(OKAction)
                                self.present(alertController, animated: true) {}
                            }
                        }
                    } catch let jsonError {
                        print(jsonError)
                    }
                    
                    
                }
                }.resume()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        <#code#>
//    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let files = files {
            print("numberOfRowsInSection files count \(files.count)")
            if files.count > 0 {
                self.tableView.separatorStyle = .singleLine;
                self.tableView.backgroundView = nil
                return files.count
            } else {
                let onlyPlayableBool = self.keyStore.bool(forKey: "onlyPlayableBool")
                if onlyPlayableBool {
                    TableViewHelper.EmptyMessage(message: "No playable files available", tableView: self.tableView)
                } else {
                    TableViewHelper.EmptyMessage(message: "Empty folder", tableView: self.tableView)
                }
                
            }
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "identifier", for: indexPath)
        if let files = self.files {
            if files.count > 0 {
                let file = files[indexPath.item]
                
                cell.textLabel?.text = file.name
                
                switch file.type {
                case FileType.folder:
                    cell.accessoryType = .disclosureIndicator
                case FileType.file:
                    cell.accessoryType = .none
                }
                
                if let size = file.size, let createdAt = file.createdAt {
                    let playableFileCell = tableView.dequeueReusableCell(withIdentifier: "playableFileCell", for: indexPath) as! PlayableFileTableViewCell
                    let bcf = ByteCountFormatter()
                    bcf.countStyle = .file
                    let sizeString = bcf.string(fromByteCount: (size))
                    
                    let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: createdAt), dateStyle: .short, timeStyle: .short)
                    
                    playableFileCell.nameLabel.text = file.name
                    playableFileCell.detailsLabel.text = "\(dateString) - \(sizeString)"
                    
                    if file.streamLink != nil {
                        playableFileCell.progressView.isHidden = false
                        if let savedItem = keyStore.object(forKey: file.id) as? [String: Double] {
                            if let playedSeconds = savedItem["playedSeconds"], let duration = savedItem["durationInSeconds"] {
                                let progressInPercent = playedSeconds/duration
                                playableFileCell.progressView.progress = progressInPercent
                                if progressInPercent >= 0.95 {
                                    playableFileCell.nameLabel.textColor = .red
                                }
                            }
                        } else {
                            playableFileCell.progressView.progress = 0
                        }
                    } else {
                        playableFileCell.progressView.isHidden = true
                    }
                    return playableFileCell
                } else {
                    cell.detailTextLabel?.text = nil
                    cell.accessoryView = nil
                    return cell
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let file = files?[indexPath.item] {
            if file.type == FileType.file {
                if let url = file.streamLink {
                    Player.playFileWithUrl(url: url, id: file.id, viewController: self)

                }
            } else if file.type == FileType.folder {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "MainViewController") as! CloudViewController
                vc.folderId = file.id
                vc.folderName = file.name
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    //    func tableView(_ tableView: UITableView,
    //                   leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    //    {
    //        let closeAction = UIContextualAction(style: .normal, title:  "Close", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
    //            print("OK, marked as Closed")
    //            success(true)
    //        })
    //        closeAction.image = UIImage(named: "bin")
    //        closeAction.backgroundColor = .red
    //
    //        return UISwipeActionsConfiguration(actions: [closeAction])
    //
    //    }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        let deleteAction = UIContextualAction(style: .destructive, title:  "Update", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            
            print("Delete action ...")
            if let item = self.files?[indexPath.item] {
//                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.deleteData(id: item.id, fileType: item.type)
            }
            success(true)
        })
        deleteAction.image = UIImage(named: "bin")
        deleteAction.backgroundColor = .red
        
        let closeAction = UIContextualAction(style: .normal, title:  "Close", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            
            
            print("OK, marked as Closed")
            //            success(true)
        })
        closeAction.image = UIImage(named: "download")
        closeAction.backgroundColor = .blue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, closeAction])
    }

    
    @objc func sortButtonPressed(sender : AnyObject) {
        let alertController = UIAlertController(title: "Sort by", message: nil, preferredStyle: .actionSheet)
        
        var sortByOriginalTitle = "Original"
        var sortByNameTitle = "Name"
        var sortBySizeTitle = "Size"
        var sortByCreatedByTitle = "Created at"
        var sortByLastPlayedTitle = "Last played"
        

        if let sortKey = keyStore.string(forKey: "sortKey") {
            print(sortKey)
            switch sortKey {
            case "original":
                sortByOriginalTitle = "✓ Original"
            case "name":
                sortByNameTitle = "✓ Name"
            case "size":
                sortBySizeTitle = "✓ Size"
            case "createdAt":
                sortByCreatedByTitle = "✓ Created at"
            case "lastPlayed":
                sortByLastPlayedTitle = "✓ Last played"
            default:
                break
            }

        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
            
        }
        alertController.addAction(cancelAction)
        
        let sortByOriginalAction = UIAlertAction(title: sortByOriginalTitle, style: .default, handler: {action in
//            self.sortData(key: "original")
            if let files = self.files {
                self.files = self.sortData(files: files, key: "original")
                self.tableView.reloadData()
            }
        })
        alertController.addAction(sortByOriginalAction)
        
        let sortByNameAction = UIAlertAction(title: sortByNameTitle, style: .default) { action in
//            self.sortData(key: "name")
            if let files = self.files {
                self.files = self.sortData(files: files, key: "name")
                self.tableView.reloadData()
            }
        }
        alertController.addAction(sortByNameAction)
        
        let sortBySizeAction = UIAlertAction(title: sortBySizeTitle, style: .default) { action in
//            self.sortData(key: "size")
            if let files = self.files {
                self.files = self.sortData(files: files, key: "size")
                self.tableView.reloadData()
            }
        }
        alertController.addAction(sortBySizeAction)
        
        let sortByCreatedAt = UIAlertAction(title: sortByCreatedByTitle, style: .default, handler: {action in
//            self.sortData(key: "createdAt")
            if let files = self.files {
                self.files = self.sortData(files: files, key: "createdAt")
                self.tableView.reloadData()
            }
        })
        alertController.addAction(sortByCreatedAt)
        
        let sortByLastPlayed = UIAlertAction(title: sortByLastPlayedTitle, style: .default, handler: {action in
//            self.sortData(key: "lastPlayed")
            if let files = self.files {
                self.files = self.sortData(files: files, key: "lastPlayed")
                self.tableView.reloadData()
            }
        })
        alertController.addAction(sortByLastPlayed)
        
        let onlyPlayableBool = self.keyStore.bool(forKey: "onlyPlayableBool")
        let onlyPlayableBoolString = onlyPlayableBool ? "✓ Only playable" : "Only playable"
        let showOnlyPlayable = UIAlertAction(title: onlyPlayableBoolString, style: .default, handler: {action in
            if let unsortedFiles = self.unsortedFiles {
                if !onlyPlayableBool {
                    self.files = unsortedFiles.filter {
                        $0.type == FileType.folder || $0.streamLink != nil
                    }
                    self.keyStore.set(true, forKey: "onlyPlayableBool")
                } else {
                    self.files = self.unsortedFiles
                    self.keyStore.set(false, forKey: "onlyPlayableBool")
                }
                self.keyStore.synchronize()
                self.tableView.reloadData()
            }
        })
        alertController.addAction(showOnlyPlayable)
        
        self.present(alertController, animated: true) {
            
        }
    }
    
    @objc func handleRefresh() {
        loadData()
    }
    
    @objc func accessoryButtonTapped(sender : AnyObject){
        print(sender.tag)
        print("Tapped")
        
        if let file = files?[sender.tag] {
            let text = file.name
            let textToShare = [ text ]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: [CustomActivityOne()])
            activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
            
            // exclude some activity types from the list (optional)
            activityViewController.excludedActivityTypes = [ UIActivityType.airDrop, UIActivityType.postToFacebook ]
            
            activityViewController.completionWithItemsHandler = {
                (type, success, items, error) -> Void in
                if success{
                    if let type = type {
                        print("item shared of type \(type)")
                    }
                }
            }
            
            // present the view controller
            self.present(activityViewController, animated: true, completion: nil)
        }
    }
    
}

