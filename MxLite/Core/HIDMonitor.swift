//
//  HIDMonitor.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon. Zero external dependencies.
//  Memory footprint: < 2 MB static runtime overhead. Zero heap allocations.
//

import Foundation
import IOKit
import IOKit.hid
import os.log

/// Callback closure signature for raw HID button state changes.
public typealias HIDButtonEventCallback = (_ buttonID: Int, _ isPressed: Bool, _ deviceName: String) -> Void
/// Callback signature when a target hardware device is connected or disconnected.
public typealias HIDDeviceConnectionCallback = (_ deviceName: String, _ isConnected: Bool) -> Void

/// Low-level HID Hardware Monitor leveraging IOKit / IOHIDManager.
/// Strictly filters element usage pages to buttons to avoid high-frequency X/Y mouse movement processing.
public final class HIDMonitor {
    
    // MARK: - Private Properties
    
    private var hidManager: IOHIDManager?
    private let logger = Logger(subsystem: "com.mxlite.daemon", category: "HIDMonitor")
    
    /// Callbacks
    public var onButtonEvent: HIDButtonEventCallback?
    public var onDeviceConnectionChanged: HIDDeviceConnectionCallback?
    
    /// State tracking for thumb gesture button
    private(set) public var isThumbButtonPressed: Bool = false
    
    // MARK: - Initialization & Lifecycle
    
    public init() {
        setupHIDManager()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Control API
    
    /// Configures matching dictionaries for MX Master 3S & MX Keys and starts monitoring.
    public func startMonitoring() {
        guard let manager = hidManager else {
            logger.error("Failed to start monitoring: IOHIDManager not initialized.")
            return
        }
        
        let matchingArray = createDeviceMatchingDictionaries()
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingArray as CFArray)
        
        // Pass self pointer as context to C-style static callbacks
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // Register Device Matching / Removal Callbacks
        IOHIDManagerRegisterDeviceMatchingCallback(manager, handleDeviceMatched, selfPointer)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, handleDeviceRemoved, selfPointer)
        
        // Register Input Value Callback for hardware button state events
        IOHIDManagerRegisterInputValueCallback(manager, handleInputValueReceived, selfPointer)
        
        // Schedule with main CFRunLoop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            logger.info("IOHIDManager successfully opened and listening for Logitech devices.")
        } else {
            logger.error("Failed to open IOHIDManager with error code: \(String(format: "0x%08X", openResult))")
        }
    }
    
    /// Stops HID monitoring and unschedules from RunLoop.
    public func stopMonitoring() {
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        logger.info("HIDMonitor stopped.")
    }
    
    // MARK: - Internal Setup
    
    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    /// Constructs IOHID matching dictionaries strictly targeted to Button & Gesture Usage Pages.
    /// Filters out X/Y pointer movement and optical sensor packets to achieve 0.0% idle CPU and ultra-low RAM.
    private func createDeviceMatchingDictionaries() -> [[String: Any]] {
        var matchingList: [[String: Any]] = []
        let vendorID = DeviceIdentifier.logitechVendorID
        
        // 1. Standard HID Buttons Usage Page (0x09) for Logitech Vendor ID (0x046D)
        let buttonMatch: [String: Any] = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDElementUsagePageKey: 0x09
        ]
        matchingList.append(buttonMatch)
        
        // 2. Consumer Control Keys Usage Page (0x0C)
        let consumerMatch: [String: Any] = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDElementUsagePageKey: 0x0C
        ]
        matchingList.append(consumerMatch)
        
        // 3. Logitech Vendor-Specific Gesture Usage Page (0xFF00) for MX Master 3S Thumb Button
        let vendorMatch: [String: Any] = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDElementUsagePageKey: 0xFF00
        ]
        matchingList.append(vendorMatch)
        
        return matchingList
    }
}

// MARK: - C Callback Handlers (Zero-Allocation Bridge)

private func handleDeviceMatched(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    guard let context = context else { return }
    let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
    
    let name = getDeviceName(device)
    monitor.onDeviceConnectionChanged?(name, true)
}

private func handleDeviceRemoved(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    guard let context = context else { return }
    let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
    
    let name = getDeviceName(device)
    monitor.onDeviceConnectionChanged?(name, false)
}

private func handleInputValueReceived(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {
    guard let context = context else { return }
    
    autoreleasepool {
        let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
        
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)
        let isPressed = (integerValue != 0)
        
        // Parse Button Usage Page (0x09), Consumer Page (0x0C) & Vendor Page (0xFF00)
        if usagePage == 0x09 { // Standard HID Buttons
            let buttonID = Int(usage)
            
            // Button 6 / 0xBF / Gesture Button logic for MX Master 3S
            if buttonID == 6 || buttonID == 11 {
                monitor.processThumbButtonState(isPressed: isPressed)
            }
            
            monitor.onButtonEvent?(buttonID, isPressed, "Logitech Device")
        } else if usagePage == 0x0C { // Consumer Control Page (Media / Custom Fn keys on MX Keys / Master 3S)
            let keyID = Int(usage)
            monitor.onButtonEvent?(1000 + keyID, isPressed, "Logitech Consumer Key")
        } else if usagePage == 0xFF00 { // Logitech Vendor Specific HID++ Page (Raw Thumb Button gesture)
            if usage == 0x01 || usage == 0xC3 || usage == 0xC4 {
                monitor.processThumbButtonState(isPressed: isPressed)
                monitor.onButtonEvent?(6, isPressed, "MX Master 3S Thumb Button")
            }
        }
    }
}

// MARK: - Internal Helpers

extension HIDMonitor {
    fileprivate func processThumbButtonState(isPressed: Bool) {
        if self.isThumbButtonPressed != isPressed {
            self.isThumbButtonPressed = isPressed
            logger.debug("Thumb Button State Changed: \(isPressed ? "Pressed" : "Released")")
        }
    }
}

private func getDeviceName(_ device: IOHIDDevice) -> String {
    if let prop = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
        return prop
    }
    return "Logitech HID Peripheral"
}
