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
    
    var unsortedFiles = [File]()
    var files = [File]()
    var dataLoadisCompleted = false
    var folderId: String?
    var folderName: String?
//    let keyStore = UserDefaults.standard
    let keyStore = NSUbiquitousKeyValueStore.default
    var sortKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let image = UIImage(named: "sort")?.withRenderingMode(.alwaysOriginal)
        let sortButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(sortButtonPressed))
        
        navigationItem.rightBarButtonItems = [sortButton]
        
        self.tableView.refreshControl = refreshControl
            
        if let items = tabBarController?.tabBar.items {
            items[0].title = "Cloud"
            items[1].title = "Downloader"
            items[2].title = "Offline"
            items[3].title = "Profile"
        }
        
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
        
        sortFilterAndSplitFiles()
        
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
                        
                        
                        //Get back to the main queue
                        DispatchQueue.main.async {
                            self.files = result.fileList
                            self.unsortedFiles = result.fileList
                            self.dataLoadisCompleted = true
                            self.sortFilterAndSplitFiles()

                            self.refreshControl.endRefreshing()
                        }
                        //
                    } catch let jsonError {
                        print(jsonError)
                    }
                }
                }.resume()
        }
    }
    
    func sortFilterAndSplitFiles() {
        
        files = self.sortData(files: files)
        
        if self.keyStore.bool(forKey: "onlyPlayableBool") {
            files = files.filter {
                $0.type == FileType.folder || $0.streamLink != nil
            }
        }
        
        print("onlyPlayable: \(files.count)")
    
        var playedFiles = [File]()
        var unplayedFiles = [File]()
        for item in files {
            if item.streamLink != nil {
                if let savedItem = keyStore.object(forKey: item.id) as? [String: Double] {
                    if let playedSeconds = savedItem["playedSeconds"], let duration = savedItem["durationInSeconds"] {
                        let progressInPercent = playedSeconds/duration
                        print(progressInPercent)
                        if progressInPercent >= 0.9 {
                            print(item)
                            playedFiles.append(item)
                            continue
                        }
                    }
                }
            }
            unplayedFiles.append(item)
        }

        files = unplayedFiles + playedFiles
        
        print("playedFiles: \(playedFiles.count)")
        print("unplayedFiles: \(unplayedFiles.count)")
        
        tableView.reloadData()
        
    }
    
    
    func sortData(files: [File]) -> [File] {
        if let key = self.keyStore.string(forKey: "sortKey") {
            switch key {
            case "original":
                return self.unsortedFiles
            case "name":
                return files.sorted(by: { $0.name < $1.name })
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
            default:
                return files
            }
        }
        return files
        
        
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.tableView.separatorStyle = .singleLine;
        self.tableView.backgroundView = nil
        
        if dataLoadisCompleted {
            if files.count > 0 {
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
                playableFileCell.nameLabel.textColor = .black
                playableFileCell.detailsLabel.textColor = .black
                playableFileCell.progressView.trackFillColor = .blue
                
                if file.streamLink != nil {
                    playableFileCell.progressView.isHidden = false
                    if let savedItem = keyStore.object(forKey: file.id) as? [String: Double] {
                        if let playedSeconds = savedItem["playedSeconds"], let duration = savedItem["durationInSeconds"] {
                            let progressInPercent = playedSeconds/duration
                            playableFileCell.progressView.progress = progressInPercent
                            if progressInPercent >= 0.9 {
                                playableFileCell.nameLabel.textColor = .lightGray
                                playableFileCell.detailsLabel.textColor = .lightGray
                                playableFileCell.progressView.trackFillColor = .lightGray
                                playableFileCell.progressView.progress = 1
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let file = files[indexPath.item]
        if file.type == FileType.file {
            if let url = file.streamLink {
                let vc = FilePlayerViewController()
                vc.id = file.id
                vc.url = url
                vc.calledViewController = self
                self.present(vc, animated: true) {
                    vc.player!.play()
                }
            }
        } else if file.type == FileType.folder {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "MainViewController") as! CloudViewController
            vc.folderId = file.id
            vc.folderName = file.name
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
        func tableView(_ tableView: UITableView,
                       leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
        {
            var titleForAction = "Mark played"
            var isPlayed = false
            if let savedItem = keyStore.object(forKey: files[indexPath.item].id) as? [String: Double] {
                if let playedSeconds = savedItem["playedSeconds"], let duration = savedItem["durationInSeconds"] {
                    let progressInPercent = playedSeconds/duration
                    if progressInPercent >= 0.9 {
                        titleForAction = "Mark unplayed"
                        isPlayed = true
                    }
                }
            }
            let playedUnplayedAction = UIContextualAction(style: .normal, title:  titleForAction, handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
                if isPlayed {
                    self.keyStore.set(["playedSeconds": 0, "durationInSeconds": 100, "lastPlayed": Double(Date().timeIntervalSince1970)], forKey: self.files[indexPath.item].id)
                } else {
                    self.keyStore.set(["playedSeconds": 1, "durationInSeconds": 1, "lastPlayed": Double(Date().timeIntervalSince1970)], forKey: self.files[indexPath.item].id)
                }
                self.keyStore.synchronize()
                self.sortFilterAndSplitFiles()
                success(true)
            })
            playedUnplayedAction.backgroundColor = .blue
    
            return UISwipeActionsConfiguration(actions: [playedUnplayedAction])
    
        }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        let deleteAction = UIContextualAction(style: .destructive, title:  "Update", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            
            print("Delete action ...")
            let item = self.files[indexPath.item]
            self.deleteData(id: item.id, fileType: item.type)
            
            success(true)
        })
        deleteAction.image = UIImage(named: "bin")
        deleteAction.backgroundColor = .red
        
        let downloadAction = UIContextualAction(style: .normal, title:  "Download", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            if let fileStreamUrl = self.files[indexPath.item].streamLink {
                
                let task = DownloadManager.shared.activate().downloadTask(with: fileStreamUrl)
                task.resume()
            } else if let fileUrl = self.files[indexPath.item].link {
                let task = DownloadManager.shared.activate().downloadTask(with: fileUrl)
                task.resume()
            }
            
            
            print("OK, marked as Closed")
            //            success(true)
        })
        downloadAction.image = UIImage(named: "download")
        downloadAction.backgroundColor = .blue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, downloadAction])
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
//            self.files = self.sortData(files: self.files, key: "original")
//            self.tableView.reloadData()
            self.keyStore.set("original", forKey: "sortKey")
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
        })
        alertController.addAction(sortByOriginalAction)
        
        let sortByNameAction = UIAlertAction(title: sortByNameTitle, style: .default) { action in
//            self.files = self.sortData(files: self.files, key: "name")
//            self.tableView.reloadData()
            self.keyStore.set("name", forKey: "sortKey")
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
        }
        alertController.addAction(sortByNameAction)
        
        let sortBySizeAction = UIAlertAction(title: sortBySizeTitle, style: .default) { action in
//            self.files = self.sortData(files: self.files, key: "size")
//            self.tableView.reloadData()
            self.keyStore.set("size", forKey: "sortKey")
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
        }
        alertController.addAction(sortBySizeAction)
        
        let sortByCreatedAt = UIAlertAction(title: sortByCreatedByTitle, style: .default, handler: {action in
//            self.files = self.sortData(files: self.files, key: "createdAt")
//            self.tableView.reloadData()
            self.keyStore.set("createdAt", forKey: "sortKey")
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
        })
        alertController.addAction(sortByCreatedAt)
        
        let sortByLastPlayed = UIAlertAction(title: sortByLastPlayedTitle, style: .default, handler: {action in
//            self.files = self.sortData(files: self.files, key: "lastPlayed")
//            self.tableView.reloadData()
            self.keyStore.set("lastPlayed", forKey: "sortKey")
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
        })
        alertController.addAction(sortByLastPlayed)
        
        let onlyPlayableBool = self.keyStore.bool(forKey: "onlyPlayableBool")
        let onlyPlayableBoolString = onlyPlayableBool ? "✓ Only playable" : "Only playable"
        let showOnlyPlayable = UIAlertAction(title: onlyPlayableBoolString, style: .default, handler: {action in
            
            if !onlyPlayableBool {
                self.keyStore.set(true, forKey: "onlyPlayableBool")
            } else {
                self.keyStore.set(false, forKey: "onlyPlayableBool")
            }
            self.keyStore.synchronize()
            self.sortFilterAndSplitFiles()
            
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
        
        let file = files[sender.tag]
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

