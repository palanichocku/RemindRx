import SwiftUI

struct MedicinePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedMedicine: Medicine?
    let medicines: [Medicine]
    var trackingStore: AdherenceTrackingStore
    @Binding var showDuplicateAlert: Bool
    
    // Debug state
    @State private var loadError: String? = nil
    
    // Filter to only show medicines without schedules
    var medicinesWithoutSchedules: [Medicine] {
        // Force refresh the schedule data first
        trackingStore.loadSchedules()
        
        // Get all medicine IDs that already have schedules
        let scheduledMedicineIDs = trackingStore.getMedicinesWithSchedules()
        
        // Filter the medicines list
        return medicines.filter { medicine in
            !scheduledMedicineIDs.contains(medicine.id)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if medicines.isEmpty {
                    // No medicines at all
                    VStack(spacing: 20) {
                        Image(systemName: "pills")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Medicines Found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Please add medicines to your collection first")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding(.top, 20)
                        .foregroundColor(AppColors.primaryFallback())
                    }
                    .padding()
                } else if medicinesWithoutSchedules.isEmpty {
                    // All medicines have schedules already
                    VStack(spacing: 20) {
                        Image(systemName: "pills")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Medicines Available")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("All your medicines already have schedules")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding(.top, 20)
                        .foregroundColor(AppColors.primaryFallback())
                    }
                    .padding()
                } else {
                    // Show available medicines
                    List {
                        ForEach(medicinesWithoutSchedules) { medicine in
                            Button(action: {
                                print("Selected medicine: \(medicine.name)")
                                selectedMedicine = medicine
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(medicine.name)
                                            .font(.headline)
                                        
                                        if !medicine.manufacturer.isEmpty {
                                            Text(medicine.manufacturer)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                
                // Show any load errors
                if let error = loadError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Select Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                print("MedicinePickerView appeared with \(medicines.count) medicines")
                
                // Force refresh data
                trackingStore.refreshAllData()
                
                // Debug print medicine list
                for medicine in medicines {
                    print("Available medicine: \(medicine.name) (ID: \(medicine.id))")
                }
                
                // Debug print schedules
                print("Current schedules: \(trackingStore.medicationSchedules.count)")
                for schedule in trackingStore.medicationSchedules {
                    print("Schedule for: \(schedule.medicineName) (Medicine ID: \(schedule.medicineId))")
                }
            }
        }
    }
}
