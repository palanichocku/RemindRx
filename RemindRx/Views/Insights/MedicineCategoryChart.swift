//
//  MedicineCategoryChart.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//
import SwiftUI

struct MedicineCategoryChart: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medicine Categories")
                .font(.headline)
            
            if medicineStore.medicines.isEmpty {
                EmptyChartView(message: "Add medicines to see category breakdown")
            } else {
                // Calculate category counts
                let categories = categoryData()
                
                HStack(alignment: .top) {
                    // Pie chart
                    ZStack {
                        ForEach(0..<categories.count, id: \.self) { i in
                            PieSegment(
                                startAngle: startAngle(for: i, in: categories),
                                endAngle: endAngle(for: i, in: categories),
                                color: categoryColor(for: i)
                            )
                        }
                        
                        // Total count in center
                        VStack {
                            Text("\(medicineStore.medicines.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<categories.count, id: \.self) { i in
                            HStack {
                                Circle()
                                    .fill(categoryColor(for: i))
                                    .frame(width: 12, height: 12)
                                Text(categories[i].name)
                                Spacer()
                                Text("\(categories[i].count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // Helper methods for chart
    private func categoryData() -> [(name: String, count: Int, percentage: Double)] {
        let prescriptionCount = medicineStore.medicines.filter { $0.type == .prescription }.count
        let otcCount = medicineStore.medicines.filter { $0.type == .otc }.count
        let total = Double(prescriptionCount + otcCount)
        
        return [
            ("Prescription", prescriptionCount, total > 0 ? Double(prescriptionCount) / total : 0),
            ("OTC", otcCount, total > 0 ? Double(otcCount) / total : 0)
        ]
    }
    
    private func startAngle(for index: Int, in data: [(name: String, count: Int, percentage: Double)]) -> Double {
        let total = data.prefix(index).reduce(0) { $0 + $1.percentage }
        return total * 360
    }
    
    private func endAngle(for index: Int, in data: [(name: String, count: Int, percentage: Double)]) -> Double {
        let total = data.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return total * 360
    }
    
    private func categoryColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red]
        return colors[index % colors.count]
    }
}

struct PieSegment: View {
    var startAngle: Double
    var endAngle: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle - 90),
                    endAngle: .degrees(endAngle - 90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

struct EmptyChartView: View {
    var message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}
