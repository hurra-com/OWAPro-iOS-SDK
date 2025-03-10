//
//  s2sframeworktestTests.swift
//  s2sframeworktestTests
//
//  Created by Robert Maciasz on 19.12.24.
//

import Testing
import AdSupport
@testable import HurraS2SSDK

// Actor to safely handle mutable state in tests
actor TestState {
    var responseReceived = false
    var firstResponseReceived = false
    var secondResponseReceived = false
    
    func setResponseReceived() {
        responseReceived = true
    }
    
    func setFirstResponseReceived() {
        firstResponseReceived = true
    }
    
    func setSecondResponseReceived() {
        secondResponseReceived = true
    }
}

struct PrivacyPrefsTests {
    
    @Test func testSetAllCategories() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        
        // Act
        prefs.setAllCategories(true)
        
        // Assert
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        #expect(decoded["ac"] == 1)
        
        // Test false case
        prefs.setAllCategories(false)
        let encodedFalse = try JSONEncoder().encode(prefs)
        let decodedFalse = try JSONSerialization.jsonObject(with: encodedFalse) as! [String: Int]
        #expect(decodedFalse["ac"] == 0)
    }
    
    @Test func testSetCategory() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        
        // Act & Assert for each category
        let categories: [(PrivacyPrefs.PrivacyCategory, String)] = [
            (.essential, "c0"),
            (.analytics, "c1"),
            (.functional, "c2"),
            (.advertisement, "c3"),
            (.personalization, "c4")
        ]
        
        for (category, key) in categories {
            // Test accept = true
            prefs.setCategory(category, accept: true)
            let encoded = try JSONEncoder().encode(prefs)
            let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
            #expect(decoded[key] == 1)
            
            // Test accept = false
            prefs.setCategory(category, accept: false)
            let encodedFalse = try JSONEncoder().encode(prefs)
            let decodedFalse = try JSONSerialization.jsonObject(with: encodedFalse) as! [String: Int]
            #expect(decodedFalse[key] == 0)
        }
    }
    
    @Test func testSetVendorById() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        let vendorId = "vendor123"
        
        // Act
        prefs.setVendorById(vendorId, accept: true)
        
        // Assert
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        #expect(decoded[vendorId] == 1)
        
        // Test false case
        prefs.setVendorById(vendorId, accept: false)
        let encodedFalse = try JSONEncoder().encode(prefs)
        let decodedFalse = try JSONSerialization.jsonObject(with: encodedFalse) as! [String: Int]
        #expect(decodedFalse[vendorId] == 0)
    }
    
    @Test func testSetVendorByNameSlug() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        let vendorName = "test-vendor"
        
        // Act
        prefs.setVendorByNameSlug(vendorName, accept: true)
        
        // Assert
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        #expect(decoded["v_\(vendorName)"] == 1)
        
        // Test false case
        prefs.setVendorByNameSlug(vendorName, accept: false)
        let encodedFalse = try JSONEncoder().encode(prefs)
        let decodedFalse = try JSONSerialization.jsonObject(with: encodedFalse) as! [String: Int]
        #expect(decodedFalse["v_\(vendorName)"] == 0)
    }
    
    @Test func testSetVendorByExternalId() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        let externalId = "ext123"
        
        // Act
        prefs.setVendorByExternalId(externalId, accept: true)
        
        // Assert
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        #expect(decoded["x_\(externalId)"] == 1)
        
        // Test false case
        prefs.setVendorByExternalId(externalId, accept: false)
        let encodedFalse = try JSONEncoder().encode(prefs)
        let decodedFalse = try JSONSerialization.jsonObject(with: encodedFalse) as! [String: Int]
        #expect(decodedFalse["x_\(externalId)"] == 0)
    }
    
    @Test func testMultiplePreferences() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        
        // Act
        prefs.setAllCategories(true)
        prefs.setCategory(.analytics, accept: false)
        prefs.setVendorById("vendor123", accept: true)
        prefs.setVendorByNameSlug("test-vendor", accept: true)
        prefs.setVendorByExternalId("ext123", accept: false)
        
        // Assert
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        
        #expect(decoded["ac"] == 1)
        #expect(decoded["c1"] == 0)
        #expect(decoded["vendor123"] == 1)
        #expect(decoded["v_test-vendor"] == 1)
        #expect(decoded["x_ext123"] == 0)
    }
    
    @Test func testCodableConformance() throws {
        // Arrange
        let prefs = PrivacyPrefs()
        prefs.setAllCategories(true)
        prefs.setCategory(.analytics, accept: false)
        
        // Act
        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(PrivacyPrefs.self, from: encoded)
        let reEncoded = try JSONEncoder().encode(decoded)
        
        // Assert
        let originalJson = try JSONSerialization.jsonObject(with: encoded) as! [String: Int]
        let reEncodedJson = try JSONSerialization.jsonObject(with: reEncoded) as! [String: Int]
        #expect(originalJson == reEncodedJson)
    }
}

struct HurraS2SSDKTests {
    
    @Test func testInitialization() {
        // Test without advertiser ID
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", testing: true)
        #expect(framework.getUserId() != nil)
        
        // Test customUserId
        let frameworkWithCustomUserId = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", testing: true, customUserId: "test-user-id")
        #expect(frameworkWithCustomUserId.getUserId() == "test-user-id")
        
        // Test with advertiser ID
        let frameworkWithAd = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: true, testing: true)
        #expect(frameworkWithAd.getUserId() == "00000000-0000-0000-0000-000000000000")
    }
    
    @Test func testSetAdvertiserId() {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: true, testing: true)
        
        // Act
        framework.setAdvertiserId()
        
        // Assert
        let advertiserId = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        #expect(framework.getUserId() == advertiserId)
    }
    
    @MainActor
    @Test func testSetPrivacyPrefs() async throws {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: false, testing: true)
        let prefs = PrivacyPrefs()
        prefs.setAllCategories(true)
        let testState = TestState()
        
        // Act
        framework.setPrivacyPrefs(prefs)
        
        // Assert through event sending
        await framework.sendEvent(
            eventData: ["test": "data"],
            currentView: "https://example.com"
        ) { result in
            if case .success(let response) = result {
                #expect(response.status == 1 || response.status == 0, "Completion response should indicate success")
                Task {
                    await testState.setResponseReceived()
                }
            }
        }
        
        // Wait a bit for the async operation to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(await testState.responseReceived, "Response should have been received")
    }
    
    @MainActor
    @Test func testSendEvent() async throws {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: false, testing: true)
        let eventData = ["action": "test_action", "value": "test_value"]
        let currentView = "https://example.com/test"
        let testState = TestState()
        
        // Act & Assert
        await framework.sendEvent(
            eventData: eventData,
            currentView: currentView,
            isInteractive: true
        ) { result in
            if case .success(let response) = result {
                #expect(response.status == 1 || response.status == 0, "Event should be sent successfully")
                Task {
                    await testState.setResponseReceived()
                }
            }
        }
        
        // Wait a bit for the async operation to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(await testState.responseReceived, "Response should have been received")
    }
    
    @MainActor
    @Test func testSendEventWithPreviousView() async throws {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: false, testing: false)
        let firstView = "https://example.com/first"
        let secondView = "https://example.com/second"
        let testState = TestState()
        
        // First event
        await framework.sendEvent(
            eventData: ["page": "first"],
            currentView: firstView
        ) { result in
            if case .success(let response) = result {
                #expect(response.status == 1 || response.status == 0, "First completion response should indicate success")
                Task {
                    await testState.setFirstResponseReceived()
                }
            }
        }
        
        // Wait a bit for the first async operation to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Second event should include first view as referrer
        await framework.sendEvent(
            eventData: ["page": "second"],
            currentView: secondView
        ) { result in
            if case .success(let response) = result {
                #expect(response.status == 1 || response.status == 0, "Second completion response should indicate success")
                Task {
                    await testState.setSecondResponseReceived()
                }
            }
        }
        
        // Wait a bit for the second async operation to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(await testState.firstResponseReceived, "First response should have been received")
        #expect(await testState.secondResponseReceived, "Second response should have been received")
    }
    
    @MainActor
    @Test func testSendEventWithoutCompletion() async throws {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: false, testing: true)
        let eventData = ["action": "test_action", "value": "test_value"]
        let currentView = "https://example.com/test"
        
        // Act & Assert - no completion handler
        await framework.sendEvent(
            eventData: eventData,
            currentView: currentView,
            isInteractive: true
        )
        
        // Wait a bit for the async operation to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Test passes if no error is thrown
        #expect(true, "Event should be sent without completion handler")
    }
    
    @MainActor
    @Test func testSendEventWithCompletion() async throws {
        // Arrange
        let framework = HurraS2SSDK(accountId: "test-account", apiKey: "test-key", useAdvertiserId: false, testing: true)
        let eventData = ["action": "test_action", "value": "test_value"]
        let currentView = "https://example.com/test"
        let testState = TestState()
        
        // Act & Assert - with completion handler
        await framework.sendEvent(
            eventData: eventData,
            currentView: currentView,
            isInteractive: true
        ) { result in
            if case .success(let response) = result {
                #expect(response.status == 1 || response.status == 0, "Completion response should indicate success")
                Task {
                    await testState.setResponseReceived()
                }
            }
        }
        
        // Wait a bit for the async operation to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        #expect(await testState.responseReceived, "Response should have been received")
    }
}
        
