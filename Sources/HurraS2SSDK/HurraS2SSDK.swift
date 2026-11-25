// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AdSupport
import AppTrackingTransparency

public class HurraS2SSDK {
    /// Default base URL of the Hurra S2S server.
    public static let defaultBaseURL = URL(string: "https://s2s.hurra.com")!

    private let accountId: String
    private let baseURL: URL
    private let apiKey: String
    private let useAdvertiserId: Bool
    private var userId: String?
    private var privacyPrefs: PrivacyPrefs?
    private var previousView: String?
//    private var privacyPrefsAPI: PrivacyPrefsAPI?
    private var testing: Bool?
    /// Effective value: always `true` for the default domain `s2s.hurra.com`.
    let requiresTrackingAuthorization: Bool
    /// Source of the App Tracking Transparency status. Replaceable in tests.
    var trackingAuthorizationStatus: () -> ATTrackingManager.AuthorizationStatus = {
        ATTrackingManager.trackingAuthorizationStatus
    }
    
    /// - Parameter baseURL: Base URL that tracking requests are sent to, e.g. your own domain with a
    ///   reverse proxy to the Hurra S2S server (`https://www.example.com/hc_s2s`). Must use https.
    ///   A trailing slash is optional. Defaults to `HurraS2SSDK.defaultBaseURL`.
    /// - Parameter requiresTrackingAuthorization: Whether events are sent only when the user has granted
    ///   App Tracking Transparency permission (`.authorized`). Always `true` for the default domain
    ///   `s2s.hurra.com`, whatever is passed. For your own domain, pass `false` if your measurement isn't
    ///   tracking in Apple's sense. The SDK never shows the ATT prompt; the app does.
    public init(
        accountId: String, 
        apiKey: String, 
        useAdvertiserId: Bool = false, 
        testing: Bool? = false, 
        customUserId: String? = nil,
        baseURL: URL = HurraS2SSDK.defaultBaseURL,
        requiresTrackingAuthorization: Bool = true
    ) {
        precondition(BaseURL.isValid(baseURL), BaseURL.preconditionMessage)
        self.baseURL = baseURL
        self.requiresTrackingAuthorization = HurraS2SSDK.effectiveRequiresTrackingAuthorization(
            baseURL: baseURL,
            requested: requiresTrackingAuthorization
        )
        self.accountId = accountId
        self.apiKey = apiKey
        self.useAdvertiserId = useAdvertiserId
        self.testing = testing
        
        if customUserId != nil && customUserId!.count > 0 {
            userId = customUserId
        } else if !useAdvertiserId {
            generateUserId()
        } else {
            setUserIdFromAdvertisingIdentifier()
        }
    }
    
    private func generateUserId() {
        userId = "\(Date().timeIntervalSince1970)-\(UUID().uuidString)"
        storeUserId()
    }
    
    private func setUserIdFromAdvertisingIdentifier() {
        userId =  ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    
    private func storeUserId() {
        // Store userId in UserDefaults for demonstration
        // In production, use more secure storage method
        UserDefaults.standard.set(userId, forKey: "S2SFramework_UserId")
    }
    
    public func setUserId(_ userId: String) {
        self.userId = userId
        storeUserId()
    }
    
    public func getUserId() -> String? {
        return userId
    }
    
    public func setAdvertiserId() {
        if useAdvertiserId {
            userId = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
    }
    
    public func setPrivacyPrefs(_ prefs: PrivacyPrefs) {
        self.privacyPrefs = prefs
    }
    
    public func getPrivcyPrefs() -> PrivacyPrefs? {
        return privacyPrefs
    }
    
    @MainActor
    public func trackView(
        eventData: [String: Any], 
        currentView: String, 
        isInteractive: Bool? = nil, 
        completion: (@Sendable (Result<ServerResponse, Error>) -> Void)? = nil
    ) async {
        await self.trackEvent(eventType: "page_view", eventData: eventData, currentView: currentView, isInteractive: isInteractive, completion: completion)
    }
    
    @MainActor
    public func trackEvent(
        eventType: String, 
        eventData: [String: Any], 
        currentView: String, 
        isInteractive: Bool? = nil, 
        completion: (@Sendable (Result<ServerResponse, Error>) -> Void)? = nil
    ) async {
        let _eventType: String = eventType
        var fullEventData = eventData
        fullEventData["event_type"] = _eventType
        await self.sendEvent(eventData: fullEventData, currentView: currentView, isInteractive: isInteractive, completion: completion)
    }
    
    @MainActor
    public func sendEvent(
        eventData: [String: Any], 
        currentView: String, 
        isInteractive: Bool? = nil, 
        completion: (@Sendable (Result<ServerResponse, Error>) -> Void)? = nil
    ) async {
        // Checked before anything else, so that an event that isn't sent doesn't change
        // `previousView`: the next sent event's referer is then a view the server has seen.
        guard isTrackingAllowed() else {
            if completion != nil {
                completion!(.failure(S2SError.trackingNotAuthorized))
            }
            return
        }

        guard let userId = userId else {
            if completion != nil {
                completion!(.failure(S2SError.userIdNotSet))
            }
            return
        }
        
        // Start with the event data as the base payload
        var payload = eventData
        
        // Add the required fields
        payload["event_ts"] = Int(Date().timeIntervalSince1970 * 1000)
        payload["user_id"] = userId
        var _currentView: String = currentView
        // debug
        let urlRegex = try! Regex("[a-z]+://[a-z0-9.-]+/.+/").ignoresCase()

        if (try? urlRegex.prefixMatch(in: _currentView)) != nil {
            // it's an uri alerady
        } else {
            let appName =  Bundle.main.bundleIdentifier ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "UnknownApp"
            _currentView = "app://\(appName.replacingOccurrences(of: "\\s", with: "-", options: .regularExpression))/\(currentView)"
        }
        payload["url"] = _currentView
        
        if let previousView = previousView {
            payload["referer"] = previousView
        }
        
        if let isInteractivex = isInteractive {
                payload["is_interactive"] = isInteractivex ? 1 : 0
        }
        
        if let privacyPrefs = privacyPrefs {
            do {
                let prefsData = try JSONEncoder().encode(privacyPrefs)
                if let prefsJson = try JSONSerialization.jsonObject(with: prefsData) as? [String: Any] {
                    payload["privacy_prefs"] = prefsJson
                }
            } catch {
                if completion != nil {
                    completion!(.failure(error))
                }
                return
            }
        }
        
        self.previousView = _currentView
        
        await sendRequest(payload: payload, completion: completion)
    }
    
    @MainActor
    private func sendRequest(
        payload: [String: Any],
        completion: (@Sendable (Result<ServerResponse, Error>) -> Void)? = nil
    ) async {
        guard let url = HurraS2SSDK.trackingURL(baseURL: baseURL, accountId: accountId) else {
            if completion != nil {
                completion!(.failure(S2SError.invalidURL))
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if (self.testing == true) {
//            print ("Test mode")
            request.setValue("tracking_devel_mode=1", forHTTPHeaderField: "Cookie")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
//            print("\(request.description) \(String(describing: request.allHTTPHeaderFields)) \(String(describing: String(data: request.httpBody!, encoding: .utf8)))")
        } catch {
            if completion != nil {
                completion!(.failure(error))
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if completion != nil {
                    completion!(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                if completion != nil {
                    completion!(.failure(S2SError.noData))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ServerResponse.self, from: data)
                if completion != nil {
                    completion!(.success(response))
                }
            } catch {
                if completion != nil {
                    completion!(.failure(error))
                }
            }
        }.resume()
    }

    /// `false` if App Tracking Transparency permission is required and not granted.
    func isTrackingAllowed() -> Bool {
        return !requiresTrackingAuthorization || trackingAuthorizationStatus() == .authorized
    }

    /// Requests to the default domain always require ATT permission; for other domains the passed value applies.
    static func effectiveRequiresTrackingAuthorization(baseURL: URL, requested: Bool) -> Bool {
        if baseURL.host?.lowercased() == defaultBaseURL.host?.lowercased() {
            return true
        }
        return requested
    }

    /// URL of the tracking endpoint for the given base URL.
    static func trackingURL(baseURL: URL, accountId: String) -> URL? {
        return URL(string: "\(BaseURL.normalizedString(baseURL))/rt?cid=\(accountId)&app=1")
    }
}

// MARK: - Supporting Types
public struct ServerResponse: Codable {
    public let status: Int
    public let error: [String]?
}

public enum S2SError: Error {
    case userIdNotSet
    case invalidURL
    case noData
    /// App Tracking Transparency permission is required (see `requiresTrackingAuthorization`) and the user hasn't granted it.
    case trackingNotAuthorized
}
