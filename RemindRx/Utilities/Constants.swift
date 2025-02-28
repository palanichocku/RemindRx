import SwiftUI

struct AppConstants {
    // App Information
    static let appName = "RemindRx"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let supportEmail = "support@remindrx.app"
    static let websiteURL = "https://www.remindrx.app"
    
    // Feature Constants
    static let defaultExpirationDays = 365 // Default expiration is 1 year
    static let lowQuantityThreshold = 5
    static let minimumScanTime = 0.5 // Minimum time to show scanning animation
    
    // UI Constants
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 4
    static let defaultPadding: CGFloat = 16
    static let tileHeight: CGFloat = 80
    static let animationDuration = 0.3
    static let scannerOverlayOpacity = 0.5
    
    // Scanner Guide Frame
    static let scanRectWidthRatio: CGFloat = 0.8
    static let scanRectHeightRatio: CGFloat = 0.4
    static let scanCornerLength: CGFloat = 20
    static let scanCornerWidth: CGFloat = 5
    
    // Notification Constants
    static let notificationTimeHour = 9 // 9 AM
    static let notificationTimeMinute = 0
    static let notificationCategory = "MEDICINE_EXPIRY"
    static let notificationActionView = "VIEW"
    static let notificationActionDismiss = "DISMISS"
    
    // Core Data
    static let coreDataModelName = "CoreDataModel"
    
    // URLs and API Keys (for real app, use secure storage)
    static let openFDAAPIKey = "" // Add your API key if needed
}

// MARK: - App Colors

struct AppColors {
    // Brand Colors
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")
    
    // Status Colors
    static let valid = Color.green
    static let warning = Color.yellow
    static let error = Color.red
    
    // Medicine Types
    static let otc = Color.green
    static let prescription = Color.blue
    
    // Fallback if custom colors not defined
    static func primaryFallback() -> Color {
        return Color(.systemBlue)
    }
    
    static func secondaryFallback() -> Color {
        return Color(.systemIndigo)
    }
    
    static func accentFallback() -> Color {
        return Color(.systemTeal)
    }
}

// MARK: - String Constants

struct AppStrings {
    // Navigation Titles
    static let medicineListTitle = "RemindRx"
    static let addMedicineTitle = "Add Medicine"
    static let editMedicineTitle = "Edit Medicine"
    static let medicineDetailTitle = "Medicine Details"
    static let aboutTitle = "About"
    static let settingsTitle = "Settings"
    
    // Button Labels
    static let add = "Add"
    static let scan = "Scan"
    static let save = "Save"
    static let cancel = "Cancel"
    static let delete = "Delete"
    static let clearAll = "Clear All"
    static let scanBarcode = "Scan Barcode"
    static let addManually = "Add Manually"
    
    // Field Labels
    static let name = "Name"
    static let manufacturer = "Manufacturer"
    static let description = "Description"
    static let type = "Type"
    static let expirationDate = "Expiration Date"
    static let alertInterval = "Alert"
    static let barcode = "Barcode"
    
    // Medicine Types
    static let prescriptionLabel = "Prescription"
    static let otcLabel = "OTC"
    
    // Alert Messages
    static let deleteConfirmationTitle = "Delete Medicine"
    static let deleteConfirmationMessage = "Are you sure you want to delete this medicine? This action cannot be undone."
    static let deleteAllConfirmationTitle = "Delete All Medicines"
    static let deleteAllConfirmationMessage = "Are you sure you want to delete all medicines? This action cannot be undone."
    static let scanFailedTitle = "Scan Failed"
    static let scanFailedMessage = "Unable to scan barcode. Please try again or enter medicine details manually."
    static let lookupFailedTitle = "Lookup Failed"
    static let lookupFailedMessage = "Unable to find medicine information for this barcode. Please enter medicine details manually."
    
    // Placeholders
    static let namePlaceholder = "Medicine Name"
    static let manufacturerPlaceholder = "Manufacturer Name"
    static let descriptionPlaceholder = "Enter medicine description, usage, or notes"
    
    // Scanner Instructions
    static let scannerInstructions = "Position barcode within frame"
    static let scanningText = "Scanning..."
    static let processingText = "Processing..."
    
    // Toggle Labels
    static let showExpiredOnly = "Show Expired Only"
    
    // Notification Text
    static let notificationTitle = "Medicine Expiring Soon"
    static let notificationBody = "will expire on"
}

// MARK: - Image Names

struct AppImages {
    // Tab Icons
    static let homeTab = "house.fill"
    static let scanTab = "barcode.viewfinder"
    static let aboutTab = "info.circle.fill"
    
    // Action Icons
    static let add = "plus"
    static let scan = "barcode.viewfinder"
    static let delete = "trash"
    static let edit = "pencil"
    static let save = "checkmark"
    static let calendar = "calendar"
    static let alert = "bell"
    static let info = "info.circle"
    
    // Medicine Type Icons
    static let prescription = "pill.fill"
    static let otc = "cross.case.fill"
    
    // Status Icons
    static let expired = "exclamationmark.circle.fill"
    static let expiringSoon = "exclamationmark.triangle.fill"
    static let valid = "checkmark.circle.fill"
    
    // App Icon
    static let appIcon = "AppIcon"
    static let appIconFallback = "pills"
}

// MARK: - Accessibility Identifiers

struct AccessibilityIDs {
    static let medicineList = "medicineListView"
    static let addMedicineButton = "addMedicineButton"
    static let scanButton = "scanButton"
    static let saveButton = "saveButton"
    static let deleteButton = "deleteButton"
    static let clearAllButton = "clearAllButton"
    static let medicineNameField = "medicineNameField"
    static let medicineTypeSelector = "medicineTypeSelector"
    static let expirationDatePicker = "expirationDatePicker"
    static let alertIntervalPicker = "alertIntervalPicker"
    static let showExpiredToggle = "showExpiredToggle"
    static let scannerView = "scannerView"
}

// MARK: - Extensions for Consistent Formatting

extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension NumberFormatter {
    static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
