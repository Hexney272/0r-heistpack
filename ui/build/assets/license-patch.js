// License Patch for 0R HeistPack
// This script patches the original JavaScript to bypass license checks

// Override fetch to always return true for license checks
const originalFetch = window.fetch;
window.fetch = function(url, options) {
    if (url && url.includes('hasillegalpacklicense')) {
        return Promise.resolve(new Response('true', {
            status: 200,
            statusText: 'OK',
            headers: { 'Content-Type': 'text/plain' }
        }));
    }
    return originalFetch.apply(this, arguments);
};

// Set global license flags
window.hasLicense = true;
window.licenseValid = true;
window.isLicensed = true;

// Override any potential license validation functions
window.validateLicense = function() { return true; };
window.checkLicense = function() { return true; };
