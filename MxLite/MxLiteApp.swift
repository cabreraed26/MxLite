//
//  MxLiteApp.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Menu Bar Agent App with interactive Scroll Sensitivity Slider directly in status bar dropdown.
//

import SwiftUI
import AppKit

@main
struct MxLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// Custom Interactive View displayed directly inside the macOS Status Bar Dropdown Menu.
struct MenuBarContentView: View {
    @ObservedObject var daemonManager: DaemonManager = DaemonManager.shared
    @State private var isSmoothScrollEnabled: Bool = DaemonManager.shared.eventTapManager.isSmoothScrollEnabled
    @State private var scrollSensitivity: Double = DaemonManager.shared.eventTapManager.scrollSensitivity
    
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("MxLite")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                Text(daemonManager.connectedDeviceName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Divider()
            
            // Smooth Scroll Toggle
            Toggle(isOn: $isSmoothScrollEnabled) {
                Text("Desplazamiento Suave (120Hz)")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.switch)
            .onChange(of: isSmoothScrollEnabled) { _, newValue in
                daemonManager.eventTapManager.isSmoothScrollEnabled = newValue
            }
            
            // Scroll Sensitivity Slider (Lo de la sensibilidad)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensibilidad de Scroll:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fx", scrollSensitivity))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                
                Slider(value: $scrollSensitivity, in: 0.2...5.0, step: 0.1)
                    .onChange(of: scrollSensitivity) { _, newValue in
                        daemonManager.eventTapManager.scrollSensitivity = newValue
                    }
            }
            .disabled(!isSmoothScrollEnabled)
            
            Divider()
            
            // Action Buttons Footer
            HStack {
                Button(action: onOpenSettings) {
                    Label("Más Ajustes...", systemImage: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(action: onQuit) {
                    Label("Salir", systemImage: "power")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}

/// Application Delegate managing StatusItem and Custom NSHostingView dropdown.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start background HID & EventTap daemon
        DaemonManager.shared.start()
        
        // Setup Menu Bar StatusItem with Custom SwiftUI Content View
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "magicmouse", accessibilityDescription: "MxLite")
            button.toolTip = "MxLite - Ajustes Rápidos"
        }
        
        let menu = NSMenu()
        
        let customItem = NSMenuItem()
        let menuView = MenuBarContentView(
            onOpenSettings: { [weak self] in
                self?.statusItem?.menu?.cancelTracking()
                self?.openSettingsWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        
        let hostingView = NSHostingView(rootView: menuView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 165)
        customItem.view = hostingView
        menu.addItem(customItem)
        
        statusItem.menu = menu
        self.statusItem = statusItem
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
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
