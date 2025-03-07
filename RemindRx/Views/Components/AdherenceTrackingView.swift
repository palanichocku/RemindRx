import SwiftUI
import Combine

struct AdherenceTrackingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject var medicineStore: MedicineStore
    
    // Create a StateObject for the tracking store that won't get recreated
    @StateObject private var trackingStore: AdherenceTrackingStore
    
    // UI state
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var isLoading = false
    
    // Sheet state
    @State private var showingAllInOneSchedulingView = false
    @State private var showEmptyMedicinesAlert = false
    
    // Observers
    @State private var medicineDeletedObserver: AnyCancellable?
    @State private var allMedicinesDeletedObserver: AnyCancellable?
    
    // MARK: - Initialization
    
    init() {
        print("📱 Initializing AdherenceTrackingView")
        let context = PersistentContainer.shared.viewContext
        
        // Create tracking store with context
        _trackingStore = StateObject(wrappedValue: AdherenceTrackingStore(context: context))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Modern compact tab selector - pill design
                    HStack {
                        Spacer()
                        
                        ZStack {
                            // Background capsule
                            Capsule()
                                .fill(Color(.systemGray6))
                                .frame(width: 300, height: 44)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            // Selection indicator
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 90, height: 36)
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                .offset(x: selectedTab == 0 ? -98 : selectedTab == 1 ? 0 : 98)
                                .animation(.spring(response: 0.3), value: selectedTab)
                            
                            // Tab buttons
                            HStack(spacing: 0) {
                                // Doses tab
                                Button(action: { withAnimation { selectedTab = 0 } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pills")
                                            .font(.system(size: 14))
                                        Text("Doses")
                                            .font(.system(size: 15))
                                    }
                                    .fontWeight(selectedTab == 0 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 0 ? AppColors.primaryFallback() : .gray)
                                    .frame(width: 100)
                                    .padding(.vertical, 8)
                                }
                                
                                // Schedule tab
                                Button(action: { withAnimation { selectedTab = 1 } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                        Text("Schedule")
                                            .font(.system(size: 15))
                                    }
                                    .fontWeight(selectedTab == 1 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 1 ? AppColors.primaryFallback() : .gray)
                                    .frame(width: 100)
                                    .padding(.vertical, 8)
                                }
                                
                                // History tab
                                Button(action: { withAnimation { selectedTab = 2 } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chart.bar")
                                            .font(.system(size: 14))
                                        Text("History")
                                            .font(.system(size: 15))
                                    }
                                    .fontWeight(selectedTab == 2 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 2 ? AppColors.primaryFallback() : .gray)
                                    .frame(width: 100)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    
                    // Tab content
                    TabView(selection: $selectedTab) {
                        // Today's medications tab
                        TodayMedicationsView(trackingStore: trackingStore)
                            .tag(0)
                        
                        // Schedule management tab
                        ScheduleManagementView(trackingStore: trackingStore)
                            .tag(1)
                        
                        // Adherence history tab
                        AdherenceHistoryView(trackingStore: trackingStore)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onChange(of: selectedTab) { newTab in
                        // When tab changes, refresh data
                        if newTab != previousTab {
                            print("Tab changed from \(previousTab) to \(newTab)")
                            
                            // Always do a full refresh when changing tabs
                            isLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                trackingStore.refreshAllData()
                                isLoading = false
                            }
                            
                            previousTab = newTab
                        }
                    }
                }
                
                // Overlay loading indicator
                if isLoading {
                    LoadingView()
                }
            }
            .navigationTitle("Medication Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 1 {
                        Button(action: {
                            handleAddButtonPressed()
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAllInOneSchedulingView, onDismiss: {
                // After scheduling is done, refresh data and switch to Today tab
                isLoading = true
                
                // Force reload data after slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trackingStore.refreshAllData()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Switch to Today tab
                        selectedTab = 0
                        isLoading = false
                    }
                }
            }) {
                // Show our new all-in-one scheduling view
                AllInOneSchedulingView(trackingStore: trackingStore)
                    .environmentObject(medicineStore)
            }
            .alert("No Medicines Added", isPresented: $showEmptyMedicinesAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add medicines to your collection before creating medication schedules.")
            }
            .onAppear {
                print("📱 AdherenceTrackingView appeared")
                isLoading = true
                setupNotificationObservers()
                
                // Force load medicines
                medicineStore.loadMedicines()
                
                // Clean up any schedules for medicines that no longer exist
                trackingStore.cleanupDeletedMedicines()
                
                // Load data with a brief delay to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    trackingStore.refreshAllData()
                    isLoading = false
                }
            }
            .onDisappear {
                // Clean up observers
                medicineDeletedObserver?.cancel()
                allMedicinesDeletedObserver?.cancel()
                
                // Clear cache when view disappears
                trackingStore.clearCache()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupNotificationObservers() {
        // Observer for when a medicine is deleted
        medicineDeletedObserver = NotificationCenter.default.publisher(for: .medicineDeleted)
            .sink { notification in
                if let medicineId = notification.object as? UUID {
                    // Clean up schedules for this medicine
                    let schedulesToRemove = trackingStore.medicationSchedules.filter { $0.medicineId == medicineId }
                    for schedule in schedulesToRemove {
                        trackingStore.deleteSchedule(schedule)
                    }
                }
                
                // Clean up anyway to be safe
                trackingStore.cleanupDeletedMedicines()
            }
        
        // Observer for when all medicines are deleted
        allMedicinesDeletedObserver = NotificationCenter.default.publisher(for: .allMedicinesDeleted)
            .sink { _ in
                // Handle all medicines deleted
                trackingStore.handleAllMedicinesDeleted()
            }
    }
    
    private func handleAddButtonPressed() {
        if medicineStore.medicines.isEmpty {
            // No medicines available
            showEmptyMedicinesAlert = true
        } else {
            // Show the all-in-one scheduling view
            showingAllInOneSchedulingView = true
        }
    }
}
