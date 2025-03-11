import SwiftUI

struct ManufacturerDistributionChart: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var manufacturersData: [(name: String, count: Int, percentage: Double)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manufacturer Distribution (Top 5)")
                .font(.headline)
            
            if medicineStore.medicines.isEmpty {
                EmptyChartView(message: "Add medicines to see manufacturer distribution")
            } else {
                VStack(spacing: 12) {
                    // Show the top manufacturers (or all if 5 or fewer)
                    ForEach(Array(manufacturersData.prefix(min(5, manufacturersData.count))), id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        // Bar chart
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                // Filled portion
                                Rectangle()
                                    .fill(manufacturerColor(for: item.name))
                                    .frame(width: calculateBarWidth(percentage: item.percentage, totalWidth: geometry.size.width), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        .id("bar-\(item.name)")
                    }
                    
                    // Only show "Other Manufacturers" if there are more than 5 manufacturers
                    if manufacturersData.count > 5 {
                        let otherCount = manufacturersData.dropFirst(5).reduce(0) { $0 + $1.count }
                        if otherCount > 0 {
                            Divider()
                                .padding(.vertical, 4)
                            
                            HStack {
                                Text("Other Manufacturers")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(otherCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            updateManufacturerData()
        }
        .onChange(of: medicineStore.medicines) { _ in
            updateManufacturerData()
        }
    }
    
    private func updateManufacturerData() {
        self.manufacturersData = manufacturerData()
    }
    
    private func calculateBarWidth(percentage: Double, totalWidth: CGFloat) -> CGFloat {
        return max(CGFloat(percentage) * totalWidth, percentage > 0 ? 2 : 0)
    }
    
    private func manufacturerData() -> [(name: String, count: Int, percentage: Double)] {
        var manufacturerCounts: [String: Int] = [:]
        
        // Process manufacturers, explicitly handling empty as "Unknown"
        for medicine in medicineStore.medicines {
            let manufacturer = medicine.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = manufacturer.isEmpty ? "Unknown" : manufacturer
            manufacturerCounts[name, default: 0] += 1
        }
        
        // Convert to array and sort
        let total = Double(medicineStore.medicines.count)
        var result = manufacturerCounts.map { (name: $0.key, count: $0.value, percentage: total > 0 ? Double($0.value) / total : 0) }
        
        // Sort by count in descending order
        result.sort { $0.count > $1.count }
        
        return result
    }
    
    private func manufacturerColor(for name: String) -> Color {
        // Use a consistent color for each manufacturer
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow]
        var hasher = Hasher()
        hasher.combine(name)
        let hash = abs(hasher.finalize())
        return colors[hash % colors.count]
    }
}
