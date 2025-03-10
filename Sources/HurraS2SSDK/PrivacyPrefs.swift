//
//  PrivacyPrefs.swift
//  S2SFramework
//
//  Created by Robert Maciasz on 11.02.25.
//

import Foundation

public class PrivacyPrefs: Codable {
    private var preferences: [String: Int] = [:]
    
    public init() {}
    
    public func setAllCategories(_ accept: Bool) {
        preferences["ac"] = accept ? 1 : 0
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
    
    public enum PrivacyCategory {
        case essential
        case analytics
        case functional
        case advertisement
        case personalization
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
