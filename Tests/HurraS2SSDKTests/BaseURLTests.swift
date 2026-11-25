//
//  BaseURLTests.swift
//  HurraS2SSDKTests
//

import Testing
import Foundation
@testable import HurraS2SSDK

struct BaseURLTests {

    // MARK: - Validation

    @Test func testValidBaseURLs() {
        #expect(BaseURL.isValid(HurraS2SSDK.defaultBaseURL))
        #expect(BaseURL.isValid(URL(string: "https://www.example.com")!))
        #expect(BaseURL.isValid(URL(string: "https://www.example.com/")!))
        #expect(BaseURL.isValid(URL(string: "https://www.example.com/hc_s2s")!))
        #expect(BaseURL.isValid(URL(string: "https://www.example.com/hc_s2s/")!))
    }

    @Test func testInvalidBaseURLs() {
        let invalid = [
            "http://www.example.com",
            "www.example.com",
            "https:///hc_s2s",
            "https://www.example.com/hc_s2s?a=1",
            "https://www.example.com/hc_s2s#a",
        ]
        for string in invalid {
            // A string that isn't a URL at all can't be passed as `URL` either.
            if let url = URL(string: string) {
                #expect(!BaseURL.isValid(url), "\(string)")
            }
        }
    }

    @Test func testNormalizedString() {
        #expect(BaseURL.normalizedString(URL(string: "https://s2s.hurra.com")!) == "https://s2s.hurra.com")
        #expect(BaseURL.normalizedString(URL(string: "https://www.example.com/")!) == "https://www.example.com")
        #expect(BaseURL.normalizedString(URL(string: "https://www.example.com/hc_s2s/")!) == "https://www.example.com/hc_s2s")
    }

    // MARK: - Tracking URL

    @Test func testTrackingURLWithDefaultBaseURLIsUnchanged() {
        let url = HurraS2SSDK.trackingURL(baseURL: HurraS2SSDK.defaultBaseURL, accountId: "acc")
        // URL built before the base URL was configurable
        let legacy = URL(string: "https://s2s.hurra.com/rt?cid=acc&app=1")
        #expect(url == legacy)
        #expect(url?.absoluteString == "https://s2s.hurra.com/rt?cid=acc&app=1")
    }

    @Test func testTrackingURLWithCustomBaseURL() {
        let expectedRoot = "https://www.example.com/rt?cid=acc&app=1"
        #expect(HurraS2SSDK.trackingURL(baseURL: URL(string: "https://www.example.com")!, accountId: "acc")?.absoluteString == expectedRoot)
        #expect(HurraS2SSDK.trackingURL(baseURL: URL(string: "https://www.example.com/")!, accountId: "acc")?.absoluteString == expectedRoot)

        let expectedPath = "https://www.example.com/hc_s2s/rt?cid=acc&app=1"
        #expect(HurraS2SSDK.trackingURL(baseURL: URL(string: "https://www.example.com/hc_s2s")!, accountId: "acc")?.absoluteString == expectedPath)
        #expect(HurraS2SSDK.trackingURL(baseURL: URL(string: "https://www.example.com/hc_s2s/")!, accountId: "acc")?.absoluteString == expectedPath)
    }

    // MARK: - Consent API URL

    /// URL as built before the base URL was configurable.
    private func legacyConsentURL(accountId: String, userId: String, endpoint: String, queryParams: [String: String]) -> URL? {
        guard let url = URL(string: "https://s2s.hurra.com/consent-api/\(accountId)/?app=1&user_id=\(userId)") else {
            return nil
        }
        var finalURL = url.appendingPathComponent(endpoint)
        for (key, value) in queryParams {
            finalURL.append(queryItems: [URLQueryItem(name: key, value: value)])
        }
        return finalURL
    }

    @Test func testConsentURLWithDefaultBaseURLIsUnchanged() {
        let endpoints = [
            "consentStatus",
            "vendors",
            "vendors/analytics",
            "vendor/vendorId/123",
            "vendor/externalVendorId/abc",
            "categories",
            "translations",
            "translations/en",
        ]
        for endpoint in endpoints {
            for queryParams in [[:], ["fields": "name"]] as [[String: String]] {
                let url = PrivacyPrefsAPI.consentURL(
                    baseURL: HurraS2SSDK.defaultBaseURL,
                    accountId: "acc",
                    userId: "user",
                    endpoint: endpoint,
                    queryParams: queryParams
                )
                let legacy = legacyConsentURL(accountId: "acc", userId: "user", endpoint: endpoint, queryParams: queryParams)
                #expect(url != nil)
                #expect(url == legacy)
            }
        }
        #expect(
            PrivacyPrefsAPI.consentURL(baseURL: HurraS2SSDK.defaultBaseURL, accountId: "acc", userId: "user", endpoint: "consentStatus", queryParams: [:])?.absoluteString
                == "https://s2s.hurra.com/consent-api/acc/consentStatus?app=1&user_id=user"
        )
    }

    @Test func testConsentURLWithCustomBaseURL() {
        func consentURL(_ base: String) -> String? {
            PrivacyPrefsAPI.consentURL(
                baseURL: URL(string: base)!,
                accountId: "acc",
                userId: "user",
                endpoint: "consentStatus",
                queryParams: [:]
            )?.absoluteString
        }

        let expectedRoot = "https://www.example.com/consent-api/acc/consentStatus?app=1&user_id=user"
        #expect(consentURL("https://www.example.com") == expectedRoot)
        #expect(consentURL("https://www.example.com/") == expectedRoot)

        let expectedPath = "https://www.example.com/hc_s2s/consent-api/acc/consentStatus?app=1&user_id=user"
        #expect(consentURL("https://www.example.com/hc_s2s") == expectedPath)
        #expect(consentURL("https://www.example.com/hc_s2s/") == expectedPath)
    }
}
