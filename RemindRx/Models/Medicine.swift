import CoreData
import Foundation

// Make Medicine conform to Equatable and Hashable to fix comparison issues
struct Medicine: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var description: String
    var manufacturer: String
    var type: MedicineType
    var alertInterval: AlertInterval
    var expirationDate: Date
    var dateAdded: Date = Date()
    var barcode: String?
    var source: String?
    
    enum MedicineType: String, Codable, CaseIterable {
        case prescription = "Prescription"
        case otc = "OTC"
    }
    
    enum AlertInterval: String, Codable, CaseIterable {
        case day = "1 Day Before"
        case week = "1 Week Before"
        case month = "1 Month Before"
        case sixtyDays = "60 Days Before"
        case ninetyDays = "90 Days Before"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .sixtyDays: return 60
            case .ninetyDays: return 90
            }
        }
    }
    
    // Equatable implementation
    static func == (lhs: Medicine, rhs: Medicine) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
