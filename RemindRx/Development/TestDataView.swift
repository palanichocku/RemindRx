//
//  TestDataView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/10/25.
//
import SwiftUI
import CoreData

// Test data view implementation
public struct TestDataView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var medicineStore: MedicineStore
    @State var showingTestDataGenerator = false
    @State private var medicineCount = 10
    @State private var isGenerating = false
    @State private var progress = 0.0
    @State private var isComplete = false
    @State private var showDeletionComplete = false
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Generate Test Data")) {
                    Stepper("Number of Medicines: \(medicineCount)", value: $medicineCount, in: 10...1000, step: 10)
                        .disabled(isGenerating)
                    
                    Button(action: generateData) {
                        Text(isGenerating ? "Generating..." : "Generate Test Medicines")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(isGenerating ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isGenerating)
                    
                    Button(action: deleteAllData) {
                        Text("Delete All Medicines")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .disabled(isGenerating)
                }
                
                if isGenerating {
                    Section(header: Text("Progress")) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
            .navigationTitle("Test Data Generator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Generation Complete", isPresented: $isComplete) {
                Button("OK") {
                    medicineStore.loadMedicines()
                }
            } message: {
                Text("Successfully generated \(medicineCount) test medicines.")
            }
            .alert(isPresented: $showDeletionComplete) {
                Alert(
                    title: Text("Deletion Complete"),
                    message: Text("All test data has been successfully deleted."),
                    dismissButton: .default(Text("OK")) {
                        // Refresh the medicine store
                        medicineStore.loadMedicines()
                    }
                )
            }
        }
    }
    
    private func generateData() {
        isGenerating = true
        progress = 0.0
        
        let generator = TestDataUtils(context: viewContext)
        
        generator.generateTestMedicines(count: medicineCount) { success in
            // First update progress
            DispatchQueue.main.async {
                self.isGenerating = false
                self.progress = 1.0
                
                // Then refresh store
                self.medicineStore.loadMedicines()
                
                // Finally show alert with a significant delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("Setting isComplete to true to show alert")
                    self.isComplete = true
                }
            }
        }
    }
    
    private func deleteAllData() {
        isGenerating = true
        
        // Use medicineStore directly to delete all medicines
        //medicineStore.deleteAll()
        medicineStore.deleteAllMedicinesWithCleanup()
        
        // Update states on main thread with delay
        DispatchQueue.main.async {
            self.isGenerating = false
            
            // Refresh medicine store
            self.medicineStore.loadMedicines()
            
            // Use a slight delay for alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showDeletionComplete = true
            }
        }
    }
    
}
