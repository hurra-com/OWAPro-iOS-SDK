//
//  BaseURL.swift
//  HurraS2SSDK
//

import Foundation

/// Validation and normalisation of the base URL that the SDK sends its requests to.
enum BaseURL {

    /// `true` if `url` is an absolute https URL with a host and without query or fragment.
    static func isValid(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        guard components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else {
            return false
        }
        return components.query == nil && components.fragment == nil
    }

    /// The base URL as a string without trailing slashes, so that paths can be appended with a single "/".
    /// Accepted: `https://host`, `https://host/`, `https://host/path`, `https://host/path/`.
    static func normalizedString(_ url: URL) -> String {
        var string = url.absoluteString
        while string.hasSuffix("/") {
            string.removeLast()
        }
        return string
    }

    static let preconditionMessage = "baseURL must be an https URL with a host and without query or fragment"
}
