// Feature: vip-hwid-reset, Property Tests for VIP Self-Service API
// Validates: Requirements 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.3, 4.4

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';

// ============ HELPER FUNCTIONS (extracted from API for testing) ============

const HWID_RESET_COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

/**
 * Calculate remaining cooldown time in seconds
 * @param {string|null} lastHwidReset - ISO timestamp of last reset
 * @returns {number} - Remaining cooldown in seconds (0 if no cooldown)
 */
function calculateCooldownRemaining(lastHwidReset) {
    if (!lastHwidReset) return 0;
    
    const lastResetTime = new Date(lastHwidReset).getTime();
    const now = Date.now();
    const elapsed = now - lastResetTime;
    const remaining = HWID_RESET_COOLDOWN_MS - elapsed;
    
    return remaining > 0 ? Math.ceil(remaining / 1000) : 0;
}

/**
 * Check if user is expired based on expiresAt field
 * @param {object} user - User object from whitelist
 * @returns {boolean} - True if user is expired
 */
function isUserExpired(user) {
    if (!user.expiresAt) return false;
    return new Date(user.expiresAt) < new Date();
}

/**
 * Verify user eligibility for self-service
 * @param {object|null} user - User object or null if not found
 * @returns {object} - { eligible: boolean, error?: string }
 */
function verifyUserEligibility(user) {
    if (!user) {
        return { eligible: false, error: 'USER_NOT_FOUND' };
    }
    
    if (isUserExpired(user)) {
        return { eligible: false, error: 'USER_EXPIRED' };
    }
    
    if (user.status === 'suspended') {
        return { eligible: false, error: 'USER_SUSPENDED' };
    }
    
    if (user.status !== 'active') {
        return { eligible: false, error: 'USER_INACTIVE' };
    }
    
    return { eligible: true };
}

/**
 * Check if HWID reset is allowed based on cooldown
 * @param {string|null} lastHwidReset - ISO timestamp of last reset
 * @returns {object} - { allowed: boolean, cooldownRemaining: number }
 */
function checkResetCooldown(lastHwidReset) {
    const cooldownRemaining = calculateCooldownRemaining(lastHwidReset);
    return {
        allowed: cooldownRemaining === 0,
        cooldownRemaining
    };
}

// ============ ARBITRARIES (Generators) ============

// Generate valid user IDs (numeric strings)
const userIdArb = fc.nat({ max: 9999999999 }).map(n => String(n + 10000));

// Generate usernames
const usernameArb = fc.string({ minLength: 3, maxLength: 20 });

// Generate user status
const statusArb = fc.constantFrom('active', 'suspended', 'expired', 'inactive');

// Generate VIP types
const typeArb = fc.constantFrom('VIP', 'MOBILE_VIP', 'owner');

// Generate platform
const platformArb = fc.constantFrom('pc', 'mobile');

// Generate timestamps using integer milliseconds
const pastTimestampArb = fc.integer({ min: 1577836800000, max: Date.now() }).map(ts => new Date(ts).toISOString());
const futureTimestampArb = fc.integer({ min: Date.now() + 86400000, max: 1893456000000 }).map(ts => new Date(ts).toISOString());

// Generate expiration dates (past, future, or null for lifetime)
const expiresAtArb = fc.oneof(
    fc.constant(null), // Lifetime
    pastTimestampArb,  // Expired
    futureTimestampArb // Not expired
);

// Generate lastHwidReset timestamps (within last 2 hours or null)
const lastHwidResetArb = fc.oneof(
    fc.constant(null), // Never reset
    fc.integer({ min: Date.now() - 2 * HWID_RESET_COOLDOWN_MS, max: Date.now() }).map(ts => new Date(ts).toISOString())
);

// Generate HWID strings
const hwidArb = fc.oneof(fc.constant(null), fc.string({ minLength: 32, maxLength: 64 }));

// Generate a complete user object
const userArb = fc.record({
    userId: userIdArb,
    username: usernameArb,
    type: typeArb,
    status: statusArb,
    platform: platformArb,
    expiresAt: expiresAtArb,
    hwid: hwidArb,
    lastHwidReset: lastHwidResetArb,
    addedAt: pastTimestampArb
});

// Generate active, non-expired user
const activeUserArb = fc.record({
    userId: userIdArb,
    username: usernameArb,
    type: typeArb,
    status: fc.constant('active'),
    platform: platformArb,
    expiresAt: fc.oneof(fc.constant(null), futureTimestampArb),
    hwid: hwidArb,
    lastHwidReset: lastHwidResetArb,
    addedAt: pastTimestampArb
});

// Generate suspended, non-expired user
const suspendedUserArb = fc.record({
    userId: userIdArb,
    username: usernameArb,
    type: typeArb,
    status: fc.constant('suspended'),
    platform: platformArb,
    expiresAt: fc.oneof(fc.constant(null), futureTimestampArb),
    hwid: hwidArb,
    lastHwidReset: lastHwidResetArb,
    addedAt: pastTimestampArb
});

// Generate expired user
const expiredUserArb = fc.record({
    userId: userIdArb,
    username: usernameArb,
    type: typeArb,
    status: fc.constant('active'),
    platform: platformArb,
    expiresAt: pastTimestampArb, // Always expired
    hwid: hwidArb,
    lastHwidReset: lastHwidResetArb,
    addedAt: pastTimestampArb
});

// ============ PROPERTY TESTS ============

describe('VIP Self-Service API - Property Tests', () => {
    
    // Feature: vip-hwid-reset, Property 1: User Verification Correctness
    // Validates: Requirements 1.1, 1.3
    describe('Property 1: User Verification Correctness', () => {
        
        it('should return USER_NOT_FOUND for null user', () => {
            fc.assert(
                fc.property(fc.constant(null), (user) => {
                    const result = verifyUserEligibility(user);
                    expect(result.eligible).toBe(false);
                    expect(result.error).toBe('USER_NOT_FOUND');
                }),
                { numRuns: 100 }
            );
        });

        it('should correctly identify user existence based on whitelist membership', () => {
            fc.assert(
                fc.property(
                    activeUserArb,
                    fc.boolean(),
                    (user, existsInWhitelist) => {
                        const userToCheck = existsInWhitelist ? user : null;
                        const result = verifyUserEligibility(userToCheck);
                        
                        if (!existsInWhitelist) {
                            expect(result.eligible).toBe(false);
                            expect(result.error).toBe('USER_NOT_FOUND');
                        } else {
                            expect(result.eligible).toBe(true);
                        }
                    }
                ),
                { numRuns: 100 }
            );
        });
    });

    // Feature: vip-hwid-reset, Property 2: Active Status Enforcement
    // Validates: Requirements 1.2, 1.4
    describe('Property 2: Active Status Enforcement', () => {
        
        it('should allow active, non-expired users', () => {
            fc.assert(
                fc.property(activeUserArb, (user) => {
                    const result = verifyUserEligibility(user);
                    expect(result.eligible).toBe(true);
                }),
                { numRuns: 100 }
            );
        });

        it('should return USER_SUSPENDED for suspended users (non-expired)', () => {
            fc.assert(
                fc.property(suspendedUserArb, (user) => {
                    const result = verifyUserEligibility(user);
                    expect(result.eligible).toBe(false);
                    expect(result.error).toBe('USER_SUSPENDED');
                }),
                { numRuns: 100 }
            );
        });

        it('should return USER_EXPIRED for expired users', () => {
            fc.assert(
                fc.property(expiredUserArb, (user) => {
                    const result = verifyUserEligibility(user);
                    expect(result.eligible).toBe(false);
                    expect(result.error).toBe('USER_EXPIRED');
                }),
                { numRuns: 100 }
            );
        });

        it('should allow lifetime users (null expiresAt) if active', () => {
            fc.assert(
                fc.property(
                    activeUserArb.map(u => ({ ...u, expiresAt: null })),
                    (user) => {
                        const result = verifyUserEligibility(user);
                        expect(result.eligible).toBe(true);
                    }
                ),
                { numRuns: 100 }
            );
        });
    });

    // Feature: vip-hwid-reset, Property 4: Cooldown Enforcement
    // Validates: Requirements 4.1, 4.2, 4.3, 4.4
    describe('Property 4: Cooldown Enforcement', () => {
        
        it('should allow reset when lastHwidReset is null (never reset before)', () => {
            fc.assert(
                fc.property(fc.constant(null), (lastHwidReset) => {
                    const result = checkResetCooldown(lastHwidReset);
                    expect(result.allowed).toBe(true);
                    expect(result.cooldownRemaining).toBe(0);
                }),
                { numRuns: 100 }
            );
        });

        it('should block reset when within cooldown period (less than 1 hour)', () => {
            fc.assert(
                fc.property(
                    // Generate timestamps within the last hour (but not exactly now)
                    fc.integer({ min: 1, max: HWID_RESET_COOLDOWN_MS - 1000 }).map(msAgo => {
                        return new Date(Date.now() - msAgo).toISOString();
                    }),
                    (lastHwidReset) => {
                        const result = checkResetCooldown(lastHwidReset);
                        expect(result.allowed).toBe(false);
                        expect(result.cooldownRemaining).toBeGreaterThan(0);
                        expect(result.cooldownRemaining).toBeLessThanOrEqual(3600); // Max 1 hour in seconds
                    }
                ),
                { numRuns: 100 }
            );
        });

        it('should allow reset when cooldown has expired (more than 1 hour)', () => {
            fc.assert(
                fc.property(
                    // Generate timestamps more than 1 hour ago
                    fc.integer({ min: HWID_RESET_COOLDOWN_MS + 1000, max: 7 * 24 * HWID_RESET_COOLDOWN_MS }).map(msAgo => {
                        return new Date(Date.now() - msAgo).toISOString();
                    }),
                    (lastHwidReset) => {
                        const result = checkResetCooldown(lastHwidReset);
                        expect(result.allowed).toBe(true);
                        expect(result.cooldownRemaining).toBe(0);
                    }
                ),
                { numRuns: 100 }
            );
        });

        it('should calculate correct remaining cooldown time', () => {
            fc.assert(
                fc.property(
                    // Generate timestamps within the last hour
                    fc.integer({ min: 60000, max: HWID_RESET_COOLDOWN_MS - 60000 }).map(msAgo => ({
                        msAgo,
                        timestamp: new Date(Date.now() - msAgo).toISOString()
                    })),
                    ({ msAgo, timestamp }) => {
                        const result = checkResetCooldown(timestamp);
                        const expectedRemaining = Math.ceil((HWID_RESET_COOLDOWN_MS - msAgo) / 1000);
                        
                        // Allow 2 second tolerance for timing differences
                        expect(Math.abs(result.cooldownRemaining - expectedRemaining)).toBeLessThanOrEqual(2);
                    }
                ),
                { numRuns: 100 }
            );
        });
    });

    // Feature: vip-hwid-reset, Property 5: Reset State Consistency
    // Validates: Requirements 3.3, 3.5
    describe('Property 5: Reset State Consistency', () => {
        
        /**
         * Simulate HWID reset operation (extracted logic from API)
         * @param {object} user - User object with hwid, hwidHistory, lastHwidReset
         * @returns {object} - Updated user object after reset
         */
        function performHwidReset(user) {
            const updatedUser = { ...user };
            
            // Initialize hwidHistory if not exists
            updatedUser.hwidHistory = updatedUser.hwidHistory || [];
            
            // Save current HWID to history if exists
            if (updatedUser.hwid) {
                updatedUser.hwidHistory = [
                    ...updatedUser.hwidHistory,
                    {
                        hwid: updatedUser.hwid,
                        resetAt: new Date().toISOString()
                    }
                ];
            }
            
            // Clear HWID and update timestamp
            updatedUser.hwid = null;
            updatedUser.lastHwidReset = new Date().toISOString();
            
            return updatedUser;
        }

        // Generate user with HWID (non-null)
        const userWithHwidArb = fc.record({
            userId: userIdArb,
            username: usernameArb,
            type: typeArb,
            status: fc.constant('active'),
            platform: platformArb,
            expiresAt: fc.oneof(fc.constant(null), futureTimestampArb),
            hwid: fc.string({ minLength: 32, maxLength: 64 }), // Always has HWID
            lastHwidReset: fc.oneof(
                fc.constant(null),
                // More than 1 hour ago (cooldown expired)
                fc.integer({ min: HWID_RESET_COOLDOWN_MS + 1000, max: 7 * 24 * HWID_RESET_COOLDOWN_MS })
                    .map(msAgo => new Date(Date.now() - msAgo).toISOString())
            ),
            hwidHistory: fc.array(
                fc.record({
                    hwid: fc.string({ minLength: 32, maxLength: 64 }),
                    resetAt: pastTimestampArb
                }),
                { maxLength: 5 }
            ),
            addedAt: pastTimestampArb
        });

        // Generate user without HWID (null)
        const userWithoutHwidArb = fc.record({
            userId: userIdArb,
            username: usernameArb,
            type: typeArb,
            status: fc.constant('active'),
            platform: platformArb,
            expiresAt: fc.oneof(fc.constant(null), futureTimestampArb),
            hwid: fc.constant(null), // No HWID
            lastHwidReset: fc.oneof(
                fc.constant(null),
                fc.integer({ min: HWID_RESET_COOLDOWN_MS + 1000, max: 7 * 24 * HWID_RESET_COOLDOWN_MS })
                    .map(msAgo => new Date(Date.now() - msAgo).toISOString())
            ),
            hwidHistory: fc.array(
                fc.record({
                    hwid: fc.string({ minLength: 32, maxLength: 64 }),
                    resetAt: pastTimestampArb
                }),
                { maxLength: 5 }
            ),
            addedAt: pastTimestampArb
        });

        it('should set HWID to null after reset', () => {
            fc.assert(
                fc.property(userWithHwidArb, (user) => {
                    const updatedUser = performHwidReset(user);
                    expect(updatedUser.hwid).toBeNull();
                }),
                { numRuns: 100 }
            );
        });

        it('should update lastHwidReset timestamp to current time after reset', () => {
            fc.assert(
                fc.property(userWithHwidArb, (user) => {
                    const beforeReset = Date.now();
                    const updatedUser = performHwidReset(user);
                    const afterReset = Date.now();
                    
                    expect(updatedUser.lastHwidReset).not.toBeNull();
                    
                    const resetTime = new Date(updatedUser.lastHwidReset).getTime();
                    // Reset timestamp should be between before and after (with small tolerance)
                    expect(resetTime).toBeGreaterThanOrEqual(beforeReset - 100);
                    expect(resetTime).toBeLessThanOrEqual(afterReset + 100);
                }),
                { numRuns: 100 }
            );
        });

        it('should add previous HWID to hwidHistory when HWID exists', () => {
            fc.assert(
                fc.property(userWithHwidArb, (user) => {
                    const originalHwid = user.hwid;
                    const originalHistoryLength = (user.hwidHistory || []).length;
                    
                    const updatedUser = performHwidReset(user);
                    
                    // History should grow by 1
                    expect(updatedUser.hwidHistory.length).toBe(originalHistoryLength + 1);
                    
                    // Last entry should contain the original HWID
                    const lastEntry = updatedUser.hwidHistory[updatedUser.hwidHistory.length - 1];
                    expect(lastEntry.hwid).toBe(originalHwid);
                    expect(lastEntry.resetAt).toBeDefined();
                }),
                { numRuns: 100 }
            );
        });

        it('should NOT add to hwidHistory when HWID is null (no HWID to save)', () => {
            fc.assert(
                fc.property(userWithoutHwidArb, (user) => {
                    const originalHistoryLength = (user.hwidHistory || []).length;
                    
                    const updatedUser = performHwidReset(user);
                    
                    // History should remain the same length
                    expect(updatedUser.hwidHistory.length).toBe(originalHistoryLength);
                }),
                { numRuns: 100 }
            );
        });

        it('should preserve existing hwidHistory entries after reset', () => {
            fc.assert(
                fc.property(userWithHwidArb, (user) => {
                    const originalHistory = [...(user.hwidHistory || [])];
                    
                    const updatedUser = performHwidReset(user);
                    
                    // All original entries should still exist
                    for (let i = 0; i < originalHistory.length; i++) {
                        expect(updatedUser.hwidHistory[i].hwid).toBe(originalHistory[i].hwid);
                        expect(updatedUser.hwidHistory[i].resetAt).toBe(originalHistory[i].resetAt);
                    }
                }),
                { numRuns: 100 }
            );
        });
    });
});
