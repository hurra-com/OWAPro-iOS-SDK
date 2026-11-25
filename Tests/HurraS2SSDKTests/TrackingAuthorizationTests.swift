//
//  TrackingAuthorizationTests.swift
//  HurraS2SSDKTests
//

import Testing
import Foundation
import AppTrackingTransparency
@testable import HurraS2SSDK

// MARK: - Test helpers

/// Requests seen by `MockTrackingURLProtocol`.
final class RecordedRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [(host: String, body: [String: Any])] = []

    func append(host: String, body: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        requests.append((host, body))
    }

    func bodies(host: String) -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return requests.filter { $0.host == host }.map { $0.body }
    }
}

/// Answers requests to `*.att-test.example.com` locally; all other requests are left alone.
final class MockTrackingURLProtocol: URLProtocol {
    static let hostSuffix = ".att-test.example.com"
    static let recorded = RecordedRequests()
    static let registered: Bool = {
        URLProtocol.registerClass(MockTrackingURLProtocol.self)
        return true
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.host?.hasSuffix(hostSuffix) == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let body = Self.readBody(request)
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        Self.recorded.append(host: host, body: json)

        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"status":1}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Mutable ATT status for one test.
final class StatusBox {
    var status: ATTrackingManager.AuthorizationStatus
    init(_ status: ATTrackingManager.AuthorizationStatus) { self.status = status }
}

private enum Outcome: Equatable, Sendable {
    case success
    case trackingNotAuthorized
    case otherFailure(String)
}

@MainActor
private func send(_ sdk: HurraS2SSDK, view: String) async -> Outcome {
    return await withCheckedContinuation { continuation in
        Task { @MainActor in
            await sdk.sendEvent(eventData: ["event_type": "page_view"], currentView: view) { result in
                switch result {
                case .success:
                    continuation.resume(returning: .success)
                case .failure(let error as S2SError) where error == .trackingNotAuthorized:
                    continuation.resume(returning: .trackingNotAuthorized)
                case .failure(let error):
                    continuation.resume(returning: .otherFailure("\(error)"))
                }
            }
        }
    }
}

// MARK: - Tests

struct TrackingAuthorizationTests {

    private let customBase = URL(string: "https://www.example.com/hc_s2s")!

    @Test func testEffectiveValueForDefaultDomainIsAlwaysTrue() {
        #expect(HurraS2SSDK.effectiveRequiresTrackingAuthorization(baseURL: HurraS2SSDK.defaultBaseURL, requested: false))
        #expect(HurraS2SSDK.effectiveRequiresTrackingAuthorization(baseURL: HurraS2SSDK.defaultBaseURL, requested: true))
        #expect(HurraS2SSDK.effectiveRequiresTrackingAuthorization(baseURL: URL(string: "https://S2S.hurra.com/")!, requested: false))
    }

    @Test func testEffectiveValueForCustomDomainIsThePassedValue() {
        #expect(!HurraS2SSDK.effectiveRequiresTrackingAuthorization(baseURL: customBase, requested: false))
        #expect(HurraS2SSDK.effectiveRequiresTrackingAuthorization(baseURL: customBase, requested: true))
    }

    @Test func testInitDefaults() {
        #expect(HurraS2SSDK(accountId: "acc", apiKey: "key").requiresTrackingAuthorization)
        #expect(HurraS2SSDK(accountId: "acc", apiKey: "key", requiresTrackingAuthorization: false).requiresTrackingAuthorization)
        #expect(HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: customBase).requiresTrackingAuthorization)
        #expect(!HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: customBase, requiresTrackingAuthorization: false).requiresTrackingAuthorization)
    }

    @Test func testIsTrackingAllowed() {
        let required = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: customBase)
        for status in [ATTrackingManager.AuthorizationStatus.notDetermined, .restricted, .denied] {
            required.trackingAuthorizationStatus = { status }
            #expect(!required.isTrackingAllowed())
        }
        required.trackingAuthorizationStatus = { .authorized }
        #expect(required.isTrackingAllowed())

        let notRequired = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: customBase, requiresTrackingAuthorization: false)
        notRequired.trackingAuthorizationStatus = { .denied }
        #expect(notRequired.isTrackingAllowed())
    }

    @MainActor
    @Test func testNoRequestOnDefaultDomainWithoutAuthorization() async {
        // `false` is ignored for the default domain; the request fails before it reaches the network.
        let sdk = HurraS2SSDK(accountId: "acc", apiKey: "key", requiresTrackingAuthorization: false)
        sdk.trackingAuthorizationStatus = { .denied }
        #expect(await send(sdk, view: "home") == .trackingNotAuthorized)
    }

    @MainActor
    @Test func testNoRequestOnCustomDomainWithoutAuthorization() async {
        _ = MockTrackingURLProtocol.registered
        let host = "denied" + MockTrackingURLProtocol.hostSuffix
        let sdk = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: URL(string: "https://\(host)")!)
        sdk.trackingAuthorizationStatus = { .denied }

        #expect(await send(sdk, view: "home") == .trackingNotAuthorized)
        #expect(MockTrackingURLProtocol.recorded.bodies(host: host).isEmpty)
    }

    @MainActor
    @Test func testRequestWhenAuthorized() async {
        _ = MockTrackingURLProtocol.registered
        let host = "authorized" + MockTrackingURLProtocol.hostSuffix
        let sdk = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: URL(string: "https://\(host)")!)
        sdk.trackingAuthorizationStatus = { .authorized }

        #expect(await send(sdk, view: "home") == .success)
        #expect(MockTrackingURLProtocol.recorded.bodies(host: host).count == 1)
    }

    @MainActor
    @Test func testRequestWithoutAuthorizationWhenNotRequired() async {
        _ = MockTrackingURLProtocol.registered
        let host = "notrequired" + MockTrackingURLProtocol.hostSuffix
        let sdk = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: URL(string: "https://\(host)")!, requiresTrackingAuthorization: false)
        sdk.trackingAuthorizationStatus = { .denied }

        #expect(await send(sdk, view: "home") == .success)
        #expect(MockTrackingURLProtocol.recorded.bodies(host: host).count == 1)
    }

    @MainActor
    @Test func testEventNotSentDoesNotBecomeReferer() async {
        _ = MockTrackingURLProtocol.registered
        let host = "referer" + MockTrackingURLProtocol.hostSuffix
        let sdk = HurraS2SSDK(accountId: "acc", apiKey: "key", baseURL: URL(string: "https://\(host)")!)
        let status = StatusBox(.authorized)
        sdk.trackingAuthorizationStatus = { status.status }

        #expect(await send(sdk, view: "https://example.com/first/") == .success)
        status.status = .denied
        #expect(await send(sdk, view: "https://example.com/not-sent/") == .trackingNotAuthorized)
        status.status = .authorized
        #expect(await send(sdk, view: "https://example.com/second/") == .success)

        let bodies = MockTrackingURLProtocol.recorded.bodies(host: host)
        #expect(bodies.count == 2)
        #expect(bodies.last?["referer"] as? String == "https://example.com/first/")
    }
}
