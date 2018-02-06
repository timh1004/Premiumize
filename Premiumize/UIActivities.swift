//
//  UIActivities.swift
//  Premiumize
//
//  Created by Tim Haug on 31.01.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import Foundation
import UIKit

class CustomActivityOne: UIActivity {
    
    override var activityTitle: String? {
        return "MyActivity"
    }
    
    //thumbnail image for the activity
    override var activityImage: UIImage?{
        return UIImage(named: "more")
    }
    
    //activiyt type
    override var activityType: UIActivityType{
        return UIActivityType.copyToPasteboard
    }
    
    //view controller for the activity
    override var activityViewController: UIViewController?{
        
        print("user did tap on my activity")
        return nil
    }
    
    //here check whether this activity can perfor with given list of items
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }
    
    //prepare the data to perform with
    override func prepare(withActivityItems activityItems: [Any]) {
        
    }
    
    
    //    override func performActivity() {
    //        UIApplication.sharedApplication().openURL(NSURL(string: "https://www.google.com")!)
    //    }
}
