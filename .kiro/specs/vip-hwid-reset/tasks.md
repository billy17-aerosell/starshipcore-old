# Implementation Plan: VIP Self-Service HWID Reset Portal

## Overview

Implementasi portal self-service untuk VIP user melakukan reset HWID secara mandiri. Menggunakan JavaScript untuk backend API dan HTML/CSS/JS untuk frontend.

## Tasks

- [x] 1. Create Backend API Endpoint
  - [x] 1.1 Add self-service actions to `/api/whitelist-manager.js` (merged to stay within Vercel 12 API limit)
    - Added `self_verify` action for user verification across PC and Mobile whitelists
    - Added `self_reset_hwid` action for HWID reset with cooldown
    - Return user data with cooldown status
    - Handle errors for non-existent and inactive users
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1-2.5_

  - [x] 1.2 Implement reset_hwid functionality in whitelist-manager
    - Implement cooldown enforcement (1 hour)
    - Clear HWID from whitelist and Redis registry
    - Update lastHwidReset timestamp
    - Add previous HWID to history
    - _Requirements: 3.1, 3.3, 3.5, 4.1_

  - [x] 1.3 Write property test for user verification
    - **Property 1: User Verification Correctness**
    - **Property 2: Active Status Enforcement**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4**

  - [x] 1.4 Write property test for cooldown enforcement
    - **Property 4: Cooldown Enforcement**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

- [x] 2. Create Frontend HTML Page
  - [x] 2.1 Create `/public/vip-reset.html` with login form
    - Input field for userId
    - Verify button
    - Loading state
    - Error display
    - _Requirements: 6.1, 6.2, 6.5_

  - [x] 2.2 Add user info display section
    - Show username, platform, VIP type
    - Show expiration date or "Lifetime"
    - Show HWID status (registered/not registered)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 2.3 Add HWID reset functionality
    - Reset button with confirmation
    - Cooldown timer display
    - Disable button during cooldown
    - Success/error messages
    - _Requirements: 3.1, 3.2, 3.4, 4.2, 4.3, 4.4_

  - [x] 2.4 Apply Starship branding and styling
    - Use existing color scheme from verify.html
    - Responsive design for mobile
    - Indonesian language for all text
    - _Requirements: 6.3, 6.4, 6.5_

- [x] 3. Checkpoint - Verify Integration
  - Ensure all tests pass, ask the user if questions arise.
  - Test login flow with valid and invalid userIds
  - Test HWID reset with cooldown enforcement
  - Verify error messages display correctly

- [x] 4. Write property test for reset state consistency
  - [x] 4.1 Write property test for HWID reset
    - **Property 5: Reset State Consistency**
    - **Validates: Requirements 3.3, 3.5**

- [x] 5. Final Checkpoint
  - Ensure all tests pass, ask the user if questions arise.
  - Verify complete user flow from login to reset
  - Test edge cases (expired users, suspended users, cooldown)

## Notes

- All tasks are required for comprehensive implementation
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Frontend uses embedded CSS/JS (single file) for simplicity
- **API merged into whitelist-manager.js** to comply with Vercel Hobby 12 API limit
- Frontend calls `/api/whitelist-manager` with actions `self_verify` and `self_reset_hwid`
