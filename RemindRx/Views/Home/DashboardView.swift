import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showTrackingView = false
    @State private var todayDosesTabIndex = 0 // To store which tab to show in tracking view
    @State private var showReportView = false
    @State private var showRefillView = false
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
                
                // Quick action buttons - 5 icons in a grid
                quickActionsGridSection
                    .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 5)
                
                // Today's doses section - if there are any doses today
                if !adherenceStore.todayDoses.isEmpty {
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
            DosageTrackingView()
        }
        .sheet(isPresented: $showReportView) {
            ReportView() // New view for reports including stats
        }
        .sheet(isPresented: $showRefillView) {
            RefillManagementView() // New view for refill management
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
    
    private var quickActionsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
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
            
    // New Today/Dosage button
    DashboardButton(
        title: "Dosage",
        description: "Track your medications",
        icon: "pills.circle.fill",
        iconColor: .green,
        action: {
            showTrackingView = true
        }
    )
            
            // Report button
            DashboardButton(
                title: "Report",
                description: "View stats & reports",
                icon: "chart.bar.doc.horizontal",
                iconColor: .orange,
                action: {
                    showReportView = true
                }
            )
            
            // Refill button
            DashboardButton(
                title: "Refill",
                description: "Manage medication refills",
                icon: "arrow.clockwise.circle",
                iconColor: .purple,
                action: {
                    // Use feature-in-development until implemented
                    inDevelopmentFeature = "Medication Refills"
                    showFeatureInDevelopment = true
                    // Uncomment when implemented
                    // showRefillView = true
                }
            )
            
            // Add manually button
            DashboardButton(
                title: "Add",
                description: "Add medicine manually",
                icon: "plus.circle",
                iconColor: .indigo,
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
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

// New Report View that includes the statistics from before
struct ReportView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats summary cards - moved from dashboard
                    statsCardsSection
                    
                    Divider()
                        .padding(.vertical, 5)
                    
                    // Adherence Chart
                    adherenceChartSection
                    
                    Divider()
                        .padding(.vertical, 5)
                    
                    // Medicine Type Breakdown
                    medicineTypesSection
                    
                    // Export options and other report features can be added here
                }
                .padding()
            }
            .navigationTitle("Medicine Reports")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var statsCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Medicine Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // Total medicines
                    statCard(
                        title: "Total Medicines",
                        value: "\(medicineStore.medicines.count)",
                        icon: "pills.fill",
                        color: .blue
                    )
                    
                    // Expired medicines
                    statCard(
                        title: "Expired",
                        value: "\(medicineStore.expiredMedicines.count)",
                        icon: "exclamationmark.circle.fill",
                        color: .red
                    )
                    
                    // Expiring soon
                    statCard(
                        title: "Expiring Soon",
                        value: "\(medicineStore.expiringSoonMedicines.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .yellow
                    )
                    
                    // Today's doses
                    statCard(
                        title: "Today's Doses",
                        value: "\(adherenceStore.todayDoses.count)",
                        icon: "calendar.badge.clock.fill",
                        color: .green
                    )
                }
            }
        }
    }
    
    private var adherenceChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adherence Trends")
                .font(.headline)
                .padding(.horizontal)
            
            // Placeholder for chart - would be replaced with actual chart
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                VStack {
                    Text("Adherence Chart")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }
    
    private var medicineTypesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Medicine Types")
                .font(.headline)
                .padding(.horizontal)
            
            // Placeholder for breakdown - would be replaced with actual visualization
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                VStack {
                    Text("Medicine Type Breakdown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
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
}

// Placeholder for Refill Management
struct RefillManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 70))
                    .foregroundColor(.purple)
                    .padding()
                
                Text("Refill Management")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Track and manage your medicine refills")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("This feature is coming soon")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Refill Management")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
