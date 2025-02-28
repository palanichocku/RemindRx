import Foundation

class DrugLookupService {
    
    // API endpoints
    private enum APIEndpoint {
        case openFDA
        case rxNav
        case upcItemDb
        case ndcList
        
        var url: URL? {
            switch self {
            case .openFDA:
                return URL(string: "https://api.fda.gov/drug/ndc.json")
            case .rxNav:
                return URL(string: "https://rxnav.nlm.nih.gov/REST/rxcui")
            case .upcItemDb:
                return URL(string: "https://api.upcitemdb.com/prod/trial/lookup")
            case .ndcList:
                return URL(string: "https://ndclist.com/api/v1/ndc")
            }
        }
    }
    
    // Error types
    enum LookupError: Error, LocalizedError {
        case invalidBarcode
        case networkError(Error)
        case noDataFound
        case invalidResponse
        case allApisFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                return "Invalid barcode format"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noDataFound:
                return "No data found for this barcode"
            case .invalidResponse:
                return "Invalid response from server"
            case .allApisFailed:
                return "Could not find information in any database"
            }
        }
    }
    
    // Drug info model
    struct DrugInfo {
        let name: String
        let description: String
        let manufacturer: String
        let isPrescription: Bool
        let ndcCode: String?
        
        // Default empty drug info
        static let empty = DrugInfo(
            name: "",
            description: "",
            manufacturer: "",
            isPrescription: false,
            ndcCode: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Lookup drug information using barcode
    /// - Parameters:
    ///   - barcode: The scanned barcode
    ///   - completion: Completion handler
    func lookupDrugByBarcode(barcode: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        // Clean up the barcode
        let cleanBarcode = cleanBarcode(barcode)
        
        // Try OpenFDA first
        lookupUsingOpenFDA(barcode: cleanBarcode) { [weak self] result in
            switch result {
            case .success(let drugInfo):
                completion(.success(drugInfo))
                
            case .failure:
                // Try RxNav next
                self?.lookupUsingRxNav(barcode: cleanBarcode) { result in
                    switch result {
                    case .success(let drugInfo):
                        completion(.success(drugInfo))
                        
                    case .failure:
                        // Try UPC database next
                        self?.lookupUsingUPCItemDb(barcode: cleanBarcode) { result in
                            switch result {
                            case .success(let drugInfo):
                                completion(.success(drugInfo))
                                
                            case .failure:
                                // Final attempt with NDC List
                                self?.lookupUsingNDCList(barcode: cleanBarcode) { result in
                                    switch result {
                                    case .success(let drugInfo):
                                        completion(.success(drugInfo))
                                        
                                    case .failure:
                                        // All APIs failed
                                        completion(.failure(LookupError.allApisFailed))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Clean up barcode by removing whitespace and validating format
    private func cleanBarcode(_ barcode: String) -> String {
        return barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Convert UPC to GTIN format if needed
    private func convertToGTIN(_ upc: String) -> String {
        // Convert UPC-A (12 digit) to GTIN-14 or EAN-13
        var gtin = upc
        
        if upc.count == 12 && CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: upc)) {
            // Add leading zero to make it EAN-13
            gtin = "0" + upc
        }
        
        return gtin
    }
    
    /// Convert NDC format as needed
    private func formatNDC(_ ndc: String) -> String {
        // NDC can be in several formats: 5-4-1, 5-3-2, 4-4-2
        // This is a simplified conversion
        let cleanNDC = ndc.replacingOccurrences(of: "-", with: "")
        
        if cleanNDC.count == 11 {
            // Standard NDC format
            return cleanNDC
        } else if cleanNDC.count == 10 {
            // Add leading zero
            return "0" + cleanNDC
        }
        
        return ndc
    }
    
    // MARK: - API Implementations
    
    /// Lookup using OpenFDA API
    private func lookupUsingOpenFDA(barcode: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        // Format NDC if barcode looks like it could be NDC
        let possibleNDC = formatNDC(barcode)
        
        guard let url = APIEndpoint.openFDA.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Construct the query URL
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "search", value: "package_ndc:\"\(possibleNDC)\""),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let requestURL = components?.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Make the request
        URLSession.shared.dataTask(with: requestURL) { data, response, error in
            if let error = error {
                completion(.failure(LookupError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LookupError.noDataFound))
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let result = results.first {
                    
                    let name = result["brand_name"] as? String ?? result["generic_name"] as? String ?? "Unknown Drug"
                    let manufacturer = result["labeler_name"] as? String ?? "Unknown Manufacturer"
                    
                    let drugClass = result["pharm_class"] as? [String] ?? []
                    let description = result["active_ingredients"] as? [[String: Any]]
                    
                    let descriptionString = description?.compactMap { ingredient in
                        if let name = ingredient["name"] as? String,
                           let strength = ingredient["strength"] as? String {
                            return "\(name) \(strength)"
                        }
                        return nil
                    }.joined(separator: ", ") ?? "No description available"
                    
                    // Check if prescription
                    let productTypes = result["product_type"] as? [String]
                    let isPrescription = productTypes == nil || !productTypes!.contains("OTC")
                    
                    let drugInfo = DrugInfo(
                        name: name,
                        description: descriptionString,
                        manufacturer: manufacturer,
                        isPrescription: isPrescription,
                        ndcCode: possibleNDC
                    )
                    
                    completion(.success(drugInfo))
                } else {
                    completion(.failure(LookupError.noDataFound))
                }
            } catch {
                completion(.failure(LookupError.invalidResponse))
            }
        }.resume()
    }
    
    /// Lookup using RxNav API
    private func lookupUsingRxNav(barcode: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        // RxNav uses NDC format
        let possibleNDC = formatNDC(barcode)
        
        guard let baseURL = APIEndpoint.rxNav.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Build URL for finding RxCUI by NDC
        let ndcURL = baseURL.appendingPathComponent("/ndcstatus.json")
        var components = URLComponents(url: ndcURL, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "ndc", value: possibleNDC)]
        
        guard let requestURL = components?.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Make the request
        URLSession.shared.dataTask(with: requestURL) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(LookupError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LookupError.noDataFound))
                return
            }
            
            // Parse the JSON response to get RxCUI
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ndcStatus = json["ndcStatus"] as? [String: Any],
                   let conceptGroup = ndcStatus["conceptGroup"] as? [[String: Any]],
                   let conceptProperties = conceptGroup.first?["conceptProperties"] as? [[String: Any]],
                   let concept = conceptProperties.first,
                   let rxcui = concept["rxcui"] as? String {
                    
                    // Now get drug info using RxCUI
                    self?.getRxNavDrugInfoByRxCUI(rxcui: rxcui, completion: completion)
                } else {
                    completion(.failure(LookupError.noDataFound))
                }
            } catch {
                completion(.failure(LookupError.invalidResponse))
            }
        }.resume()
    }
    
    /// Get detailed drug info from RxNav using RxCUI
    private func getRxNavDrugInfoByRxCUI(rxcui: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        guard let baseURL = APIEndpoint.rxNav.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Build URL for drug properties
        let rxcuiURL = baseURL.appendingPathComponent("/\(rxcui)/allProperties.json")
        var components = URLComponents(url: rxcuiURL, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "prop", value: "names,attributes")]
        
        guard let requestURL = components?.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Make the request
        URLSession.shared.dataTask(with: requestURL) { data, response, error in
            if let error = error {
                completion(.failure(LookupError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LookupError.noDataFound))
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let propConceptGroup = json["propConceptGroup"] as? [String: Any],
                   let propConcept = propConceptGroup["propConcept"] as? [[String: Any]] {
                    
                    var name = ""
                    var manufacturer = "Unknown"
                    var description = ""
                    var isPrescription = true
                    
                    // Extract drug properties
                    for prop in propConcept {
                        if let propName = prop["propName"] as? String,
                           let propValue = prop["propValue"] as? String {
                            
                            switch propName {
                            case "RxNorm Name":
                                name = propValue
                            case "DISPLAY_NAME":
                                if name.isEmpty {
                                    name = propValue
                                }
                            case "MANUFACTURER":
                                manufacturer = propValue
                            case "ATTRIBUTES":
                                description += propValue + ". "
                            case "TTY":
                                if propValue == "OTC" {
                                    isPrescription = false
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    if name.isEmpty {
                        name = "Unknown Drug"
                    }
                    
                    if description.isEmpty {
                        description = "No description available"
                    }
                    
                    let drugInfo = DrugInfo(
                        name: name,
                        description: description,
                        manufacturer: manufacturer,
                        isPrescription: isPrescription,
                        ndcCode: nil
                    )
                    
                    completion(.success(drugInfo))
                } else {
                    completion(.failure(LookupError.noDataFound))
                }
            } catch {
                completion(.failure(LookupError.invalidResponse))
            }
        }.resume()
    }
    
    /// Lookup using UPC Item Database (useful for OTC drugs in retail packaging)
    private func lookupUsingUPCItemDb(barcode: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        guard let url = APIEndpoint.upcItemDb.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Prepare request body
        let requestBody: [String: Any] = ["upc": barcode]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(LookupError.invalidResponse))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Make the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(LookupError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LookupError.noDataFound))
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let item = items.first {
                    
                    let name = item["title"] as? String ?? "Unknown Product"
                    let brand = item["brand"] as? String ?? "Unknown Brand"
                    let description = item["description"] as? String ?? "No description available"
                    
                    // Determine if it's a medication
                    let category = item["category"] as? String ?? ""
                    let isMedication = category.lowercased().contains("health") ||
                                       category.lowercased().contains("medicine") ||
                                       category.lowercased().contains("drug")
                    
                    if isMedication {
                        // Assume OTC since this is retail database
                        let drugInfo = DrugInfo(
                            name: name,
                            description: description,
                            manufacturer: brand,
                            isPrescription: false,
                            ndcCode: nil
                        )
                        
                        completion(.success(drugInfo))
                    } else {
                        completion(.failure(LookupError.noDataFound))
                    }
                } else {
                    completion(.failure(LookupError.noDataFound))
                }
            } catch {
                completion(.failure(LookupError.invalidResponse))
            }
        }.resume()
    }
    
    /// Lookup using NDC List API
    private func lookupUsingNDCList(barcode: String, completion: @escaping (Result<DrugInfo, Error>) -> Void) {
        // Format NDC if barcode looks like it could be NDC
        let possibleNDC = formatNDC(barcode)
        
        guard let url = APIEndpoint.ndcList.url else {
            completion(.failure(LookupError.networkError(NSError(domain: "Invalid URL", code: 0, userInfo: nil))))
            return
        }
        
        // Construct the query URL
        let searchURL = url.appendingPathComponent("/\(possibleNDC)")
        
        // Make the request
        URLSession.shared.dataTask(with: searchURL) { data, response, error in
            if let error = error {
                completion(.failure(LookupError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(LookupError.noDataFound))
                return
            }
            
            // Parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let drugData = json["package"] as? [String: Any] {
                    
                    let name = drugData["proprietary_name"] as? String ?? drugData["nonproprietary_name"] as? String ?? "Unknown Drug"
                    let manufacturer = drugData["labeler_name"] as? String ?? "Unknown Manufacturer"
                    
                    // Get description from active ingredients
                    let activeIngredients = drugData["active_ingredients"] as? [[String: Any]] ?? []
                    let description = activeIngredients.compactMap { ingredient in
                        if let name = ingredient["name"] as? String,
                           let strength = ingredient["strength"] as? String {
                            return "\(name) \(strength)"
                        }
                        return nil
                    }.joined(separator: ", ")
                    
                    // Determine if prescription
                    let doseForm = (drugData["dosage_form"] as? String ?? "").lowercased()
                    let productType = (drugData["product_type"] as? String ?? "").lowercased()
                    
                    let isPrescription = !productType.contains("otc") &&
                                        !doseForm.contains("otc") &&
                                        !name.lowercased().contains("otc")
                    
                    let drugInfo = DrugInfo(
                        name: name,
                        description: description.isEmpty ? "No description available" : description,
                        manufacturer: manufacturer,
                        isPrescription: isPrescription,
                        ndcCode: possibleNDC
                    )
                    
                    completion(.success(drugInfo))
                } else {
                    completion(.failure(LookupError.noDataFound))
                }
            } catch {
                completion(.failure(LookupError.invalidResponse))
            }
        }.resume()
    }
}
