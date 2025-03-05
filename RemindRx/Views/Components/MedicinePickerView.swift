//
//  MedicinePickerView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

struct MedicinePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedMedicine: Medicine?
    let medicines: [Medicine]
    var trackingStore: AdherenceTrackingStore
    @Binding var showDuplicateAlert: Bool
    
    // Filter to only show medicines without schedules
    var medicinesWithoutSchedules: [Medicine] {
        return medicines.filter { medicine in
            !trackingStore.hasSchedule(for: medicine.id)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if medicinesWithoutSchedules.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "pills")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Medicines Available")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("All your medicines already have schedules or you need to add medicines first")
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
                    List {
                        ForEach(medicinesWithoutSchedules) { medicine in
                            Button(action: {
                                selectedMedicine = medicine
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(medicine.name)
                                            .font(.headline)
                                        
                                        Text(medicine.manufacturer)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
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
                // Load schedules to ensure we can properly filter medicines
                trackingStore.loadSchedules()
            }
        }
    }
}
