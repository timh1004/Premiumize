//
//  DownloaderViewController.swift
//  Premiumize
//
//  Created by Tim Haug on 03.02.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import UIKit

class DownloaderViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var tableView: UITableView!
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(DownloaderViewController.handleRefresh),
                                 for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    
    var transferResult: TransferResult?
    var transfers: [Transfer]?
    var runningTransfers = [Transfer]()
    var finishedTransfers = [Transfer]()
    
    var files: [File]?
    var folderId: String?
    var folderName: String?
//    let defaults = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let addDownloadButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDownloadButtonHandler))
        navigationItem.rightBarButtonItems = [addDownloadButton]
        
        self.tableView.refreshControl = refreshControl
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        self.tabBarItem.title = "Downloader"
        loadData()
        
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(loadDataTimer), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.indexPathsForSelectedRows?.forEach {
            tableView.deselectRow(at: $0, animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        let urlTransfers = "https://www.premiumize.me/api/transfer/list?customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        let urlString = "https://www.premiumize.me/api/folder/list?customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        self.title = "Downloader"
        
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
                    
                    if result.status == Status.success {
                        self.files = result.fileList
                    }
                    
                    if urlTransfers != "" {
                        guard let transfersUrl = URL(string: urlTransfers) else { return }

                        URLSession.shared.dataTask(with: transfersUrl) {
                            (data, response, error) in
                            if error != nil {
                                print(error!.localizedDescription)
                            } else {
                                guard let data = data else { return }
                                
                                do {
                                    //Decode retrived data with JSONDecoder and assing type of Article object
//                                    let oldTransferResult = self.transferResult
                                    let result = try JSONDecoder().decode(TransferResult.self, from: data)
                                    
//                                    var not
//                                    if let transferResult = self.transferResult, let oldTransferResult = oldTransferResult {
//
//                                    }
                                    
                                    self.finishedTransfers = []
                                    self.runningTransfers = []
                                    
                                    if result.status == Status.success {
                                        for transfer in result.transferList {
                                            
                                            if transfer.status == TransferStatus.finished {
                                                self.finishedTransfers.append(transfer)
                                            } else {
                                                self.runningTransfers.append(transfer)
                                            }
                                        }
                                    }
                                    //Get back to the main queue
                                    DispatchQueue.main.async {
                                        
                                        self.tableView?.reloadData()
                                        self.refreshControl.endRefreshing()
                                    }
                                } catch let jsonError {
                                    print(jsonError)
                                }
                            }
                            }.resume()
                    } else {
                        //Get back to the main queue
                        DispatchQueue.main.async {
                            
                            self.tableView?.reloadData()
                            self.refreshControl.endRefreshing()
                        }
                    }
                    
                    
                    //
                } catch let jsonError {
                    print(jsonError)
                }
            }
            }.resume()
        
        // necessary to allow audio playback when silent mode is turned on
        do {
            //            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            //            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func addDownload(url: String) {
                
        let urlString = "https://www.premiumize.me/api/transfer/create?src=\(url)&customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    let alertController = UIAlertController(title: "Error", message: error!.localizedDescription, preferredStyle: .alert)
                    let OKAction = UIAlertAction(title: "OK", style: .default) { action in}
                    alertController.addAction(OKAction)
                    self.present(alertController, animated: true) {}
                }
            } else {
                guard let data = data else { return }
                
                do {
                    //Decode retrived data with JSONDecoder and assing type of Article object
                    let result = try JSONDecoder().decode(CreateResult.self, from: data)
                    //Get back to the main queue
                    DispatchQueue.main.async {
                        if result.status == Status.error, let message = result.message {
                            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                            let cancelAction = UIAlertAction(title: "OK", style: .cancel) { action in
                                
                            }
                            alertController.addAction(cancelAction)
                            self.present(alertController, animated: true) {}
                        } else {
                            self.loadData()
                        }
                    }
                    //
                } catch let jsonError {
                    print(jsonError)
                }
            }
            }.resume()
    }
    
    func deleteTransfer(id: String) {
        let urlString = "https://www.premiumize.me/api/transfer/delete?id=\(id)&customer_id=\(LoginCredentials.customerId)&pin=\(LoginCredentials.pin)"
        
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    let alertController = UIAlertController(title: "Error", message: error!.localizedDescription, preferredStyle: .alert)
                    let OKAction = UIAlertAction(title: "OK", style: .default) { action in}
                    alertController.addAction(OKAction)
                    self.present(alertController, animated: true) {}
                }
            } else {
                guard let data = data else { return }
                
                do {
                    //Decode retrived data with JSONDecoder and assing type of Article object
                    let result = try JSONDecoder().decode(Response.self, from: data)
                    
                    //Get back to the main queue
                    DispatchQueue.main.async {
                        if result.status == Status.error, let message = result.message {
                            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                            let cancelAction = UIAlertAction(title: "OK", style: .cancel) { action in
                                
                            }
                            alertController.addAction(cancelAction)
                            self.present(alertController, animated: true) {}
                        } else {
                            self.loadData()
                        }
                    }
                    //
                } catch let jsonError {
                    print(jsonError)
                }
            }
            }.resume()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Running"
        default:
            return "Finished"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return runningTransfers.count
        default:
            return finishedTransfers.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "identifier", for: indexPath)
        switch indexPath.section {
        case 0:
            let transfer = runningTransfers[indexPath.item]
            cell.textLabel?.text = transfer.name
            cell.detailTextLabel?.text = transfer.message
        default:
            let transfer = finishedTransfers[indexPath.item]
            if transfer.folderId != nil {
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryType = .none
            }
            cell.textLabel?.text = transfer.name
            cell.detailTextLabel?.text = transfer.status.rawValue
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let _ = runningTransfers[indexPath.item]
            
        default:
            let transfer = finishedTransfers[indexPath.item]
            if let folderId = transfer.folderId {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "MainViewController") as! CloudViewController
                vc.folderId = folderId
                vc.folderName = transfer.name
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                if let files = self.files {
                    for file in files {
                        if file.id == transfer.fileId, let streamLink = file.streamLink {
                            Player.playFileWithUrl(url: streamLink, id: file.id, viewController: self)
                        }
                    }
                }
                
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        var transfer: Transfer
        var clearActionTitle: String
        switch indexPath.section {
        case 0:
            transfer = runningTransfers[indexPath.item]
            clearActionTitle = "Stop & Clear"
        default:
            transfer = finishedTransfers[indexPath.item]
            clearActionTitle = "Delete"
        }
        let clearAction = UIContextualAction(style: .destructive, title:  clearActionTitle, handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            self.deleteTransfer(id: transfer.id)
            success(true)
        })
        clearAction.backgroundColor = .red

        
        return UISwipeActionsConfiguration(actions: [clearAction])
    }
    
    @objc func handleRefresh() {
        loadData()
    }
    
    @objc func addDownloadButtonHandler() {
        let enterUrlAlertController = UIAlertController(title: "New Download", message: "Enter links, magnet links, filehost links, NZBs, Torrents, ...", preferredStyle: .alert)

        enterUrlAlertController.addTextField{(textfield) in
            textfield.placeholder = "Enter URL"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in

        }

        let enterUrlAction = UIAlertAction(title: "Add", style: .default) { _ in
            if let urlString = enterUrlAlertController.textFields![0].text {
                self.addDownload(url: urlString)
            }
        }
        enterUrlAlertController.addAction(cancelAction)
        enterUrlAlertController.addAction(enterUrlAction)
        
        if UIPasteboard.general.hasURLs {
            if let url = UIPasteboard.general.url {
                let alertController = UIAlertController(title: "URL found", message: "Would you like to download the URL found in the clipboard?", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "No", style: .cancel) { action in
                    self.present(enterUrlAlertController, animated: true) {}
                }
                let addUrl = UIAlertAction(title: "Yes", style: .default) { _ in
                    self.addDownload(url: url.absoluteString)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(addUrl)
                self.present(alertController, animated: true) {}
            }
        } else {
            self.present(enterUrlAlertController, animated: true) {}
        }
    }
    
    @objc func loadDataTimer() {
        if self.tableView.isEditing == false && runningTransfers.count > 0 {
            print("loading data")
            loadData()
        }
    }
    
}
