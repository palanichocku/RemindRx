import SwiftUI
import Combine

struct AdherenceTrackingView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject var medicineStore: MedicineStore
    @StateObject private var trackingStore: AdherenceTrackingStore
    
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showingAddSchedule = false
    @State private var selectedMedicine: Medicine?
    @State private var isLoading = false
    @State private var showDuplicateAlert = false
    
    // For the simplified flow
    @State private var showingSimpleScheduleCreator = false
    
    // Add notification observers
    @State private var medicineDeletedObserver: AnyCancellable?
    @State private var allMedicinesDeletedObserver: AnyCancellable?
    
    init() {
        let context = PersistentContainer.shared.viewContext
        _trackingStore = StateObject(wrappedValue: AdherenceTrackingStore(context: context))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Tab selector
                    TabSelectorView(selectedTab: $selectedTab, tabs: ["Today", "Schedule", "History"])
                    
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                            showingAddSchedule = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                // Show medicine picker
                MedicinePickerView(
                    selectedMedicine: $selectedMedicine,
                    medicines: medicineStore.medicines,
                    trackingStore: trackingStore,
                    showDuplicateAlert: $showDuplicateAlert
                )
                .environmentObject(medicineStore)
                .onDisappear {
                    if let medicine = selectedMedicine {
                        handleMedicineSelection(medicine)
                        selectedMedicine = nil
                    }
                }
            }
            .sheet(isPresented: $showingSimpleScheduleCreator) {
                // Use the new SimpleScheduleCreationView instead of NewScheduleEditorView
                if let medicine = selectedMedicine {
                    SimpleScheduleCreationView(
                        trackingStore: trackingStore,
                        medicine: medicine,
                        onComplete: {
                            // Switch to Today tab
                            selectedTab = 0
                        }
                    )
                }
            }
            .alert("Already Scheduled", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This medicine is already in your schedule. You can edit its existing schedule from the Schedule tab.")
            }
            .onAppear {
                isLoading = true
                setupNotificationObservers()
                
                // Clean up any schedules for medicines that no longer exist
                trackingStore.cleanupDeletedMedicines()
                
                // Load data with a brief delay to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trackingStore.loadData()
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
    
    // Handle medicine selection with simplified flow
    private func handleMedicineSelection(_ medicine: Medicine) {
        // Check if this medicine already has a schedule
        if trackingStore.hasSchedule(for: medicine.id) {
            showDuplicateAlert = true
            return
        }
        
        // Keep the selected medicine
        self.selectedMedicine = medicine
        
        // Show the simplified schedule creator directly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showingSimpleScheduleCreator = true
        }
    }
}
