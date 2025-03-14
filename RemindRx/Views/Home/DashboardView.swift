import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showTwoStepOCR = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var selectedMedicine: Medicine? = nil
    @State private var showOCRWarning = false

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

                // Section 1: Medicine Catalog Management
                VStack(alignment: .leading, spacing: 16) {
                    Text("Medicine Catalog")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Medicine management options in a grid
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

                        // OCR button
                        DashboardButton(
                            title: "OCR",
                            description: "Capture with camera",
                            icon: "text.viewfinder",
                            iconColor: .orange,
                            action: {
                                showOCRWarning = true
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
                    }
                }
                .padding(.vertical)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Section 2: Upcoming Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upcoming Features")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Upcoming features in a grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 20
                    ) {
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
                .padding(.vertical)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
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
        .sheet(isPresented: $showTwoStepOCR) {
            TwoStepOCRView { result in
                handleOCRResult(result)
            }
        }
        .sheet(isPresented: $showAddMedicineForm) {
            NavigationView {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
        }
        .sheet(isPresented: $showFeatureInDevelopment) {
            ComingSoonFeatureView(featureName: inDevelopmentFeature)
        }
        .alert("OCR Capture Information", isPresented: $showOCRWarning) {
            Button("Continue", role: .none) {
                showTwoStepOCR = true
            }
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: {
            Text("OCR capture works in two steps:\n\n1. Scan the medicine packaging to capture general information\n\n2. Optionally scan the expiration date if it appears on a different part of the packaging\n\nYou can always edit details after scanning.")
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
    
    private func handleOCRResult(_ result: OCRResult) {
        // Create a pre-filled medicine based on OCR results
        let medicine = Medicine(
            name: result.name,
            description: result.description,
            manufacturer: result.manufacturer,
            type: result.isPrescription ? .prescription : .otc,
            alertInterval: .week, // Default alert interval
            expirationDate: result.expirationDate ?? Date().addingTimeInterval(60 * 60 * 24 * 90),
            dateAdded: Date(),
            barcode: result.barcode,
            source: "OCR Capture"
        )
        
        // Set as draft medicine and show form
        medicineStore.draftMedicine = medicine
        showAddMedicineForm = true
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
