//
//  DownloadManager.swift
//  Premiumize
//
//  Created by Tim Haug on 11.02.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import Foundation

class DownloadManager : NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    
    static var shared = DownloadManager()
    
    typealias ProgressHandler = (Float) -> ()
    
    var onProgress : ProgressHandler? {
        didSet {
            if onProgress != nil {
                let _ = activate()
            }
        }
    }
    
    override private init() {
        super.init()
    }
    
    func activate() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
        
        // Warning: If an URLSession still exists from a previous download, it doesn't create a new URLSession object but returns the existing one with the old delegate object attached!
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    private func calculateProgress(session : URLSession, completionHandler : @escaping (Float) -> ()) {
        session.getTasksWithCompletionHandler { (tasks, uploads, downloads) in
            let bytesReceived = downloads.map{ $0.countOfBytesReceived }.reduce(0, +)
            let bytesExpectedToReceive = downloads.map{ $0.countOfBytesExpectedToReceive }.reduce(0, +)
            let progress = bytesExpectedToReceive > 0 ? Float(bytesReceived) / Float(bytesExpectedToReceive) : 0.0
            completionHandler(progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if totalBytesExpectedToWrite > 0 {
            if let onProgress = onProgress {
                calculateProgress(session: session, completionHandler: onProgress)
            }
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            debugPrint("Progress \(downloadTask) \(progress)")
            
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        debugPrint("Download finished: \(location)")
//        try? FileManager.default.removeItem(at: location)
        let filemgr = FileManager.default
        
        let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
        
        let docsURL = dirPaths[0]
        
        let newDir = docsURL.appendingPathComponent("/dataT")
        
        do {
            try filemgr.createDirectory(atPath: newDir.path,
                                        withIntermediateDirectories: true, attributes: nil)
            do {
                try filemgr.moveItem(at: location, to: newDir)
                // show file
            }   catch{
                print("An error occurred while moving file to destination url")
            }
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
        }
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task completed: \(task), error: \(error)")
    }
    
}


