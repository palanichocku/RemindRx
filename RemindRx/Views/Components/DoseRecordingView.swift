import SwiftUI

// Fixed DoseRecordingView that won't show an empty screen
struct DoseRecordingView: View {
    let dose: AdherenceTrackingStore.TodayDose
    @Binding var isPresented: Bool
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    @State private var recordAsTaken: Bool = true
    @State private var skippedReason: String = ""
    @State private var notes: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            // Wrap in a ZStack to handle potential errors
            ZStack {
                // The main form content
                Form {
                    Section(header: Text("Medication")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dose.medicine.name)
                                .font(.headline)
                            
                            if !dose.medicine.manufacturer.isEmpty {
                                Text(dose.medicine.manufacturer)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        HStack {
                            Text("Scheduled time:")
                            Spacer()
                            Text(formatTime(dose.scheduledTime))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Record Status")) {
                        Picker("Status", selection: $recordAsTaken) {
                            Text("Taken").tag(true)
                            Text("Skipped").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        if !recordAsTaken {
                            TextField("Reason for skipping", text: $skippedReason)
                        }
                    }
                    
                    Section(header: Text("Notes")) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                    
                    Section {
                        Button(action: saveDose) {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(AppColors.primaryFallback())
                                .cornerRadius(10)
                        }
                    }
                    
                    if dose.doseId != nil {
                        Section {
                            Button(action: deleteDose) {
                                Text("Delete Record")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // Error display
                if showError {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding()
                        Spacer().frame(height: 100)
                    }
                }
            }
            .navigationTitle("Record Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                debugPrint("DoseRecordingView appeared - Medicine: \(dose.medicine.name)")
                
                // If there's an existing dose with a status, pre-populate the form
                if let status = dose.status {
                    recordAsTaken = status == .taken
                    if status == .skipped, let doseId = dose.doseId {
                        // Try to fetch existing skipped reason
                        if let existingDose = trackingStore.getDoseById(doseId) {
                            skippedReason = existingDose.skippedReason ?? ""
                            notes = existingDose.notes ?? ""
                        }
                    }
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveDose() {
        do {
            // Create or update dose record
            let medicationDose = MedicationDose(
                id: dose.doseId ?? UUID(),
                medicineId: dose.medicine.id,
                medicineName: dose.medicine.name,
                timestamp: Date(),
                taken: recordAsTaken,
                notes: notes.isEmpty ? nil : notes,
                skippedReason: (!recordAsTaken && !skippedReason.isEmpty) ? skippedReason : nil
            )
            
            if dose.doseId != nil {
                trackingStore.updateDose(medicationDose)
            } else {
                trackingStore.recordDose(medicationDose)
            }
            
            isPresented = false
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
            
            // Auto-hide error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showError = false
            }
        }
    }
    
    private func deleteDose() {
        if let doseId = dose.doseId {
            let medicationDose = MedicationDose(
                id: doseId,
                medicineId: dose.medicine.id,
                medicineName: dose.medicine.name,
                timestamp: Date(),
                taken: false
            )
            trackingStore.deleteDose(medicationDose)
        }
        isPresented = false
    }
}
