import Foundation
import VisionKit
import Vision
import UIKit


class OCRProcessingService {
    static let shared = OCRProcessingService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Process an image and extract medicine information using OCR
    func processImage(_ image: UIImage, completion: @escaping (OCRResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(OCRResult())
            return
        }
        
        // Create a request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create a text recognition request
        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNRecognizedTextObservation] else {
                completion(OCRResult())
                return
            }
            
            // Process the recognized text
            let recognizedText = results.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // Extract medicine information from recognized text
            let ocrResult = self.extractMedicineInformation(from: recognizedText)
            completion(ocrResult)
        }
        
        // Configure text recognition request
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        
        // Perform the request
        do {
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Error performing text recognition: \(error.localizedDescription)")
            completion(OCRResult())
        }
    }
    
    /// Process images from a VNDocumentCameraScan
    func processDocumentScan(_ scan: VNDocumentCameraScan, completion: @escaping (OCRResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allText: [String] = []
            var finalResult = OCRResult()
            
            // Process all pages
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                
                let semaphore = DispatchSemaphore(value: 0)
                self.processImage(image) { result in
                    // Merge results from this page
                    self.mergeOCRResults(&finalResult, with: result)
                    
                    // Extract all text for later analysis
                    if let cgImage = image.cgImage {
                        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
                            guard let results = request.results as? [VNRecognizedTextObservation] else {
                                semaphore.signal()
                                return
                            }
                            
                            let pageText = results.compactMap { $0.topCandidates(1).first?.string }
                            allText.append(contentsOf: pageText)
                            semaphore.signal()
                        }
                        
                        textRecognitionRequest.recognitionLevel = .accurate
                        do {
                            try requestHandler.perform([textRecognitionRequest])
                        } catch {
                            semaphore.signal()
                        }
                    } else {
                        semaphore.signal()
                    }
                }
                
                // Wait for page processing to complete
                semaphore.wait()
            }
            
            // Additional processing on all text
            self.extractExpirationDate(from: allText, into: &finalResult)
            
            // Return final result on main thread
            DispatchQueue.main.async {
                completion(finalResult)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func extractMedicineInformation(from textLines: [String]) -> OCRResult {
        var result = OCRResult()
        
        // Extract name (usually in larger text near the top)
        if let name = findMedicineName(in: textLines) {
            result.name = name
        }
        
        // Extract manufacturer
        if let manufacturer = findManufacturer(in: textLines) {
            result.manufacturer = manufacturer
        }
        
        // Extract description
        if let description = findDescription(in: textLines) {
            result.description = description
        }
        
        // Check if it's prescription
        result.isPrescription = checkIfPrescription(in: textLines)
        
        // Extract expiration date
        extractExpirationDate(from: textLines, into: &result)
        
        // Extract barcode if visible in text
        if let barcode = findBarcode(in: textLines) {
            result.barcode = barcode
        }
        
        return result
    }
    
    private func findMedicineName(in textLines: [String]) -> String? {
        // Look at the first few lines for potential medicine names
        // Often the name appears in the first 3-5 lines and has certain characteristics
        
        let excludedWords = ["drug", "facts", "information", "patient", "healthcare", "professional", "storage", "uses", "warnings"]
        
        for line in textLines.prefix(5) {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip short lines, empty lines or lines with too many numbers
            if cleanLine.count < 3 || cleanLine.isEmpty {
                continue
            }
            
            // Skip lines that are likely not the medicine name
            let lowercaseLine = cleanLine.lowercased()
            if excludedWords.contains(where: { lowercaseLine.contains($0) }) {
                continue
            }
            
            // Check if line contains too many digits (probably not a name)
            let digitCount = lowercaseLine.filter { $0.isNumber }.count
            if Double(digitCount) / Double(lowercaseLine.count) > 0.3 {
                continue
            }
            
            // If we reach here, this is likely a good candidate for the medicine name
            return cleanLine
        }
        
        return nil
    }
    
    private func findManufacturer(in textLines: [String]) -> String? {
        // Keywords that often precede manufacturer information
        let manufacturerKeywords = ["manufactured by", "distributed by", "marketed by", "by:", "manufactured for"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            for keyword in manufacturerKeywords {
                if lowercaseLine.contains(keyword) {
                    // Extract the part after the keyword
                    if let range = lowercaseLine.range(of: keyword) {
                        let manufacturerPart = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !manufacturerPart.isEmpty {
                            return manufacturerPart
                        }
                    }
                }
            }
        }
        
        // If no clear manufacturer found, look for lines that might be company names
        let companyIndicators = ["inc.", "llc", "ltd", "corp.", "corporation", "pharmaceuticals", "pharma"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            if companyIndicators.contains(where: { lowercaseLine.contains($0) }) && !line.contains("www.") {
                // This line likely contains a company name (but skip website URLs)
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func findDescription(in textLines: [String]) -> String? {
        // Keywords that often appear in medicine descriptions
        let descriptionKeywords = ["contains", "active ingredient", "each tablet", "for the treatment of",
                                 "mg", "mcg", "ml", "treatment", "relief", "symptoms"]
        
        // Look for ingredient sections
        var descriptionLines: [String] = []
        var foundIngredientSection = false
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            // Start of ingredient section
            if lowercaseLine.contains("active ingredients") ||
               lowercaseLine.contains("ingredients") && !foundIngredientSection {
                foundIngredientSection = true
                descriptionLines.append(line)
                continue
            }
            
            // Within ingredient section, collect lines until we hit a new section
            if foundIngredientSection {
                // Check if we've reached the end of the ingredient section
                if lowercaseLine.contains("directions") ||
                   lowercaseLine.contains("warnings") ||
                   lowercaseLine.contains("storage") {
                    break
                }
                
                // Add this line to our description
                descriptionLines.append(line)
                
                // Limit description to keep it reasonable
                if descriptionLines.count >= 5 {
                    break
                }
            }
        }
        
        // If no ingredient section found, try to find description using keywords
        if descriptionLines.isEmpty {
            for line in textLines {
                let lowercaseLine = line.lowercased()
                
                if descriptionKeywords.contains(where: { lowercaseLine.contains($0) }) {
                    descriptionLines.append(line)
                    
                    // Limit to a reasonable size
                    if descriptionLines.count >= 3 {
                        break
                    }
                }
            }
        }
        
        // Return the compiled description
        if !descriptionLines.isEmpty {
            return descriptionLines.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func checkIfPrescription(in textLines: [String]) -> Bool {
        // Look for keywords indicating prescription status
        let prescriptionIndicators = ["rx only", "prescription only", "prescription drug", "federal law prohibits"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            for indicator in prescriptionIndicators {
                if lowercaseLine.contains(indicator) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func findBarcode(in textLines: [String]) -> String? {
        // Look for potential barcode numbers in the text
        // Common barcode formats: NDC codes, UPC, EAN, etc.
        
        // NDC code pattern (National Drug Code)
        let ndcPatterns = [
            #"NDC\s*\d{1,5}[-\s]?\d{1,4}[-\s]?\d{1,2}"#,   // NDC XXXXX-XXXX-XX format
            #"NDC\s*\d{1,5}[-\s]?\d{1,4}"#                 // NDC XXXXX-XXXX format
        ]
        
        // UPC/EAN patterns (common retail barcodes)
        let barcodePatterns = [
            #"\b\d{12}\b"#,    // UPC-A (12 digits)
            #"\b\d{13}\b"#,    // EAN-13 (13 digits)
            #"\b\d{8}\b"#      // EAN-8 (8 digits)
        ]
        
        // First try to find NDC codes
        for pattern in ndcPatterns {
            if let barcode = searchPattern(pattern: pattern, in: textLines) {
                // Clean up any spaces or hyphens
                return barcode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            }
        }
        
        // Then try to find UPC/EAN barcodes
        for pattern in barcodePatterns {
            if let barcode = searchPattern(pattern: pattern, in: textLines) {
                return barcode
            }
        }
        
        return nil
    }
    
    private func searchPattern(pattern: String, in textLines: [String]) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            
            for line in textLines {
                let nsString = line as NSString
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches.first {
                    return nsString.substring(with: match.range)
                }
            }
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func extractExpirationDate(from textLines: [String], into result: inout OCRResult) {
        // Common expiration date indicators
        let expiryKeywords = ["exp", "exp.", "exp date", "expiry", "expire", "expires", "expiration", "use by", "best by"]
        
        // First pass: look for explicit expiration date mentions
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            // Check if line contains expiration keywords
            for keyword in expiryKeywords {
                if lowercaseLine.contains(keyword) {
                    // Try to extract date from this line
                    if let date = extractDateFromText(line) {
                        result.expirationDate = date
                        return
                    }
                }
            }
        }
        
        // Second pass: look for date patterns that might be expiration dates
        for line in textLines {
            if let date = extractDateFromText(line) {
                // Make sure it's a future date or reasonably recent past date
                let calendar = Calendar.current
                let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                let fiveYearsFromNow = calendar.date(byAdding: .year, value: 5, to: Date()) ?? Date()
                
                if date >= sixMonthsAgo && date <= fiveYearsFromNow {
                    result.expirationDate = date
                    return
                }
            }
        }
    }
    
    private func extractDateFromText(_ text: String) -> Date? {
        // Define date formatters for various common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Common date formats found on medicine packaging
        let dateFormats = [
            "MM/yyyy",
            "MM/dd/yyyy",
            "yyyy-MM-dd",
            "MMM yyyy",
            "MMMM yyyy",
            "dd MMM yyyy",
            "yyyy-MM",
            "MM-yyyy"
        ]
        
        // Common date patterns to extract from text
        let datePatterns = [
            #"\d{1,2}/\d{1,2}/\d{2,4}"#,     // MM/DD/YYYY or DD/MM/YYYY
            #"\d{1,2}/\d{2,4}"#,             // MM/YYYY
            #"\d{2,4}-\d{1,2}-\d{1,2}"#,     // YYYY-MM-DD
            #"\d{2,4}-\d{1,2}"#,             // YYYY-MM
            #"\d{1,2}-\d{1,2}-\d{2,4}"#,     // DD-MM-YYYY or MM-DD-YYYY
            #"\d{1,2}-\d{2,4}"#,             // MM-YYYY
            #"[A-Za-z]{3,} \d{2,4}"#,        // MMM YYYY or MMMM YYYY
            #"\d{1,2} [A-Za-z]{3,} \d{2,4}"# // DD MMM YYYY or DD MMMM YYYY
        ]
        
        for pattern in datePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[match])
                
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func mergeOCRResults(_ main: inout OCRResult, with additional: OCRResult) {
        // Keep the name if main doesn't have one or if additional has a longer, more descriptive name
        if main.name.isEmpty ||
           (!additional.name.isEmpty && additional.name.count > main.name.count && main.name.count < 10) {
            main.name = additional.name
        }
        
        // Keep manufacturer if main doesn't have one
        if main.manufacturer.isEmpty && !additional.manufacturer.isEmpty {
            main.manufacturer = additional.manufacturer
        }
        
        // Append descriptions if they're different
        if !additional.description.isEmpty {
            if main.description.isEmpty {
                main.description = additional.description
            } else if !main.description.contains(additional.description) {
                main.description += ". " + additional.description
            }
        }
        
        // Take expiration date if main doesn't have one or additional is later
        if let additionalDate = additional.expirationDate {
            if main.expirationDate == nil ||
               (main.expirationDate! < additionalDate && additionalDate > Date()) {
                main.expirationDate = additionalDate
            }
        }
        
        // Take barcode if main doesn't have one
        if main.barcode == nil && additional.barcode != nil {
            main.barcode = additional.barcode
        }
        
        // Check prescription status - if either says prescription, mark as prescription
        if additional.isPrescription {
            main.isPrescription = true
        }
    }
}
