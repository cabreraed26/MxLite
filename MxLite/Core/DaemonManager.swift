//
//  DaemonManager.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon.
//

import Foundation
import Combine
import os.log

/// Main background engine controller for MxLite.
/// Coordinates HIDMonitor (IOKit) and EventTapManager (CoreGraphics) within the app bundle.
public final class DaemonManager: ObservableObject {
    
    public static let shared = DaemonManager()
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isTapActive: Bool = false
    @Published public private(set) var connectedDeviceName: String = "Ningún dispositivo detectado"
    
    public let hidMonitor = HIDMonitor()
    public let eventTapManager = EventTapManager()
    private let logger = Logger(subsystem: "com.mxlite", category: "DaemonManager")
    
    private init() {
        setupCallbacks()
    }
    
    /// Starts the HIDMonitor hardware listener and CoreGraphics CGEventTap engine.
    public func start() {
        guard !isRunning else { return }
        logger.info("Iniciando servicio DaemonManager...")
        
        // 1. Validate Accessibility permissions
        let isAccessibilityGranted = SecurityHelper.checkAccessibilityPermissions(promptIfNeeded: true)
        if !isAccessibilityGranted {
            logger.warning("Permisos de accesibilidad aún no concedidos.")
        }
        
        // 2. Start HID Monitor
        hidMonitor.startMonitoring()
        
        // 3. Start EventTap Manager
        eventTapManager.hidMonitor = hidMonitor
        let tapSuccess = eventTapManager.startTap()
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.isTapActive = tapSuccess
        }
    }
    
    /// Stops the daemon background services.
    public func stop() {
        guard isRunning else { return }
        eventTapManager.stopTap()
        hidMonitor.stopMonitoring()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.isTapActive = false
        }
    }
    
    private func setupCallbacks() {
        hidMonitor.onDeviceConnectionChanged = { [weak self] deviceName, isConnected in
            let newName = isConnected ? deviceName : "Ningún dispositivo detectado"
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.connectedDeviceName != newName {
                    self.connectedDeviceName = newName
                }
            }
        }
    }
}
