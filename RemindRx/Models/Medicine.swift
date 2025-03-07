import CoreData
import Foundation

// Make Medicine conform to Equatable and Hashable to fix comparison issues
public struct Medicine: Identifiable, Codable, Equatable, Hashable {
    public var id = UUID()
    public var name: String
    public var description: String
    public var manufacturer: String
    public var type: MedicineType
    public var alertInterval: AlertInterval
    public var expirationDate: Date
    public var dateAdded: Date = Date()
    public var barcode: String?
    public var source: String?
    
    public enum MedicineType: String, Codable, CaseIterable {
        case prescription = "Prescription"
        case otc = "OTC"
    }
    
    public enum AlertInterval: String, Codable, CaseIterable {
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
    public static func == (lhs: Medicine, rhs: Medicine) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
