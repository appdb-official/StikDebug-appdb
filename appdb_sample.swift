import Foundation
import AppdbSDK

/**
 * APPDB SDK Sample Code
 * 
 * This file demonstrates the key APPDB SDK functionality used in StikDebug-appdb:
 * 1. Version checking using appdb framework
 * 2. Automatic pairing file import from appdb services
 * 3. Authentication and identifier retrieval
 * 
 * Based on implementation in:
 * - StikJIT/Utilities/AppdbImportManager.swift
 * - StikJIT/StikJITApp.swift
 */

// MARK: - Version Checking Sample

/**
 * Check if app update is available via APPDB SDK
 * Replaces upstream GitHub version checking with appdb-native method
 */
func checkAppdbVersion() {
    // Use appdb SDK method instead of manual GitHub API calls
    // Note: This method is asynchronous and uses a completion handler
    Appdb.shared.isAppUpdateAvailable { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let isUpdateAvailable):
                if isUpdateAvailable {
                    print("Update available on appdb!")
                    
                    // Open appdb app page for update
                    let appdbURL = "https://appdb.to/details/45a698af5360560fd8a522a8ebbc634da8f55df4"
                    if let url = URL(string: appdbURL) {
                        // In real app, use UIApplication.shared.open(url)
                        print("Would open: \(url)")
                    }
                } else {
                    print("App is up to date")
                }
            case .failure(let error):
                print("Failed to check for updates: \(error)")
            }
        }
    }
}

// MARK: - Pairing File Import Sample

/**
 * Automatic pairing file import using APPDB SDK
 * This replaces manual file picker with seamless appdb integration
 */
class AppdbImportSample {
    
    func importPairingFileFromAppdb(completion: @escaping (Bool, String?) -> Void) {
        // Step 1: Verify app is installed via appdb
        guard Appdb.shared.isInstalledViaAppdb() else {
            completion(false, "App is not installed from appdb")
            return
        }
        
        // Step 2: Get required identifiers from appdb SDK
        let customerResult = Appdb.shared.getPersistentCustomerIdentifier()
        let deviceResult = Appdb.shared.getPersistentDeviceIdentifier()
        let uuidResult = Appdb.shared.getInstallationUUID()
        
        guard case .success(let customerID) = customerResult,
              case .success(let deviceID) = deviceResult,
              case .success(let installUUID) = uuidResult else {
            completion(false, "Failed to get required identifiers from appdb")
            return
        }
        
        print("Retrieved identifiers:")
        print("- Customer ID: \(customerID)")
        print("- Device ID: \(deviceID)")
        print("- Install UUID: \(installUUID)")
        
        // Step 3: Make authenticated API request to appdb services
        requestPairingFile(
            customerID: customerID,
            deviceID: deviceID,
            installUUID: installUUID,
            completion: completion
        )
    }
    
    private func requestPairingFile(
        customerID: String,
        deviceID: String,
        installUUID: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // APPDB API endpoint for pairing file retrieval
        guard let url = URL(string: "https://api.dbservices.to/v1.7/get_pairing_file/") else {
            completion(false, "Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Prepare form data with appdb identifiers
        let parameters = [
            "brand": "appdb",
            "lang": "en",
            "persistent_customer_identifier": customerID,
            "persistent_device_identifier": deviceID,
            "installation_uuid": installUUID,
        ]
        
        let formData = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = formData.data(using: .utf8)
        
        // Execute API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion(false, "No data received from server")
                return
            }
            
            // Parse response
            do {
                let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let success = responseDict?["success"] as? Bool, success,
                   let pairingFileData = responseDict?["data"] as? String {
                    
                    // Save pairing file to documents directory
                    self.savePairingFile(data: pairingFileData, completion: completion)
                    
                } else if let errors = responseDict?["errors"] as? [[String: Any]], !errors.isEmpty,
                         let firstError = errors.first,
                         let translatedMessage = firstError["translated"] as? String {
                    
                    completion(false, translatedMessage)
                } else {
                    completion(false, "Unknown error occurred")
                }
            } catch {
                completion(false, "Failed to parse server response: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func savePairingFile(data: String, completion: @escaping (Bool, String?) -> Void) {
        let fileManager = FileManager.default
        let pairingFilePath = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
        
        do {
            // Remove existing pairing file if it exists
            if fileManager.fileExists(atPath: pairingFilePath.path) {
                try fileManager.removeItem(at: pairingFilePath)
            }
            
            // Write new pairing file
            try data.write(to: pairingFilePath, atomically: true, encoding: .utf8)
            
            print("Pairing file saved successfully to: \(pairingFilePath.path)")
            completion(true, "Pairing file imported successfully")
            
        } catch {
            completion(false, "Failed to save pairing file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Additional APPDB SDK Methods

/**
 * Demonstrate other useful APPDB SDK methods
 */
func demonstrateAdditionalSDKMethods() {
    print("=== APPDB SDK Additional Methods ===")
    
    // Get app bundle identifier
    let bundleResult = Appdb.shared.getAppleBundleIdentifier()
    if case .success(let bundleID) = bundleResult {
        print("Bundle ID: \(bundleID)")
    }
    
    // Get app group identifier
    let appGroupResult = Appdb.shared.getAppleAppGroupIdentifier()
    if case .success(let appGroup) = appGroupResult {
        print("App Group: \(appGroup)")
    }
    
    // Get appdb app identifier
    let appdbIDResult = Appdb.shared.getAppdbAppIdentifier()
    if case .success(let appdbID) = appdbIDResult {
        print("APPDB App ID: \(appdbID)")
    }
    
    // Get alongside identifier (if exists)
    let alongsideResult = Appdb.shared.getAlongsideIdentifier()
    if case .success(let alongside) = alongsideResult {
        print("Alongside ID: \(alongside)")
    }
}

// MARK: - Usage Example

/**
 * Example usage of the APPDB SDK functionality
 */
func exampleUsage() {
    print("=== APPDB SDK Sample Usage ===")
    
    // 1. Check for app updates
    print("1. Checking for app updates...")
    checkAppdbVersion()
    
    // 2. Import pairing file automatically
    print("\n2. Importing pairing file from appdb...")
    let importManager = AppdbImportSample()
    importManager.importPairingFileFromAppdb { success, message in
        DispatchQueue.main.async {
            if success {
                print("✅ Success: \(message ?? "Pairing file imported")")
            } else {
                print("❌ Error: \(message ?? "Unknown error")")
            }
        }
    }
    
    // 3. Demonstrate additional SDK methods
    print("\n3. Additional SDK methods...")
    demonstrateAdditionalSDKMethods()
}

// MARK: - Integration Notes

/**
 * INTEGRATION NOTES FOR DEVELOPERS:
 * 
 * 1. SDK Setup:
 *    - Add AppdbFramework to Package.swift dependencies
 *    - Import AppdbSDK in relevant files
 *    - Use the same app group as upstream StikDebug: "group.com.stik.stikdebug" (entitlements + UserDefaults suite)
 * 
 * 2. Version Checking Migration:
 *    - Replace GitHub API calls with Appdb.shared.isAppUpdateAvailable(completion:)
 *    - Handle async completion with Result<Bool, AppdbError>
 *    - Update alert to redirect to appdb store page
 *    - Remove manual version.txt parsing
 * 
 * 3. Pairing File Import:
 *    - Use AppdbImportManager class from this sample
 *    - Integrate with SwiftUI @StateObject for UI updates
 *    - Add progress indicators and error handling
 * 
 * 4. Bundle & signing:
 *    - Keep upstream bundle id `com.stik.stikdebug` and marketing/build version format (e.g. 3.1.2)
 *    - Appdb provisioning should match those identifiers; SDK exposes them via getApple*Identifier APIs
 * 
 * 5. Version strings:
 *    - Do not add a/b/c suffixes for appdb; stay aligned with upstream StikDebug versioning
 */
