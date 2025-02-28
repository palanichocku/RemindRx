import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App icon and title
                HStack {
                    Image(systemName: "pills")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("RemindRx")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Medicine Expiration Tracker")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                Divider()
                
                // App description
                Text("About RemindRx")
                    .font(.headline)
                
                Text("RemindRx helps you track the expiration dates of your medicines and provides timely reminders before they expire. Scan your medicine barcodes or enter them manually to keep your medicine cabinet up to date.")
                    .font(.body)
                
                // Features
                Text("Features")
                    .font(.headline)
                    .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "barcode.viewfinder", text: "Scan medicine barcodes")
                    FeatureRow(icon: "bell", text: "Get expiration reminders")
                    FeatureRow(icon: "list.bullet", text: "Organize your medicine cabinet")
                    FeatureRow(icon: "exclamationmark.triangle", text: "Identify expired medicines")
                }
                
                // Developer info
                Text("Developer Information")
                    .font(.headline)
                    .padding(.top, 10)
                
                Text("Developed by: Palam Chocku\nContact: support@remindrx.app\nVersion: 1.0.0")
                
                // Support section
                Text("Support")
                    .font(.headline)
                    .padding(.top, 10)
                
                Text("For questions, feedback, or support, please contact us at support@remindrx.app or visit our website at www.remindrx.app")
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
        }
    }
}
