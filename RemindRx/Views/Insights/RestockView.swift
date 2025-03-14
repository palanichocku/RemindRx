import SwiftUI

struct RestockView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    // Define timeframe types
    enum TimeframeUnit: String, CaseIterable, Identifiable {
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        
        var id: String { self.rawValue }
    }
    
    // Filter state
    @State private var selectedTimeframeUnit: TimeframeUnit = .months
    @State private var timeframeValue: Int = 1
    @State private var includeExpired: Bool = true
    @State private var showFilterOptions: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter section
            filterSection
            
            Divider()
            
            if filteredMedicines.isEmpty {
                emptyStateView
            } else {
                // Items list
                medicinesList
            }
        }
        .onAppear {
            // Start with filter options expanded
            showFilterOptions = true
        }
    }
    
    // MARK: - View Components
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Filter header with expand/collapse
            HStack {
                Text("Filter Options")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showFilterOptions.toggle()
                    }
                }) {
                    Image(systemName: showFilterOptions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Expanded filter options
            if showFilterOptions {
                VStack(spacing: 12) {
                    // Timeframe selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show medicines expiring within:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Custom segmented control
                        timeUnitSelector
                    }
                    
                    // Timeframe value stepper
                    Stepper(value: $timeframeValue, in: 1...99) {
                        Text("\(timeframeValue) \(selectedTimeframeUnit.rawValue.lowercased())")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Include expired toggle - part of expanded options
                    Toggle("Include expired medicines", isOn: $includeExpired)
                }
                .padding(.horizontal)
            }
            
            // Filter summary - always visible
            Text("Showing medicines \(includeExpired ? "including expired items " : "")expiring within \(timeframeValue) \(selectedTimeframeUnit.rawValue.lowercased())")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var timeUnitSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeframeUnit.allCases) { unit in
                Button(action: {
                    selectedTimeframeUnit = unit
                    // Reset value to appropriate defaults when changing units
                    switch unit {
                    case .days:
                        timeframeValue = 7
                    case .weeks:
                        timeframeValue = 2
                    case .months:
                        timeframeValue = 1
                    }
                }) {
                    Text(unit.rawValue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedTimeframeUnit == unit ?
                                   Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedTimeframeUnit == unit ?
                                         .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(medicineStore.medicines.isEmpty
                ? "Add medicines to generate a Restock list"
                : "No medicines match your current filter settings")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var medicinesList: some View {
        List {
            ForEach(filteredMedicines) { item in
                RestockItemRow(item: item)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Data Processing
    
    private var filteredMedicines: [Medicine] {
        // Calculate the cutoff date based on the selected timeframe
        let calendar = Calendar.current
        let now = Date()
        
        let cutoffDate: Date
        switch selectedTimeframeUnit {
        case .days:
            cutoffDate = calendar.date(byAdding: .day, value: timeframeValue, to: now) ?? now
        case .weeks:
            cutoffDate = calendar.date(byAdding: .weekOfYear, value: timeframeValue, to: now) ?? now
        case .months:
            cutoffDate = calendar.date(byAdding: .month, value: timeframeValue, to: now) ?? now
        }
        
        // Filter medicines
        return medicineStore.medicines.filter { medicine in
            // Check if it's expired and we're including expired medicines
            let isExpired = medicine.expirationDate < now
            
            // Check if it's within the cutoff date
            let isWithinTimeframe = medicine.expirationDate <= cutoffDate
            
            // Include if it meets our criteria
            return (isExpired && includeExpired) || (!isExpired && isWithinTimeframe)
        }
        .sorted { $0.expirationDate < $1.expirationDate } // Sort by expiration date (soonest first)
    }
}

struct RestockItemRow: View {
    let item: Medicine
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text(item.manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: isExpired ? "exclamationmark.circle.fill" : "clock")
                        .foregroundColor(isExpired ? .red : .orange)
                        .font(.caption)
                    
                    Text(isExpired ? "Expired on \(formatDate(item.expirationDate))" : "Expires on \(formatDate(item.expirationDate))")
                        .font(.caption)
                        .foregroundColor(isExpired ? .red : .orange)
                }
                
                // Time remaining indicator (only show if not expired)
                if !isExpired {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(timeRemainingText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Type badge
            Text(item.type.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.type == .prescription ? Color.blue : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding(.vertical, 4)
    }
    
    // Enhanced helper properties
    private var isExpired: Bool {
        return item.expirationDate < Date()
    }
    
    private var timeRemainingText: String {
        let calendar = Calendar.current
        let now = Date()
        
        if isExpired {
            return "Expired"
        }
        
        // Calculate components
        let components = calendar.dateComponents([.day, .month], from: now, to: item.expirationDate)
        
        if let months = components.month, months > 0 {
            let monthText = months == 1 ? "month" : "months"
            if let days = components.day, days > 0 {
                return "\(months) \(monthText), \(days) days left"
            } else {
                return "\(months) \(monthText) left"
            }
        } else if let days = components.day, days > 0 {
            if days >= 7 {
                let weeks = days / 7
                let remainingDays = days % 7
                if remainingDays > 0 {
                    return "\(weeks) week\(weeks == 1 ? "" : "s"), \(remainingDays) day\(remainingDays == 1 ? "" : "s") left"
                } else {
                    return "\(weeks) week\(weeks == 1 ? "" : "s") left"
                }
            } else {
                return "\(days) day\(days == 1 ? "" : "s") left"
            }
        } else {
            return "Expiring today"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
