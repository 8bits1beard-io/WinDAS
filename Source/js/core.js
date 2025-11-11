        function loadSystemData() {
            if (!window.systemData) {
                console.error('System data not loaded');
                return;
            }

            // Set header information
            const computerName = systemData.Metadata?.ComputerName || systemData.ComputerName || 'Unknown Computer';
            const computerModel = systemData.Hardware?.SystemBoard?.Computer?.Model || '';
            const computerManufacturer = systemData.Hardware?.SystemBoard?.Computer?.Manufacturer || '';
            const computerInfo = computerManufacturer && computerModel ? `${escapeHtml(computerManufacturer)} ${escapeHtml(computerModel)}` : '';
            const collectionDate = formatDateISO(new Date(systemData.CollectionTimestamp || systemData.Metadata?.CollectionTimestamp));
            document.getElementById('timestamp').innerHTML =
                `<div class="system-info-badge">💻 ${escapeHtml(computerName)}${computerInfo ? ` (${computerInfo})` : ''}</div>
                 <div class="date-info">
                    <svg fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd"/>
                    </svg>
                    ${collectionDate}
                 </div>`;
            document.getElementById('computerName').style.display = 'none';

            // Load Health Summary Dashboard
            loadHealthSummaryDashboard();

            // Load each tab's data
            loadOSTab();
            loadHardwareTab();
            loadNetworkTab();
            loadPrintersTab();
            loadSoftwareTab();
            loadDriversTab();
            loadBrowsersTab();
            loadEventsTab();

            // Update badges
            updateBadges();
        }

        // Load OS Tab - Redesigned with Priority-Based Layout
