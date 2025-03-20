# PrivacyPrefsAPI Documentation

The PrivacyPrefsAPI module provides an interface for managing user privacy preferences and consent settings through Hurra's privacy API.

## Initialization

```swift
let api = await PrivacyPrefsAPI(
    accountId: "your_account_id",
    apiKey: "your_api_key",
    userId: "user_identifier",
    testing: false // Set to true for development environment
)
```

## API Availability

The API performs an initial availability check during initialization. If the API is not available, subsequent requests will fail with an appropriate error message.

## Core Methods

### Get Consent Status

Retrieves the current consent status for the user:

```swift
let result = await api.getConsentStatus()
switch result {
case .success(let status):
    // Access consent status properties:
    // - userPreferences
    // - vendors
    // - statusesReasons
    // - acceptedVendorIds
    // - declinedVendorIds
    // - showConsentBanner
case .failure(let error):
    // Handle error
}
```

### Set Consent Status

Updates the user's consent preferences:

```swift
// First, configure privacy preferences
api.privacyPrefs?.setAllCategories(true) // Accept all
// Or set specific categories
api.privacyPrefs?.setCategory(.essential, accept: true)
api.privacyPrefs?.setCategory(.analytics, accept: true)

// Then update consent status
let result = await api.setConsentStatus()
```

### Get Vendor Details

Retrieve details for a specific vendor:

```swift
// Using vendor ID
let result = await api.getVendorDetails(vendorId: "vendor_id")

// Using external vendor ID
let result = await api.getVendorDetails(externalVendorId: "ga")
```

### Get All Vendors

Retrieve all available vendors:

```swift
let result = await api.getVendorsDetails()
```

You can also filter vendors by category:

```swift
let result = await api.getVendorsDetails(categoryName: "essential")
```

### Get Categories

Retrieve all available privacy categories:

```swift
let result = await api.getCategories()
```

### Get Translations

Retrieve UI translations:

```swift
// Get default translations
let result = await api.getTranslations()

// Get translations for specific language
let result = await api.getTranslations(language: "en")

// Get specific translation fields
let result = await api.getTranslations(fields: ["vendors", "privacyCenter"])
```

## Error Handling

The API uses a custom `APIError` type that provides detailed error information:

```swift
public enum APIError: Error {
    case networkError(Error)
    case noData
    case decodingError(Error, responseData: String?, statusCode: Int?)
    case apiError(String, responseData: String?, statusCode: Int?)
    case invalidURL
}
```

Each error case includes relevant debugging information such as:
- Original error message
- HTTP status code
- Raw response data (when available)

## Thread Safety

All public methods are marked with `@MainActor` to ensure thread safety. Always call these methods from the main thread or use `await` in async contexts.

## Testing

For testing purposes, initialize the API with `testing: true`:

```swift
let api = await PrivacyPrefsAPI(
    accountId: "test_account",
    apiKey: "test_key",
    userId: "test_user",
    testing: true
)
```

This enables development mode for the API endpoints. 

### Running integration tests (Tests/HurraS2SSDKTests/PrivacyPrefsAPITests.swift):

copy Tests/HurraS2SSDKTests/Resources/testCredentials.plist.example to Tests/HurraS2SSDKTests/Resources/testCredentials.plist and set the values for accountId, apiKey and testVendorId.

testVendorId is the vendor ID for getting vendor details.

Then run the tests:

```
swift test
```