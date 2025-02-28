import SwiftUI

struct DeleteConfirmationAlert {
    let title: String
    let message: String
    let primaryButtonLabel: String
    let secondaryButtonLabel: String
    let isPresented: Binding<Bool>
    let onDelete: () -> Void
    
    init(
        title: String,
        message: String,
        primaryButtonLabel: String = "Delete",
        secondaryButtonLabel: String = "Cancel",
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.primaryButtonLabel = primaryButtonLabel
        self.secondaryButtonLabel = secondaryButtonLabel
        self.isPresented = isPresented
        self.onDelete = onDelete
    }
    
    // Extension method to add the alert to a view
    func alert() -> Alert {
        Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: .destructive(Text(primaryButtonLabel), action: onDelete),
            secondaryButton: .cancel(Text(secondaryButtonLabel))
        )
    }
}

// Usage example extension for View
extension View {
    func deleteConfirmationAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        itemName: String? = nil,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.alert(isPresented: isPresented) {
            let formattedTitle = itemName != nil ? "\(title) \(itemName!)" : title
            
            return DeleteConfirmationAlert(
                title: formattedTitle,
                message: message,
                isPresented: isPresented,
                onDelete: onDelete
            ).alert()
        }
    }
    
    // Specialized variant for deleting a single medicine
    func deleteMedicineAlert(
        isPresented: Binding<Bool>,
        medicine: Medicine,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.deleteConfirmationAlert(
            isPresented: isPresented,
            title: "Delete Medicine",
            message: "Are you sure you want to delete \(medicine.name)? This action cannot be undone.",
            onDelete: onDelete
        )
    }
    
    // Specialized variant for deleting all medicines
    func deleteAllMedicinesAlert(
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        self.deleteConfirmationAlert(
            isPresented: isPresented,
            title: "Delete All Medicines",
            message: "Are you sure you want to delete all medicines? This action cannot be undone.",
            onDelete: onDelete
        )
    }
}
