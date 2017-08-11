//
//  HeartRateMonitor.swift
//  HeartRateMonitor
//
//  Created by Michael Jordan on 7/26/15.
//  Copyright (c) 2015 MichaelJordan. All rights reserved.
//

import Foundation
import CoreBluetooth

class HeartRateMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Bluetooth GATT Services
    
    // Bluetooth GATT specifications - Services
    // https://developer.bluetooth.org/gatt/services/Pages/ServicesHome.aspx
    //
    fileprivate enum BlueToothGATTServices: UInt16 {
        case batteryService    = 0x180F
        case deviceInformation = 0x180A
        case heartRate         = 0x180D
        
        var UUID: CBUUID {
            return CBUUID(string: String(self.rawValue, radix: 16, uppercase: true))
        }
    }
    
    // MARK: - Bluetooth GATT Characteristics
    
    // Bluetooth GATT specifications - Characteristics
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicsHome.aspx
    //
    fileprivate enum BlueToothGATTCharacteristics: UInt16 {
        case batteryLevel           = 0x2A19
        case bodySensorLocation     = 0x2A38
        case heartRateMeasurement   = 0x2A37
        case manufacturerNameString = 0x2A29
        
        func isEqual(_ characteristic: AnyObject) -> Bool {
            if let characteristic = characteristic as? CBCharacteristic {
                return self.UUID.isEqual(characteristic.uuid)
            }
            return false
        }
        
        var UUID: CBUUID {
            return CBUUID(string: String(self.rawValue, radix: 16, uppercase: true))
        }
    }

    // MARK: - Bluetooth Heart Rate Measurement Flags
    
    // Heart Rate Measurement flags as defined on the Bluetooth developer portal.
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.heart_rate_measurement.xml
    //
    fileprivate enum HeartRateMeasurement: UInt8 {
        case heartRateValueFormatUInt8  = 0b00000000
        case heartRateValueFormatUInt16 = 0b00000001
        case sensorContactIsSupported   = 0b00000100
        case sensorContactDetected      = 0b00000110
        case energyExpended             = 0b00001000
        case rrInterval                 = 0b00010000
        
        func flagIsSet(_ flagData: UInt8) -> Bool {
            return (flagData & self.rawValue) != 0
        }
    }
    
    // MARK: - Properties
    
    var centralManager: CBCentralManager? = nil
    var heartRateSensorPeripheral: CBPeripheral? = nil
    
    var connected: String? = nil
    var polarH7DeviceData: String? = nil
    
    fileprivate(set) var heartRate = 0
    fileprivate(set) var sensorDetected = false
    fileprivate(set) var energyExpended:Int?
    fileprivate(set) var rrIntervals = [Float]()
    
    fileprivate(set) var manufacturerName: String?
    
    // MARK: - Methods
    
    func scanForDevices()
    {
        // Scan for all available CoreBluetooth LE devices
    //    NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
        
        self.centralManager = CBCentralManager(delegate:self, queue:nil)
        
    //   [centralManager scanForPeripheralsWithServices:services options:nil];
    }
    
    fileprivate func getHeartRateMeasurementData(_ hrmData: Data)
    {
        // Maintain an index into the measurement data of the next byte to read.
        var byteIndex = 0
        
        var hrmFlags: UInt8 = 0
        (hrmData as NSData).getBytes(&hrmFlags, length: MemoryLayout<UInt8>.size)
        byteIndex += MemoryLayout<UInt8>.size
        
        if HeartRateMeasurement.heartRateValueFormatUInt16.flagIsSet(hrmFlags) {
            var value: UInt16 = 0
            (hrmData as NSData).getBytes(&value, range: NSMakeRange(byteIndex, MemoryLayout<UInt16>.size))
            byteIndex += MemoryLayout<UInt16>.size
            heartRate = Int(value)
        }
        else {
            var value: UInt8 = 0
            (hrmData as NSData).getBytes(&value, length: MemoryLayout<UInt8>.size)
            byteIndex += MemoryLayout<UInt8>.size
            heartRate = Int(value)
        }
        
        if HeartRateMeasurement.sensorContactIsSupported.flagIsSet(hrmFlags) {
            sensorDetected = HeartRateMeasurement.sensorContactDetected.flagIsSet(hrmFlags)
        }
        
        if HeartRateMeasurement.energyExpended.flagIsSet(hrmFlags) {
            var value: UInt16 = 0
            (hrmData as NSData).getBytes(&value, range: NSMakeRange(byteIndex, MemoryLayout<UInt16>.size))
            byteIndex += MemoryLayout<UInt16>.size
            energyExpended = Int(value)
        }
        
        if HeartRateMeasurement.rrInterval.flagIsSet(hrmFlags) {
            while byteIndex < hrmData.count {
                var value: UInt16 = 0
                (hrmData as NSData).getBytes(&value, range: NSMakeRange(byteIndex, MemoryLayout<UInt16>.size))
                byteIndex += MemoryLayout<UInt16>.size
                rrIntervals.append(Float(value) / 1024.0)
            }
        }
        
        NSLog("Heart rate: \(heartRate)")
        NSLog("Sensor detected: \(sensorDetected)")
        if let energyExpended = energyExpended {
            NSLog("Energy expended: \(energyExpended)")
        }
        NSLog("RR Intervals: \(rrIntervals)")
    }
    
    fileprivate func getManufacturerName(_ manufacturerNameData: Data)
    {
        if let manufacturerNameString = NSString(data: manufacturerNameData, encoding: String.Encoding.utf8.rawValue) as String? {
            manufacturerName = manufacturerNameString
            NSLog("Manufacturer Name: \(manufacturerName ?? "Unknown Manufacturer")")
        }
    }

    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let services = [
            BlueToothGATTServices.deviceInformation.UUID,
            BlueToothGATTServices.heartRate.UUID,
            BlueToothGATTServices.batteryService.UUID
        ]
    
        // Determine the state of the peripheral
        //
        switch central.state {
            
        case CBManagerState.poweredOff:
            NSLog("CoreBluetooth BLE hardware is powered off");
            
        case CBManagerState.poweredOn:
            NSLog("CoreBluetooth BLE hardware is powered on and ready");
            
            // Scan for all available CoreBluetooth LE devices
            //            NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
            //            [self.centralManager scanForPeripheralsWithServices:services options:nil];
            
            if let centralManager = self.centralManager {
                centralManager.scanForPeripherals(withServices: services, options: nil)
          //      central.scanForPeripheralsWithServices(services, options: nil)
                NSLog("Services: \(services.description)")
            }
            
        case CBManagerState.unauthorized:
            NSLog("CoreBluetooth BLE hardware is unauthorized");
            
        case CBManagerState.resetting:
            NSLog("CoreBluetooth BLE hardware is resetting");
            
        case CBManagerState.unknown:
            NSLog("CoreBluetooth BLE hardware is unknown");
            
        case CBManagerState.unsupported:
            NSLog("CoreBluetooth BLE hardware is unsupported");
        }
    }
    
    // Called from the CentralManager when a successful connection to the Bluetooth LE peripheral has been established.
    //
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        let connected = "Connected: " + (peripheral.state == CBPeripheralState.connected ? "YES" : "NO")
        NSLog("\(connected)")
    }
    
    // Called from the CentralManager when...
    // CBCentralMangerDelegate - This is called with the CBPeripheral class as its main input
    // parameter. This contains most of the information there is to know about a BLE peripheral.
    //
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as! String? {
            if !localName.isEmpty {
                NSLog("Found the heart rate monitor: \(localName)")
                self.centralManager?.stopScan()
                self.heartRateSensorPeripheral = peripheral
                peripheral.delegate = self
                self.centralManager?.connect(peripheral, options: nil)
            }
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    // Invoked when you discover the characteristics of a specified service.
    //
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        switch service.uuid {
        case BlueToothGATTServices.deviceInformation.UUID:
            for characteristic in service.characteristics! {
                if BlueToothGATTCharacteristics.manufacturerNameString.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValue(for: characteristic )
                    NSLog("Found a device manufacturer name string characteristic");
                }
            }

        case BlueToothGATTServices.heartRate.UUID:
            for characteristic in service.characteristics! {
                // Request heart rate notifications
                if BlueToothGATTCharacteristics.heartRateMeasurement.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.setNotifyValue(true, for: (characteristic ))
                    NSLog("Found heart rate measurement characteristic")
                }
                    // Request body sensor location
                else if BlueToothGATTCharacteristics.bodySensorLocation.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValue(for: characteristic )
                    NSLog("Found body sensor location characteristic")
                }
            }

        case BlueToothGATTServices.batteryService.UUID:
            for characteristic in service.characteristics! {
                if BlueToothGATTCharacteristics.batteryLevel.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValue(for: characteristic )
                    NSLog("Found the battery level characteristic");
                }
            }
            
        default:
            NSLog("Default!")
        }
    }
    
    // CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
    //
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services!
        {
            NSLog("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service )
        }
    }
    
    // Invoked when you retrieve a specified characteristic's value, or when the peripheral
    // device notifies your app that the characteristic's value has changed.
    //
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        switch characteristic.uuid {
        case BlueToothGATTCharacteristics.heartRateMeasurement.UUID:
            getHeartRateMeasurementData(characteristic.value!)
            
        case BlueToothGATTCharacteristics.manufacturerNameString.UUID:
            getManufacturerName(characteristic.value!)
            
        case BlueToothGATTCharacteristics.bodySensorLocation.UUID:
            // TODO: Add code to get the body sensor location information.
            //            // Retrieve the characteristic value for the body sensor location received
            //        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {
            //            [self getBodyLocation:characteristic];
            //        }
            return
            
        default:
            return
        }
        
//
//        // Add your constructed device information to your UITextView
//        self.deviceInfo.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", self.connected, self.bodyData, self.manufacturer];
    }
    
    // MARK: - ???? Public Methods and Properties
    
    func bodyLocation() -> String
    {
        return "Body location"
    }
}
