import SwiftUI

// Fixed version of TodayMedicationsView
struct TodayMedicationsView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @State private var showingDoseDetails = false
    @State private var selectedDose: AdherenceTrackingStore.TodayDose?
    
    var body: some View {
        ZStack {
            if trackingStore.todayDoses.isEmpty {
                EmptyStateView(
                    icon: "pills",
                    title: "No Medications Scheduled",
                    message: "Add medication schedules to track your daily doses"
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Upcoming section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Upcoming Doses")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if trackingStore.upcomingDoses.isEmpty {
                                Text("No upcoming doses for today")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(trackingStore.upcomingDoses, id: \.medicine.id) { dose in
                                    UpcomingDoseCard(dose: dose)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Today's schedule
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today's Schedule")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(trackingStore.todayDoses, id: \.id) { dose in
                                TodayDoseCard(
                                    dose: dose,
                                    onRecordTap: {
                                        selectedDose = dose
                                        showingDoseDetails = true
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $showingDoseDetails) {
            if let dose = selectedDose {
                // Use the fixed DoseRecordingView
                DoseRecordingView(
                    dose: dose,
                    isPresented: $showingDoseDetails,
                    trackingStore: trackingStore
                )
            }
        }
        // Reset selectedDose when sheet is dismissed to prevent stale data
        .onChange(of: showingDoseDetails) { isShowing in
            if !isShowing {
                // Short delay to ensure sheet is fully dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedDose = nil
                }
            }
        }
    }
}
