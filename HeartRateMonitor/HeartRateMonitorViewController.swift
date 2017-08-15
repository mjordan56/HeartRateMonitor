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

    @IBOutlet weak var heartImage: UIImageView!
    @IBOutlet weak var deviceInfo: UITextView!
    
    // Properties to handle storing the BPM and heart beat
    var heartRateBPM: UILabel!
//    var pulseTimer: Timer
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.heartImage.image = UIImage(named: "HeartImage")
        
        // Create your Heart Rate BPM Label
        self.heartRateBPM = UILabel(frame: CGRect(x: 55, y: 30, width: 75, height: 50))
        self.heartRateBPM.textColor = UIColor.black
        self.heartRateBPM.text = "0 bmp"
//        self.heartRateBPM.font
//        [self.heartRateBPM setText:[NSString stringWithFormat:@"%i", 0]];
//        [self.heartRateBPM setFont:[UIFont fontWithName:@"Futura-CondensedMedium" size:28]];
        self.heartImage.addSubview(self.heartRateBPM)
        
        NotificationCenter.default.addObserver(self, selector: #selector(HeartRateMonitorViewController.updateHeartRateMeasurement), name: NSNotification.Name(HeartRateMeasurementDidUpdate), object: heartRateMonitor)

        
        heartRateMonitor = HeartRateMonitor()
        heartRateMonitor.scanForDevices()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func updateHeartRateMeasurement(notification: NSNotification) {
        if let info = notification.userInfo as? Dictionary<String, Any> {
            if let heartRate = info["heartRate"] {
                self.heartRateBPM.text = "\(heartRate) bpm"
            }
            if let sensorDetected = info["sensorDetected"] as? Bool {
                self.deviceInfo.text = "Sensor Detected: " + (sensorDetected ? "Yes" : "No")
            }
            
            self.deviceInfo.text = self.deviceInfo.text + "\nManufacturer: \(self.heartRateMonitor.manufacturerName)"
        }
    }
}
