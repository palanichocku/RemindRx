import SwiftUI
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTestDataGenerator = false
    @State private var showingFAQView = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsAndConditions = false
    @State private var showingBillingTerms = false
    @State private var showingRateAppView = false
    @State private var showingSupportUsView = false
    @State private var isNotificationsEnabled = true
    @State private var emailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingEmailSheet = false
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    
    // Use a string for the retention period since we can't find the enum
    @State private var retentionPeriod: String = "6 Months"
    private let retentionOptions = [
        "2 Weeks", "1 Month", "3 Months", "6 Months", "1 Year", "2 Years", "Forever"
    ]
    
    var body: some View {
        List {
            // Notification Section
            Section(header: Text("Notifications")) {
                Toggle("Enable Push Notifications", isOn: $isNotificationsEnabled)
                    .onChange(of: isNotificationsEnabled) { newValue in
                        updateNotificationSettings(enabled: newValue)
                    }
            }
            Section(header: Text("Help")) {
                Button(action: {
                    onboardingCoordinator.shouldShowOnboarding = true
                    onboardingCoordinator.resetOnboarding()
                    // This might help force a UI update
                    onboardingCoordinator.objectWillChange.send()
                }) {
                    Label("Show Onboarding Guide Again", systemImage: "book")
                }
            }
            // Data Management Section
            Section(header: Text("Data Management")) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
                
                #if DEBUG
                Button(action: {
                    showingTestDataGenerator = true
                }) {
                    Label("Generate Test Data", systemImage: "wand.and.stars")
                        .foregroundColor(.purple)
                }
                #endif
            }
            
            // Get Support Section
            Section(header: Text("Get Support")) {
                Button(action: {
                    showingFAQView = true
                }) {
                    Label("Frequently Asked Questions", systemImage: "questionmark.circle")
                }
                
                Button(action: {
                    isShowingEmailSheet = true
                }) {
                    Label("Contact Support", systemImage: "envelope")
                }
                .disabled(!MFMailComposeViewController.canSendMail())
            }
            
            // Feedback Section
            Section(header: Text("Feedback")) {
                Button(action: {
                    showingRateAppView = true
                }) {
                    Label("Rate RemindRx", systemImage: "star")
                }
                
                Button(action: {
                    shareApp()
                }) {
                    Label("Share the App", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    showingSupportUsView = true
                }) {
                    Label("Support Us", systemImage: "heart")
                        .foregroundColor(.red)
                }
            }
            
            // Legal Section
            Section(header: Text("Legal")) {
                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
                
                Button(action: {
                    showingTermsAndConditions = true
                }) {
                    Label("Terms and Conditions", systemImage: "doc.text")
                }
                
                Button(action: {
                    showingBillingTerms = true
                }) {
                    Label("Billing Terms", systemImage: "creditcard")
                }
            }
            
            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Palam Chocku")
                        .foregroundColor(.gray)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .sheet(isPresented: $showingFAQView) {
            FAQView()
        }
        .sheet(isPresented: $showingRateAppView) {
            RateAppView(isPresented: $showingRateAppView)
        }
        .sheet(isPresented: $showingSupportUsView) {
            SupportUsView(isPresented: $showingSupportUsView)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsAndConditions) {
            TermsAndConditionsView()
        }
        .sheet(isPresented: $showingBillingTerms) {
            BillingTermsView()
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteConfirmationView(isPresented: $showingDeleteConfirmation)
        }
        .sheet(isPresented: $showingTestDataGenerator) {
            TestDataView()
                .environment(\.managedObjectContext, PersistentContainer.shared.viewContext)
                .environmentObject(medicineStore)
        }
        .alert(isPresented: $showingLogoutConfirmation) {
            Alert(
                title: Text("Log Out"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Log Out")) {
                    // Perform logout
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Check current notification settings
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    self.isNotificationsEnabled = (settings.authorizationStatus == .authorized)
                }
            }
            
            // Load saved retention period
            if let savedPeriod = UserDefaults.standard.string(forKey: "historyRetentionPeriod") {
                retentionPeriod = savedPeriod
            }
        }
        .sheet(isPresented: $isShowingEmailSheet) {
            if MFMailComposeViewController.canSendMail() {
                MailView(result: $emailResult, subject: "RemindRx Support Request", message: "")
            }
        }
    }
    
    private func updateNotificationSettings(enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    self.isNotificationsEnabled = granted
                }
            }
        } else {
            // Direct user to settings if they want to disable notifications
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func shareApp() {
        // App Store URL (replace with your actual App Store URL when available)
        let appStoreURL = "https://apps.apple.com/app/remindrx"
        let message = "Check out RemindRx - a great app for tracking medicine expiration dates!"
        
        let activityItems: [Any] = [message, appStoreURL]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // Convert retention period string to days
    private func stringToDays(_ period: String) -> Int {
        switch period {
        case "2 Weeks": return 14
        case "1 Month": return 30
        case "3 Months": return 90
        case "6 Months": return 180
        case "1 Year": return 365
        case "2 Years": return 730
        case "Forever": return Int.max
        default: return 180 // Default to 6 months
        }
    }
}

// Mail view using UIKit's MFMailComposeViewController
struct MailView: UIViewControllerRepresentable {
    @Binding var result: Result<MFMailComposeResult, Error>?
    let subject: String
    let message: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(["support@remindrx.app"])
        vc.setSubject(subject)
        vc.setMessageBody(message, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            controller.dismiss(animated: true)
        }
    }
}

// FAQView
struct FAQView: View {
    @Environment(\.presentationMode) var presentationMode
    
    struct FAQ: Identifiable {
        var id = UUID()
        var question: String
        var answer: String
        var isExpanded: Bool = false
    }
    
    @State private var faqs: [FAQ] = [
        FAQ(question: "What is RemindRx?", answer: "RemindRx is a medicine expiration tracker that helps you manage your medications, track expiration dates, and receive timely reminders before your medicines expire."),
        FAQ(question: "How do I add a new medicine?", answer: "You can add a medicine by tapping the + button in the Medicines tab or by using the 'Scan' option to scan a medicine barcode. Fill in the required details and tap 'Save'."),
        FAQ(question: "How do I scan a medicine barcode?", answer: "Tap the 'Scan' option, then position your device so the barcode is within the scanning frame. The app will automatically detect and scan the barcode."),
        FAQ(question: "Can I edit medicine information?", answer: "Yes, you can edit medicine details by viewing a medicine and tapping the 'Edit' button in the expiration section."),
        FAQ(question: "How do I delete a medicine?", answer: "Open the medicine details and tap the trash icon in the top-right corner. Confirm deletion when prompted."),
        FAQ(question: "What types of notifications will I receive?", answer: "You'll receive notifications when your medicines are about to expire, based on the alert interval you've set for each medicine (e.g., 1 day, 1 week, or 1 month before expiration)."),
        FAQ(question: "What happens if I disable notifications?", answer: "If you disable notifications, you won't receive alerts about expiring medicines. You'll need to check the app manually to see which medicines are expiring soon."),
        FAQ(question: "Does RemindRx store my medicine data securely?", answer: "Yes, all your medicine data is stored locally on your device and is not shared with third parties without your consent."),
        FAQ(question: "Is RemindRx free to use?", answer: "Yes, RemindRx is currently free to use on a trial basis. We may introduce premium features in the future."),
        FAQ(question: "How can I contact support?", answer: "You can contact us by going to Settings → Get Support → Contact Support, or by emailing support@remindrx.app.")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(0..<faqs.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            withAnimation {
                                faqs[index].isExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text(faqs[index].question)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: faqs[index].isExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if faqs[index].isExpanded {
                            Text(faqs[index].answer)
                                .padding(.top, 4)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Frequently Asked Questions")
            .navigationBarItems(trailing: Button("Done") {
                // Properly dismiss the sheet using SwiftUI's presentationMode
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Rate App View
struct RateAppView: View {
    @Binding var isPresented: Bool
    @State private var rating: Int = 0
    @State private var feedback: String = ""
    @State private var hasSubmitted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("How would you rate RemindRx?")
                    .font(.headline)
                    .padding(.top, 20)
                
                // Star rating
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(star <= rating ? .yellow : .gray)
                            .onTapGesture {
                                withAnimation {
                                    rating = star
                                }
                            }
                    }
                }
                .padding()
                
                // Feedback form
                if rating > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Would you like to share your feedback?")
                            .font(.subheadline)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $feedback)
                                .frame(height: 120)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            if feedback.isEmpty {
                                Text("Your feedback helps us improve RemindRx...")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if rating >= 4 {
                        // For positive ratings, offer App Store review
                        Button(action: {
                            submitRating()
                            // In a real app, would redirect to App Store
                            // Using App Store URL and UIApplication.shared.open()
                        }) {
                            Text("Rate on App Store")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        // For lower ratings, submit feedback
                        Button(action: {
                            submitRating()
                        }) {
                            Text("Submit Feedback")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                
                if hasSubmitted {
                    Text("Thank you for your feedback!")
                        .foregroundColor(.green)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Rate RemindRx")
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
        }
    }
    
    private func submitRating() {
        // In a real app, would send feedback to a server or analytics service
        // For demo, just show confirmation
        withAnimation {
            hasSubmitted = true
        }
        
        // Auto-dismiss after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPresented = false
        }
    }
}

// Support Us View with actual payment options
struct SupportUsView: View {
    @Binding var isPresented: Bool
    @State private var selectedAmount: Double = 2.99
    @State private var customAmount: String = ""
    @State private var isProcessing = false
    @State private var showThankYou = false
    @State private var selectedPaymentMethod: PaymentMethod = .applePay
    @State private var showingPaymentSheet = false
    
    enum PaymentMethod: String, CaseIterable, Identifiable {
        case applePay = "Apple Pay"
        case venmo = "Venmo"
        case paypal = "PayPal"
        case cashApp = "Cash App"
        
        var id: String { self.rawValue }
        
        var iconName: String {
            switch self {
            case .applePay: return "applepay"
            case .venmo: return "v.square"
            case .paypal: return "p.square"
            case .cashApp: return "dollarsign.square"
            }
        }
        
        var actionURL: URL? {
            switch self {
            case .applePay:
                return nil // Handled natively
            case .venmo:
                return URL(string: "venmo://paycharge?txn=pay&recipients=PalamChocku&amount=\(2.99)&note=RemindRx%20Support")
            case .paypal:
                return URL(string: "https://www.paypal.me/PalamChocku/2.99")
            case .cashApp:
                return URL(string: "https://cash.app/$PalamChocku/2.99")
            }
        }
    }
    
    private let predefinedAmounts = [0.99, 2.99, 4.99, 9.99]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)
                    
                    Text("Support RemindRx Development")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your support helps us continue to improve RemindRx and add new features. Choose an amount and payment method below.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Step 1: Choose amount
                    GroupBox(label: Text("Step 1: Choose Amount").bold()) {
                        VStack(spacing: 15) {
                            // Predefined amounts
                            HStack(spacing: 15) {
                                ForEach(predefinedAmounts, id: \.self) { amount in
                                    Button(action: {
                                        selectedAmount = amount
                                        customAmount = ""
                                    }) {
                                        Text("$\(String(format: "%.2f", amount))")
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 15)
                                            .background(selectedAmount == amount && customAmount.isEmpty ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedAmount == amount && customAmount.isEmpty ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // Custom amount
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Or enter a custom amount:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("$")
                                        .font(.headline)
                                    
                                    TextField("Custom amount", text: $customAmount)
                                        .keyboardType(.decimalPad)
                                        .onChange(of: customAmount) { newValue in
                                            if let amount = Double(newValue), amount > 0 {
                                                selectedAmount = amount
                                            }
                                        }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Step 2: Choose payment method
                    GroupBox(label: Text("Step 2: Choose Payment Method").bold()) {
                        VStack(alignment: .leading, spacing: 15) {
                            ForEach(PaymentMethod.allCases) { method in
                                Button(action: {
                                    selectedPaymentMethod = method
                                }) {
                                    HStack {
                                        Image(systemName: method == .applePay ? "applepay" : method.iconName)
                                            .font(.system(size: 24))
                                            .foregroundColor(method == selectedPaymentMethod ? .blue : .gray)
                                        
                                        Text(method.rawValue)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if method == selectedPaymentMethod {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if method != PaymentMethod.allCases.last {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Step 3: Complete payment
                    GroupBox(label: Text("Step 3: Complete Payment").bold()) {
                        Button(action: {
                            initiatePayment()
                        }) {
                            Group {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Pay $\(customAmount.isEmpty ? String(format: "%.2f", selectedAmount) : customAmount) with \(selectedPaymentMethod.rawValue)")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding(.vertical, 8)
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal)
                    
                    // Thank you message
                    if showThankYou {
                        Text("Thank you for your support! ❤️")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Notice about trial
                    Text("RemindRx is currently free on a trial basis.\nYour support is completely optional.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Support Us")
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
            .onDisappear {
                // Clean up when view disappears
                isProcessing = false
            }
        }
    }
    
    private func initiatePayment() {
        // Get the final amount
        let finalAmount = customAmount.isEmpty ? selectedAmount : (Double(customAmount) ?? selectedAmount)
        
        // Start processing animation
        withAnimation {
            isProcessing = true
        }
        
        // Apply different payment methods
        switch selectedPaymentMethod {
        case .applePay:
            // In a real app, you would integrate with Apple Pay SDK here
            simulateApplePayment()
            
        case .venmo, .paypal, .cashApp:
            if let url = getPaymentURL(for: selectedPaymentMethod, amount: finalAmount) {
                // Open the payment app
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                isProcessing = false
                                showThankYou = true
                            }
                            
                            // Dismiss after showing thank you
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isPresented = false
                            }
                        }
                    } else {
                        // Couldn't open the app - show error or fallback
                        withAnimation {
                            isProcessing = false
                        }
                        
                        // Open web fallback for PayPal
                        if selectedPaymentMethod == .paypal {
                            openWebPaymentFallback(amount: finalAmount)
                        }
                    }
                }
            } else {
                // URL creation failed
                withAnimation {
                    isProcessing = false
                }
            }
        }
    }
    
    private func simulateApplePayment() {
        // Simulate Apple Pay flow - in a real app, use PKPaymentButton and PKPaymentRequest
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isProcessing = false
                showThankYou = true
            }
            
            // Dismiss after showing thank you
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPresented = false
            }
        }
    }
    
    private func getPaymentURL(for method: PaymentMethod, amount: Double) -> URL? {
        let formattedAmount = String(format: "%.2f", amount)
        let encodedNote = "RemindRx%20Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "RemindRx%20Support"
        
        // Replace with your actual payment details
        switch method {
        case .venmo:
            return URL(string: "venmo://paycharge?txn=pay&recipients=PalamChocku&amount=\(formattedAmount)&note=\(encodedNote)")
        case .paypal:
            return URL(string: "https://www.paypal.me/PalamChocku/\(formattedAmount)")
        case .cashApp:
            return URL(string: "https://cash.app/$PalamChocku/\(formattedAmount)")
        default:
            return nil
        }
    }
    
    private func openWebPaymentFallback(amount: Double) {
        let formattedAmount = String(format: "%.2f", amount)
        // Open PayPal in Safari as a fallback
        if let url = URL(string: "https://www.paypal.me/PalamChocku/\(formattedAmount)") {
            UIApplication.shared.open(url)
        }
    }
}

// Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Privacy Policy")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Last Updated: March 13, 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("This Privacy Policy describes how RemindRx (\"we\", \"us\", or \"our\") collects, uses, and discloses your information when you use our mobile application (the \"App\").")
                    }
                    
                    Group {
                        Text("Information We Collect")
                            .font(.headline)
                        
                        Text("RemindRx is designed with your privacy in mind. We collect minimal personal information:")
                        
                        Text("• **Local Storage**: All your medicine data is stored locally on your device and is not transmitted to our servers.\n• **Usage Data**: Anonymous usage statistics that help us improve the app.\n• **Device Information**: Basic information about your device to optimize app performance.")
                    }
                    
                    Group {
                        Text("How We Use Your Information")
                            .font(.headline)
                        
                        Text("We use the collected information to:")
                        
                        Text("• Provide and maintain the App\n• Improve and optimize our services\n• Respond to your requests and support needs\n• Send notifications about expiring medicines (only with your permission)")
                    }
                    
                    Group {
                        Text("Data Sharing and Disclosure")
                            .font(.headline)
                        
                        Text("We do not sell or rent your personal information to third parties. We may share anonymous, aggregated data with:")
                        
                        Text("• Service providers that help us operate the App\n• Analytics partners to understand app usage\n• Legal authorities when required by law")
                    }
                    
                    Group {
                        Text("Your Rights")
                            .font(.headline)
                        
                        Text("You have control over your data:")
                        
                        Text("• Access all your data directly in the App\n• Delete your data through the App settings\n• Control notification permissions in your device settings")
                    }
                    
                    Group {
                        Text("Children's Privacy")
                            .font(.headline)
                        
                        Text("The App is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.")
                    }
                    
                    Group {
                        Text("Changes to This Privacy Policy")
                            .font(.headline)
                        
                        Text("We may update our Privacy Policy from time to time. We will notify you of any changes by updating the \"Last Updated\" date at the top of this policy.")
                    }
                    
                    Group {
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("If you have any questions about this Privacy Policy, please contact us at:")
                        
                        Text("support@remindrx.app")
                            .foregroundColor(.blue)
                    }
                    
                    Text("By using the App, you agree to the collection and use of information in accordance with this policy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarItems(trailing: Button("Done") {
                // Properly dismiss the sheet using SwiftUI's presentationMode
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Terms and Conditions View
struct TermsAndConditionsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Terms and Conditions")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Last Updated: March 13, 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Please read these Terms and Conditions (\"Terms\") carefully before using the RemindRx mobile application (the \"App\"). Your access to and use of the App is conditioned on your acceptance of and compliance with these Terms.")
                    }
                    
                    Group {
                        Text("License")
                            .font(.headline)
                        
                        Text("RemindRx grants you a limited, non-exclusive, non-transferable, revocable license to use the App for your personal, non-commercial purposes. You may not copy, modify, distribute, sell, or lease any part of the App or its content, nor may you reverse engineer or attempt to extract the source code of the App, unless laws prohibit these restrictions.")
                    }
                    
                    Group {
                        Text("User Responsibilities")
                            .font(.headline)
                        
                        Text("As a user of the App, you are responsible for:")
                        
                        Text("• Maintaining the confidentiality of your account\n• Providing accurate medicine information\n• Ensuring your device is compatible with the App\n• Complying with all applicable laws when using the App")
                    }
                    
                    Group {
                        Text("Medical Disclaimer")
                            .font(.headline)
                        
                        Text("RemindRx is not a medical device or healthcare provider. The App is designed to help track medicine expiration dates and is not intended to replace professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional for medical advice. Never disregard professional medical advice or delay seeking it because of something you have read or seen in the App.")
                    }
                    
                    Group {
                        Text("Intellectual Property")
                            .font(.headline)
                        
                        Text("The App and its original content, features, and functionality are owned by RemindRx and are protected by international copyright, trademark, patent, trade secret, and other intellectual property or proprietary rights laws.")
                    }
                    
                    Group {
                        Text("Limitation of Liability")
                            .font(.headline)
                        
                        Text("To the maximum extent permitted by applicable law, RemindRx shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, data, or use, arising out of or in connection with these Terms or your use of the App, whether based on warranty, contract, tort, or any other legal theory, even if RemindRx has been advised of the possibility of such damages.")
                    }
                    
                    Group {
                        Text("Changes to Terms")
                            .font(.headline)
                        
                        Text("We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days' notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.")
                    }
                    
                    Group {
                        Text("Termination")
                            .font(.headline)
                        
                        Text("We may terminate or suspend your access to the App immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.")
                    }
                    
                    Group {
                        Text("Governing Law")
                            .font(.headline)
                        
                        Text("These Terms shall be governed by the laws of the jurisdiction in which the App developer is located, without regard to its conflict of law provisions.")
                    }
                    
                    Group {
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("If you have any questions about these Terms, please contact us at:")
                        
                        Text("support@remindrx.app")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms and Conditions")
            .navigationBarItems(trailing: Button("Done") {
                // Properly dismiss the sheet using SwiftUI's presentationMode
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Billing Terms View
struct BillingTermsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Billing Terms")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Last Updated: March 13, 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("These Billing Terms (\"Billing Terms\") govern your payments and financial contributions to RemindRx. Please read them carefully.")
                    }
                    
                    Group {
                        Text("Free Trial")
                            .font(.headline)
                        
                        Text("RemindRx is currently available for free on a trial basis. All features are available to all users at no cost. We may introduce premium features or subscription options in the future, at which time these Billing Terms will be updated accordingly.")
                    }
                    
                    Group {
                        Text("Voluntary Contributions")
                            .font(.headline)
                        
                        Text("Users may choose to make voluntary contributions to support the development of RemindRx. These contributions are:")
                        
                        Text("• Completely optional\n• Non-refundable\n• Not required to access any app features\n• Processed through secure third-party payment processors")
                    }
                    
                    Group {
                        Text("Future Pricing")
                            .font(.headline)
                        
                        Text("If RemindRx introduces premium features or subscription options in the future:")
                        
                        Text("• We will clearly communicate any changes to our pricing model\n• Current users will be given advance notice of at least 30 days\n• Some features may remain free while others become premium\n• We may offer grandfathered pricing or special offers to early users")
                    }
                    
                    Group {
                        Text("Payment Processing")
                            .font(.headline)
                        
                        Text("All voluntary contributions and any future payments are processed by trusted third-party payment processors. RemindRx does not directly store your credit card or banking information. By making a payment, you agree to the terms and privacy policies of these payment processors in addition to these Billing Terms.")
                    }
                    
                    Group {
                        Text("Cancellation and Refunds")
                            .font(.headline)
                        
                        Text("For voluntary contributions:")
                        
                        Text("• Contributions are considered donations and are generally non-refundable\n• In exceptional circumstances, refund requests may be considered on a case-by-case basis")
                        
                        Text("For any future subscription services:")
                        
                        Text("• You will be able to cancel at any time through your account settings\n• No refunds will be provided for partial subscription periods\n• Access to premium features will continue until the end of the current billing period")
                    }
                    
                    Group {
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("If you have any questions about these Billing Terms or any payment issues, please contact us at:")
                        
                        Text("support@remindrx.app")
                            .foregroundColor(.blue)
                    }
                    
                    Text("By making any payment to RemindRx, you acknowledge that you have read and agree to these Billing Terms.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("Billing Terms")
            .navigationBarItems(trailing: Button("Done") {
                // Properly dismiss the sheet using SwiftUI's presentationMode
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Extension to help with dismissing presented views
extension UIPresentationController {
    static var current: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.rootViewController?.presentedViewController
    }
    
    static func dismiss() {
        current?.dismiss(animated: true, completion: nil)
    }
}
struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding()
                
                Text("Delete All Data")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("This will permanently delete all your medicines, schedules, and history records. This action cannot be undone.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    // Delete all data
                    medicineStore.deleteAllMedicinesWithCleanup()
                    isPresented = false
                }) {
                    Text("Permanently Delete All Data")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Confirm Deletion", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}
