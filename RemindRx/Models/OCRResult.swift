import Foundation

public struct OCRResult {
    public var name: String = ""
    public var manufacturer: String = ""
    public var description: String = ""
    public var expirationDate: Date? = nil
    public var isPrescription: Bool = false
    public var barcode: String? = nil
    
    // Default initializer
    public init(
        name: String = "",
        manufacturer: String = "",
        description: String = "",
        expirationDate: Date? = nil,
        isPrescription: Bool = false,
        barcode: String? = nil
    ) {
        self.name = name
        self.manufacturer = manufacturer
        self.description = description
        self.expirationDate = expirationDate
        self.isPrescription = isPrescription
        self.barcode = barcode
    }
    
    // Utility to check if we have meaningful results
    public var hasSubstantialContent: Bool {
        return !name.isEmpty || !manufacturer.isEmpty || !description.isEmpty || expirationDate != nil
    }
}
