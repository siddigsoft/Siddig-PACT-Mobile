# Biometric Authentication Flow Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PACT Mobile App                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────┐      ┌──────────────────┐                  │
│  │  Login Screen │◄────►│ BiometricService │                  │
│  └───────────────┘      └──────────────────┘                  │
│         │                        │                              │
│         │                        ▼                              │
│         │               ┌──────────────────┐                   │
│         │               │  LocalAuth API   │                   │
│         │               │  (local_auth)    │                   │
│         │               └──────────────────┘                   │
│         │                        │                              │
│         ▼                        ▼                              │
│  ┌───────────────┐      ┌──────────────────┐                  │
│  │ Setup Dialog  │      │ Secure Storage   │                  │
│  └───────────────┘      │  (Credentials)   │                  │
│                         └──────────────────┘                   │
│                                  │                              │
└──────────────────────────────────┼──────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
            ┌──────────────┐            ┌──────────────┐
            │ iOS Keychain │            │Android KeyStore│
            └──────────────┘            └──────────────┘
```

## User Flow - First Login

```
START
  │
  ├─► User opens app
  │
  ├─► Enters email & password
  │
  ├─► Taps "Sign In"
  │
  ├─► Authentication successful
  │
  ├─► Check: Is biometric available?
  │     │
  │     ├─NO──► Go to main screen
  │     │
  │     └─YES─► Show BiometricSetupDialog
  │              │
  │              ├─► User taps "Enable"
  │              │     │
  │              │     ├─► Authenticate with biometric
  │              │     │
  │              │     ├─► Store credentials securely
  │              │     │
  │              │     ├─► Enable biometric flag
  │              │     │
  │              │     └─► Success message
  │              │
  │              └─► User taps "Maybe Later"
  │                    │
  │                    └─► Continue without biometric
  │
  └─► Go to main screen
  │
END
```

## User Flow - Subsequent Logins

```
START
  │
  ├─► User opens app
  │
  ├─► Check: Is biometric enabled?
  │     │
  │     ├─NO──► Show normal login form
  │     │
  │     └─YES─► Show biometric button
  │              │
  │              ├─► User taps biometric button
  │              │     │
  │              │     ├─► Show Face ID / Fingerprint prompt
  │              │     │
  │              │     ├─► User authenticates
  │              │     │
  │              │     ├─► Retrieve stored credentials
  │              │     │
  │              │     ├─► Login with credentials
  │              │     │
  │              │     └─► Success → Main screen
  │              │
  │              └─► User enters password manually
  │                    │
  │                    └─► Normal login flow
  │
END
```

## Error Handling Flow

```
User initiates biometric authentication
  │
  ├─► LocalAuth.authenticate()
  │
  ├─► Platform performs authentication
  │
  ├─► Result?
      │
      ├─SUCCESS──► Return true → Continue
      │
      ├─CANCELLED──► Return false → Show login form
      │
      ├─ERROR: notAvailable
      │  └─► Message: "Biometric not available"
      │     └─► Disable biometric, show login form
      │
      ├─ERROR: notEnrolled
      │  └─► Message: "No biometric enrolled"
      │     └─► Guide to settings, show login form
      │
      ├─ERROR: lockedOut
      │  └─► Message: "Too many attempts"
      │     └─► Show device credential option
      │
      ├─ERROR: permanentlyLockedOut
      │  └─► Message: "Permanently locked"
      │     └─► Guide to settings, show login form
      │
      └─ERROR: passcodeNotSet
         └─► Message: "Set device passcode"
            └─► Guide to settings, show login form
```

## Service Methods Flow

```
BiometricAuthService
  │
  ├─► isBiometricAvailable()
  │   ├─► Check canCheckBiometrics
  │   ├─► Check isDeviceSupported
  │   └─► Return boolean
  │
  ├─► getAvailableBiometrics()
  │   └─► Return List<BiometricType>
  │       (face, fingerprint, iris, etc.)
  │
  ├─► getBiometricTypeName(biometrics)
  │   └─► Return friendly name string
  │       ("Face ID", "Fingerprint", etc.)
  │
  ├─► authenticate(reason)
  │   ├─► Call LocalAuth.authenticate()
  │   ├─► Handle errors
  │   └─► Return boolean
  │
  ├─► enableBiometric(email)
  │   ├─► Store flag in secure storage
  │   └─► Store email in secure storage
  │
  ├─► disableBiometric()
  │   ├─► Delete flag from secure storage
  │   └─► Delete email from secure storage
  │
  ├─► storeCredentials(email, password)
  │   ├─► Encrypt credentials
  │   └─► Store in secure storage
  │
  ├─► getStoredCredentials()
  │   ├─► Retrieve from secure storage
  │   ├─► Decrypt credentials
  │   └─► Return Map<String, String?>
  │
  └─► clearStoredCredentials()
      └─► Delete from secure storage
```

## Data Flow - Credential Storage

```
User Credentials
  │
  ├─► Email + Password
  │
  ├─► BiometricService.storeCredentials()
  │
  ├─► FlutterSecureStorage.write()
  │
  ├─► Platform-specific encryption
  │     │
  │     ├─iOS──► Keychain (AES-256)
  │     │
  │     └─Android──► KeyStore (AES-256)
  │
  ├─► Encrypted storage
  │
  └─► Retrieved with:
      BiometricService.getStoredCredentials()
```

## Component Relationships

```
┌──────────────────────────────────────────────────────────┐
│                  Login Screen                            │
│  • Checks biometric availability                         │
│  • Shows biometric button if enabled                     │
│  • Handles auto-login on app start                       │
└────────────────────┬─────────────────────────────────────┘
                     │ uses
                     ▼
┌──────────────────────────────────────────────────────────┐
│            BiometricAuthService                          │
│  • Core business logic                                   │
│  • Wraps LocalAuth API                                   │
│  • Manages secure storage                                │
│  • Error handling                                        │
└────┬─────────────────────────────────┬──────────────────┘
     │ uses                            │ uses
     ▼                                 ▼
┌──────────────────┐          ┌──────────────────────┐
│   LocalAuth      │          │ FlutterSecureStorage │
│   Package        │          │   Package            │
│  • Face ID       │          │  • Credentials       │
│  • Touch ID      │          │  • Settings          │
│  • Fingerprint   │          │  • Flags             │
└──────────────────┘          └──────────────────────┘
     │                                 │
     ▼                                 ▼
┌──────────────────┐          ┌──────────────────────┐
│ Platform API     │          │ Platform Storage     │
│ • LocalAuth (iOS)│          │ • Keychain (iOS)     │
│ • BiometricPrompt│          │ • KeyStore (Android) │
│   (Android)      │          │                      │
└──────────────────┘          └──────────────────────┘
```

## Authentication States

```
┌─────────────────┐
│ Not Available   │──► Biometric hardware not present
└─────────────────┘

┌─────────────────┐
│ Available       │──► Hardware present, not enrolled
└─────────────────┘

┌─────────────────┐
│ Enabled         │──► User opted in to biometric login
└─────────────────┘

┌─────────────────┐
│ Disabled        │──► User opted out
└─────────────────┘

┌─────────────────┐
│ Locked Out      │──► Too many failed attempts
└─────────────────┘

┌─────────────────┐
│ Authenticated   │──► Successfully authenticated
└─────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────┐
│           Application Layer                 │
│  • BiometricAuthService                     │
│  • Business logic                           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         Flutter Layer                       │
│  • FlutterSecureStorage                     │
│  • LocalAuth wrapper                        │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         Platform Layer                      │
│  • Keychain (iOS)                           │
│  • KeyStore (Android)                       │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         Hardware Layer                      │
│  • Secure Enclave (iOS)                     │
│  • Trusted Execution Environment (Android)  │
└─────────────────────────────────────────────┘
```

## Legend

```
┌────────┐
│ Box    │  = Component/Screen
└────────┘

   ◄───►      = Two-way interaction

   ───►       = One-way flow

   │
   ├─►        = Decision branch
   │
   └─►        = Alternative path
```
