//
//  ViewController.swift
//  HeartRateMonitor
//
//  Created by Michael Jordan on 7/26/15.
//  Copyright (c) 2015 MichaelJordan. All rights reserved.
//

import UIKit

class HeartRateMonitorViewController: UIViewController {
    
    var heartRateMonitor: HeartRateMonitor!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        heartRateMonitor = HeartRateMonitor()
        heartRateMonitor.scanForDevices()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
