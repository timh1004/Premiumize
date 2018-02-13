//
//  OfflineViewController.swift
//  Premiumize
//
//  Created by Tim Haug on 11.02.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import UIKit

class OfflineViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }

    override func viewDidAppear(_ animated: Bool) {
        let filemgr = FileManager.default
        
        let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
        
        let docsURL = dirPaths[0]
        
        let newDir = docsURL.appendingPathComponent("dataT").path
        
        
        
        do {
            let filelist = try filemgr.contentsOfDirectory(atPath: newDir)
            
            for filename in filelist {
                print(filename)
            }
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
