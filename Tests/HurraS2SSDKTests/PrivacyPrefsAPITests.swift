import Testing
// import AdSupport
import Foundation
@testable import HurraS2SSDK

// Actor to safely handle mutable state in tests
actor PPATestState {
    var responseReceived = false
    var firstResponseReceived = false
    var secondResponseReceived = false
    
    func setResponseReceived() {
//        print("response received")
        responseReceived = true
    }
    
    func setFirstResponseReceived() {
        firstResponseReceived = true
    }
    
    func setSecondResponseReceived() {
        secondResponseReceived = true
    }
}


struct TestCredentials: Sendable {
    let accountId: String?
    let apiKey: String?
    let vendorId: String?
}

private final class TestBundleLocator {}

private func configureTestCredentials() -> TestCredentials {
    // Get the bundle containing the test target
    let bundle = Bundle(for: TestBundleLocator.self)
    
    if let path = bundle.path(forResource: "testCredentials", ofType: "plist", inDirectory: "HurraS2SSDK_HurraS2SSDKTests.bundle"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
        return TestCredentials(
            accountId: dict["testAccountId"] as? String,
            apiKey: dict["testAPIKey"] as? String,
            vendorId: dict["testVendorId"] as? String
        )
    }
    return TestCredentials(accountId: nil, apiKey: nil, vendorId: nil)
}

let testCredentials = configureTestCredentials()

let testAccountId = testCredentials.accountId
let testApiKey = testCredentials.apiKey
let testVendorId = testCredentials.vendorId
let testUserId = UUID().uuidString // Generate a random UUID for each test run

struct PrivacyPrefsAPITests {
    
    @MainActor
    @Test func testConsentStatus() async throws {
        guard let accountId = testAccountId else {
            print("Skipping test \(#function): testAccountId not found in testCredentials.plist")
            return
        }
        guard let apiKey = testApiKey else {
            print("Skipping test \(#function): testApiKey not found in testCredentials.plist")
            return
        }
        
        let state = PPATestState()
        let api = PrivacyPrefsAPI(
            accountId: accountId,
            apiKey: apiKey,
            userId: testUserId,
            testing: true
        )

        let c1 = await api.getConsentStatus() { result in
        Task { await state.setResponseReceived() }
            switch result {
            case .success(let status):
//                #expect(status.error == nil)
                #expect(status.userPreferences == nil)
                #expect(status.vendors != nil)
//                #expect(status.consentStatus?.externalVendors is [String:Int])
                #expect(status.statusesReasons != nil)
                #expect(status.acceptedVendorIds != nil)
                #expect(status.declinedVendorIds != nil)
//                #expect(status.consentStatus?.acceptedExternalVendorIds is [String])
//                #expect(status.consentStatus?.declinedExternalVendorIds is [String])
                #expect(status.showConsentBanner == true)
            case .failure(let error):
                #expect(Bool(false), "API call failed: \(error)")
            }
        }
        try await Task.sleep(for: .seconds(1))
//        #expect(state.responseReceived, "Response should have been received")
        api.privacyPrefs?.setAllCategories(true)
        switch c1 {
        case .success(let status):
            // print("Consent status:")
            // dump(status)
            #expect(status.userPreferences == nil)
            #expect(api.privacyPrefs?.getUserPreferences() == status.userPreferences)
         case .failure(let error):
            #expect(Bool(false), "API call failed: \(error)")
        }
        
        let c2 = await api.setConsentStatus() { result in
            Task { await state.setSecondResponseReceived() }
//            print ("Result:")
//            dump(result)
            switch result {
            case .success(let status):
//                print("Consent status:")
//                dump(status)
                #expect(status.userPreferences != nil)
            case .failure(let error):
                #expect(Bool(false), "API call failed: \(error)")
            }
        }
        try await Task.sleep(for: .seconds(1))
        switch c2 {
        case .success(let status):
            // print("Consent status:")
            // dump(status)
            #expect(status.userPreferences != nil)
            #expect(api.privacyPrefs?.getUserPreferences() == status.userPreferences)
         case .failure(let error):
            #expect(Bool(false), "API call failed: \(error)")
        }
        
    }

   @MainActor
   @Test func testVendorDetails() async throws {
       guard let accountId = testAccountId else {
           print("Skipping test \(#function): testAccountId not found in testCredentials.plist")
           return
       }
       guard let apiKey = testApiKey else {
           print("Skipping test \(#function): testApiKey not found in testCredentials.plist")
           return
       }
       guard let vendorId = testVendorId else {
           print("Skipping test \(#function): testVendorId not found in testCredentials.plist")
           return
       }
       let state = PPATestState()
       let api = PrivacyPrefsAPI(
           accountId: accountId,
           apiKey: apiKey,
           userId: testUserId,
           testing: true
       )
       // 302
       _ = await api.getVendorDetails(vendorId: vendorId) { result in
           Task { await state.setResponseReceived() }
           switch result {
           case .success(let status):
//                print("Vendor details:")
//                dump(status)
               #expect(status.vendorId == vendorId)
           case .failure(let error):
            //    print("Error: \(error)")
               #expect(Bool(false), "API call failed: \(error)")
           }
       }
       try await Task.sleep(for: .seconds(1))
       
       _ = await api.getVendorDetails(externalVendorId: "ga") { result in
           Task { await state.setResponseReceived() }
           switch result {
           case .success(let status):
//                print("Vendor details:")
//                dump(status)
               #expect(status.vendorId == "302")
               #expect(status.externalVendorId == "ga")
           case .failure(let error):
            //    print("Error: \(error)")
               #expect(Bool(false), "API call failed: \(error)")
           }
       }
       try await Task.sleep(for: .seconds(1))
   }
   
   @MainActor
   @Test func testGetVendorsDetails() async throws {
       guard let accountId = testAccountId else {
           print("Skipping test \(#function): testAccountId not found in testCredentials.plist")
           return
       }
       guard let apiKey = testApiKey else {
           print("Skipping test \(#function): testApiKey not found in testCredentials.plist")
           return
       }
       let api = PrivacyPrefsAPI(
           accountId: accountId,
           apiKey: apiKey,
           userId: testUserId,
           testing: true
       )
       
       _ = await api.getVendorsDetails(){ result in
       switch result {
           case .success(let vendors):
                   // Check that we received vendors data
                   #expect(vendors.count > 0)  
                   // Check vendor data structure
                   if let firstVendor = vendors.items.first {
                       #expect(firstVendor.name?.isEmpty == false)
                       #expect(firstVendor.vendorId?.isEmpty == false)
                   }
           case .failure(let error):
               print("Error: \(error)")
                   #expect(Bool(false), "API call failed: \(error)")
               }
       }
       try await Task.sleep(for: .seconds(1))
       
       
       _ = await api.getVendorsDetails(categoryName: PrivacyPrefs.PrivacyCategory.essential.categoryName){ result in
       
       
       switch result {
           case .success(let vendors):               
                // Check that we received vendors data
                #expect(vendors.count > 0)
                
                // Check that all vendors belong to the requested category
                let categoryName = PrivacyPrefs.PrivacyCategory.essential.categoryName
                let allInCategory = vendors.items.allSatisfy { $0.categoryName == categoryName }
                #expect(allInCategory, "All vendors should have categoryName equal to \(categoryName)")

                // Check vendor data structure
                if let firstVendor = vendors.items.first {
                    #expect(firstVendor.name?.isEmpty == false)
                    #expect(firstVendor.vendorId?.isEmpty == false)
                }
           case .failure(let error):
               print("Error: \(error)")
                   #expect(Bool(false), "API call failed: \(error)")
            }
       }
       try await Task.sleep(for: .seconds(1))

   }

   @Test func testGetCategories() async throws {
       guard let accountId = testAccountId else {
           print("Skipping test \(#function): testAccountId not found in testCredentials.plist")
           return
       }
       guard let apiKey = testApiKey else {
           print("Skipping test \(#function): testApiKey not found in testCredentials.plist")
           return
       }
       let api = PrivacyPrefsAPI(
           accountId: accountId,
           apiKey: apiKey,
           userId: testUserId,
           testing: true
       )

       _ = await api.getCategories() { result in
           switch result {
           case .success(let categories):
               
                // Check that all categories have unique categoryId and categoryName
                let categoryIds = categories.map { $0.categoryId }
                let uniqueCategoryIds = Set(categoryIds)
                #expect(categoryIds.count == uniqueCategoryIds.count, "All categoryIds should be unique")
                
                let categoryNames = categories.map { $0.categoryName }
                let uniqueCategoryNames = Set(categoryNames)
                #expect(categoryNames.count == uniqueCategoryNames.count, "All categoryNames should be unique")
                
                // Check that all categories have non-empty vendorIds
                let allCategoriesHaveVendors = categories.allSatisfy { category in
                    let vendorIds = category.vendorIds
                    return !vendorIds.isEmpty
                }
                #expect(allCategoriesHaveVendors, "All categories should have non-empty vendorIds")

           case .failure(let error):
               #expect(Bool(false), "API call failed: \(error)")
            }
       }
       try await Task.sleep(for: .seconds(1))
   }

    @Test func testGetTranslations() async throws {
       guard let accountId = testAccountId else {
           print("Skipping test \(#function): testAccountId not found in testCredentials.plist")
           return
       }
       guard let apiKey = testApiKey else {
           print("Skipping test \(#function): testApiKey not found in testCredentials.plist")
           return
       }
       let api = PrivacyPrefsAPI(
           accountId: accountId,
           apiKey: apiKey,
           userId: testUserId,
           testing: true   
       )
       
       let defaultTranslations = await api.getTranslations() { result in
           switch result {
           case .success(let translations):
                #expect(translations.language != nil, "Language should not be nil")
               #expect(translations.availableLanguages!.count > 0, "Available languages should not be empty")
                #expect(translations.privacyCenter != nil, "Privacy center should not be nil")
               #expect(translations.privacyCenter?.header != nil, "Privacy center header should not be nil")
               #expect(translations.privacyCenter?.subHeader != nil, "Privacy center subHeader should not be nil")
                   
           case .failure(let error):
               #expect(Bool(false), "API call failed: \(error)")
           }
        }
        try await Task.sleep(for: .seconds(1))
        
        switch defaultTranslations {
        case .success(let translations):
            if translations.availableLanguages!.count > 1 {
                // Create a local copy of the second language
                let secondLanguage = translations.availableLanguages![1]
                
                // Use it in a new async context
                _ = await api.getTranslations(language: secondLanguage) { result in
                    switch result {
                    case .success(let translations):
                        #expect(translations.language == secondLanguage, "Language should be \(secondLanguage)")
                    case .failure(let error):
                        #expect(Bool(false), "API call failed: \(error)")
                    }
                }
            } else {
                // Create a local copy of the second language
                let secondLanguage = translations.language
                
                // Use it in a new async context
                _ = await api.getTranslations(language: secondLanguage) { result in
                    switch result {
                    case .success(let translations):
                        #expect(translations.language == secondLanguage, "Language should be \(String(describing: secondLanguage))")
                    case .failure(let error):
                        #expect(Bool(false), "API call failed: \(error)")
                    }
                }
            }
        case .failure(let error):
            #expect(Bool(false), "API call failed: \(error)")
        }
        try await Task.sleep(for: .seconds(1))
        
        _ = await api.getTranslations(fields: ["vendors", "privacyCenter"]) { result in
            switch result {
            case .success(let translations):
                #expect(translations.language == nil, "Language should be nil")
                #expect(translations.availableLanguages == nil, "Available languages should be nil")
                #expect(translations.privacyCenter != nil, "Privacy center should not be nil")
                #expect(translations.privacyCenter?.header != nil, "Privacy center header should not be nil")
                #expect(translations.privacyCenter?.subHeader != nil, "Privacy center subHeader should not be nil")
                    
            case .failure(let error):
                #expect(Bool(false), "API call failed: \(error)")
            }
         }
         try await Task.sleep(for: .seconds(1))
   }
}
