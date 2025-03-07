//
//  Dashboard.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/7/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showTrackingView = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var selectedMedicine: Medicine? = nil
    
    private func refreshAllData() {
        medicineStore.loadMedicines()
        adherenceStore.refreshAllData()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("RemindRx")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryFallback())
                        
                        Text("Medicine Management")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // App logo/icon
                    Image(systemName: "pills")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primaryFallback())
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Summary cards
                summaryCardsSection
                
                // Quick action buttons
                quickActionsGridSection
                    .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 5)
                
                // Medicine list section
                medicineListSection
                
                // Today's doses section
                if !adherenceStore.todayDoses.isEmpty {
                    Divider()
                        .padding(.vertical, 5)
                    
                    todayDosesSection
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showScannerSheet) {
            BarcodeScannerView(
                onScanCompletion: { result in
                    self.showScannerSheet = false
                    handleScanResult(result: result)
                },
                onCancel: {
                    self.showScannerSheet = false
                }
            )
        }
        .sheet(isPresented: $showAddMedicineForm) {
            NavigationView {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
        }
        .sheet(isPresented: $showTrackingView) {
            AdherenceTrackingView()
        }
        .alert(isPresented: $showFeatureInDevelopment) {
            Alert(
                title: Text("Coming Soon"),
                message: Text("\(inDevelopmentFeature) feature is currently under development and will be available in a future update."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            refreshAllData()
        }
        // Navigation to medicine detail
        .background(
            NavigationLink(
                destination: selectedMedicine.map { MedicineDetailView(medicine: $0) },
                isActive: Binding(
                    get: { selectedMedicine != nil },
                    set: { if !$0 { selectedMedicine = nil } }
                ),
                label: { EmptyView() }
            )
            .hidden()
        )
    }
    
    // MARK: - Section Views
    
    private var summaryCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                // Total medicines
                summaryCard(
                    title: "Total Medicines",
                    value: "\(medicineStore.medicines.count)",
                    icon: "pills.fill",
                    color: .blue
                )
                
                // Expired medicines
                summaryCard(
                    title: "Expired",
                    value: "\(medicineStore.expiredMedicines.count)",
                    icon: "exclamationmark.circle.fill",
                    color: .red
                )
                
                // Expiring soon
                summaryCard(
                    title: "Expiring Soon",
                    value: "\(medicineStore.expiringSoonMedicines.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .yellow
                )
                
                // Today's doses
                summaryCard(
                    title: "Today's Doses",
                    value: "\(adherenceStore.todayDoses.count)",
                    icon: "calendar.badge.clock.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var quickActionsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            // Scan button
            DashboardButton(
                title: "Scan",
                description: "Scan medicine barcode",
                icon: "barcode.viewfinder",
                iconColor: .blue,
                action: {
                    showScannerSheet = true
                }
            )
            
            // Track button
            DashboardButton(
                title: "Track",
                description: "Track medication adherence",
                icon: "list.bullet.clipboard",
                iconColor: .green,
                action: {
                    showTrackingView = true
                }
            )
            
            // Report button
            DashboardButton(
                title: "Report",
                description: "View medication reports",
                icon: "chart.bar.doc.horizontal",
                iconColor: .orange,
                action: {
                    inDevelopmentFeature = "Medication Reports"
                    showFeatureInDevelopment = true
                }
            )
            
            // Add manually button
            DashboardButton(
                title: "Add",
                description: "Add medicine manually",
                icon: "plus.circle",
                iconColor: .purple,
                action: {
                    medicineStore.draftMedicine = Medicine(
                        name: "",
                        description: "",
                        manufacturer: "",
                        type: .otc,
                        alertInterval: .week,
                        expirationDate: Date().addingTimeInterval(60*60*24*90)
                    )
                    showAddMedicineForm = true
                }
            )
        }
    }
    
    private var medicineListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Medicines")
                    .font(.headline)
                    .padding(.horizontal)
                
                Spacer()
                
                NavigationLink(destination: MedicineListView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(AppColors.primaryFallback())
                }
                .padding(.horizontal)
            }
            
            if medicineStore.medicines.isEmpty {
                emptyMedicinesView
            } else {
                recentMedicinesView
            }
        }
    }
    
    private var recentMedicinesView: some View {
        VStack(spacing: 10) {
            ForEach(medicineStore.medicines.prefix(3)) { medicine in
                medicineCardView(medicine: medicine)
                    .onTapGesture {
                        selectedMedicine = medicine
                    }
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyMedicinesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No medicines added")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Scan a medicine barcode to add it to your collection")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showScannerSheet = true
            }) {
                Text("Scan Barcode")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primaryFallback())
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var todayDosesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Doses")
                    .font(.headline)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    showTrackingView = true
                }) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(AppColors.primaryFallback())
                }
                .padding(.horizontal)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(adherenceStore.todayDoses.prefix(5)) { dose in
                        doseCardView(dose: dose)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Component Views
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(width: 150, height: 100)
    }
    
    private func medicineCardView(medicine: Medicine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(medicine.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Expires: \(formatDate(medicine.expirationDate))")
                    .font(.subheadline)
                    .foregroundColor(medicine.expirationDate < Date() ? .red : .secondary)
            }
            
            Spacer()
            
            // Status indicator
            if medicine.expirationDate < Date() {
                ExpiryBadgeView(status: .expired, compact: true)
            } else if isExpiringSoon(medicine) {
                ExpiryBadgeView(status: .expiringSoon, compact: true)
            } else {
                ExpiryBadgeView(status: .valid, compact: true)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func doseCardView(dose: AdherenceTrackingStore.TodayDose) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: dose.medicine.type == .prescription ? "pills.fill" : "cross.case.fill")
                    .foregroundColor(dose.medicine.type == .prescription ? .blue : .green)
                
                Spacer()
                
                if let status = dose.status {
                    statusIcon(for: status)
                } else {
                    Text("Due")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
            }
            
            Text(dose.medicine.name)
                .font(.headline)
                .lineLimit(1)
            
            Text(formatTime(dose.scheduledTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .frame(width: 150, height: 120)
    }
    
    private func statusIcon(for status: MedicationDose.DoseStatus) -> some View {
        switch status {
        case .taken:
            return Text("Taken")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(10)
        case .missed:
            return Text("Missed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(10)
        case .skipped:
            return Text("Skipped")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ medicine: Medicine) -> Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    private func handleScanResult(result: Result<String, Error>) {
        switch result {
        case .success(let barcode):
            // Handle successful scan
            medicineStore.lookupDrug(barcode: barcode) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let medicine):
                        // Pre-populate form with found data
                        medicineStore.draftMedicine = medicine
                        showAddMedicineForm = true
                    case .failure:
                        // Show empty form for manual entry
                        medicineStore.draftMedicine = Medicine(
                            name: "",
                            description: "",
                            manufacturer: "",
                            type: .otc,
                            alertInterval: .week,
                            expirationDate: Date().addingTimeInterval(60*60*24*90),
                            barcode: barcode
                        )
                        showAddMedicineForm = true
                    }
                }
            }
        case .failure:
            // Show empty form for manual entry on scan failure
            medicineStore.draftMedicine = Medicine(
                name: "",
                description: "",
                manufacturer: "",
                type: .otc,
                alertInterval: .week,
                expirationDate: Date().addingTimeInterval(60*60*24*90)
            )
            showAddMedicineForm = true
        }
    }
}

// Simple design for dashboard buttons
struct DashboardButton: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(iconColor)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}
