//
//  Player.swift
//  Premiumize
//
//  Created by Tim Haug on 03.02.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import Foundation
import MediaPlayer
import AVKit

class FilePlayerViewController: AVPlayerViewController, AVPlayerViewControllerDelegate  {
    
    var url: URL!
    var id: String!
    var calledViewController: UIViewController!
    
    override func viewDidAppear(_ animated: Bool) {
        self.delegate = self
        
        let keyStore = NSUbiquitousKeyValueStore.default
        
        self.player = AVPlayer(url: url)
        
        // check if there is an exisitng entry for the file to be played
        // if an entry is found, try to set the start time to the saved time
        if let savedItem = keyStore.object(forKey: id) as? [String: Double] {
            if let playedSeconds = savedItem["playedSeconds"] {
                self.player!.seek(to: CMTime(seconds: playedSeconds - 5, preferredTimescale: 1), toleranceBefore: CMTime(seconds: 0.2, preferredTimescale: 1), toleranceAfter: CMTime(seconds: 0.2, preferredTimescale: 1))
            }
        }
        
        // necessary to allow audio playback when silent mode is turned on
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            print(error.localizedDescription)
        }
        
        // check every second for the current play time and save it together with the total duration of the file
        self.player!.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, 1), queue: DispatchQueue.main) { (CMTime) -> Void in
            if let currentItem = self.player!.currentItem {
                if currentItem.status == .readyToPlay {
                    let time : Double = CMTimeGetSeconds(currentItem.currentTime());
                    let duration = CMTimeGetSeconds(currentItem.duration)
                    let currentTimeStamp = Double(Date().timeIntervalSince1970)
                    
                    keyStore.set(["playedSeconds": time, "durationInSeconds": duration, "lastPlayed": currentTimeStamp], forKey: self.id)
                    keyStore.synchronize()
                    if let object = keyStore.object(forKey: self.id) as? [String: Double] {
                        print(object["playedSeconds"] ?? "error")
                    }
                }
            }
        }
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("hey")
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {

        calledViewController.present(playerViewController, animated: true) {
            completionHandler(true)
        }
    }

}


