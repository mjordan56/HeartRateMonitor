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
    private enum BlueToothGATTServices: UInt16 {
        case BatteryService    = 0x180F
        case DeviceInformation = 0x180A
        case HeartRate         = 0x180D
        
        func UUID() -> CBUUID {
            return CBUUID(string: String(self.rawValue, radix: 16, uppercase: true))
        }
    }
    
    // MARK: - Bluetooth GATT Characteristics
    
    // Bluetooth GATT specifications - Characteristics
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicsHome.aspx
    //
    private enum BlueToothGATTCharacteristics: UInt16 {
        case BatteryLevel           = 0x2A19
        case BodySensorLocation     = 0x2A38
        case HeartRateMeasurement   = 0x2A37
        case ManufacturerNameString = 0x2A29
        
        func isEqual(characteristic: AnyObject) -> Bool {
            if let characteristic = characteristic as? CBCharacteristic {
                return self.UUID().isEqual(characteristic.UUID)
            }
            return false
        }
        
        func UUID() -> CBUUID {
            return CBUUID(string: String(self.rawValue, radix: 16, uppercase: true))
        }
    }

    // MARK: - Bluetooth Heart Rate Measurement Flags
    
    // Heart Rate Measurement flags as defined on the Bluetooth developer portal.
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.heart_rate_measurement.xml
    //
    private enum HeartRateMeasurement: UInt8 {
        case HeartRateValueFormatUInt8  = 0b00000000
        case HeartRateValueFormatUInt16 = 0b00000001
        case SensorContactIsSupported   = 0b00000100
        case SensorContactDetected      = 0b00000110
        case EnergyExpended             = 0b00001000
        case RRInterval                 = 0b00010000
        
        func flagIsSet(flagData: UInt8) -> Bool {
            return (flagData & self.rawValue) != 0
        }
    }
    
    // MARK: - Properties
    
    var centralManager: CBCentralManager? = nil
    var polarH7HRMPeripheral: CBPeripheral? = nil
    
    var connected: String? = nil
    var polarH7DeviceData: String? = nil
    
    private(set) var heartRate = 0
    private(set) var sensorDetected = false
    private(set) var energyExpended:Int?
    private(set) var rrIntervals = [Float]()
    
    private(set) var manufacturerName: String?
        
    // MARK: - Methods
    
    func scanForDevices()
    {
        // Scan for all available CoreBluetooth LE devices
    //    NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
        
        self.centralManager = CBCentralManager(delegate:self, queue:nil)
        
    //   [centralManager scanForPeripheralsWithServices:services options:nil];
    }
    
    private func getHeartRateMeasurementData(hrmData: NSData)
    {
        // Maintain an index into the measurement data of the next byte to read.
        var byteIndex = 0
        
        var hrmFlags: UInt8 = 0
        hrmData.getBytes(&hrmFlags, length: sizeof(UInt8))
        byteIndex += sizeof(UInt8)
        
        if HeartRateMeasurement.HeartRateValueFormatUInt16.flagIsSet(hrmFlags) {
            var value: UInt16 = 0
            hrmData.getBytes(&value, range: NSMakeRange(byteIndex, sizeof(UInt16)))
            byteIndex += sizeof(UInt16)
            heartRate = Int(value)
        }
        else {
            var value: UInt8 = 0
            hrmData.getBytes(&value, length: sizeof(UInt8))
            byteIndex += sizeof(UInt8)
            heartRate = Int(value)
        }
        
        if HeartRateMeasurement.SensorContactIsSupported.flagIsSet(hrmFlags) {
            sensorDetected = HeartRateMeasurement.SensorContactDetected.flagIsSet(hrmFlags)
        }
        
        if HeartRateMeasurement.EnergyExpended.flagIsSet(hrmFlags) {
            var value: UInt16 = 0
            hrmData.getBytes(&value, range: NSMakeRange(byteIndex, sizeof(UInt16)))
            byteIndex += sizeof(UInt16)
            energyExpended = Int(value)
        }
        
        if HeartRateMeasurement.RRInterval.flagIsSet(hrmFlags) {
            while byteIndex < hrmData.length {
                var value: UInt16 = 0
                hrmData.getBytes(&value, range: NSMakeRange(byteIndex, sizeof(UInt16)))
                byteIndex += sizeof(UInt16)
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
    
    private func getManufacturerName(manufacturerNameData: NSData)
    {
        if let manufacturerNameString = NSString(data: manufacturerNameData, encoding: NSUTF8StringEncoding) as? String {
            manufacturerName = manufacturerNameString
        }
    }

    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        
        // Determine the state of the peripheral
        //
        switch central.state {
            
        case CBCentralManagerState.PoweredOff:
            NSLog("CoreBluetooth BLE hardware is powered off");
            
        case CBCentralManagerState.PoweredOn:
            NSLog("CoreBluetooth BLE hardware is powered on and ready");
            
            // Scan for all available CoreBluetooth LE devices
            //            NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
            //            [self.centralManager scanForPeripheralsWithServices:services options:nil];
            var services = [BlueToothGATTServices.DeviceInformation.UUID(), BlueToothGATTServices.HeartRate.UUID(), BlueToothGATTServices.BatteryService.UUID()]
            self.centralManager?.scanForPeripheralsWithServices(services, options: nil)
            NSLog("Services: \(services.description)")

        case CBCentralManagerState.Unauthorized:
            NSLog("CoreBluetooth BLE hardware is unauthorized");

        case CBCentralManagerState.Resetting:
            NSLog("CoreBluetooth BLE hardware is resetting");

        case CBCentralManagerState.Unknown:
            NSLog("CoreBluetooth BLE hardware is unknown");

        case CBCentralManagerState.Unsupported:
            NSLog("CoreBluetooth BLE hardware is unsupported");
        }
    }
    
    // Called from the CentralManager when a successful connection to the Bluetooth LE peripheral has been established.
    //
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        if let peripheral = peripheral {
            peripheral.delegate = self
            peripheral.discoverServices(nil)
            let connected = "Connected: " + (peripheral.state == CBPeripheralState.Connected ? "YES" : "NO")
            NSLog("\(connected)")
        }
    }
    
    // Called from the CentralManager when...
    // CBCentralMangerDelegate - This is called with the CBPeripheral class as its main input
    // parameter. This contains most of the information there is to know about a BLE peripheral.
    //
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!)
    {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as! String? {
            if !localName.isEmpty {
                NSLog("Found the heart rate monitor: \(localName)")
                self.centralManager?.stopScan()
                self.polarH7HRMPeripheral = peripheral
                peripheral.delegate = self
                self.centralManager?.connectPeripheral(peripheral, options: nil)
            }
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    // Invoked when you discover the characteristics of a specified service.
    //
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if service.UUID.isEqual(BlueToothGATTServices.HeartRate.UUID()) {
            for characteristic in service.characteristics {
                // Request heart rate notifications
                if BlueToothGATTCharacteristics.HeartRateMeasurement.isEqual(characteristic) {
                    self.polarH7HRMPeripheral?.setNotifyValue(true, forCharacteristic: (characteristic as! CBCharacteristic))
                    NSLog("Found heart rate measurement characteristic")
                }
                // Request body sensor location
                else if BlueToothGATTCharacteristics.BodySensorLocation.isEqual(characteristic) {
                    self.polarH7HRMPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found body sensor location characteristic")
                }
            }
        }
        
        // Retrieve Device Information Services for the Manufacturer Name
        if service.UUID.isEqual(BlueToothGATTServices.DeviceInformation.UUID()) {
            for characteristic in service.characteristics {
                if BlueToothGATTCharacteristics.ManufacturerNameString.isEqual(characteristic) {
                    self.polarH7HRMPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found a device manufacturer name string characteristic");
                }
            }
        }
        
        // Retrieve Device Information Services for the Manufacturer Name
        if service.UUID.isEqual(BlueToothGATTServices.BatteryService.UUID()) {
            for characteristic in service.characteristics {
                if BlueToothGATTCharacteristics.BatteryLevel.isEqual(characteristic) {
                    self.polarH7HRMPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found the battery level characteristic");
                }
            }
        }
    }
    
    // CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
    //
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        for service in peripheral.services
        {
            NSLog("Discovered service: \(service.UUID)")
            peripheral.discoverCharacteristics(nil, forService: service as! CBService)
        }
    }
    
    // Invoked when you retrieve a specified characteristic's value, or when the peripheral
    // device notifies your app that the characteristic's value has changed.
    //
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        // Update value for heart rate measurement received
        if characteristic.UUID.isEqual(BlueToothGATTCharacteristics.HeartRateMeasurement.UUID()) {
            // Get the Heart Rate Monitor BPM
         //   [self getHeartBPMData:characteristic error:error];
            
            let data = characteristic.value
            NSLog("Character value: \(data)")
            
            getHeartRateMeasurementData(characteristic.value)
        }
        
        // Retrieve the characteristic value for manufacturer name.
        //
        if characteristic.UUID.isEqual(BlueToothGATTCharacteristics.ManufacturerNameString.UUID()) {
            getManufacturerName(characteristic.value)
        }
//            // Retrieve the characteristic value for the body sensor location received
//        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {
//            [self getBodyLocation:characteristic];
//        }
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
