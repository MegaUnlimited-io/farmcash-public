// ============================================================================
// FARMCASH SUPABASE CLIENT & AUTH UTILITIES
// Shared across all pages: index.html, verify/index.html, referral/index.html
// ============================================================================

// Initialize Supabase client
const SUPABASE_URL = 'https://sqljnhjsrwixyeasbjur.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_ZNm9BWAUZkAV29iYMkOlHg_gIc6NVGM'; 

// Import Supabase (already done in HTML via CDN)
const { createClient } = supabase;

// Create client instance
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================================
// CLIENT FINGERPRINT COLLECTION (Minimal for Waitlist)
// ============================================================================

async function getQuickFingerprint() {
    const fp = {
        ip: null,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        browser: getBrowser(),
        os: getOS(),
        deviceType: getDeviceType(),
    };
    
    // Get IP address
    try {
        const res = await fetch('https://api.ipify.org?format=json');
        const data = await res.json();
        fp.ip = data.ip;
    } catch (e) {
        console.warn('Could not fetch IP:', e);
        fp.ip = null;
    }
    
    // Generate simple hash for deduplication
    const hashString = `${fp.ip}-${fp.timezone}-${fp.browser}-${fp.os}`;
    fp.hash = simpleHash(hashString);
    
    return fp;
}

function getBrowser() {
    const ua = navigator.userAgent;
    if (ua.includes('Edg')) return 'Edge';
    if (ua.includes('Chrome')) return 'Chrome';
    if (ua.includes('Firefox')) return 'Firefox';
    if (ua.includes('Safari')) return 'Safari';
    return 'Other';
}

function getOS() {
    const ua = navigator.userAgent;
    if (ua.includes('Windows')) return 'Windows';
    if (ua.includes('Mac')) return 'Mac';
    if (ua.includes('Linux')) return 'Linux';
    if (ua.includes('Android')) return 'Android';
    if (/iPad|iPhone|iPod/.test(ua)) return 'iOS';
    return 'Other';
}

function getDeviceType() {
    const ua = navigator.userAgent;
    if (/Mobile|Android|iPhone/i.test(ua)) return 'mobile';
    if (/iPad|Tablet/i.test(ua)) return 'tablet';
    return 'desktop';
}

function simpleHash(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
}

// ============================================================================
// AUTH HELPER FUNCTIONS
// ============================================================================

// Check if user is logged in
async function checkAuth() {
    const { data: { session }, error } = await supabaseClient.auth.getSession();
    return { session, error };
}

// Sign up new user
async function signUpUser(email, password = null) {
    // For magic link only, password can be null
    const { data, error } = await supabaseClient.auth.signUp({
        email: email,
        password: password || generateRandomPassword(), // Required by Supabase
        options: {
            emailRedirectTo: `${window.location.origin}/verify/`
        }
    });
    return { data, error };
}

// Send magic link for login
async function sendMagicLink(email) {
    const { data, error } = await supabaseClient.auth.signInWithOtp({
        email: email,
        options: {
            emailRedirectTo: `${window.location.origin}/verify/`
        }
    });
    return { data, error };
}

// Sign out
async function signOut() {
    const { error } = await supabaseClient.auth.signOut();
    return { error };
}

// Generate random password (required by Supabase even for magic link)
function generateRandomPassword() {
    return Math.random().toString(36).slice(-16) + Math.random().toString(36).slice(-16);
}

// ============================================================================
// DATABASE FUNCTIONS
// ============================================================================

// Create waitlist user record
async function createWaitlistUser(userId, email, surveyData, fingerprintData, referredBy = null) {
    try {
        // 1. Check if user record exists (from ApparenceKit trigger or otherwise)
        const { data: existingUser } = await supabaseClient
            .from('users')
            .select('id, referral_code')
            .eq('id', userId)
            .single();
        
        let referralCode = existingUser?.referral_code;
        
        // 2. If user doesn't exist, create it manually
        if (!existingUser) {
            // Generate unique referral code
            referralCode = await generateUniqueReferralCode();
            
            const { error: userError } = await supabaseClient
                .from('users')
                .insert({
                    id: userId,
                    email: email,
                    seeds_balance: 0,
                    cash_balance: 0.00,
                    user_level: 1,
                    total_harvests: 0,
                    experience_points: 0,
                    water_balance: 100,
                    referral_code: referralCode,
                    is_waitlist_user: true,
                    referred_by: referredBy
                });
            
            if (userError) {
                console.error('Error creating user record:', userError);
                throw userError;
            }
        } else {
            // User exists (created by trigger), update it with waitlist flag
            const { error: updateError } = await supabaseClient
                .from('users')
                .update({
                    is_waitlist_user: true,
                    referred_by: referredBy
                })
                .eq('id', userId);
            
            if (updateError) {
                console.error('Error updating user record:', updateError);
                throw updateError;
            }
        }
        
        // 3. Create waitlist_signups record
        const { data: waitlistData, error: waitlistError } = await supabaseClient
            .from('waitlist_signups')
            .insert({
                user_id: userId,
                email: email,
                game_type: surveyData.gameType,
                rewarded_apps: surveyData.rewardedApps,
                devices: surveyData.devices,
                ip_address: fingerprintData.ip,
                timezone: fingerprintData.timezone,
                browser: fingerprintData.browser,
                os: fingerprintData.os,
                device_type: fingerprintData.deviceType,
                fingerprint_hash: fingerprintData.hash,
                referrer: document.referrer || 'direct'
            })
            .select()
            .single();
        
        if (waitlistError) {
            console.error('Error creating waitlist record:', waitlistError);
            throw waitlistError;
        }
        
        return { success: true, data: waitlistData, referralCode: referralCode };
        
    } catch (error) {
        console.error('Error creating waitlist user:', error);
        return { success: false, error: error.message };
    }
}

// Generate unique referral code with database verification
async function generateUniqueReferralCode(maxAttempts = 5) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        // Generate random 6-character code
        let code = '';
        for (let i = 0; i < 6; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        
        // Check if code already exists in database
        const { data, error } = await supabaseClient
            .from('users')
            .select('id')
            .eq('referral_code', code)
            .single();
        
        // If no match found (error PGRST116 means no results), code is unique!
        if (error && error.code === 'PGRST116') {
            return code;
        }
        
        // If we got data back, code already exists - try again
        console.warn(`Referral code collision detected: ${code}, retrying... (attempt ${attempt + 1}/${maxAttempts})`);
    }
    
    // If we failed after max attempts, throw error
    throw new Error('Failed to generate unique referral code after multiple attempts');
}

// Process email verification and award seeds
async function processEmailVerification(userId, referredBy = null) {
    try {
        console.log('Calling process_email_verification RPC:', { userId, referredBy });
        
        const { data, error } = await supabaseClient.rpc('process_email_verification', {
            p_user_id: userId,
            p_referred_by: referredBy
        });
        
        if (error) {
            console.error('RPC error:', error);
            throw error;
        }
        
        console.log('RPC returned:', data);
        console.log('RPC result structure:', JSON.stringify(data, null, 2));
        
        return { success: true, data: data[0] };
        
    } catch (error) {
        console.error('Error processing verification:', error);
        return { success: false, error: error.message };
    }
}

// Get user dashboard data
async function getUserDashboardData(userId) {
    try {
        // Get user data
        const { data: userData, error: userError } = await supabaseClient
            .from('users')
            .select('email, seeds_balance, referral_code, referral_count, creation_date')
            .eq('id', userId)
            .single();
        
        if (userError) throw userError;
        
        // Get waitlist data
        const { data: waitlistData, error: waitlistError } = await supabaseClient
            .from('waitlist_signups')
            .select('email_verified, created_at')
            .eq('user_id', userId)
            .single();
        
        if (waitlistError) throw waitlistError;
        
        return { 
            success: true, 
            data: {
                ...userData,
                email_verified: waitlistData.email_verified,
                created_at: waitlistData.created_at
            }
        };
        
    } catch (error) {
        console.error('Error fetching dashboard data:', error);
        return { success: false, error: error.message };
    }
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Get referral code from URL
function getReferralCode() {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('ref');
}

// Get user ID from referral code
async function getUserIdFromReferralCode(referralCode) {
    try {
        const { data, error } = await supabaseClient
            .from('users')
            .select('id')
            .eq('referral_code', referralCode)
            .single();
        
        if (error) return null;
        return data?.id || null;
        
    } catch (error) {
        console.error('Error looking up referral code:', error);
        return null;
    }
}

// Store referral code in LOCAL storage (persists across sessions)
function storeReferralCode(code) {
    if (code) {
        localStorage.setItem('farmcash_referral', code); // ← Changed
    }
}

function getStoredReferralCode() {
    return localStorage.getItem('farmcash_referral'); // ← Changed
}

function clearStoredReferralCode() {
    localStorage.removeItem('farmcash_referral'); // ← Changed
}

// ============================================================================
// GLOBAL SCOPE (for non-module scripts like index.html)
// Functions are already available globally since this is loaded as a regular script
// ============================================================================

// For ES6 modules (verify/referral pages), we'll create a separate export file
