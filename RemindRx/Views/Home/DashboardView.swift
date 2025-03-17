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
    @State private var showingScanningTip = !UserDefaults.standard.bool(forKey: "hasDismissedScanningTip")
    //@State private var showingScanningTip = !UserDefaults.standard.bool(forKey: "hasDismissedScanningTip")

    private func refreshAllData() {
        medicineStore.loadMedicines()
    }
    
    var body: some View {
        ScrollView {
            
            if showingScanningTip {
                QuickTipView(
                    iconName: "barcode.viewfinder",
                    title: "Remember: Barcode Scanning is Recommended",
                    message: "For best results, use the Scan button first. If the barcode isn't available or recognized, try OCR or manual entry as backup methods.",
                    actionTitle: "Show Me How",
                    action: {
                        // Add actual functionality here
                        // For example, you could show a brief tutorial or highlight the scan button
                        
                        // Simple approach: show an alert with more detailed instructions
                        let alert = UIAlertController(
                            title: "How to Scan Medicines",
                            message: "1. Tap the 'Scan' button\n2. Position your camera so the barcode is within the scanning frame\n3. Hold steady until the barcode is detected\n\nIf scanning fails, try the OCR button to capture text from the package, or add medicine details manually.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Got it", style: .default))
                        
                        // Present the alert
                        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
                    },
                    dismissAction: {
                        showingScanningTip = false
                        
                        // Optionally, save this preference so the tip stays dismissed
                        UserDefaults.standard.set(true, forKey: "hasDismissedScanningTip")
                    }
                )
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
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
                        ], spacing: 12
                    ) {
                        // Scan button
                        DashboardButton(
                            title: "Scan",
                            icon: "barcode.viewfinder",
                            iconColor: .blue,
                            action: {
                                showScannerSheet = true
                            }
                        )

                        // OCR button
                        DashboardButton(
                            title: "OCR",
                            icon: "text.viewfinder",
                            iconColor: .orange,
                            action: {
                                showOCRWarning = true
                            }
                        )

                        // Add manually button
                        DashboardButton(
                            title: "Add",
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
                        ], spacing: 12
                    ) {
                        // Schedule button - Coming Soon
                        DashboardButton(
                            title: "Schedule",
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
                // Use the fixed version instead
                DirectTwoStepOCRView { result in
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
            // Set a small delay to ensure alert is dismissed first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTwoStepOCR = true
                }
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
        medicineStore.draftMedicine = Medicine(
            name: result.name,
            description: result.description,
            manufacturer: result.manufacturer,
            type: result.isPrescription ? .prescription : .otc,
            alertInterval: .week, // Default alert interval
            expirationDate: result.expirationDate ?? Date().addingTimeInterval(60 * 60 * 24 * 90),
            barcode: result.barcode,
            source: "OCR Capture"
        )
        
        // Show the form for editing/confirmation
        showAddMedicineForm = true
    }
}

// Simple design for dashboard buttons
// Updated DashboardButton with no descriptions and square-like appearance

struct DashboardButton: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .frame(height: 36) // Fixed height for icon
                
                // Title only (no description)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100) // Fixed height for square-like appearance
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}
