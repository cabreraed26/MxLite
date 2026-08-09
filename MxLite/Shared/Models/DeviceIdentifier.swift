//
//  DeviceIdentifier.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon.
//

import Foundation
import IOKit.hid

/// Known Vendor and Product Identifiers for target Logitech devices.
public enum DeviceIdentifier {
    /// Logitech Vendor ID in Hex (1133 in Decimal)
    public static let logitechVendorID: Int32 = 0x046D
    
    /// Target Product IDs for Logitech MX Master 3S & MX Keys variants
    public enum ProductID {
        // MX Master 3S Product IDs (Bluetooth, Bolt, and Receiver modes)
        public static let mxMaster3S_Bluetooth: Int32   = 0xB034
        public static let mxMaster3S_Bolt: Int32        = 0xC548
        public static let mxMaster3S_AltBLE: Int32      = 0xB028
        public static let mxMaster3S_MacBLE: Int32      = 0x4094
        
        // MX Master 3 (Legacy reference)
        public static let mxMaster3_Bluetooth: Int32    = 0xB023
        public static let mxMaster3_Unifying: Int32     = 0x4082
        
        // MX Keys / MX Keys S / MX Keys Mini
        public static let mxKeys_Bluetooth: Int32       = 0xB35B
        public static let mxKeys_Unifying: Int32        = 0x408A
        public static let mxKeysS_Bluetooth: Int32      = 0xB378
        public static let mxKeysMini_Bluetooth: Int32   = 0xB369
        
        /// Array of all monitored product IDs
        public static let allTargetProductIDs: [Int32] = [
            mxMaster3S_Bluetooth, mxMaster3S_Bolt, mxMaster3S_AltBLE, mxMaster3S_MacBLE,
            mxMaster3_Bluetooth, mxMaster3_Unifying,
            mxKeys_Bluetooth, mxKeys_Unifying, mxKeysS_Bluetooth, mxKeysMini_Bluetooth
        ]
    }
    
    /// HID Usage Pages & Usages
    public enum HIDUsage {
        public static let genericDesktopPage: Int32  = 0x01
        public static let consumerPage: Int32        = 0x0C
        public static let vendorDefinedPage: Int32   = 0xFF00
        
        public static let mouseUsage: Int32          = 0x02
        public static let pointerUsage: Int32        = 0x01
        public static let keyboardUsage: Int32       = 0x06
    }
}
