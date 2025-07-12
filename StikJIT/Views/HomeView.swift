//
//  ContentView.swift
//  StikJIT
//
//  Created by Stephen on 3/26/25.
//

import AppdbSDK
import SwiftUI
import UniformTypeIdentifiers
import Pipify

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool)
        -> UIDocumentPickerViewController
    {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct HomeView: View {

    @AppStorage("username") private var username = "User"
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accentColor) private var environmentAccentColor
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("bundleID") private var bundleID: String = ""
    @State private var isProcessing = false
    @State private var isShowingInstalledApps = false
    @State private var isShowingPairingFilePicker = false
    @State private var pairingFileExists: Bool = false
    @State private var showPairingFileMessage = false
    @State private var pairingFileIsValid = false
    @State private var isImportingFile = false
    @State private var showingConsoleLogsView = false
    @State private var importProgress: Float = 0.0

    @State private var pidTextAlertShow = false
    @State private var pidStr = ""

    @State private var viewDidAppeared = false
    @State private var pendingBundleIdToEnableJIT: String? = nil
    @State private var pendingPIDToEnableJIT: Int? = nil
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false
    
    @AppStorage("useDefaultScript") private var useDefaultScript = false
    @State var scriptViewShow = false
    @AppStorage("DefaultScriptName") var selectedScript = "attachDetach.js"
    @State var jsModel: RunJSViewModel?

    // Add state variables for appdb import
    @State private var isImportingFromAppdb = false
    @State private var showAppdbErrorAlert = false
    @State private var appdbErrorMessage = ""
    
    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }

    var body: some View {
        ZStack {
            // Use system background
            Color(colorScheme == .dark ? .black : .white)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 25) {
                Spacer()
                VStack(spacing: 5) {
                    Text("Welcome to StikDebug-appdb \(username)!")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)

                    Text(
                        pairingFileExists
                            ? "Click connect to get started" : "Pick pairing file to get started"
                    )
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Add "Import from appdb" button if no pairing file exists
                if !pairingFileExists {
                    Button(action: {
                        importFromAppdb()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 20))
                            Text("Import from appdb")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isImportingFromAppdb ? Color.gray : accentColor)
                        .foregroundColor(accentColor.contrastText())
                        .cornerRadius(16)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isImportingFromAppdb)
                    .padding(.horizontal, 20)
                }

                Button(action: {

                    if pairingFileExists {
                        // Got a pairing file, show apps
                        if !isMounted() {
                            showAlert(title: "Device Not Mounted".localized, message: "The Developer Disk Image has not been mounted yet. Check in settings for more information.".localized, showOk: true) { cool in
                                // No Need
                            }
                            return
                        }

                        isShowingInstalledApps = true

                    } else {
                        // No pairing file yet, let's get one
                        isShowingPairingFilePicker = true
                    }
                }) {
                    HStack {
                        Image(
                            systemName: pairingFileExists
                                ? "cable.connector.horizontal" : "doc.badge.plus"
                        )
                        .font(.system(size: 20))
                        Text(pairingFileExists ? "Connect by App" : "Select Pairing File")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(accentColor.contrastText())
                    .cornerRadius(16)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                
                if pairingFileExists && enableAdvancedOptions {
                    Button(action: {
                        pidTextAlertShow = true
                    }) {
                        HStack {
                            Image(systemName: "cable.connector.horizontal")
                                .font(.system(size: 20))
                            Text("Connect by PID")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor)
                        .foregroundColor(accentColor.contrastText())
                        .cornerRadius(16)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: {
                    showingConsoleLogsView = true
                }) {
                    HStack {
                        Image(systemName: "apple.terminal")
                            .font(.system(size: 20))
                        Text("Open Console")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(accentColor.contrastText())
                    .cornerRadius(16)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingConsoleLogsView) {
                    ConsoleLogsView()
                }

                // Status message area - keeps layout consistent
                ZStack {
                    // Progress bar for importing file
                    if isImportingFile {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Processing pairing file...")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                Text("\(Int(importProgress * 100))%")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondaryText)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.2))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(
                                            width: geometry.size.width * CGFloat(importProgress),
                                            height: 8
                                        )
                                        .animation(.linear(duration: 0.3), value: importProgress)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal, 40)
                    }

                    // Success message
                    if showPairingFileMessage && pairingFileIsValid {
                        Text("✓ Pairing file successfully imported")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }

                    // Invisible text to reserve space - no layout jumps
                    Text(" ").opacity(0)
                }
                .frame(height: isImportingFile ? 60 : 30)  // Adjust height based on what's showing

                Spacer()
            }
            .padding()
        }
        .onAppear {
            checkPairingFileExists()
            // Don't initialize specific color value when empty - empty means "use system theme"
            // This was causing the toggle to turn off when returning to settings

            // Initialize background color
            refreshBackground()

            // Add notification observer for showing pairing file picker
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowPairingFilePicker"),
                object: nil,
                queue: .main
            ) { _ in
                isShowingPairingFilePicker = true
            }
        }
        .alert("Appdb Import Error", isPresented: $showAppdbErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appdbErrorMessage)
        }
        .onReceive(timer) { _ in
            refreshBackground()
            checkPairingFileExists()

        }
        .fileImporter(
            isPresented: $isShowingPairingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!,
                .propertyList,
            ]
        ) { result in
            switch result {

            case .success(let url):
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()

                if fileManager.fileExists(atPath: url.path) {
                    do {
                        if fileManager.fileExists(
                            atPath: URL.documentsDirectory.appendingPathComponent(
                                "pairingFile.plist"
                            ).path)
                        {
                            try fileManager.removeItem(
                                at: URL.documentsDirectory.appendingPathComponent(
                                    "pairingFile.plist"))
                        }

                        try fileManager.copyItem(
                            at: url,
                            to: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        print("File copied successfully!")

                        // Show progress bar and initialize progress
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0.0
                            pairingFileExists = true
                        }

                        // Start heartbeat in background
                        startHeartbeatInBackground()

                        // Create timer to update progress instead of sleeping
                        let progressTimer = Timer.scheduledTimer(
                            withTimeInterval: 0.05, repeats: true
                        ) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.25
                                } else {
                                    timer.invalidate()
                                    isImportingFile = false
                                    pairingFileIsValid = true

                                    // Show success message
                                    withAnimation {
                                        showPairingFileMessage = true
                                    }

                                    // Hide message after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            showPairingFileMessage = false
                                        }
                                    }
                                }
                            }
                        }

                        // Ensure timer keeps running
                        RunLoop.current.add(progressTimer, forMode: .common)

                    } catch {
                        print("Error copying file: \(error)")
                    }
                } else {
                    print("Source file does not exist.")
                }

                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
        .sheet(isPresented: $isShowingInstalledApps) {
            InstalledAppsListView { selectedBundle in
                bundleID = selectedBundle
                isShowingInstalledApps = false
                HapticFeedbackHelper.trigger()
                startJITInBackground(with: selectedBundle)
            }
        }
        .pipify(isPresented: $isProcessing) {
            RunJSViewPiP(model: $jsModel)
        }
        .sheet(isPresented: $scriptViewShow) {
            NavigationView {
                if let jsModel {
                    RunJSView(model: jsModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    scriptViewShow = false
                                    isProcessing = false
                                }
                            }
                        }
                        .navigationTitle(selectedScript)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onChange(of: scriptViewShow) { oldValue, newValue in
            if !newValue, let jsModel {
                jsModel.executionInterrupted = true
                jsModel.semaphore?.signal()
            }
        }
        .textFieldAlert(
            isPresented: $pidTextAlertShow,
            title: "Please enter the PID of the process you want to connect to".localized,
            text: $pidStr,
            placeholder: "",
            action: { newText in

                guard let pidStr = newText, pidStr != "" else {
                    return
                }

                guard let pid = Int(pidStr) else {
                    showAlert(title: "", message: "Invalid PID".localized, showOk: true, completion: { _ in })
                    return
                }
                startJITInBackground(with: pid)

            },
            actionCancel: { _ in
                pidStr = ""
            }
        )
        .onOpenURL { url in
            print(url.path())
            if url.host() != "enable-jit" {
                return
            }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let bundleId = components?.queryItems?.first(where: { $0.name == "bundle-id" })?
                .value
            {
                if viewDidAppeared {
                    startJITInBackground(with: bundleId)
                } else {
                    pendingBundleIdToEnableJIT = bundleId
                }
            } else if let pidStr = components?.queryItems?.first(where: { $0.name == "pid" })?
                .value, let pid = Int(pidStr)
            {
                if viewDidAppeared {
                    startJITInBackground(with: pid)
                } else {
                    pendingPIDToEnableJIT = pid
                }
            }

        }
        .onAppear {
            viewDidAppeared = true
            if let pendingBundleIdToEnableJIT {
                startJITInBackground(with: pendingBundleIdToEnableJIT)
                self.pendingBundleIdToEnableJIT = nil
            }
            if let pendingPIDToEnableJIT {
                startJITInBackground(with: pendingPIDToEnableJIT)
                self.pendingPIDToEnableJIT = nil
            }
        }
    }

    private func checkPairingFileExists() {
        let fileExists = FileManager.default.fileExists(
            atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path)

        // If the file exists, check if it's valid
        if fileExists {
            // Check if the pairing file is valid
            let isValid = isPairing()
            pairingFileExists = isValid
        } else {
            pairingFileExists = false
        }
    }

    private func refreshBackground() {
        // This function is no longer needed for background color
        // but we'll keep it empty to avoid breaking anything
    }
    
    private func getJsCallback() -> DebugAppCallback? {
        let selectedScriptURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scripts").appendingPathComponent(selectedScript)
        
        if !FileManager.default.fileExists(atPath: selectedScriptURL.path()) {
            return nil
        }
        
        return { pid, debugProxyHandle, semaphore in
            jsModel = RunJSViewModel(pid: Int(pid), debugProxy: debugProxyHandle, semaphore: semaphore)
            scriptViewShow = true
            DispatchQueue.global(qos: .background).async {
                do {
                    try jsModel?.runScript(path: selectedScriptURL)
                    isProcessing = false
                } catch {
                    showAlert(title: "Error Occurred While Executing the Default Script.".localized, message: error.localizedDescription, showOk: true)
                }
            }
        }
    }
    
    private func startJITInBackground(with bundleID: String) {
        isProcessing = true

        // Add log message
        LogManager.shared.addInfoLog("Starting Debug for \(bundleID)")

        DispatchQueue.global(qos: .background).async {
            let success = JITEnableContext.shared.debugApp(withBundleID: bundleID, logger: { message in

                if let message = message {
                    // Log messages from the JIT process
                    LogManager.shared.addInfoLog(message)
                }
            }, jsCallback: useDefaultScript ? getJsCallback() : nil)
            
            DispatchQueue.main.async {
                LogManager.shared.addInfoLog("Debug process completed for \(bundleID)")
                isProcessing = false
            }
        }
    }

    private func startJITInBackground(with pid: Int) {
        isProcessing = true

        // Add log message
        LogManager.shared.addInfoLog("Starting JIT for pid \(pid)")

        DispatchQueue.global(qos: .background).async {
            let success = JITEnableContext.shared.debugApp(withPID: Int32(pid), logger: { message in
                
                if let message = message {
                    // Log messages from the JIT process
                    LogManager.shared.addInfoLog(message)
                }
            }, jsCallback: useDefaultScript ? getJsCallback() : nil)
            
            DispatchQueue.main.async {
                LogManager.shared.addInfoLog("JIT process completed for \(pid)")
                showAlert(title: "Success".localized, message: String(format: "JIT has been enabled for pid %d.".localized, pid), showOk: true, messageType: .success)
                isProcessing = false
            }
        }
    }

    private func importFromAppdb() {
        // Check if app is installed via appdb
        guard Appdb.shared.isInstalledViaAppdb() else {
            appdbErrorMessage = "App is not installed from appdb"
            showAppdbErrorAlert = true
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
            return
        }

        // Make API request
        DispatchQueue.global(qos: .background).async {
            self.makeAppdbPairingFileRequest(
                persistentCustomerIdentifier: persistentCustomerIdentifier,
                persistentDeviceIdentifier: persistentDeviceIdentifier,
                installationUUID: installationUUID
            )
        }
    }

    private func makeAppdbPairingFileRequest(
        persistentCustomerIdentifier: String, persistentDeviceIdentifier: String,
        installationUUID: String
    ) {
        guard let url = URL(string: "https://api.dbservices.to/v1.7/get_pairing_file/") else {
            DispatchQueue.main.async {
                self.appdbErrorMessage = "Invalid API URL"
                self.showAppdbErrorAlert = true
                self.isImportingFromAppdb = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "brand": "appdb",
            "lang": "en",
            "persistent_customer_identifier": persistentCustomerIdentifier,
            "persistent_device_identifier": persistentDeviceIdentifier,
            "installation_uuid": installationUUID,
        ]

        let formData = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
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
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.appdbErrorMessage = "No data received from server"
                    self.showAppdbErrorAlert = true
                }
                return
            }

            do {
                let responseDict =
                    try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let success = responseDict?["success"] as? Bool, success,
                    let pairingFileData = responseDict?["data"] as? String
                {
                    // Save pairing file
                    self.savePairingFile(data: pairingFileData)
                } else if let errors = responseDict?["errors"] as? [[String: Any]], !errors.isEmpty,
                    let firstError = errors.first,
                    let translatedMessage = firstError["translated"] as? String
                {
                    DispatchQueue.main.async {
                        self.appdbErrorMessage = translatedMessage
                        self.showAppdbErrorAlert = true
                    }
                } else {
                    DispatchQueue.main.async {
                        self.appdbErrorMessage = "Unknown error occurred"
                        self.showAppdbErrorAlert = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.appdbErrorMessage = "Failed to parse server response"
                    self.showAppdbErrorAlert = true
                }
            }
        }.resume()
    }

    private func savePairingFile(data: String) {
        let fileManager = FileManager.default
        let pairingFilePath = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")

        do {
            // Remove existing pairing file if it exists
            if fileManager.fileExists(atPath: pairingFilePath.path) {
                try fileManager.removeItem(at: pairingFilePath)
            }

            // Write new pairing file
            try data.write(to: pairingFilePath, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                // Show progress bar and initialize progress
                self.isImportingFile = true
                self.importProgress = 0.0
                self.pairingFileExists = true

                // Start heartbeat in background
                startHeartbeatInBackground()

                // Create timer to update progress
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
                    timer in
                    DispatchQueue.main.async {
                        if self.importProgress < 1.0 {
                            self.importProgress += 0.25
                        } else {
                            timer.invalidate()
                            self.isImportingFile = false
                            self.pairingFileIsValid = true

                            // Show success message
                            withAnimation {
                                self.showPairingFileMessage = true
                            }

                            // Hide message after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    self.showPairingFileMessage = false
                                }
                            }
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
            }
        }
    }
}

class InstalledAppsViewModel: ObservableObject {
    @Published var apps: [String: String] = [:]

    init() {
        loadApps()
    }

    func loadApps() {
        do {
            self.apps = try JITEnableContext.shared.getAppList()
        } catch {
            print(error)
            self.apps = [:]
        }
    }
}

#Preview {
    HomeView()
}
