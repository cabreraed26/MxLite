//
//  ContentView.swift
//  MxLite
//
//  Created for MxLite - Ultra-lightweight Logitech MX Controller.
//  Optimized for macOS Apple Silicon.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var daemonManager: DaemonManager
    
    @State private var isAccessibilityGranted: Bool = false
    @State private var isSmoothScrollEnabled: Bool = true
    @State private var scrollSensitivity: Double = 1.5
    
    // Side Buttons State
    @State private var selectedSideBackButton: GestureAction = .navigateBack
    @State private var selectedSideForwardButton: GestureAction = .navigateForward
    
    // Thumb Gestures State
    @State private var selectedClickGesture: GestureAction = .missionControl
    @State private var selectedUpGesture: GestureAction = .missionControl
    @State private var selectedDownGesture: GestureAction = .appExpose
    @State private var selectedLeftGesture: GestureAction = .spaceLeft
    @State private var selectedRightGesture: GestureAction = .spaceRight
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magicmouse")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MxLite Controller")
                            .font(.headline)
                        Text("Logitech MX Master 3S & MX Keys Controller")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Active Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(daemonManager.isTapActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(daemonManager.isTapActive ? "Servicio Activo" : "Servicio Inactivo")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Hardware Connection Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estado del Dispositivo")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "dot.radiowaves.up.forward")
                                .foregroundStyle(daemonManager.connectedDeviceName.contains("Ningún") ? Color.secondary : Color.green)
                            Text(daemonManager.connectedDeviceName)
                                .font(.body)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
                    
                    // Accessibility Permissions Alert
                    if !isAccessibilityGranted {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Permiso de Accesibilidad Requerido")
                                    .font(.headline)
                            }
                            Text("MxLite necesita permiso de Accesibilidad para capturar los gestos del botón del pulgar de tu ratón Logitech.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button("Abrir Preferencias del Sistema") {
                                SecurityHelper.openAccessibilitySystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
                    }
                    
                    // Smooth Scrolling Settings Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Smooth Scrolling Inercial (120Hz Trackpad)")
                            .font(.headline)
                        
                        Toggle("Habilitar Desplazamiento Suave de Alta Resolución", isOn: $isSmoothScrollEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: isSmoothScrollEnabled) { _, newValue in
                                daemonManager.eventTapManager.isSmoothScrollEnabled = newValue
                            }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensibilidad e Inercia:")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1fx", scrollSensitivity))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .fontWeight(.semibold)
                            }
                            
                            Slider(value: $scrollSensitivity, in: 0.2...5.0, step: 0.1)
                                .onChange(of: scrollSensitivity) { _, newValue in
                                    daemonManager.eventTapManager.scrollSensitivity = newValue
                                }
                        }
                        .disabled(!isSmoothScrollEnabled)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
                    
                    // Side Buttons Customization (Upper Side Buttons)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Botones Laterales (Encima del Pulgar)")
                            .font(.headline)
                        
                        Text("Configura la acción para los botones laterales de navegación:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Label("Botón Trasero (Inferior)", systemImage: "arrow.uturn.backward")
                                Picker("", selection: $selectedSideBackButton) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedSideBackButton) { _, action in
                                    daemonManager.eventTapManager.sideBackButtonAction = action
                                }
                            }
                            
                            GridRow {
                                Label("Botón Delantero (Superior)", systemImage: "arrow.uturn.forward")
                                Picker("", selection: $selectedSideForwardButton) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedSideForwardButton) { _, action in
                                    daemonManager.eventTapManager.sideForwardButtonAction = action
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
                    
                    // Thumb Gestures Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Botón del Pulgar y Gestos (Ala Inferior)")
                            .font(.headline)
                        
                        Text("Configura la acción al presionar o arrastrar el botón del pulgar:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            
                            GridRow {
                                Label("Clic Simple (Sin mover)", systemImage: "hand.tap.fill")
                                Picker("", selection: $selectedClickGesture) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedClickGesture) { _, action in
                                    daemonManager.eventTapManager.clickAction = action
                                }
                            }
                            
                            GridRow {
                                Label("Arriba ↑", systemImage: "arrow.up")
                                Picker("", selection: $selectedUpGesture) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedUpGesture) { _, action in
                                    daemonManager.eventTapManager.upAction = action
                                }
                            }
                            
                            GridRow {
                                Label("Abajo ↓", systemImage: "arrow.down")
                                Picker("", selection: $selectedDownGesture) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedDownGesture) { _, action in
                                    daemonManager.eventTapManager.downAction = action
                                }
                            }
                            
                            GridRow {
                                Label("Izquierda ←", systemImage: "arrow.left")
                                Picker("", selection: $selectedLeftGesture) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedLeftGesture) { _, action in
                                    daemonManager.eventTapManager.leftAction = action
                                }
                            }
                            
                            GridRow {
                                Label("Derecha →", systemImage: "arrow.right")
                                Picker("", selection: $selectedRightGesture) {
                                    ForEach(GestureAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .onChange(of: selectedRightGesture) { _, action in
                                    daemonManager.eventTapManager.rightAction = action
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
                }
                .padding()
            }
        }
        .frame(minWidth: 560, minHeight: 580)
        .onAppear {
            checkPermissions()
            syncInitialValues()
        }
    }
    
    private func checkPermissions() {
        isAccessibilityGranted = SecurityHelper.checkAccessibilityPermissions(promptIfNeeded: false)
    }
    
    private func syncInitialValues() {
        let tapManager = daemonManager.eventTapManager
        isSmoothScrollEnabled = tapManager.isSmoothScrollEnabled
        scrollSensitivity = tapManager.scrollSensitivity
        selectedSideBackButton = tapManager.sideBackButtonAction
        selectedSideForwardButton = tapManager.sideForwardButtonAction
        selectedClickGesture = tapManager.clickAction
        selectedUpGesture = tapManager.upAction
        selectedDownGesture = tapManager.downAction
        selectedLeftGesture = tapManager.leftAction
        selectedRightGesture = tapManager.rightAction
    }
}
