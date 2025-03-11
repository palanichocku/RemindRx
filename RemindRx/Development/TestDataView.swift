import SwiftUI
import CoreData

struct TestDataView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var medicineStore: MedicineStore
    
    @State private var medicineCount = 10
    @State private var isGenerating = false
    @State private var progress = 0.0
    @State private var isComplete = false
    @State private var showDeletionComplete = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Generate Test Data")) {
                    Stepper("Number of Medicines: \(medicineCount)", value: $medicineCount, in: 10...500, step: 10)
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
                        ProgressView()
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
        
        let generator = TestDataGenerator(context: viewContext)
        
        generator.generateTestData(count: medicineCount) { success in
            self.isGenerating = false
            
            if success {
                self.isComplete = true
            }
        }
    }
    
    private func deleteAllData() {
        isGenerating = true
        
        let generator = TestDataGenerator(context: viewContext)
        
        generator.deleteAllData { success in
            self.isGenerating = false
            
            if success {
                self.showDeletionComplete = true
            }
        }
    }
}
