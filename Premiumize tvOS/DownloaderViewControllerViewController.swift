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
        
        self.tabBarItem.title = "Downloader"
        loadData()
        
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(loadDataTimer), userInfo: nil, repeats: true)
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
                let vc = storyboard.instantiateViewController(withIdentifier: "CloudViewController") as! CloudViewController
                vc.folderId = folderId
                vc.folderName = transfer.name
                self.show(vc, sender: nil)
            } else {
                if let files = self.files {
                    for file in files {
                        if file.id == transfer.fileId, let streamLink = file.streamLink {
                            let vc = FilePlayerViewController()
                            vc.id = file.id
                            vc.url = streamLink
                            vc.calledViewController = self
                            self.present(vc, animated: true) {
                                vc.player!.play()
                            }
                        }
                    }
                }
                
            }
            
        }
    }
    
    
    @objc func loadDataTimer() {
        if self.tableView.isEditing == false && runningTransfers.count > 0 {
            print("loading data")
            loadData()
        }
    }
    
}
