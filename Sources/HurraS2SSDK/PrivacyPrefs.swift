//
//  PrivacyPrefs.swift
//  S2SFramework
//
//  Created by Robert Maciasz on 11.02.25.
//

import Foundation

public class PrivacyPrefs: Codable, @unchecked Sendable {
    private var preferences: [String: Int] = [:]
    private var userPreferences: String? = nil
    private var showConsentBanner: Bool = false
    private var vendors: [String: Int] = [:]
    private var externalVendors: [String: Int] = [:]
    public init() {}
    
    public func setAllCategories(_ accept: Bool) {
        preferences["all"] = accept ? 1 : 0
    }
    
    public func setCategory(_ category: PrivacyCategory, accept: Bool) {
        let value = accept ? 1 : 0
        switch category {
        case .essential:
            preferences["c0"] = value
        case .analytics:
            preferences["c1"] = value
        case .functional:
            preferences["c2"] = value
        case .advertisement:
            preferences["c3"] = value
        case .personalization:
            preferences["c4"] = value
        }
    }
    
    public func setVendorById(_ vendorId: String, accept: Bool) {
        preferences[vendorId] = accept ? 1 : 0
    }
    
    public func setVendorByNameSlug(_ vendorName: String, accept: Bool) {
        preferences["v_\(vendorName)"] = accept ? 1 : 0
    }
    
    public func setVendorByExternalId(_ externalId: String, accept: Bool) {
        preferences["x_\(externalId)"] = accept ? 1 : 0
    }
    
    public enum PrivacyCategory: String, CaseIterable {
        case essential
        case analytics
        case functional
        case advertisement
        case personalization
        
        var categoryName: String {
            switch self {
            case .essential: return "ESSENTIAL"
            case .analytics: return "ANALYTICS"
            case .functional: return "FUNCTIONAL"
            case .advertisement: return "ADVERTISEMENT"
            case .personalization: return "PERSONALIZATION"
            }
        }
        var categoryId: Int {
            switch self {
            case .essential: return 0
            case .analytics: return 1
            case .functional: return 2
            case .advertisement: return 3
            case .personalization: return 4
            }
        }
    }
    
    public func getPreferences() -> [String: Int] {
        return preferences
    }
    
    public func getUserPreferences() -> String? {
        return userPreferences
    }
    
    public func setUserPreferences(_ userPreferences: String?) {
        self.userPreferences = userPreferences
    }

    public func getShowConsentBanner() -> Bool {
        return showConsentBanner
    }

    public func _setShowConsentBanner(_ showConsentBanner: Bool) {
        self.showConsentBanner = showConsentBanner
    }


    
    // Codable conformance
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(preferences)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        preferences = try container.decode([String: Int].self)
    }

    
}
