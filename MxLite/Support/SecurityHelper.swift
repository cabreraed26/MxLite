//
//  SecurityHelper.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon. Zero external dependencies.
//

import Foundation
import ApplicationServices
import Cocoa
import os.log

/// Runtime Security Guard providing programmatic accessibility checks and system settings prompts.
public enum SecurityHelper {
    
    private static let logger = Logger(subsystem: "com.mxlite", category: "SecurityHelper")
    
    /// Checks if Accessibility permissions are currently granted for this app process.
    /// - Parameter promptIfNeeded: If `true`, macOS presents a system prompt to grant permissions.
    /// - Returns: `true` if trusted, `false` otherwise.
    public static func checkAccessibilityPermissions(promptIfNeeded: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility permissions status: \(isTrusted ? "GRANTED" : "DENIED")")
        return isTrusted
    }
    
    /// Opens the Privacy & Security -> Accessibility pane in System Settings.
    public static func openAccessibilitySystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Opens the Privacy & Security -> Input Monitoring pane in System Settings.
    public static func openInputMonitoringSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
