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

class CloudViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AVPlayerViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        if let items = tabBarController?.tabBar.items {
            items[0].title = "Cloud"
            items[1].title = "Downloader"
        }
        
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sortFilterAndSplitFiles()
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
                        TableViewHelper.EmptyMessage(message: error!.localizedDescription, tableView: self.tableView)
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
                        }

                    } catch let jsonError {
                        print(jsonError)
                    }
                }
                }.resume()
        }
    }
    
    func sortFilterAndSplitFiles() {
        
        // only playable files on tvOS
        files = files.filter {
            $0.type == FileType.folder || $0.streamLink != nil
        }
    
        var playedFiles = [File]()
        var unplayedFiles = [File]()
        for item in files {
            if item.streamLink != nil {
                if let savedItem = keyStore.object(forKey: item.id) as? [String: Double] {
                    print(savedItem)
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
        
        activityIndicator.stopAnimating()
        tableView.reloadData()
        
    }
    
    
    func sortData(files: [File]) -> [File] {
        return files.sorted(by: { $0.name < $1.name })
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dataLoadisCompleted {
            if files.count > 0 {
                return files.count
            } else {
                TableViewHelper.EmptyMessage(message: "No playable files available", tableView: self.tableView)
            }
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "identifier", for: indexPath)
        if files.count > 0 {
            let file = files[indexPath.item]
            
            cell.textLabel?.textColor = .black
            cell.detailTextLabel?.textColor = .black
            
            cell.textLabel?.text = file.name
            
            switch file.type {
            case FileType.folder:
                cell.accessoryType = .disclosureIndicator
            case FileType.file:
                cell.accessoryType = .none
            }
            
            if file.createdAt != nil {
                
                cell.textLabel?.text = file.name
                cell.detailTextLabel?.text = "0%"
                
                if let savedItem = keyStore.object(forKey: file.id) as? [String: Double] {
                    if let playedSeconds = savedItem["playedSeconds"], let duration = savedItem["durationInSeconds"] {
                        let progressInPercent = playedSeconds/duration
                        cell.detailTextLabel?.text = String(format: "%.0f%%", progressInPercent * 100)
                        if progressInPercent >= 0.9 {
                            cell.textLabel?.textColor = .lightGray
                            cell.detailTextLabel?.textColor = .lightGray
                            cell.detailTextLabel?.text = "played"
                        }
                    }
                }
                
                return cell
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
            if let vc = storyboard.instantiateViewController(withIdentifier: "CloudViewController") as? CloudViewController {
                vc.folderId = file.id
                vc.folderName = file.name
                self.show(vc, sender: nil)
//                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    
    
}

