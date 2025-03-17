//
//  ModernDashboardVie.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI

struct ModernDashboardView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showTwoStepOCR = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var showOCRWarning = false
    @State private var selectedMedicine: Medicine? = nil
    @State private var showingScanningTip = !UserDefaults.standard.bool(forKey: "hasDismissedScanningTip")

    private func refreshAllData() {
        medicineStore.loadMedicines()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with app info and icon
                headerSection
                
                // Quick tip about scanning (if not dismissed)
                if showingScanningTip {
                    QuickTipView(
                        iconName: "barcode.viewfinder",
                        title: "Remember: Barcode Scanning is Recommended",
                        message: "For best results, use the Scan button first. If the barcode isn't available or recognized, try OCR or manual entry as backup methods.",
                        actionTitle: "Show Me How",
                        action: {
                            // Show alert with instructions
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
                            UserDefaults.standard.set(true, forKey: "hasDismissedScanningTip")
                        }
                    )
                    .padding(.horizontal)
                }
                
                // Quick stats section
                quickStatsSection
                
                // Section 1: Medicine Catalog Management
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "Medicine Catalog", icon: "pills")
                    
                    // Medicine management options in a grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                        spacing: 16
                    ) {
                        // Scan button
                        ModernDashboardButton(
                            title: "Scan",
                            icon: "barcode.viewfinder",
                            iconColor: .blue,
                            action: {
                                showScannerSheet = true
                            }
                        )

                        // OCR button
                        ModernDashboardButton(
                            title: "OCR",
                            icon: "text.viewfinder",
                            iconColor: .orange,
                            action: {
                                showOCRWarning = true
                            }
                        )

                        // Add manually button
                        ModernDashboardButton(
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
                .padding(.horizontal)
                
                // Section 2: Upcoming Features
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "Upcoming Features", icon: "sparkles")
                    
                    // Upcoming features in a grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                        spacing: 16
                    ) {
                        // Schedule button - Coming Soon
                        ModernDashboardButton(
                            title: "Schedule",
                            icon: "calendar.badge.clock",
                            iconColor: .green,
                            action: {
                                inDevelopmentFeature = "Medicine Scheduling"
                                showFeatureInDevelopment = true
                            },
                            isComingSoon: true
                        )

                        // Refill button - Coming Soon
                        ModernDashboardButton(
                            title: "Refill",
                            icon: "arrow.clockwise.circle",
                            iconColor: .purple,
                            action: {
                                inDevelopmentFeature = "Medication Refills"
                                showFeatureInDevelopment = true
                            },
                            isComingSoon: true
                        )
                    }
                }
                .padding(.horizontal)
                
                // Empty space at the bottom for better scrolling
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            refreshAllData()
        }
        // Add your sheets and alerts here
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
        .sheet(isPresented: $showTwoStepOCR) {
            DirectTwoStepOCRView { result in
                handleOCRResult(result)
            }
        }
        .sheet(isPresented: $showFeatureInDevelopment) {
            ComingSoonFeatureView(featureName: inDevelopmentFeature)
        }
        .alert("OCR Capture Information", isPresented: $showOCRWarning) {
            Button("Continue", role: .none) {
                showTwoStepOCR = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will guide you through capturing your medicine information in two simple steps.")
        }
    }
    
    // MARK: - UI Components
    
    // Header section with app name and icon
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("RemindRx")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.blue)

                    Text("Medicine Manager")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // App logo/icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "pills")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            
            // Add decorative divider
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 3)
                .cornerRadius(1.5)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    // Quick stats card showing medicine counts
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            // Total medicines stat
            statCard(
                count: medicineStore.medicines.count,
                label: "Total",
                icon: "pill",
                color: .blue
            )
            
            // Expiring soon stat
            statCard(
                count: medicineStore.expiringSoonMedicines.count,
                label: "Expiring Soon",
                icon: "exclamationmark.triangle",
                color: .orange
            )
            
            // Expired stat
            statCard(
                count: medicineStore.expiredMedicines.count,
                label: "Expired",
                icon: "xmark.circle",
                color: .red
            )
        }
        .padding(.horizontal)
    }
    
    // Individual stat card
    private func statCard(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            
            // Count
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            // Label
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
    
    // Section header with icon
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            // Icon in circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.top, 8)
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
