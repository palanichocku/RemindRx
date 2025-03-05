import SwiftUI

struct AdherenceHistoryView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedMedicine: Medicine?
    @State private var showingFullHistory = false
    @State private var timeRange = 7 // days
    
    // Get only medicines that have schedules
    var scheduledMedicines: [Medicine] {
        return medicineStore.medicines.filter { medicine in
            trackingStore.hasSchedule(for: medicine.id)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if scheduledMedicines.isEmpty {
                    // Show empty state when no medicines have schedules
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "No Medication History",
                        message: "Add medication schedules first to track adherence history"
                    )
                    .padding(.top, 40)
                } else {
                    // Medicine selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Medicine")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(scheduledMedicines) { medicine in
                                    MedicineChip(
                                        medicine: medicine,
                                        isSelected: selectedMedicine?.id == medicine.id,
                                        action: { selectMedicine(medicine) }
                                    )
                                }
                            }
                            .padding(.horizontal)
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
                        .onChange(of: timeRange) { _ in
                            trackingStore.updateTodayDoses()
                        }
                    }
                    
                    if let medicine = selectedMedicine {
                        Divider()
                            .padding(.vertical, 5)
                        
                        // Adherence stats
                        VStack(spacing: 15) {
                            // Adherence rate
                            AdherenceStatCard(
                                title: "Adherence Rate",
                                value: String(format: "%.1f%%", trackingStore.calculateAdherenceRate(forMedicine: medicine.id, in: timeRange)),
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            
                            // Current streak
                            AdherenceStatCard(
                                title: "Current Streak",
                                value: "\(trackingStore.getCurrentStreak(forMedicine: medicine.id)) days",
                                icon: "flame.fill",
                                color: .orange
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
                        .padding(.horizontal)
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
                // Force a refresh when view appears
                trackingStore.refreshAllData()
                
                // Clear selection if the selected medicine is no longer scheduled
                if let selected = selectedMedicine, !trackingStore.hasSchedule(for: selected.id) {
                    selectedMedicine = nil
                }
                
                // Auto-select first medicine if none selected but medicines are available
                if selectedMedicine == nil && !scheduledMedicines.isEmpty {
                    selectedMedicine = scheduledMedicines.first
                }
            }
        }
        .sheet(isPresented: $showingFullHistory) {
            if let medicine = selectedMedicine {
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
        // Use onReceive instead of onChange for collections that may not conform to Equatable
        .onReceive(trackingStore.objectWillChange) { _ in
            // This will trigger whenever trackingStore publishes changes
            // We can use this to update our selected medicine if needed
            DispatchQueue.main.async {
                if let selected = selectedMedicine, !trackingStore.hasSchedule(for: selected.id) {
                    selectedMedicine = scheduledMedicines.first
                }
            }
        }
    }
    
    private func selectMedicine(_ medicine: Medicine) {
        selectedMedicine = medicine
    }
}
