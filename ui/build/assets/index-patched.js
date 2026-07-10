// Read the original file and patch the license check
const originalJs = await fetch('./assets/index-1767362123431.js').then(r => r.text());

// Patch the license check - replace the fetch call with direct true
const patchedJs = originalJs.replace(
    /const le=await fetch\("https:\/\/0r_lib\/hasillegalpacklicense",\{method:"POST",headers:\{"Content-Type":"application\/json; charset=UTF-8"\}\}\);if\(!le\.ok\)throw new Error\(`Fetch failed with status \${le\.status}`\);const ge=await le\.text\(\)==="true";o\(ge\)/,
    'const ge=true;o(ge)' // Always return true for license
);

// Also patch any other license-related checks
const finalPatchedJs = patchedJs.replace(
    /if\(ca\(\)\)return o\(!0\);o\(!0\),\(async\(\)=>\{try\{.*?\}catch\{o\(!1\)\}\}\)\(\)/,
    'o(!0)' // Always set license to true
);

// Write the patched version
document.write(finalPatchedJs);

// Alternative approach: Simple fetch override
if (typeof fetch !== 'undefined') {
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
}

// Set global license flags
window.hasLicense = true;
window.licenseValid = true;
window.isLicensed = true;
