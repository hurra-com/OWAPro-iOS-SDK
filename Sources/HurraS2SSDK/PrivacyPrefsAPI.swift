//
//  PrivacyPrefsAPI.swift
//  HurraS2SSDK
//
//  Created by Robert Maciasz on 12.03.25.
//

import Foundation

public final class PrivacyPrefsAPI: Codable, @unchecked Sendable {
    private let accountId: String
    private let apiKey: String
    private let userId: String
    private let testing: Bool?
    private var api_available: Bool?
    private var apiNotAvailableReason: String?
    public let privacyPrefs: PrivacyPrefs?

    @MainActor
    public init(
        accountId: String, 
        apiKey: String, 
        userId: String, 
        testing: Bool? = false, 
        privacyPrefs: PrivacyPrefs? = nil
    ) async {
        self.accountId = accountId
        self.apiKey = apiKey
        self.userId = userId
        self.testing = testing
        self.privacyPrefs = privacyPrefs ?? PrivacyPrefs()
        _ = await self.prefetchConsentStatus()
    }

    public enum APIError: Error {
        case networkError(Error)
        case noData
        case decodingError(Error)
        case apiError(String)
        case invalidURL
        
        public var localizedDescription: String {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noData:
                return "No data received from server"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .apiError(let message):
                return "API error: \(message)"
            case .invalidURL:
                return "Invalid URL"
            }
        }
    }

    @MainActor
    private func sendRequest<T>(
        method: String,
        endpoint: String,
        queryParams: [String: String],
        body: [String: Any],
        responseType: T.Type,
        completion: (@Sendable (Result<T, APIError>) -> Void)? = nil
    ) async where T: Decodable {
        guard let url = URL(string: "https://s2s.hurra.com/consent-api/\(accountId)/?app=1&user_id=\(userId)") else {
            completion?(.failure(.invalidURL))
            return
        }
        
        var finalURL = url.appendingPathComponent(endpoint)
        
        for (key, value) in queryParams {
            finalURL.append(queryItems: [URLQueryItem(name: key, value: value)])
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        if testing == true {
            request.setValue("tracking_devel_mode=1", forHTTPHeaderField: "Cookie")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion?(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion?(.failure(.noData))
                return
            }
            // First try to decode as the expected type
            do {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                // if satusCode is not 200 it may be error returned by API
                if statusCode >= 400 {
                    throw APIError.apiError("status: \(statusCode)")
                }
                let result = try JSONDecoder().decode(T.self, from: data)
//                dump(result)
                completion?(.success(result))
                return
                
            } catch {
                // If decoding as expected type fails, try to decode as error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion?(.failure(.apiError(errorResponse.error)))
                    return
                }
                
                // If both decodings fail, log the raw response and return decoding error
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Decoding failed for data: \(dataString)")
                }
                completion?(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }
    
    @MainActor
    private func prefetchConsentStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                await self.sendRequest(
                    method: "GET",
                    endpoint: "consentStatus",
                    queryParams: [:],
                    body: [:],
                    responseType: ConsentStatus.self
                ) { [weak self] result in
                    switch result {

                     case .success(_):
                        self?.api_available = true
                        continuation.resume(returning: true)
                    case .failure(let error):
                        self?.api_available = false
                        self?.apiNotAvailableReason = error.localizedDescription
                        continuation.resume(returning: false)
                    
                    }
                }
            }
        }
    }
    
    @MainActor
    public func getConsentStatus(
        completion: (@Sendable (Result<ConsentStatus, APIError>) -> Void)? = nil
    ) async -> Result<ConsentStatus, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }

        return await withCheckedContinuation { continuation in
            Task {
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "consentStatus", 
                    queryParams: [:], 
                    body: [:],
                    responseType: ConsentStatus.self
                ) { [weak self] result in
                    if case .success(let value) = result,
                       let self = self {
                        if let userPreferences = value.userPreferences {
                            self.privacyPrefs?.setUserPreferences(userPreferences)
                        }
                        // if let acceptedVendorIds = value.acceptedVendorIds {
                        //     for vendorId in acceptedVendorIds {
                        //         self.privacyPrefs?.setVendor(vendorId, accept: true)
                        //     }
                        // }
                        // if let declinedVendorIds = value.declinedVendorIds {
                        //     for vendorId in declinedVendorIds {
                        //         self.privacyPrefs?.setVendor(vendorId, accept: false)
                        //     }
                        // }
                        // if let acceptedExternalVendorIds = value.acceptedExternalVendorIds {
                        //     for vendorId in acceptedExternalVendorIds {
                        //         self.privacyPrefs?.setExternalVendor(vendorId, accept: true)
                        //     }
                        // }
                        // if let declinedExternalVendorIds = value.declinedExternalVendorIds {
                        //     for vendorId in declinedExternalVendorIds {
                        //         self.privacyPrefs?.setExternalVendor(vendorId, accept: false)
                        //     }
                        // }
                        
                        // if let showConsentBanner = value.showConsentBanner {
                        //     self.privacyPrefs?.setShowConsentBanner(showConsentBanner)
                        // }
                    }
                    completion?(result)
                    continuation.resume(returning: result)
                }
            }
        }
    }

    @MainActor
    public func setConsentStatus(
        completion: (@Sendable (Result<ConsentStatus, APIError>) -> Void)? = nil
    ) async -> Result<ConsentStatus, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in
            Task {
                await self.sendRequest(
                    method: "PUT", 
                    endpoint: "consentStatus", 
                    queryParams: [:], 
                    body: privacyPrefs?.getPreferences() ?? [:],
                    responseType: ConsentStatus.self
                ) { [weak self] result in
                    if case .success(let value) = result,
                       let self = self {
                        if let userPreferences = value.userPreferences {
                            self.privacyPrefs?.setUserPreferences(userPreferences)
                        }
                        // if let acceptedVendorIds = value.acceptedVendorIds {
                        //     for vendorId in acceptedVendorIds {
                        //         self.privacyPrefs?.setVendor(vendorId, accept: true)
                        //     }
                        // }
                        // if let declinedVendorIds = value.declinedVendorIds {
                        //     for vendorId in declinedVendorIds {
                        //         self.privacyPrefs?.setVendor(vendorId, accept: false)
                        //     }
                        // }
                        // if let acceptedExternalVendorIds = value.acceptedExternalVendorIds {
                        //     for vendorId in acceptedExternalVendorIds {
                        //         self.privacyPrefs?.setExternalVendor(vendorId, accept: true)
                        //     }
                        // }
                        // if let declinedExternalVendorIds = value.declinedExternalVendorIds {
                        //     for vendorId in declinedExternalVendorIds {
                        //         self.privacyPrefs?.setExternalVendor(vendorId, accept: false)
                        //     }
                        // }
                        
                        // if let showConsentBanner = value.showConsentBanner {
                        //     self.privacyPrefs?.setShowConsentBanner(showConsentBanner)
                        // }
                    }
                    completion?(result)
                    continuation.resume(returning: result)
                }
            }
        }
    }

    @MainActor
    public func getVendorsDetails(
        completion: (@Sendable (Result<Vendors, APIError>) -> Void)? = nil
    ) async -> Result<Vendors, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in
            Task {
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "vendors", 
                    queryParams: [:], 
                    body: [:],
                    responseType: Vendors.self
                ) { result in
                    // Create a new Result to avoid data races
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    @MainActor
    public func getVendorsDetails(
        categoryName: String,
        completion: (@Sendable (Result<Vendors, APIError>) -> Void)? = nil
    ) async -> Result<Vendors, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in
            Task {
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "vendors/\(categoryName)", 
                    queryParams: [:], 
                    body: [:],
                    responseType: Vendors.self
                ) { result in
                    // Create a new Result to avoid data races
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    @MainActor
    public func getVendorDetails(
        vendorId: String,
        completion: (@Sendable (Result<Vendor, APIError>) -> Void)? = nil
    ) async -> Result<Vendor, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in  
            Task {
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "vendor/vendorId/\(vendorId)", 
                    queryParams: [:], 
                    body: [:],
                    responseType: Vendor.self
                ) { result in
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):   
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    @MainActor
    public func getVendorDetails(
        externalVendorId: String,
        completion: (@Sendable (Result<Vendor, APIError>) -> Void)? = nil
    ) async -> Result<Vendor, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in  
            Task {
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "vendor/externalVendorId/\(externalVendorId)", 
                    queryParams: [:], 
                    body: [:],
                    responseType: Vendor.self
                ) { result in
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):   
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    @MainActor
    public func getCategories(
        completion: (@Sendable (Result<Categories, APIError>) -> Void)? = nil
    ) async -> Result<Categories, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in
            Task {  
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "categories", 
                    queryParams: [:], 
                    body: [:],
                    responseType: Categories.self   
                ) { result in
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }

    @MainActor
    public func getTranslations(
        language: String? = nil,
        fields: [String]? = nil,
        completion: (@Sendable (Result<Translations, APIError>) -> Void)? = nil
    ) async -> Result<Translations, APIError> {
        // Check api_available first
        guard api_available! else {
            let error = APIError.apiError("API is not available: \(String(describing: apiNotAvailableReason))")
            completion?(.failure(error))
            return .failure(error)
        }
        return await withCheckedContinuation { continuation in
            Task {
                let queryParams: [String: String] = ["fields": fields?.joined(separator: ",") ?? ""]
                await self.sendRequest(
                    method: "GET", 
                    endpoint: "translations\(language != nil ? "/\(language!)" : "")", 
                    queryParams: queryParams,
                    body: [:],
                    responseType: Translations.self 
                ) { result in
                    completion?(result)
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: .success(value))
                    case .failure(let error):   
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }
    
    
}

// MARK: - Supporting Types

public struct ErrorResponse: Codable {
    public let error: String
}

public struct ConsentStatus: Codable, Sendable {
    // public let error: String?
    public let userPreferences: String?
    public let vendors: [String: Int]?
    public let externalVendors: [String: Int]?
    public let statusesReasons: [String: String]?
    public let acceptedVendorIds: [String]?
    public let declinedVendorIds: [String]?
    public let acceptedExternalVendorIds: [String]?
    public let declinedExternalVendorIds: [String]?
    public let showConsentBanner: Bool?
}

public struct Vendor: Codable, Sendable {
    public let name: String?
    public let vendorId: String?
    public let externalVendorId: String?
    public let categoryName: String?
    public let legalBasis: String?
    public let defaultStatus: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case vendorId
        case externalVendorId
        case categoryName
        case legalBasis
        case defaultStatus
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        vendorId = try container.decode(String.self, forKey: .vendorId)
        externalVendorId = try container.decodeIfPresent(String.self, forKey: .externalVendorId)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        legalBasis = try container.decode(String.self, forKey: .legalBasis)
        defaultStatus = try container.decode(Int.self, forKey: .defaultStatus)
    }
}


public struct Vendors: Codable, Sendable {
    public private(set) var items: [Vendor]
    
    public init(items: [Vendor] = []) {
        self.items = items
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        // Try to decode as an array of vendors
        if let container = try? decoder.singleValueContainer() {
            items = try container.decode([Vendor].self)
        } else {
            // If that fails, initialize with an empty array
            items = []
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
    }
    
    // MARK: - Collection-like functionality
    
    public var count: Int {
        return items.count
    }
    
    public var isEmpty: Bool {
        return items.isEmpty
    }
    
    public subscript(index: Int) -> Vendor {
        return items[index]
    }
    
    // MARK: - Vendor lookup methods
    
//    /// Find a vendor by its ID
//    public func vendor(withId id: String) -> Vendor? {
//        return items.first { $0.vendorId == id }
//    }
//    
//    /// Find a vendor by its external ID
//    public func vendor(withExternalId id: String) -> Vendor? {
//        return items.first { $0.externalVendorId == id }
//    }
//    
//    /// Find vendors by category name
//    public func vendors(inCategory categoryName: String) -> [Vendor] {
//        return items.filter { $0.categoryName == categoryName }
//    }
//    
//    /// Get all vendors with a specific default status
//    public func vendors(withDefaultStatus status: ConsentStatus) -> [Vendor] {
//        return items.filter { $0.defaultStatus == status }
//    }
//    
//    /// Get all unique category names
//    public var categoryNames: [String] {
//        return Array(Set(items.map { $0.categoryName })).sorted()
//    }
    
    // MARK: - Mutating methods
    
    // /// Add a vendor to the collection
    // public mutating func add(_ vendor: Vendor) {
    //     // Don't add duplicates
    //     if !items.contains(where: { $0.vendorId == vendor.vendorId }) {
    //         items.append(vendor)
    //     }
    // }
    
    // /// Add multiple vendors to the collection
    // public mutating func add(contentsOf vendors: [Vendor]) {
    //     for vendor in vendors {
    //         add(vendor)
    //     }
    // }
    
    // /// Remove a vendor by ID
    // @discardableResult
    // public mutating func remove(vendorId: String) -> Vendor? {
    //     guard let index = items.firstIndex(where: { $0.vendorId == vendorId }) else {
    //         return nil
    //     }
    //     return items.remove(at: index)
    // }
}

// MARK: - Sequence Conformance
extension Vendors: Sequence {
    public func makeIterator() -> Array<Vendor>.Iterator {
        return items.makeIterator()
    }
}

// MARK: - Error handling extension
extension Vendors {
    /// Attempts to decode vendors from data, handling potential error responses
    public static func decode(from data: Data) -> Result<Vendors, Error> {
        do {
            // First try to decode as Vendors
            let vendors = try JSONDecoder().decode(Vendors.self, from: data)
            return .success(vendors)
        } catch {
            // If that fails, try to decode as an error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                return .failure(errorResponse.error as! Error)
            } else {
                // If both fail, return a generic error
                return .failure("Failed to decode vendors: \(error.localizedDescription)" as! Error)
            }
        }
    }
}

public struct Category: Codable, Sendable {
    public let categoryName: String
    public let categoryId: Int
    public let vendorIds: [String]
    public let externalVendorIds: [String]?
    
    public init(categoryName: String, categoryId: Int, vendorIds: [String], externalVendorIds: [String]? = nil) {
        self.categoryName = categoryName
        self.categoryId = categoryId
        self.vendorIds = vendorIds
        self.externalVendorIds = externalVendorIds
    }
}

public struct Categories: Codable, Sendable {
    public private(set) var items: [Category]
    
    public init(items: [Category] = []) {
        self.items = items
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        // Try to decode as an array of categories
        if let container = try? decoder.singleValueContainer() {
            items = try container.decode([Category].self)
        } else {
            // If that fails, initialize with an empty array
            items = []
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
    }
    
    // MARK: - Collection-like functionality
    
    public var count: Int {
        return items.count
    }
    
    public var isEmpty: Bool {
        return items.isEmpty
    }
    
    public subscript(index: Int) -> Category {
        return items[index]
    }
    
    // MARK: - Category lookup methods
    
//    /// Find a category by its ID
//    public func category(withId id: Int) -> Category? {
//        return items.first { $0.categoryId == id }
//    }
//    
//    /// Find a category by its name
//    public func category(withName name: String) -> Category? {
//        return items.first { $0.categoryName.lowercased() == name.lowercased() }
//    }
//    
//    /// Find all categories that contain a specific vendor ID
//    public func categories(containingVendorId vendorId: String) -> [Category] {
//        return items.filter { $0.containsVendor(id: vendorId) }
//    }
//    
//    /// Find all categories that contain a specific external vendor ID
//    public func categories(containingExternalVendorId vendorId: String) -> [Category] {
//        return items.filter { $0.containsExternalVendor(id: vendorId) }
//    }
//    
//    /// Get all category names
//    public var categoryNames: [String] {
//        return items.map { $0.categoryName }.sorted()
//    }
//    
//    /// Get all vendor IDs across all categories (deduplicated)
//    public var allVendorIds: [String] {
//        var vendorIds = Set<String>()
//        for category in items {
//            for id in category.vendorIds {
//                vendorIds.insert(id)
//            }
//        }
//        return Array(vendorIds).sorted()
//    }
//    
//    /// Get all external vendor IDs across all categories (deduplicated)
//    public var allExternalVendorIds: [String] {
//        var vendorIds = Set<String>()
//        for category in items {
//            if let externalIds = category.externalVendorIds {
//                for id in externalIds {
//                    vendorIds.insert(id)
//                }
//            }
//        }
//        return Array(vendorIds).sorted()
//    }
    
    // MARK: - Mutating methods
    
    // /// Add a category to the collection
    // public mutating func add(_ category: Category) {
    //     // Don't add duplicates
    //     if !items.contains(where: { $0.categoryId == category.categoryId }) {
    //         items.append(category)
    //     }
    // }
    
    // /// Add multiple categories to the collection
    // public mutating func add(contentsOf categories: [Category]) {
    //     for category in categories {
    //         add(category)
    //     }
    // }
    
    // /// Remove a category by ID
    // @discardableResult
    // public mutating func remove(categoryId: Int) -> Category? {
    //     guard let index = items.firstIndex(where: { $0.categoryId == categoryId }) else {
    //         return nil
    //     }
    //     return items.remove(at: index)
    // }
}

// MARK: - Sequence Conformance
extension Categories: Sequence {
    public func makeIterator() -> Array<Category>.Iterator {
        return items.makeIterator()
    }
}

// MARK: - Error handling extension
extension Categories {
    /// Attempts to decode categories from data, handling potential error responses
    public static func decode(from data: Data) -> Result<Categories, Error> {
        do {
            // First try to decode as Categories
            let categories = try JSONDecoder().decode(Categories.self, from: data)
            return .success(categories)
        } catch {
            // If that fails, try to decode as an error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                return .failure(errorResponse.error as! Error)
            } else {
                // If both fail, return a generic error
                return .failure("Failed to decode categories: \(error.localizedDescription)" as! Error)
            }
        }
    }
}

// MARK: - Translations
public struct Translations: Codable, Sendable {
    public let language: String?
    public let availableLanguages: [String]?
    public let consentBar: ConsentBar?
    public let privacyCenter: PrivacyCenter?
    public let categories: [CategoryInfo]?
    public let vendors: [VendorInfo]?
    
    // MARK: - ConsentBar
    public struct ConsentBar: Codable, Sendable {
        public let header: String?
        public let text: String
        public let bottomText: String?
        public let buttons: [String: ConsentBarButton]?
        public let cookiePolicy: ConsentBarPolicy?
        public let privacyPolicy: ConsentBarPolicy?
        
        // MARK: - ConsentBarButton
        public struct ConsentBarButton: Codable, Sendable {
            public let inline: Int?
            public let label: String?
            public let inlineToken: String?
            
            public var isInline: Bool {
                return inline == 1
            }
        }
        
        // MARK: - ConsentBarPolicy
        public struct ConsentBarPolicy: Codable, Sendable {
            public let inline: Int?
            public let label: String?
            public let url: String?
            public let inlineToken: String?
            
            public var isInline: Bool {
                return inline == 1
            }
        }
    }
    
    // MARK: - PrivacyCenter
    public struct PrivacyCenter: Codable, Sendable {
        public let header: String?
        public let info: PrivacyCenterInfo?
        public let subHeader: String?
        public let buttons: [String: PrivacyCenterButton]?
        public let cookiePolicy: PrivacyCenterPolicy?
        public let privacyPolicy: PrivacyCenterPolicy?
        
        // MARK: - PrivacyCenterInfo
        public struct PrivacyCenterInfo: Codable, Sendable {
            public let label: String?
            public let description: String?
        }
        
        // MARK: - PrivacyCenterButton
        public struct PrivacyCenterButton: Codable, Sendable {
            public let label: String?
        }
        
        // MARK: - PrivacyCenterPolicy
        public struct PrivacyCenterPolicy: Codable, Sendable {
            public let label: String?
            public let url: String?
        }
    }
    
    // MARK: - CategoryInfo
    public struct CategoryInfo: Codable, Sendable {
        public let categoryId: Int?
        public let categoryName: String?
        public let label: String?
        public let description: String?
    }
    
    // MARK: - VendorInfo
    public struct VendorInfo: Codable, Sendable {
        public let name: String?
        public let vendorId: String?
        public let externalVendorId: String?
        public let categoryId: Int?
        public let categoryName: String?
        public let description: String?
        public let cookiePolicy: String?
        public let privacyPolicy: String?
        public let optOut: String?
    }
    
    // MARK: - Helper Methods
    
    /// Get all vendors for a specific category
    public func vendors(forCategoryId categoryId: Int) -> [VendorInfo] {
        return vendors!.filter { $0.categoryId == categoryId }
    }
    
    /// Get all vendors for a specific category name
    public func vendors(forCategoryName categoryName: String) -> [VendorInfo] {
        return vendors!.filter { $0.categoryName == categoryName }
    }
    
    /// Get a category by its ID
    public func category(withId categoryId: Int) -> CategoryInfo? {
        return categories!.first { $0.categoryId == categoryId }
    }
    
    /// Get a category by its name
    public func category(withName categoryName: String) -> CategoryInfo? {
        return categories!.first { $0.categoryName == categoryName }
    }
    
    /// Get a vendor by its ID
    public func vendor(withId vendorId: String) -> VendorInfo? {
        return vendors!.first { $0.vendorId == vendorId }
    }
    
    /// Get a vendor by its external ID
    public func vendor(withExternalId externalVendorId: String) -> VendorInfo? {
        return vendors!.first { $0.externalVendorId == externalVendorId }
    }
    
    //    /// Get a button from the consent bar by its identifier
    // public func consentBarButton(withId buttonId: String) -> ConsentBarButton? {
    //     return consentBar?.buttons[buttonId]
    // }
    
    //    /// Get a button from the privacy center by its identifier
//    public func privacyCenterButton(withId buttonId: String) -> PrivacyCenterButton? {
//        return privacyCenter?.buttons[buttonId]
//    }
}

// MARK: - Error Handling
extension Translations {
    /// Attempts to decode Translations from data, handling potential error responses
    public static func decode(from data: Data) -> Result<Translations, Error> {
        do {
            let translations = try JSONDecoder().decode(Translations.self, from: data)
            return .success(translations)
        } catch {
            // Try to decode as an error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                return .failure(NSError(domain: "API Error", code: 400, userInfo: [NSLocalizedDescriptionKey: errorResponse.error]))
            } else {
                // If that fails too, return the original error
                return .failure(error)
            }
        }
    }
}

// // Thread-safe boolean wrapper
// private class AtomicBool: @unchecked Sendable{
//     private var value: Bool = false
//     private let lock = NSLock()
    
//     func set(_ newValue: Bool) {
//         lock.lock()
//         value = newValue
//         lock.unlock()
//     }
    
//     func get() -> Bool {
//         lock.lock()
//         defer { lock.unlock() }
//         return value
//     }
// }
