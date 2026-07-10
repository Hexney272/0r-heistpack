// Open Source License-Free HeistPack UI
// Vanilla JavaScript version for FiveM NUI

// License bypass - Always return true for any license check
// Set global license flags
globalThis.hasLicense = true;
globalThis.licenseValid = true;
globalThis.isLicensed = true;

// Override fetch to bypass license check
if (typeof fetch !== 'undefined') {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = function(url, options) {
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

// Main UI initialization
const initApp = () => {
    // Signal that UI is ready to load
    fetch(`https://${GetParentResourceName()}/nui:client:loadUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });

    // Create the UI structure
    const root = document.getElementById('root');
    if (root) {
        root.innerHTML = `
            <div class="heistpack-ui" style="display: none;">
                <div class="ui-overlay"></div>
                <div class="ui-main">
                    <div class="ui-header">
                        <h1>0R Heist Pack</h1>
                        <button class="close-btn">×</button>
                    </div>
                    <div class="ui-content">
                        <div class="home-page">
                            <h2>Heist Pack</h2>
                            <p>Choose your next heist</p>
                            <div id="scenarios-list"></div>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Add styles that match the original UI
        const style = document.createElement('style');
        style.textContent = `
            @import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap');
            @import url('https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@300;400;500;600;700&display=swap');

            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            body {
                margin: 0;
                overflow: hidden;
                font-family: 'Poppins', sans-serif;
            }

            .heistpack-ui {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                z-index: 9999;
                font-family: 'Poppins', sans-serif;
            }
            
            .ui-overlay {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.8);
                backdrop-filter: blur(8px);
            }
            
            .ui-main {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: 95%;
                max-width: 900px;
                max-height: 85vh;
                background: linear-gradient(145deg, #0f1419 0%, #1a1f2e 50%, #0f1419 100%);
                border-radius: 20px;
                border: 2px solid rgba(255, 215, 0, 0.2);
                box-shadow: 0 25px 50px rgba(0, 0, 0, 0.7), 
                           0 0 0 1px rgba(255, 215, 0, 0.1),
                           inset 0 1px 0 rgba(255, 255, 255, 0.1);
                overflow: hidden;
            }
            
            .ui-header {
                background: linear-gradient(90deg, rgba(255, 215, 0, 0.15) 0%, rgba(255, 215, 0, 0.05) 100%);
                padding: 25px 30px;
                border-bottom: 1px solid rgba(255, 215, 0, 0.3);
                display: flex;
                justify-content: space-between;
                align-items: center;
                backdrop-filter: blur(10px);
            }
            
            .ui-header h1 {
                color: #ffd700;
                margin: 0;
                font-size: 28px;
                font-weight: 700;
                font-family: 'Chakra Petch', sans-serif;
                text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
                letter-spacing: 1px;
            }
            
            .close-btn {
                background: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
                color: #fff;
                width: 35px;
                height: 35px;
                border-radius: 50%;
                cursor: pointer;
                font-size: 20px;
                font-weight: 600;
                transition: all 0.3s ease;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            
            .close-btn:hover {
                background: rgba(255, 69, 58, 0.8);
                border-color: rgba(255, 69, 58, 0.8);
                transform: scale(1.1) rotate(90deg);
            }
            
            .ui-content {
                padding: 30px;
                max-height: calc(100% - 90px);
                overflow-y: auto;
            }
            
            .ui-content::-webkit-scrollbar {
                width: 8px;
            }
            
            .ui-content::-webkit-scrollbar-track {
                background: rgba(255, 255, 255, 0.05);
                border-radius: 4px;
            }
            
            .ui-content::-webkit-scrollbar-thumb {
                background: rgba(255, 215, 0, 0.3);
                border-radius: 4px;
            }
            
            .ui-content::-webkit-scrollbar-thumb:hover {
                background: rgba(255, 215, 0, 0.5);
            }
            
            .home-page h2 {
                color: #ffd700;
                text-align: center;
                margin-bottom: 10px;
                font-size: 32px;
                font-weight: 700;
                font-family: 'Chakra Petch', sans-serif;
                text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
            }
            
            .home-page p {
                color: #a0a0a0;
                text-align: center;
                margin-bottom: 40px;
                font-size: 16px;
                font-weight: 400;
            }
            
            .scenario-card {
                background: linear-gradient(145deg, rgba(255, 255, 255, 0.03) 0%, rgba(255, 255, 255, 0.01) 100%);
                border: 1px solid rgba(255, 215, 0, 0.15);
                border-radius: 15px;
                padding: 25px;
                margin-bottom: 20px;
                cursor: pointer;
                transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
                position: relative;
                overflow: hidden;
            }
            
            .scenario-card::before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg, transparent, rgba(255, 215, 0, 0.1), transparent);
                transition: left 0.6s ease;
            }
            
            .scenario-card:hover::before {
                left: 100%;
            }
            
            .scenario-card:hover {
                background: linear-gradient(145deg, rgba(255, 215, 0, 0.08) 0%, rgba(255, 215, 0, 0.04) 100%);
                border-color: rgba(255, 215, 0, 0.4);
                transform: translateY(-5px) scale(1.02);
                box-shadow: 0 15px 30px rgba(255, 215, 0, 0.2),
                           0 0 20px rgba(255, 215, 0, 0.1);
            }
            
            .scenario-card h3 {
                color: #ffd700;
                margin: 0 0 15px 0;
                font-size: 22px;
                font-weight: 600;
                font-family: 'Chakra Petch', sans-serif;
                text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5);
            }
            
            .scenario-card p {
                color: #c0c0c0;
                margin: 0 0 20px 0;
                font-size: 15px;
                line-height: 1.5;
                font-weight: 400;
            }
            
            .scenario-details {
                display: flex;
                gap: 12px;
                margin-bottom: 20px;
                flex-wrap: wrap;
            }
            
            .scenario-details span {
                background: linear-gradient(45deg, rgba(255, 215, 0, 0.15) 0%, rgba(255, 215, 0, 0.08) 100%);
                color: #ffd700;
                padding: 8px 14px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
                border: 1px solid rgba(255, 215, 0, 0.2);
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }
            
            .start-btn {
                background: linear-gradient(45deg, #ffd700 0%, #ffed4e 50%, #ffd700 100%);
                border: none;
                color: #0f1419;
                padding: 12px 25px;
                border-radius: 10px;
                cursor: pointer;
                font-weight: 700;
                font-size: 14px;
                font-family: 'Chakra Petch', sans-serif;
                transition: all 0.3s ease;
                text-transform: uppercase;
                letter-spacing: 1px;
                position: relative;
                overflow: hidden;
                box-shadow: 0 4px 15px rgba(255, 215, 0, 0.3);
            }
            
            .start-btn::before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4), transparent);
                transition: left 0.6s ease;
            }
            
            .start-btn:hover::before {
                left: 100%;
            }
            
            .start-btn:hover {
                transform: scale(1.05) translateY(-2px);
                box-shadow: 0 8px 25px rgba(255, 215, 0, 0.5),
                           0 0 20px rgba(255, 215, 0, 0.3);
            }
            
            .start-btn:active {
                transform: scale(0.98);
            }
            
            .alert {
                padding: 18px 25px;
                border-radius: 12px;
                margin-bottom: 25px;
                text-align: center;
                font-weight: 500;
                font-size: 15px;
                border: 1px solid;
                backdrop-filter: blur(10px);
            }
            
            .alert-error {
                background: rgba(255, 69, 58, 0.15);
                border-color: rgba(255, 69, 58, 0.4);
                color: #ff6b6b;
                box-shadow: 0 4px 15px rgba(255, 69, 58, 0.2);
            }
            
            .alert-success {
                background: rgba(52, 199, 89, 0.15);
                border-color: rgba(52, 199, 89, 0.4);
                color: #51cf66;
                box-shadow: 0 4px 15px rgba(52, 199, 89, 0.2);
            }
            
            .alert-info {
                background: rgba(0, 123, 255, 0.15);
                border-color: rgba(0, 123, 255, 0.4);
                color: #74c0fc;
                box-shadow: 0 4px 15px rgba(0, 123, 255, 0.2);
            }
        `;
        document.head.appendChild(style);

        // Message listener
        window.addEventListener('message', function(event) {
            const { action, data } = event.data;
            
            switch (action) {
                case 'ui:setVisible':
                    const ui = document.querySelector('.heistpack-ui');
                    ui.style.display = data ? 'block' : 'none';
                    break;
                    
                case 'ui:setupUI':
                    if (data.heistScenarios) {
                        const scenariosList = document.getElementById('scenarios-list');
                        scenariosList.innerHTML = '';
                        
                        Object.entries(data.heistScenarios).forEach(([key, scenario]) => {
                            const card = document.createElement('div');
                            card.className = 'scenario-card';
                            
                            const details = [];
                            if (scenario.level) details.push(`<span>Level: ${scenario.level}</span>`);
                            if (scenario.requiredCops) details.push(`<span>Police: ${scenario.requiredCops}</span>`);
                            if (scenario.teamSize) {
                                const min = scenario.teamSize.min || 1;
                                const max = scenario.teamSize.max || 4;
                                details.push(`<span>Players: ${min}-${max}</span>`);
                            }
                            
                            card.innerHTML = `
                                <h3>${scenario.label || scenario.name || key}</h3>
                                <p>${scenario.description || 'No description available'}</p>
                                ${details.length > 0 ? `<div class="scenario-details">${details.join('')}</div>` : ''}
                                <button class="start-btn" onclick="startHeist('${key}')">Start Heist</button>
                            `;
                            scenariosList.appendChild(card);
                        });
                    }
                    
                    // Signal UI is loaded
                    fetch(`https://${GetParentResourceName()}/nui:client:onLoadUI`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                        body: JSON.stringify({})
                    });
                    break;
                    
                case 'ui:setAlert':
                    if (data && data.text) {
                        const alertDiv = document.createElement('div');
                        alertDiv.className = `alert alert-${data.type || 'info'}`;
                        alertDiv.textContent = data.text;
                        
                        const content = document.querySelector('.ui-content');
                        content.insertBefore(alertDiv, content.firstChild);
                        
                        setTimeout(() => {
                            alertDiv.remove();
                        }, 3000);
                    }
                    break;
                    
                case 'ui:setPage':
                    // Handle page changes if needed
                    break;
            }
        });

        // Close button handler
        document.querySelector('.close-btn').addEventListener('click', function() {
            document.querySelector('.heistpack-ui').style.display = 'none';
            fetch(`https://${GetParentResourceName()}/nui:client:hideFrame`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            });
        });

        // Overlay click handler
        document.querySelector('.ui-overlay').addEventListener('click', function() {
            document.querySelector('.heistpack-ui').style.display = 'none';
            fetch(`https://${GetParentResourceName()}/nui:client:hideFrame`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            });
        });
    }

    // Global function for starting heists
    globalThis.startHeist = function(scenarioKey) {
        fetch(`https://${GetParentResourceName()}/nui:client:startScenario`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ scenarioKey: scenarioKey })
        });
    };
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initApp);
} else {
    initApp();
}

// Signal that this is a license-free version
console.log('[0R-HeistPack] License-Free UI Loaded Successfully');
