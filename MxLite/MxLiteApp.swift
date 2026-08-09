//
//  MxLiteApp.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Pure Native AppKit Status Bar Agent App with ultra-low memory footprint (<15 MB RAM).
//  Zero SwiftUI.App runtime overhead.
//

import AppKit
import SwiftUI

/// Lightweight Native AppKit Custom View for Scroll Sensitivity Slider inside Status Bar Menu.
/// Memory Footprint: < 0.2 MB. Zero Metal/SwiftUI hosting overhead.
final class MenuBarSliderView: NSView {
    
    private let titleLabel = NSTextField(labelWithString: "Sensibilidad de Scroll:")
    private let valueLabel = NSTextField(labelWithString: "1.5x")
    private let slider = NSSlider(value: 1.5, minValue: 0.2, maxValue: 5.0, target: nil, action: nil)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .secondaryLabelColor
        
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        valueLabel.alignment = .right
        
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        
        let headerStack = NSStackView(views: [titleLabel, valueLabel])
        headerStack.orientation = .horizontal
        headerStack.distribution = .fill
        
        let mainStack = NSStackView(views: [headerStack, slider])
        mainStack.orientation = .vertical
        mainStack.spacing = 6
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        let val = (sender.doubleValue * 10).rounded() / 10
        valueLabel.stringValue = String(format: "%.1fx", val)
        DaemonManager.shared.eventTapManager.scrollSensitivity = val
    }
    
    public func syncValue() {
        let val = DaemonManager.shared.eventTapManager.scrollSensitivity
        slider.doubleValue = val
        valueLabel.stringValue = String(format: "%.1fx", val)
    }
}

/// Pure AppKit Application Delegate managing StatusItem, Native AppKit Menu, and Lazy Settings Window.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var sliderView: MenuBarSliderView?
    private var smoothScrollMenuItem: NSMenuItem?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start background daemon services
        DaemonManager.shared.start()
        
        // Setup Native Status Bar Menu
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "magicmouse", accessibilityDescription: "MxLite")
            button.toolTip = "MxLite - Controlador Logitech MX"
        }
        
        let menu = NSMenu()
        menu.delegate = self
        
        // 1. Header Status Item
        let statusTitle = "MxLite - " + DaemonManager.shared.connectedDeviceName
        let titleItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Smooth Scroll Toggle Item
        let smoothScrollItem = NSMenuItem(title: "Desplazamiento Suave (120Hz)", action: #selector(toggleSmoothScroll), keyEquivalent: "")
        smoothScrollItem.target = self
        smoothScrollItem.state = DaemonManager.shared.eventTapManager.isSmoothScrollEnabled ? .on : .off
        menu.addItem(smoothScrollItem)
        self.smoothScrollMenuItem = smoothScrollItem
        
        // 3. Native Slider Item
        let sliderItem = NSMenuItem()
        let sliderView = MenuBarSliderView(frame: NSRect(x: 0, y: 0, width: 220, height: 48))
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        self.sliderView = sliderView
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Open Preferences Window
        let settingsItem = NSMenuItem(title: "Configuración...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit App
        let quitItem = NSMenuItem(title: "Salir de MxLite", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        self.statusItem = statusItem
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        sliderView?.syncValue()
        smoothScrollMenuItem?.state = DaemonManager.shared.eventTapManager.isSmoothScrollEnabled ? .on : .off
    }
    
    @objc private func toggleSmoothScroll(_ sender: NSMenuItem) {
        let newState = !(sender.state == .on)
        sender.state = newState ? .on : .off
        DaemonManager.shared.eventTapManager.isSmoothScrollEnabled = newState
    }
    
    @objc public func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = ContentView()
            .environmentObject(DaemonManager.shared)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MxLite - Configuración de Gestos"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = true
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
