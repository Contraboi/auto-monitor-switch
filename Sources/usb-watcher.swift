//  usb-watcher.swift
//  monitor-changer
//
//  Created by Selmir Nedzibi on 30. 7. 24.

import IOKit.usb
import IOKit.usb.IOUSBLib
import IOKit
import Foundation

public protocol USBWatcherDelegate: class {
    /// Called on the main thread when a device is connected.
    func deviceAdded(_ device: io_object_t)

    /// Called on the main thread when a device is disconnected.
   func deviceRemoved(_ device: io_object_t)
}

/// An object which observes USB devices added and removed from the system.
/// Abstracts away most of the ugliness of IOKit APIs.
public class USBWatcher {
    private weak var delegate: USBWatcherDelegate?
    private let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0



public init(delegate: USBWatcherDelegate) {
        self.delegate = delegate

        func handleNotification(instance: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
            let watcher = Unmanaged<USBWatcher>.fromOpaque(instance!).takeUnretainedValue()
            let handler: ((io_iterator_t) -> Void)?
            switch iterator {
            case watcher.addedIterator: handler = watcher.delegate?.deviceAdded
            case watcher.removedIterator: handler = watcher.delegate?.deviceRemoved
            default: assertionFailure("received unexpected IOIterator"); return
            }
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                handler?(device)
                IOObjectRelease(device)
            }
        }

        let query = IOServiceMatching(kIOUSBDeviceClassName)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        // Watch for connected devices.
        IOServiceAddMatchingNotification(
            notificationPort, kIOMatchedNotification, query,
            handleNotification, opaqueSelf, &addedIterator)

        handleNotification(instance: opaqueSelf, addedIterator)

        // Watch for disconnected devices.
        IOServiceAddMatchingNotification(
            notificationPort, kIOTerminatedNotification, query,
            handleNotification, opaqueSelf, &removedIterator)

        handleNotification(instance: opaqueSelf, removedIterator)

        // Add the notification to the main run loop to receive future updates.
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue(),
            .commonModes)
    }

    deinit {
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(notificationPort)
    }
}

extension io_object_t {
    /// - Returns: The device's name.
    func name() -> String? {
        let buf = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
        defer { buf.deallocate() }
        return buf.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<io_name_t>.size) {
            if IORegistryEntryGetName(self, $0) == KERN_SUCCESS {
                return String(cString: $0)
            }
            return nil
        }
    }
}

class usbDelegate: USBWatcherDelegate {
    private var usbWatcher: USBWatcher!
    private var _name: String
    private var _effect: String
    private var _values: [String]

    init(name: String, effect: String, values: [String]) {
        _name = name
        _effect = effect
        _values = values
        usbWatcher = USBWatcher(delegate: self)
    }

    func deviceAdded(_ device: io_object_t) {
        if(isMatching(device) && _effect == "add"){
            switchMonitor()
        }
        
        print("device added: \(device.name() ?? "<unknown>")")
    }

    func deviceRemoved(_ device: io_object_t) {
        if(isMatching(device) && _effect == "remove"){
            switchMonitor()
        }
        
        print("device removed: \(device.name() ?? "<unknown>")")
    }
    
    private func isMatching(_ device: io_object_t) -> Bool {
        let name = device.name() ?? "{unknown}"
        print(name, _name)
        return name == _name
    }
    
    private func switchMonitor(){
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = "\(home.path)/Documents/open-source/m1ddc/m1ddc"
        
        let output = runShellCommand(path, arguments: buildArguments())
        print(output)
    }
    
    private func buildArguments() -> [String] {
        var arguments: [String] = []
        
        for value in _values {
            let split = value.split(separator: ",")
            
            if split.count == 2 {
                let monitorId = String(split[0])
                let inputId = String(split[1])
                
                arguments.append("display")
                arguments.append(monitorId)
                arguments.append("set")
                arguments.append("input")
                arguments.append(inputId)
            }
        }
        
        return arguments
    }
}
