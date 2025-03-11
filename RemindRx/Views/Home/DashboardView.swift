import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore

    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var selectedMedicine: Medicine? = nil

    private func refreshAllData() {
        medicineStore.loadMedicines()
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

                // Quick action buttons - 3 icons in a grid
                quickActionsGridSection
                    .padding(.horizontal)

                // Empty space at the bottom to make it look nice
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
        .alert(isPresented: $showFeatureInDevelopment) {
            Alert(
                title: Text("Coming Soon"),
                message: Text(
                    "\(inDevelopmentFeature) feature is currently under development and will be available in a future update."
                ),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            refreshAllData()
        }
        // Navigation to medicine detail
        .background(
            NavigationLink(
                destination: selectedMedicine.map {
                    MedicineDetailView(medicine: $0)
                },
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
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 20
        ) {
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
                        expirationDate: Date().addingTimeInterval(
                            60 * 60 * 24 * 90)
                    )
                    showAddMedicineForm = true
                }
            )

            // Schedule button - Coming Soon
            DashboardButton(
                title: "Schedule",
                description: "Medicine schedules",
                icon: "calendar.badge.clock",
                iconColor: .green,
                action: {
                    inDevelopmentFeature = "Medicine Scheduling"
                    showFeatureInDevelopment = true
                }
            )

            // Refill button - Coming Soon
            DashboardButton(
                title: "Refill",
                description: "Manage medication refills",
                icon: "arrow.clockwise.circle",
                iconColor: .purple,
                action: {
                    inDevelopmentFeature = "Medication Refills"
                    showFeatureInDevelopment = true
                }
            )
        }
    }

    // MARK: - Helper Methods

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
                            expirationDate: Date().addingTimeInterval(
                                60 * 60 * 24 * 90),
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
                expirationDate: Date().addingTimeInterval(60 * 60 * 24 * 90)
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
