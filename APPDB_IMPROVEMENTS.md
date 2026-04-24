# APPDB Improvements Documentation

## Overview

This document describes **StikDebug-appdb**: upstream [StikDebug](https://github.com/StephenDev0/StikDebug) with appdb SDK and service integration for users who install the app through appdb. The fork is **regularly merged from `upstream/main`**; where project identity (bundle id, app group, version format) is concerned, it follows **upstream**, not a separate appdb-specific bundle or letter-suffixed versions.

## Major APPDB Improvements

### 1. Automatic Pairing File Import

**Implementation**: `StikJIT/Utilities/AppdbImportManager.swift`

**Key Features**:
- **SDK Integration**: Uses `import AppdbSDK` for appdb service integration
- **Automatic Detection**: Checks if the app is installed via appdb using `Appdb.shared.isInstalledViaAppdb()`
- **Secure Authentication**: Retrieves required identifiers from appdb SDK:
  - `getPersistentCustomerIdentifier()`
  - `getPersistentDeviceIdentifier()`
  - `getInstallationUUID()`
- **API Integration**: Makes authenticated requests to `https://api.dbservices.to/v1.7/get_pairing_file/`
- **Automatic File Management**: Downloads and saves pairing files to the correct location
- **Progress Tracking**: Real-time import progress with visual feedback
- **Error Handling**: User-facing alerts for failures

**UI Integration**:
- **HomeView**: “Import from appdb” card when no pairing file exists (appdb installs only)
- **SettingsView**: Manual import in the pairing file section
- **Progress / alerts**: Import state and error messaging

### 2. Credits for APPDB Team

**Developer Profiles**:

Adds an “appdb” developer profile with icon https://appdb.to/favicon-appdb.png

### 3. Support Link Integration

**Implementation**: Multiple locations throughout the app

**Support Links**:
- **APPDB Guide**: `https://appdb.to/enable-jit` (pairing / JIT guide)
- **APPDB Support**: `https://appdb.to/my/support` (replaces original Discord for this fork)

**Integration Points**:
- **Settings Help Card**: `enable-jit` and `my/support`
- **HomeView tips**: appdb JIT guide where applicable
- **Info.md**: Support section with `https://appdb.to/enable-jit`

### 4. APPDB Version Checking via APPDB SDK

Uses `isAppUpdateAvailable()` from the appdb framework. When an update is available, the user is directed to `https://appdb.to/details/45a698af5360560fd8a522a8ebbc634da8f55df4`.

### 5. Usage of APPDB SDK

**SDK Integration**: `AppdbFramework` (see Xcode Swift package **AppdbSDK** → `https://github.com/appdb-official/AppdbSDK`)

**SDK Methods Utilized**:
- `isInstalledViaAppdb()`: Validates appdb installation
- `getPersistentCustomerIdentifier()` / `getPersistentDeviceIdentifier()` / `getInstallationUUID()`: Pairing file API
- `getAppleBundleIdentifier()` / `getAppleAppGroupIdentifier()`: Match provisioned app to services
- `isAppUpdateAvailable()`: appdb-side update check

**Security**:
- **Entitlements**: Same app group as upstream StikDebug (`group.com.stik.stikdebug`) for App Group / shared defaults
- **Authentication**: appdb API calls use SDK-provided credentials

### Dependencies
- **AppdbSDK** (AppdbFramework): appdb service integration

### Build configuration (aligned with upstream)

These values track **upstream StikDebug** (Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, not separate appdb-only IDs or a/b/c build suffixes):

- **Bundle ID**: `com.stik.stikdebug`
- **App Group**: `group.com.stik.stikdebug` (`StikJIT.entitlements`, `ScriptStore.favoriteAppNamesSuiteName` in `Extensions.swift`)
- **Minimum iOS**: 17.4+ (per upstream)
- **Architecture**: arm64 (iOS devices)

**Note for appdb builds**: Provisioning and app group must match the same identifiers; the SDK reflects what is embedded in the installed build.

## Comparison with Upstream

### APPDB-specific additions
- Automatic pairing file import from appdb
- appdb developer credit line
- appdb help/support links
- `isAppUpdateAvailable` flow for appdb installs
- `AppdbSDK` package dependency

### Upstream to-dos (for maintainers when merging)

- Re-verify appdb flows after each `upstream/main` merge (import, update check, entitlements)
- Keep bundle id, app group, and version scheme identical to upstream unless upstream changes them

### Sample code

See `appdb_sample.swift`
