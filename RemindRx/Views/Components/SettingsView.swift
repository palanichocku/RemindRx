//
//  SettingsView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/7/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showAboutView = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }
                
                Text("Receive alerts when medicines are about to expire")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("App Information")) {
                NavigationLink(destination: AboutView()) {
                    Label("About RemindRx", systemImage: "info.circle")
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppConstants.appVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(AppConstants.appBuild)
                        .foregroundColor(.secondary)
                }
            }
            
            #if DEBUG
            // Development options section (only in debug builds)
            Section(header: Text("Development")) {
                NavigationLink(destination: TestDataView()) {
                    Label("Test Data Generator", systemImage: "hammer.fill")
                        .foregroundColor(.purple)
                }
            }
            #endif
            
            Section {
                Link(destination: URL(string: AppConstants.websiteURL)!) {
                    HStack {
                        Label("Visit Website", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                
                Link(destination: URL(string: "mailto:\(AppConstants.supportEmail)")!) {
                    HStack {
                        Label("Contact Support", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
            
            if !granted {
                // If permission denied, update the toggle
                DispatchQueue.main.async {
                    self.notificationsEnabled = false
                }
            }
        }
    }
}

// If you need a TestDataView reference for the debug section, but don't want to implement it yet
#if DEBUG

#endif
