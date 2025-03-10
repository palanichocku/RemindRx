import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTestDataGenerator = false
    
    // Use a string for the retention period since we can't find the enum
    @State private var retentionPeriod: String = "6 Months"
    private let retentionOptions = [
        "2 Weeks", "1 Month", "3 Months", "6 Months", "1 Year", "2 Years", "Forever"
    ]
    
    var body: some View {
        List {
            Section(header: Text("Data Retention")) {
                Picker("History Retention", selection: $retentionPeriod) {
                    ForEach(retentionOptions, id: \.self) { period in
                        Text(period).tag(period)
                    }
                }
                .onChange(of: retentionPeriod) { newValue in
                    // Update the adherence store retention period
                    UserDefaults.standard.set(retentionPeriod, forKey: "historyRetentionPeriod")
                    
                    // You'll need to convert string to days in the store
                    let days = stringToDays(retentionPeriod)
                    adherenceStore.applyRetentionPolicy(days: days)
                }
                
                Button(action: {
                    // Convert current retention period to days
                    let days = stringToDays(retentionPeriod)
                    adherenceStore.applyRetentionPolicy(days: days)
                }) {
                    Label("Clean Up Old Records", systemImage: "trash")
                }
                .foregroundColor(.blue)
            }
            
            Section(header: Text("Account")) {
                // Replace ProfileView with a placeholder for now
                Button(action: {
                    // Show profile settings (placeholder)
                }) {
                    Label("Profile Settings", systemImage: "person.crop.circle")
                }
                
                // Replace NotificationSettingsView with a placeholder
                Button(action: {
                    // Show notification settings (placeholder)
                }) {
                    Label("Notification Settings", systemImage: "bell")
                }
                
                Button(action: {
                    showingLogoutConfirmation = true
                }) {
                    Label("Log Out", systemImage: "arrow.right.square")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Data Management")) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
                
                #if DEBUG
                Button(action: {
                    showingTestDataGenerator = true
                }) {
                    Label("Generate Test Data", systemImage: "wand.and.stars")
                        .foregroundColor(.purple)
                }
                #endif
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.gray)
                }
                
                Link(destination: URL(string: "https://www.remindrx.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
                
                Link(destination: URL(string: "https://www.remindrx.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                
                Link(destination: URL(string: "https://www.remindrx.com/support")!) {
                    Label("Support", systemImage: "questionmark.circle")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .alert(isPresented: $showingLogoutConfirmation) {
            Alert(
                title: Text("Log Out"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Log Out")) {
                    // Perform logout
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteConfirmationView(isPresented: $showingDeleteConfirmation)
        }
        .sheet(isPresented: $showingTestDataGenerator) {
            TestDataView()
        }
        .onAppear {
            // Load saved retention period
            if let savedPeriod = UserDefaults.standard.string(forKey: "historyRetentionPeriod") {
                retentionPeriod = savedPeriod
            }
        }
    }
    
    // Convert retention period string to days
    private func stringToDays(_ period: String) -> Int {
        switch period {
        case "2 Weeks": return 14
        case "1 Month": return 30
        case "3 Months": return 90
        case "6 Months": return 180
        case "1 Year": return 365
        case "2 Years": return 730
        case "Forever": return Int.max
        default: return 180 // Default to 6 months
        }
    }
}

struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding()
                
                Text("Delete All Data")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("This will permanently delete all your medicines, schedules, and history records. This action cannot be undone.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    // Delete all data
                    medicineStore.deleteAllMedicinesWithCleanup()
                    isPresented = false
                }) {
                    Text("Permanently Delete All Data")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Confirm Deletion", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}
