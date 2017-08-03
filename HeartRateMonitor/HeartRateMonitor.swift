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
        
        var UUID: CBUUID {
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
                return self.UUID.isEqual(characteristic.UUID)
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
    
    // MARK: - Bluetooth Body Sensor Location Flags
    
    // Heart Rate Measurement flags as defined on the Bluetooth developer portal.
    // https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.body_sensor_location.xml
    //
    enum BodySensorLocation: UInt8 {
        case Other = 0
        case Chest
        case Wrist
        case Finger
        case Hand
        case EarLobe
        case Foot
    }
    
    // MARK: - Properties
    
    var centralManager: CBCentralManager? = nil
    var heartRateSensorPeripheral: CBPeripheral? = nil
    
    var connected: String? = nil
    var polarH7DeviceData: String? = nil
    
    private(set) var heartRate = 0
    private(set) var sensorDetected = false
    private(set) var energyExpended:Int?
    private(set) var rrIntervals = [Float]()
    
    private(set) var bodySensorLocation: BodySensorLocation?
    
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
            NSLog("Manufacturer Name: \(manufacturerName)")
        }
    }

    private func getBodyLocation(bodyLocationData: NSData)
    {
        var value: UInt8 = 0
        bodyLocationData.getBytes(&value, range: NSMakeRange(0, sizeof(UInt8)))
        switch value {
        case BodySensorLocation.Chest.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.EarLobe.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.Finger.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.Foot.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.Hand.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.Other.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        case BodySensorLocation.EarLobe.rawValue:
            bodySensorLocation = BodySensorLocation.Chest
            
        }
        bodySensorLocation = BodySensorLocation(value)
        NSLog("Body Location: \(bodySensorLocation)")
    }

    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        
        let services = [
            BlueToothGATTServices.DeviceInformation.UUID,
            BlueToothGATTServices.HeartRate.UUID,
            BlueToothGATTServices.BatteryService.UUID
        ]
    
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
            
            if let centralManager = self.centralManager {
                centralManager.scanForPeripheralsWithServices(services, options: nil)
          //      central.scanForPeripheralsWithServices(services, options: nil)
                NSLog("Services: \(services.description)")
            }
            
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
                self.heartRateSensorPeripheral = peripheral
                peripheral.delegate = self
                self.centralManager?.connectPeripheral(peripheral, options: nil)
            }
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    // Invoked when you discover the characteristics of a specified service.
    //
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        
        switch service.UUID {
        case BlueToothGATTServices.DeviceInformation.UUID:
            for characteristic in service.characteristics {
                if BlueToothGATTCharacteristics.ManufacturerNameString.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found a device manufacturer name string characteristic");
                }
            }

        case BlueToothGATTServices.HeartRate.UUID:
            for characteristic in service.characteristics {
                // Request heart rate notifications
                if BlueToothGATTCharacteristics.HeartRateMeasurement.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.setNotifyValue(true, forCharacteristic: (characteristic as! CBCharacteristic))
                    NSLog("Found heart rate measurement characteristic")
                }
                    // Request body sensor location
                else if BlueToothGATTCharacteristics.BodySensorLocation.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found body sensor location characteristic")
                }
            }

        case BlueToothGATTServices.BatteryService.UUID:
            for characteristic in service.characteristics {
                if BlueToothGATTCharacteristics.BatteryLevel.isEqual(characteristic) {
                    self.heartRateSensorPeripheral?.readValueForCharacteristic(characteristic as! CBCharacteristic)
                    NSLog("Found the battery level characteristic");
                }
            }
            
        default:
            NSLog("Default!")
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
        
        switch characteristic.UUID {
        case BlueToothGATTCharacteristics.HeartRateMeasurement.UUID:
            getHeartRateMeasurementData(characteristic.value)
            
        case BlueToothGATTCharacteristics.ManufacturerNameString.UUID:
            getManufacturerName(characteristic.value)
            
        case BlueToothGATTCharacteristics.BodySensorLocation.UUID:
            // TODO: Add code to get the body sensor location information.
            //            // Retrieve the characteristic value for the body sensor location received
            //        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {
            //            [self getBodyLocation:characteristic];
            //        }
            getBodyLocation(characteristic.value)
            
        default:
            return
        }
        
//
//        // Add your constructed device information to your UITextView
//        self.deviceInfo.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", self.connected, self.bodyData, self.manufacturer];
    }
}
