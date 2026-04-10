import Foundation
import AppdbSDK

class AppdbImportManager: ObservableObject {
    @Published var isImportingFromAppdb = false
    @Published var showAppdbErrorAlert = false
    @Published var appdbErrorMessage = ""
    @Published var isImportingFile = false
    @Published var importProgress: Double = 0.0
    
    func importFromAppdb(completion: @escaping (Bool) -> Void) {
        // Check if app is installed via appdb
        guard Appdb.shared.isInstalledViaAppdb() else {
            appdbErrorMessage = "App is not installed from appdb"
            showAppdbErrorAlert = true
            completion(false)
            return
        }

        // Set importing state
        isImportingFromAppdb = true

        // Get required identifiers from AppdbSDK
        let persistentCustomerIdentifierResult = Appdb.shared.getPersistentCustomerIdentifier()
        let persistentDeviceIdentifierResult = Appdb.shared.getPersistentDeviceIdentifier()
        let installationUUIDResult = Appdb.shared.getInstallationUUID()

        guard case .success(let persistentCustomerIdentifier) = persistentCustomerIdentifierResult,
            case .success(let persistentDeviceIdentifier) = persistentDeviceIdentifierResult,
            case .success(let installationUUID) = installationUUIDResult
        else {
            DispatchQueue.main.async {
                self.appdbErrorMessage = "Failed to get required identifiers from appdb"
                self.showAppdbErrorAlert = true
                self.isImportingFromAppdb = false
            }
            completion(false)
            return
        }

        // Make API request
        DispatchQueue.global(qos: .background).async {
            self.makeAppdbPairingFileRequest(
                persistentCustomerIdentifier: persistentCustomerIdentifier,
                persistentDeviceIdentifier: persistentDeviceIdentifier,
                installationUUID: installationUUID,
                completion: completion
            )
        }
    }

    private func makeAppdbPairingFileRequest(
        persistentCustomerIdentifier: String,
        persistentDeviceIdentifier: String,
        installationUUID: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let url = URL(string: "https://api.dbservices.to/v1.7/get_pairing_file/") else {
            DispatchQueue.main.async {
                self.appdbErrorMessage = "Invalid API URL"
                self.showAppdbErrorAlert = true
                self.isImportingFromAppdb = false
            }
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters: [String: String] = [
            "brand": "appdb",
            "lang": "en",
            "persistent_customer_identifier": persistentCustomerIdentifier,
            "persistent_device_identifier": persistentDeviceIdentifier,
            "installation_uuid": installationUUID,
        ]

        let formData = parameters
            .sorted { $0.key < $1.key }
            .map { key, value in
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
        request.httpBody = formData.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isImportingFromAppdb = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.appdbErrorMessage = "Network error: \(error.localizedDescription)"
                    self.showAppdbErrorAlert = true
                }
                completion(false)
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.appdbErrorMessage = "No data received from server"
                    self.showAppdbErrorAlert = true
                }
                completion(false)
                return
            }

            do {
                let responseDict =
                    try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let success = responseDict?["success"] as? Bool, success,
                    let pairingFileData = responseDict?["data"] as? String
                {
                    // Save pairing file
                    self.savePairingFile(data: pairingFileData, completion: completion)
                } else if let errors = responseDict?["errors"] as? [[String: Any]], !errors.isEmpty,
                    let firstError = errors.first,
                    let translatedMessage = firstError["translated"] as? String
                {
                    DispatchQueue.main.async {
                        self.appdbErrorMessage = translatedMessage
                        self.showAppdbErrorAlert = true
                    }
                    completion(false)
                } else {
                    DispatchQueue.main.async {
                        self.appdbErrorMessage = "Unknown error occurred"
                        self.showAppdbErrorAlert = true
                    }
                    completion(false)
                }
            } catch {
                DispatchQueue.main.async {
                    self.appdbErrorMessage = "Failed to parse server response"
                    self.showAppdbErrorAlert = true
                }
                completion(false)
            }
        }.resume()
    }

    private func savePairingFile(data: String, completion: @escaping (Bool) -> Void) {
        do {
            let destinationURL = PairingFileStore.prepareURL()
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            guard let pairingData = data.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try pairingData.write(to: destinationURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)

            DispatchQueue.main.async {
                self.isImportingFile = true
                self.importProgress = 0.0
                startHeartbeatInBackground()
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
                    timer in
                    DispatchQueue.main.async {
                        if self.importProgress < 1.0 {
                            self.importProgress += 0.025
                        } else {
                            timer.invalidate()
                            self.isImportingFile = false
                            self.isImportingFromAppdb = false
                            completion(true)
                        }
                    }
                }

                RunLoop.current.add(progressTimer, forMode: .common)
            }

        } catch {
            DispatchQueue.main.async {
                self.appdbErrorMessage =
                    "Failed to save pairing file: \(error.localizedDescription)"
                self.showAppdbErrorAlert = true
                self.isImportingFromAppdb = false
            }
            completion(false)
        }
    }

} 
