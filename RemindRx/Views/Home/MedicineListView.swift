import SwiftUI

struct MedicineListView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    // Local state
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showingDeleteAllConfirmation = false
    @State private var selectedMedicine: Medicine? = nil
    @State private var isShowingTimeout = false // New state to handle loading timeout
    @State private var refreshTrigger = UUID() // Add a refresh trigger
    @State private var hasInitiallyLoaded = false // Track if we've done the initial load
    
    // Format date helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.mediumDate
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Filter toggle
                HStack {
                    Toggle("Show Expired Only", isOn: $medicineStore.showExpiredOnly)
                        .padding(.horizontal)
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Content based on data state
                Group {
                    // Only show loading on initial load and if still loading after a delay
                    if medicineStore.isLoading && !hasInitiallyLoaded {
                        LoadingView(message: "Loading medicines...")
                            .onAppear {
                                // If loading takes too long, mark as loaded anyway
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    hasInitiallyLoaded = true
                                }
                            }
                    } else if medicineStore.filteredMedicines.isEmpty {
                        EmptyStateView(
                            icon: "pills",
                            title: "No Medicines Found",
                            message: medicineStore.showExpiredOnly
                                ? "No expired medicines in your collection"
                                : "Add medicines to your collection by tapping the + button"
                        )
                    } else {
                        medicineList
                    }
                }
            }
            
            // Navigation destination for medicine detail
            // This is now hidden - we'll use programmatic navigation
            NavigationLink(
                destination: selectedMedicine.map { MedicineDetailView(medicine: $0) },
                isActive: Binding(
                    get: { selectedMedicine != nil },
                    set: { if !$0 { selectedMedicine = nil } }
                ),
                label: { EmptyView() }
            )
        }
        .navigationTitle("Medicines")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !medicineStore.medicines.isEmpty {
                    Button {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showScannerSheet = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    
                    Button {
                        medicineStore.draftMedicine = Medicine(
                            name: "",
                            description: "",
                            manufacturer: "",
                            type: .otc,
                            alertInterval: .week,
                            expirationDate: Date().addingTimeInterval(60*60*24*90)
                        )
                        showAddMedicineForm = true
                    } label: {
                        Label("Add Manually", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showScannerSheet) {
            BarcodeScannerView(
                onScanCompletion: { result in
                    self.showScannerSheet = false
                    switch result {
                    case .success(let barcode):
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
                },
                onCancel: {
                    showScannerSheet = false
                }
            )
        }
        .sheet(isPresented: $showAddMedicineForm) {
            NavigationView {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
        }
        .alert("Delete All Medicines", isPresented: $showingDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                medicineStore.deleteAll()
            }
        } message: {
            Text("Are you sure you want to delete all medicines? This action cannot be undone.")
        }
        .onAppear {
            // Reset timeout state and refresh data when view appears
            isShowingTimeout = false
            // Load medicines but don't show loading if we've already loaded
            if !hasInitiallyLoaded {
                medicineStore.loadMedicines()
            }
            //refreshTrigger = UUID()
        }
        .onDisappear {
            // Reset the loading flag when view disappears
            hasInitiallyLoaded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MedicineDataChanged"))) { _ in
            // Force refresh when medicine data changes
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Subviews
    
    /// Medicine list view
    private var medicineList: some View {
        List {
            ForEach(medicineStore.filteredMedicines, id: \.id) { medicine in
                MedicineRow(medicine: medicine)
                    .contentShape(Rectangle()) // Make entire cell tappable
                    .onTapGesture {
                        // Programmatically navigate to detail view
                        selectedMedicine = medicine
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            medicineStore.delete(medicine)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    // Use a more unique ID with the refresh trigger
                    .id("medicine-\(medicine.id)-\(refreshTrigger)")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            // Pull to refresh
            medicineStore.loadMedicines()
            refreshTrigger = UUID()
        }
    }
}

/// Row item for a medicine in the list
struct MedicineRow: View {
    let medicine: Medicine
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter.mediumDate
        return formatter.string(from: date)
    }
    
    private var isExpired: Bool {
        return medicine.expirationDate < Date()
    }
    
    private var isExpiringSoon: Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(medicine.name)
                    .font(.headline)
                // Use a Text view whose content is set in onAppear
                Text("Expires: \(formatDate(medicine.expirationDate))")
                    .font(.subheadline)
                    .foregroundColor(isExpired ? .red : .secondary)
            }
            
            Spacer()
            
            // Status indicator
            if isExpired {
                ExpiryBadgeView(status: .expired, compact: true)
            } else if isExpiringSoon {
                ExpiryBadgeView(status: .expiringSoon, compact: true)
            } else {
                ExpiryBadgeView(status: .valid, compact: true)
            }
            
            // Chevron icon to indicate navigation
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
        // We'll use a unique ID that includes the expiration date to force updates
        .id("medicine-row-\(medicine.id)-\(medicine.expirationDate.timeIntervalSince1970)")
    }
}

// Helper components to support the tracking view
struct ExpiryBadgeView: View {
    enum ExpiryStatus {
        case expired
        case expiringSoon
        case valid
        
        var color: Color {
            switch self {
            case .expired:
                return .red
            case .expiringSoon:
                return .yellow
            case .valid:
                return .green
            }
        }
        
        var text: String {
            switch self {
            case .expired:
                return "EXPIRED"
            case .expiringSoon:
                return "EXPIRING SOON"
            case .valid:
                return "VALID"
            }
        }
        
        var icon: String {
            switch self {
            case .expired:
                return "exclamationmark.circle.fill"
            case .expiringSoon:
                return "exclamationmark.triangle.fill"
            case .valid:
                return "checkmark.circle.fill"
            }
        }
    }
    
    let status: ExpiryStatus
    let compact: Bool
    
    init(status: ExpiryStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactBadge
        } else {
            fullBadge
        }
    }
    
    private var fullBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            
            Text(status.text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .foregroundColor(badgeForeground)
        .clipShape(Capsule())
    }
    
    private var compactBadge: some View {
        Image(systemName: status.icon)
            .font(.system(size: 16))
            .foregroundColor(status.color)
    }
    
    private var badgeBackground: Color {
        switch status {
        case .expired:
            return .red
        case .expiringSoon:
            return .yellow
        case .valid:
            return .green.opacity(0.2)
        }
    }
    
    private var badgeForeground: Color {
        switch status {
        case .expired:
            return .white
        case .expiringSoon:
            return .black
        case .valid:
            return .green
        }
    }
}

/// Loading view for async operations
struct LoadingView: View {
    var message: String = "Loading..." // Default message parameter
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty state for when there's no data to display
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Date Formatter Extensions

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
