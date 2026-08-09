//
//  EventTapManager.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon ProMotion (120Hz). Zero external dependencies.
//  Memory optimized with strict autoreleasepool draining (<15 MB RAM target).
//

import Foundation
import CoreGraphics
import ApplicationServices
import Cocoa
import os.log

/// Directional gesture types including single click and side buttons.
public enum GestureDirection {
    case click
    case up
    case down
    case left
    case right
}

/// Available system actions configurable for all mouse buttons and gestures.
public enum GestureAction: String, CaseIterable, Identifiable {
    case navigateBack = "Navegar Atrás (Back)"
    case navigateForward = "Navegar Adelante (Forward)"
    case missionControl = "Mission Control"
    case launchpad = "Launchpad"
    case appExpose = "App Exposé"
    case spaceLeft = "Space a la Izquierda"
    case spaceRight = "Space a la Derecha"
    case showDesktop = "Mostrar Escritorio"
    case mediaPlayPause = "Reproducir / Pausar"
    
    public var id: String { rawValue }
}

/// Authentic High-Precision 120Hz Kinetic Inertial Physics Engine matching Apple Magic Trackpad physics.
/// Features non-linear velocity compression to eliminate sudden speed jumps.
public final class KineticScrollEngine {
    
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.mxlite.kineticscroll", qos: .userInteractive)
    private let logger = Logger(subsystem: "com.mxlite", category: "KineticScrollEngine")
    
    // Kinetic State Variables
    private var targetVelocityY: Double = 0.0
    private var targetVelocityX: Double = 0.0
    private var currentVelocityY: Double = 0.0
    private var currentVelocityX: Double = 0.0
    
    // Configurable Physics Parameters (Default 1.5x for natural soft scrolling)
    public var sensitivity: Double = 1.5
    
    private var isRunning: Bool = false
    private var isFirstFrame: Bool = true
    
    public init() {}
    
    /// Accumulates discrete scroll wheel impulses with non-linear velocity compression.
    public func addImpulse(deltaY: Double, deltaX: Double, flags: CGEventFlags) {
        queue.async {
            autoreleasepool {
                let scale = self.sensitivity * 3.8
                let signY: Double = deltaY >= 0 ? 1.0 : -1.0
                let signX: Double = deltaX >= 0 ? 1.0 : -1.0
                
                // Non-linear square root velocity compression to prevent abrupt speed jumps
                let compressedY = signY * sqrt(abs(deltaY)) * scale
                let compressedX = signX * sqrt(abs(deltaX)) * scale
                
                // Smoothly blend new impulse into target velocity
                self.targetVelocityY = (self.targetVelocityY * 0.45) + (compressedY * 0.75)
                self.targetVelocityX = (self.targetVelocityX * 0.45) + (compressedX * 0.75)
                
                if !self.isRunning {
                    self.isFirstFrame = true
                    self.startPhysicsLoop(flags: flags)
                }
            }
        }
    }
    
    private func startPhysicsLoop(flags: CGEventFlags) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // 120Hz ProMotion timer: 8,333 microseconds per frame
        timer.schedule(deadline: .now(), repeating: .microseconds(8333), leeway: .microseconds(500))
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.physicsStep(flags: flags)
        }
        
        self.timer = timer
        self.isRunning = true
        timer.resume()
    }
    
    private func physicsStep(flags: CGEventFlags) {
        autoreleasepool {
            // Critical damping spring interpolation towards target velocity
            currentVelocityY += (targetVelocityY - currentVelocityY) * 0.22
            currentVelocityX += (targetVelocityX - currentVelocityX) * 0.22
            
            // Soft dynamic friction curve
            let speed = sqrt(currentVelocityY * currentVelocityY + currentVelocityX * currentVelocityX)
            let dynamicFriction = speed > 15.0 ? 0.88 : (speed > 4.0 ? 0.84 : 0.76)
            
            targetVelocityY *= dynamicFriction
            targetVelocityX *= dynamicFriction
            
            // Stop condition when movement falls below sub-pixel visibility threshold
            if abs(currentVelocityY) < 0.05 && abs(targetVelocityY) < 0.05 &&
               abs(currentVelocityX) < 0.05 && abs(targetVelocityX) < 0.05 {
                sendScrollPhaseEnded(flags: flags)
                stopPhysicsLoop()
                return
            }
            
            let phase: Int64 = isFirstFrame ? 1 : 2 // 1 = Began, 2 = Changed
            isFirstFrame = false
            
            // Synthesize native Trackpad CGEvent with continuous bit and floating-point deltas
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(currentVelocityY),
                wheel2: Int32(currentVelocityX),
                wheel3: 0
            ) {
                scrollEvent.flags = flags
                
                // Set macOS Trackpad continuous and sub-pixel float fields
                scrollEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                scrollEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: currentVelocityY)
                scrollEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: currentVelocityX)
                scrollEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
                
                scrollEvent.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func sendScrollPhaseEnded(flags: CGEventFlags) {
        autoreleasepool {
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: 0,
                wheel2: 0,
                wheel3: 0
            ) {
                scrollEvent.flags = flags
                scrollEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                scrollEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0.0)
                scrollEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: 0.0)
                scrollEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4) // 4 = Ended
                scrollEvent.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func stopPhysicsLoop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isFirstFrame = true
        targetVelocityY = 0
        targetVelocityX = 0
        currentVelocityY = 0
        currentVelocityX = 0
    }
}

/// System level Event Tap Manager operating with CGEventTap.
/// Features high-resolution kinetic scroll engine and full custom button action mapping.
public final class EventTapManager {
    
    // MARK: - Properties
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let logger = Logger(subsystem: "com.mxlite.daemon", category: "EventTapManager")
    
    /// Kinetic Physics Engine
    public let kineticEngine = KineticScrollEngine()
    
    /// Smooth Scroll settings wrapper
    public var isSmoothScrollEnabled: Bool = true {
        didSet {
            kineticEngine.sensitivity = scrollSensitivity
        }
    }
    public var scrollSensitivity: Double = 1.5 {
        didSet {
            kineticEngine.sensitivity = scrollSensitivity
        }
    }
    
    /// Mapped actions for Side Buttons above thumb
    public var sideBackButtonAction: GestureAction = .navigateBack
    public var sideForwardButtonAction: GestureAction = .navigateForward
    
    /// Mapped actions for Thumb Rest Button & Gestures
    public var clickAction: GestureAction = .missionControl
    public var upAction: GestureAction = .missionControl
    public var downAction: GestureAction = .appExpose
    public var leftAction: GestureAction = .spaceLeft
    public var rightAction: GestureAction = .spaceRight
    
    /// Reference to HIDMonitor for thumb button status
    public weak var hidMonitor: HIDMonitor?
    
    /// Gesture state tracking
    fileprivate var isThumbPressedInTap: Bool = false
    private var isGestureActive: Bool = false
    private var gestureStartX: Double = 0
    private var gestureStartY: Double = 0
    private var gestureThreshold: Double = 12.0
    private var gestureTriggered: Bool = false
    
    // MARK: - Lifecycle
    
    public init() {}
    
    deinit {
        stopTap()
    }
    
    // MARK: - Public API
    
    /// Creates and enables the active system-wide CGEventTap.
    /// LISTENS ONLY TO SCROLLWHEEL AND EXTRA MOUSE BUTTON CLICKS. Zero CPU overhead when idle.
    public func startTap() -> Bool {
        let eventsOfInterest: CGEventMask = (1 << CGEventType.scrollWheel.rawValue) |
                                            (1 << CGEventType.otherMouseDown.rawValue) |
                                            (1 << CGEventType.otherMouseUp.rawValue)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: eventTapCallback,
            userInfo: selfPointer
        )
        
        guard let validTap = tap else {
            logger.error("Failed to create CGEventTap. Ensure Accessibility permission is granted.")
            return false
        }
        
        self.eventTap = validTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, validTap, 0)
        self.runLoopSource = source
        
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: validTap, enable: true)
        
        logger.info("CGEventTap created and enabled successfully.")
        return true
    }
    
    /// Disables and removes the CGEventTap.
    public func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("CGEventTap stopped.")
    }
    
    // MARK: - Event Processing Algorithms
    
    /// Intercepts discrete scroll steps and feeds impulses to 120Hz kinetic scroll engine.
    fileprivate func processScrollEvent(cgEvent: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        guard isSmoothScrollEnabled else { return Unmanaged.passUnretained(cgEvent) }
        
        let isContinuous = cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous)
        if isContinuous != 0 {
            return Unmanaged.passUnretained(cgEvent)
        }
        
        let rawDeltaY = Double(cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let rawDeltaX = Double(cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        
        if rawDeltaY == 0 && rawDeltaX == 0 {
            return Unmanaged.passUnretained(cgEvent)
        }
        
        kineticEngine.addImpulse(deltaY: rawDeltaY, deltaX: rawDeltaX, flags: cgEvent.flags)
        return nil
    }
    
    /// Intercepts mouse button clicks and thumb gestures.
    fileprivate func processMouseEvent(cgEvent: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .otherMouseDown {
            let buttonNumber = cgEvent.getIntegerValueField(.mouseEventButtonNumber)
            
            if buttonNumber == 3 { // Side Back Button (Lower side button)
                logger.info("Side Back Button pressed (Button 3)")
                performAction(sideBackButtonAction)
                return nil
            } else if buttonNumber == 4 { // Side Forward Button (Upper side button)
                logger.info("Side Forward Button pressed (Button 4)")
                performAction(sideForwardButtonAction)
                return nil
            } else if buttonNumber == 5 || buttonNumber == 11 { // Thumb Rest Wing Gesture Button
                isThumbPressedInTap = true
                isGestureActive = true
                gestureStartX = cgEvent.location.x
                gestureStartY = cgEvent.location.y
                gestureTriggered = false
                return nil
            }
            return Unmanaged.passUnretained(cgEvent)
            
        } else if type == .otherMouseUp {
            let buttonNumber = cgEvent.getIntegerValueField(.mouseEventButtonNumber)
            if buttonNumber == 3 || buttonNumber == 4 {
                return nil // Consume side button release
            } else if buttonNumber == 5 || buttonNumber == 11 || isThumbPressedInTap {
                if isThumbPressedInTap && !gestureTriggered && isGestureActive {
                    executeGestureDirection(.click)
                }
                
                isThumbPressedInTap = false
                isGestureActive = false
                gestureTriggered = false
                return nil
            }
            return Unmanaged.passUnretained(cgEvent)
        }
        
        return Unmanaged.passUnretained(cgEvent)
    }
    
    private func executeGestureDirection(_ direction: GestureDirection) {
        let action: GestureAction
        switch direction {
        case .click: action = clickAction
        case .up:    action = upAction
        case .down:  action = downAction
        case .left:  action = leftAction
        case .right: action = rightAction
        }
        
        logger.info("Executing Gesture Direction: \(String(describing: direction)) -> Action: \(action.rawValue)")
        performAction(action)
    }
    
    /// Executes the target system action with clean, non-duplicated single dispatch calls.
    private func performAction(_ action: GestureAction) {
        switch action {
        case .navigateBack:
            postKeyboardShortcut(virtualKey: 0x7B, flags: .maskCommand)
            
        case .navigateForward:
            postKeyboardShortcut(virtualKey: 0x7C, flags: .maskCommand)
            
        case .missionControl:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.expose") ??
               URL(string: "file:///System/Applications/Mission%20Control.app") {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            } else {
                executeOSAScript("tell application \"System Events\" to key code 126 using control down")
            }
            
        case .launchpad:
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher") ??
               URL(string: "file:///System/Applications/Launchpad.app") {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
            
        case .appExpose:
            executeOSAScript("tell application \"System Events\" to key code 125 using control down")
            
        case .spaceLeft:
            executeOSAScript("tell application \"System Events\" to key code 123 using control down")
            
        case .spaceRight:
            executeOSAScript("tell application \"System Events\" to key code 124 using control down")
            
        case .showDesktop:
            executeOSAScript("tell application \"System Events\" to key code 103")
            
        case .mediaPlayPause:
            postKeyboardShortcut(virtualKey: 0x34, flags: [])
        }
    }
    
    /// Executes AppleScript out-of-process via /usr/bin/osascript.
    private func executeOSAScript(_ script: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }
    
    /// Synthesizes and posts a single key press + release CGEvent.
    private func postKeyboardShortcut(virtualKey: CGKeyCode, flags: CGEventFlags) {
        autoreleasepool {
            let source = CGEventSource(stateID: .hidSystemState)
            
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) {
                
                keyDown.flags = flags
                keyUp.flags = flags
                
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}

// MARK: - CGEventTap C Callback

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    
    return autoreleasepool {
        switch type {
        case .scrollWheel:
            return manager.processScrollEvent(cgEvent: event, type: type)
            
        case .otherMouseDown, .otherMouseUp:
            return manager.processMouseEvent(cgEvent: event, type: type)
            
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
