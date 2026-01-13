# Requirements Document

## Introduction

Fitur ini menyediakan halaman web self-service yang memungkinkan user VIP (baik PC maupun Mobile) untuk melakukan reset HWID mereka sendiri tanpa perlu menghubungi admin. User harus login menggunakan userId Roblox mereka dan sistem akan memverifikasi bahwa userId tersebut terdaftar sebagai VIP aktif sebelum mengizinkan reset HWID.

## Glossary

- **VIP_User**: User yang terdaftar dalam whitelist sistem Starship (PC atau Mobile) dengan status aktif
- **HWID**: Hardware ID - identifier unik perangkat yang digunakan untuk membatasi akses per device
- **Self_Service_Portal**: Halaman web yang memungkinkan VIP user melakukan operasi tertentu secara mandiri
- **User_ID**: ID numerik unik dari akun Roblox user
- **Platform**: Jenis whitelist yang digunakan (PC atau Mobile)
- **Reset_Cooldown**: Periode waktu minimum antara reset HWID untuk mencegah penyalahgunaan

## Requirements

### Requirement 1: User Authentication

**User Story:** As a VIP user, I want to login using my Roblox userId, so that I can access the self-service portal securely.

#### Acceptance Criteria

1. WHEN a user enters their userId and submits the login form, THE Self_Service_Portal SHALL verify the userId exists in either PC or Mobile whitelist
2. WHEN a userId is found in the whitelist, THE Self_Service_Portal SHALL check that the user status is "active"
3. IF a userId is not found in any whitelist, THEN THE Self_Service_Portal SHALL display an error message "User ID tidak terdaftar sebagai VIP"
4. IF a userId exists but status is not "active", THEN THE Self_Service_Portal SHALL display an error message indicating the account status (suspended/expired)
5. WHEN authentication is successful, THE Self_Service_Portal SHALL display the user's profile information including username, platform, and VIP type

### Requirement 2: VIP Status Display

**User Story:** As a VIP user, I want to see my VIP status details, so that I can verify my account information.

#### Acceptance Criteria

1. WHEN a user is authenticated, THE Self_Service_Portal SHALL display the username from whitelist data
2. WHEN a user is authenticated, THE Self_Service_Portal SHALL display the platform type (PC or Mobile)
3. WHEN a user is authenticated, THE Self_Service_Portal SHALL display the VIP type (VIP, MOBILE_VIP, owner, etc.)
4. WHEN a user is authenticated, THE Self_Service_Portal SHALL display the expiration date if applicable, or "Lifetime" if no expiration
5. WHEN a user is authenticated, THE Self_Service_Portal SHALL display the current HWID status (registered or not registered)

### Requirement 3: HWID Reset Functionality

**User Story:** As a VIP user, I want to reset my HWID, so that I can use Starship on a different device.

#### Acceptance Criteria

1. WHEN a user clicks the reset HWID button, THE Self_Service_Portal SHALL send a reset request to the whitelist-manager API
2. WHEN the reset is successful, THE Self_Service_Portal SHALL display a success message confirming the HWID has been cleared
3. WHEN the reset is successful, THE Self_Service_Portal SHALL update the displayed HWID status to "Not Registered"
4. IF the reset fails, THEN THE Self_Service_Portal SHALL display an error message with the failure reason
5. WHEN a reset is performed, THE Self_Service_Portal SHALL record the reset timestamp for the user

### Requirement 4: Reset Cooldown Protection

**User Story:** As a system administrator, I want to limit HWID reset frequency, so that the feature is not abused.

#### Acceptance Criteria

1. THE Self_Service_Portal SHALL enforce a minimum 1-hour cooldown between HWID resets
2. WHEN a user attempts to reset within the cooldown period, THE Self_Service_Portal SHALL display the remaining cooldown time
3. IF a user is within cooldown period, THEN THE Self_Service_Portal SHALL disable the reset button
4. WHEN the cooldown period expires, THE Self_Service_Portal SHALL enable the reset button automatically

### Requirement 5: Security and API Integration

**User Story:** As a system administrator, I want the portal to securely communicate with the backend, so that unauthorized resets are prevented.

#### Acceptance Criteria

1. THE Self_Service_Portal SHALL use a dedicated API endpoint for user verification that does not require admin credentials
2. THE Self_Service_Portal SHALL use a dedicated API endpoint for HWID reset that validates user identity
3. WHEN making API requests, THE Self_Service_Portal SHALL include the userId for identity verification
4. THE Self_Service_Portal SHALL NOT expose admin secrets or sensitive credentials to the client

### Requirement 6: User Interface Design

**User Story:** As a VIP user, I want a clean and intuitive interface, so that I can easily perform HWID reset.

#### Acceptance Criteria

1. THE Self_Service_Portal SHALL display a login form with userId input field on initial load
2. THE Self_Service_Portal SHALL display loading indicators during API requests
3. THE Self_Service_Portal SHALL use consistent styling with the existing Starship branding
4. THE Self_Service_Portal SHALL be responsive and work on both desktop and mobile browsers
5. THE Self_Service_Portal SHALL display clear error messages in Indonesian language
