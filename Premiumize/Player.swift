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

class Player  {
    class func playFileWithUrl(url: URL, id: String, viewController: UIViewController) {
        let keyStore = NSUbiquitousKeyValueStore()
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        
        playerViewController.player = player
        viewController.present(playerViewController, animated: true)
        
        // check if there is an exisitng entry for the file to be played
        // if an entry is found, try to set the start time to the saved time
        if let savedItem = keyStore.object(forKey: id) as? [String: Double] {
            if let playedSeconds = savedItem["playedSeconds"] {
                playerViewController.player!.seek(to: CMTime(seconds: playedSeconds - 5, preferredTimescale: 1), toleranceBefore: CMTime(seconds: 0.2, preferredTimescale: 1), toleranceAfter: CMTime(seconds: 0.2, preferredTimescale: 1))
            }
        }
        
        playerViewController.player!.play()
        
        // check every second for the current play time and save it together with the total duration of the file
        playerViewController.player!.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, 1), queue: DispatchQueue.main) { (CMTime) -> Void in
            if let currentItem = playerViewController.player!.currentItem {
                if currentItem.status == .readyToPlay {
                    let time : Double = CMTimeGetSeconds(currentItem.currentTime());
                    let duration = CMTimeGetSeconds(currentItem.duration)
                    let currentTimeStamp = Double(Date().timeIntervalSince1970)
                    
                    keyStore.set(["playedSeconds": time, "durationInSeconds": duration, "lastPlayed": currentTimeStamp], forKey: id)
                    keyStore.synchronize()
                }
            }
        }
    }

}


