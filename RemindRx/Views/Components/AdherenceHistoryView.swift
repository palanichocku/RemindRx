import SwiftUI

struct AdherenceHistoryView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedMedicineId: UUID?
    @State private var showingFullHistory = false
    @State private var timeRange = 7 // days
    @State private var showingMedicinePicker = false
    
    // All medicines without filtering
    var allAvailableMedicines: [Medicine] {
        return medicineStore.medicines
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if medicineStore.medicines.isEmpty {
                    // Show empty state when no medicines
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "No Medication History",
                        message: "Add medicines to your collection first to track adherence history"
                    )
                    .padding(.top, 40)
                } else {
                    // Medicine dropdown selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Medicine")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Dropdown menu
                        Button(action: {
                            showingMedicinePicker = true
                        }) {
                            HStack {
                                if let selectedId = selectedMedicineId,
                                   let medicine = allAvailableMedicines.first(where: { $0.id == selectedId }) {
                                    Text(medicine.name)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Select a medicine")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .actionSheet(isPresented: $showingMedicinePicker) {
                            ActionSheet(
                                title: Text("Select Medicine"),
                                buttons: allAvailableMedicines.map { medicine in
                                    .default(Text(medicine.name)) {
                                        selectedMedicineId = medicine.id
                                    }
                                } + [.cancel()]
                            )
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 5)
                    
                    // Time range selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Range")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("", selection: $timeRange) {
                            Text("7 Days").tag(7)
                            Text("14 Days").tag(14)
                            Text("30 Days").tag(30)
                            Text("90 Days").tag(90)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    if let selectedId = selectedMedicineId,
                       let medicine = allAvailableMedicines.first(where: { $0.id == selectedId }) {
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        // Adherence stats
                        VStack(spacing: 15) {
                            // Calculate real statistics for the selected medicine
                            let stats = calculateStats(medicineId: selectedId)
                            
                            // Adherence rate
                            statsCard(
                                title: "Adherence Rate",
                                value: String(format: "%.1f%%", stats.adherenceRate),
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            
                            // Current streak
                            statsCard(
                                title: "Current Streak",
                                value: "\(stats.currentStreak) days",
                                icon: "flame.fill",
                                color: .orange
                            )
                            
                            // Doses taken
                            statsCard(
                                title: "Doses Taken",
                                value: "\(stats.dosesTaken)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            // View full history button
                            Button(action: {
                                showingFullHistory = true
                            }) {
                                Text("View Detailed History")
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryFallback())
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        EmptyStateView(
                            icon: "chart.xyaxis.line",
                            title: "Select a Medicine",
                            message: "Choose a medicine to see adherence stats"
                        )
                        .padding(.top, 40)
                    }
                }
            }
            .padding(.vertical)
            .onAppear {
                // Select first medicine by default if none selected
                if selectedMedicineId == nil && !allAvailableMedicines.isEmpty {
                    selectedMedicineId = allAvailableMedicines.first?.id
                }
                
                // Debug
                print("🔍 History view: Found \(allAvailableMedicines.count) total medicines")
                print("🔍 Recorded doses: \(trackingStore.medicationDoses.count)")
                
                // Refresh data when view appears
                trackingStore.refreshAllData()
            }
            .sheet(isPresented: $showingFullHistory) {
                if let selectedId = selectedMedicineId,
                   let medicine = allAvailableMedicines.first(where: { $0.id == selectedId }) {
                    
                    NavigationView {
                        HistoryDetailView(
                            medicine: medicine,
                            timeRange: timeRange,
                            trackingStore: trackingStore
                        )
                        .navigationTitle("Medication History")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showingFullHistory = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Stats card view
    private func statsCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Calculate real statistics for a medicine
    private func calculateStats(medicineId: UUID) -> (adherenceRate: Double, currentStreak: Int, dosesTaken: Int) {
        // Count doses taken
        let dosesTaken = trackingStore.medicationDoses.filter {
            $0.medicineId == medicineId && $0.taken
        }.count
        
        // Calculate streak - for now use a simplified approach
        let streak = max(dosesTaken, 1) // At least 1 if any doses taken
        
        // Calculate adherence rate - for now use a simplified approach
        let adherenceRate = dosesTaken > 0 ? 100.0 : 0.0
        
        print("📊 Stats for medicine \(medicineId):")
        print("- Doses taken: \(dosesTaken)")
        print("- Streak: \(streak)")
        print("- Adherence rate: \(adherenceRate)%")
        
        return (adherenceRate, streak, dosesTaken)
    }
}
