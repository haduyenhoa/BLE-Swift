//
//  BLEPeripheralManager.swift
//  AmHere
//
//  Created by Duyen Hoa Ha on 29/04/2015.
//  Copyright (c) 2015 Duyen Hoa Ha. All rights reserved.
//

import Foundation
import CoreBluetooth
import UIKit



@objc protocol PeripheralDelegate {
    optional func receiveMessage(msg: String!, cb : CBCharacteristic)
    optional func receiveMessage(msg: String!, cb : CBCharacteristic, request : CBATTRequest)
    
}

class BLEPeripheralManager : NSObject, CBPeripheralManagerDelegate {
    //private use
    var canBroadcast : Bool = false
    var isBroadcasting : Bool = false
    
    var myBTManager : CBPeripheralManager? = nil
    var delegate : PeripheralDelegate?
    
    var advertismentData : [NSObject : AnyObject]?
    var needAdvertising = false
    
    class func SharedInstance() -> BLEPeripheralManager {
        struct Static {
            static var instance: BLEPeripheralManager? = nil
            static var onceToken: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.onceToken, {
            Static.instance = BLEPeripheralManager()
        })
        
        return Static.instance!
    }
    
    override init() {
        //create boardcast reagion &
        super.init()
        
        advertismentData = [CBAdvertisementDataServiceUUIDsKey:[SERVICE_TRANSFER_CBUUID], CBAdvertisementDataLocalNameKey : (UIApplication.sharedApplication().delegate as! AppDelegate).UUIDString]
    }
    
    //MARK Peripheral Manager
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        println(__FUNCTION__)
        if peripheral.state == CBPeripheralManagerState.PoweredOn {
            println("Broadcasting...")
            if (needAdvertising) {
                var transferService  = CBMutableService(type: SERVICE_TRANSFER_CBUUID, primary: true)
                
                //add characteristic
                if let _userId = ChatSession.SharedInstance().userId {
                    //Create CBCharacteristics
                    let userIdChar = CBMutableCharacteristic(type: USER_ID_CBUUID, properties: CBCharacteristicProperties.Read
                        , value: _userId.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true), permissions: CBAttributePermissions.Readable)
                    let exchangeDataChar = CBMutableCharacteristic(type: EXCHANGE_DATA_CBUUID, properties: CBCharacteristicProperties.Write | CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Writeable)
                    let endSessionChar = CBMutableCharacteristic(type: END_CHAT_SESSION_CBUUID, properties: CBCharacteristicProperties.Write | CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Writeable)
                    let beginSessionChar = CBMutableCharacteristic(type: START_CHAT_SESSION_CBUUID, properties: CBCharacteristicProperties.Write | CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Writeable)
                    let reconnectChar = CBMutableCharacteristic(type: RECONNECT_CBUUID, properties: CBCharacteristicProperties.Write | CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Writeable)
                    
                    transferService.characteristics = [userIdChar, exchangeDataChar, endSessionChar, beginSessionChar, reconnectChar]
                    
                    self.myBTManager?.addService(transferService)
                    self.myBTManager?.startAdvertising(advertismentData)
                    
                } else {
                    //do nothing
                    println("This session is not start, just do nothing")
                    self.myBTManager?.stopAdvertising() //to be sure, stop advertising
                }
            } else {
                println("This session is not start, just do nothing")
                self.myBTManager?.stopAdvertising() //to be sure, stop advertising
            }
            
        } else if peripheral.state == CBPeripheralManagerState.PoweredOff {
            println("Stopped")
            self.myBTManager?.stopAdvertising()
        } else if peripheral.state == CBPeripheralManagerState.Unsupported {
            println("Unsupported")
        } else if peripheral.state == CBPeripheralManagerState.Unauthorized {
            println("This option is not allowed by your application")
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, willRestoreState dict: [NSObject : AnyObject]!) {
        println("willRestoreState")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {
        println("didReceiveReadRequest")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {
        println("didReceiveWriteRequests")
        
        for _request in requests as! [CBATTRequest] {
            let msg = NSString(data: _request.value, encoding: NSUTF8StringEncoding) as! String
            
            /*

            if let _perif = _request.characteristic.service.peripheral {
                println("received request <\(msg)> from cb <\(_request.characteristic.UUID.getName())>, perif <\(_perif.name)>")
                
                if _request.characteristic.UUID == BEGIN_CHAT_SESSION_CBUUID {
                    println("Some one ask to begin chat session")
                } else if _request.characteristic.UUID == END_CHAT_SESSION_CBUUID {
                    println("Some one ask to end chat session")
                } else if (_request.characteristic.UUID == EXCHANGE_DATA_CBUUID) {
                    println("Some one ask to send msg during chat session")
                } else  if _request.characteristic.UUID == RECONNECT_CBUUID {
                    println("Some one ask to reconnect corrupted session")
                }
                
            } else {
                println("received request <\(msg)> from cb <\(_request.characteristic.UUID.getName())>, of unknown perif")
            }
*/
  
//            println("received request <\(msg)> from cb <\(_request.characteristic.UUID.UUIDString)>, of unknown perif")
            
            //responds to sender
            if (_request.characteristic.UUID == START_CHAT_SESSION_CBUUID) {
                self.delegate?.receiveMessage?(msg, cb: _request.characteristic, request: _request) //call delegate if possible
            } else if (_request.characteristic.UUID == EXCHANGE_DATA_CBUUID) {
                self.myBTManager?.respondToRequest(_request, withResult: CBATTError.Success)
                self.delegate?.receiveMessage?(msg, cb: _request.characteristic) //call delegate if possible
            }
        }
    }
    
    //public function
    func enableBroadcast(shouldEnabled:Bool) {
        if (shouldEnabled) {
            needAdvertising = true //in order to re-start service when in need
            if self.myBTManager == nil {
                NSLog("Create CBPeripheralManager to catch call-back peripheralManagerDidUpdateState then advetising");
                self.myBTManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
                
            } else {
                if (!self.myBTManager!.isAdvertising) {
                    //update state
                    self.peripheralManagerDidUpdateState(self.myBTManager)
                } else {
                    //do nothing
                    NSLog("CBPeripheralManager has already advertised")
                }
            }
        } else {
            self.myBTManager?.stopAdvertising()
            needAdvertising = false
        }
        
    }
}