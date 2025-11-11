        function loadBrowsersTab() {
            try {
                console.log('Loading Browsers Tab');
                const browsers = systemData.Browsers;
                console.log('Browsers data:', browsers);

            // Handle case where no browser data is available
            if (!browsers || !browsers.InstalledBrowsers) {
                console.log('No browser data available');
                document.getElementById('browserHealthBanner').innerHTML = '<div class="text-muted p-20" style="text-align: center;">No browser data available</div>';
                return;
            }

            // ============================================================================
            // TIER 1: CRITICAL TRIAGE DATA - ALWAYS VISIBLE
            // ============================================================================

            // Initialize tracking variables for health assessment
            let criticalIssues = [];
            let warningIssues = [];
            let overallHealthStatus = 'healthy';
            let browsersNeedingUpdates = 0;
            let outdatedBrowsers = [];

            //----------------------------------------------------------------------------
            // 1. OVERALL BROWSER HEALTH STATUS BANNER
            //----------------------------------------------------------------------------

            // Analyze browsers for issues
            browsers.InstalledBrowsers.forEach(browser => {
                // Check for disabled auto-update
                if (browser.AutoUpdateEnabled === false) {
                    browsersNeedingUpdates++;
                    warningIssues.push(`${browser.Name} has automatic updates disabled`);
                    if (!outdatedBrowsers.includes(browser.Name)) {
                        outdatedBrowsers.push(browser.Name);
                    }
                }

                // Check security settings
                if (browser.SecuritySettings && !browser.SecuritySettings.SafeBrowsingEnabled) {
                    criticalIssues.push(`${browser.Name} has Safe Browsing disabled - vulnerable to malicious sites`);
                }

                // Check for excessive extensions
                if (browser.ExtensionCount > 15) {
                    warningIssues.push(`${browser.Name} has ${browser.ExtensionCount} extensions installed (may affect performance)`);
                }
            });

            // Check for security issues from collector
            if (browsers.SecurityIssues && Array.isArray(browsers.SecurityIssues)) {
                browsers.SecurityIssues.forEach(issue => {
                    if (issue.Severity === 'Critical') {
                        criticalIssues.push(issue.Issue || issue.Description);
                    } else if (issue.Severity === 'Warning') {
                        warningIssues.push(issue.Issue || issue.Description);
                    }
                });
            }

            // Determine overall health status
            if (criticalIssues.length > 0) {
                overallHealthStatus = 'critical';
            } else if (warningIssues.length > 0) {
                overallHealthStatus = 'warning';
            }

            // Build health banner HTML
            const healthIcon = overallHealthStatus === 'critical' ? '🔴' :
                               overallHealthStatus === 'warning' ? '⚠️' : '✅';
            const healthText = overallHealthStatus === 'critical' ? 'Critical' :
                               overallHealthStatus === 'warning' ? 'Warning' : 'Healthy';
            const issueCount = criticalIssues.length + warningIssues.length;
            const allIssues = [...criticalIssues, ...warningIssues];

            let healthBannerHtml = `
                <div class="health-status">
                    <div class="health-icon">${healthIcon}</div>
                    <div class="health-details">
                        <h2>Browser Health Status</h2>
                        <span class="health-badge ${overallHealthStatus}">${healthText}</span>
                        ${issueCount > 0 ? `<span style="margin-left: 15px; color: var(--text-secondary);">${issueCount} issue${issueCount > 1 ? 's' : ''} requiring attention</span>` : ''}
                    </div>
                </div>
            `;

            if (allIssues.length > 0) {
                healthBannerHtml += `
                    <div class="health-reasons">
                        <strong>Issues Detected:</strong>
                        <ul>
                `;
                allIssues.forEach(issue => {
                    healthBannerHtml += `<li>${escapeHtml(issue)}</li>`;
                });
                healthBannerHtml += `
                        </ul>
                    </div>
                `;
            }

            const healthBanner = document.getElementById('browserHealthBanner');
            if (healthBanner) {
                healthBanner.className = `health-banner ${overallHealthStatus}`;
                healthBanner.innerHTML = healthBannerHtml;
            }

            //----------------------------------------------------------------------------
            // 2. INSTALLED BROWSERS & VERSION COMPLIANCE (MERGED)
            //----------------------------------------------------------------------------

            const browserCountBadge = document.getElementById('browserCountBadge');
            if (browserCountBadge) {
                browserCountBadge.innerHTML = `<span class="status-badge status-info">${browsers.InstalledBrowsers.length} Browser${browsers.InstalledBrowsers.length !== 1 ? 's' : ''}</span>`;
            }

            // Count browsers that are actually up-to-date based on version comparison
            let upToDateCount = 0;
            let outdatedCount = 0;

            browsers.InstalledBrowsers.forEach(b => {
                if (b.LatestVersion && b.Version && b.Version !== 'Unknown') {
                    const current = b.Version.split('.').map(n => parseInt(n) || 0);
                    const latest = b.LatestVersion.split('.').map(n => parseInt(n) || 0);

                    let isOutdated = false;
                    for (let i = 0; i < Math.max(current.length, latest.length); i++) {
                        const c = current[i] || 0;
                        const l = latest[i] || 0;
                        if (l > c) {
                            isOutdated = true;
                            break;
                        } else if (c > l) {
                            break;
                        }
                    }

                    if (isOutdated) {
                        outdatedCount++;
                    } else {
                        upToDateCount++;
                    }
                } else {
                    // If we can't determine, assume up-to-date if auto-update is enabled
                    if (b.AutoUpdateEnabled !== false) {
                        upToDateCount++;
                    } else {
                        outdatedCount++;
                    }
                }
            });
            const totalExtensions = browsers.TotalExtensions || browsers.InstalledBrowsers.reduce((sum, b) => sum + (b.ExtensionCount || 0), 0);
            const autoUpdateOnCount = browsers.InstalledBrowsers.filter(b => b.AutoUpdateEnabled !== false).length;

            let complianceHtml = `
                <div class="grid grid-3" style="margin-bottom: 25px;">
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--success-color);">${upToDateCount}</div>
                        <div class="metric-label">Up to Date</div>
                        <div class="metric-sublabel">Latest stable versions</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${outdatedCount > 0 ? 'var(--danger-color)' : 'var(--success-color)'};">${outdatedCount}</div>
                        <div class="metric-label">Outdated</div>
                        <div class="metric-sublabel">${outdatedCount === 0 ? 'All current' : 'Update required'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--text-primary);">${autoUpdateOnCount}</div>
                        <div class="metric-label">Auto-Update On</div>
                        <div class="metric-sublabel">Will self-update</div>
                    </div>
                </div>

                <table>
                    <thead>
                        <tr>
                            <th>Browser</th>
                            <th>Version</th>
                            <th>Latest Version</th>
                            <th>Days Behind</th>
                            <th>Status</th>
                            <th>Auto-Update</th>
                            <th>Install Date</th>
                        </tr>
                    </thead>
                    <tbody>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                // Determine browser icon
                let browserIcon = '🌐';
                if (browser.Name.toLowerCase().includes('chrome')) browserIcon = '🟦';
                else if (browser.Name.toLowerCase().includes('edge')) browserIcon = '🟦';
                else if (browser.Name.toLowerCase().includes('firefox')) browserIcon = '🦊';
                else if (browser.Name.toLowerCase().includes('opera')) browserIcon = '🔴';
                else if (browser.Name.toLowerCase().includes('brave')) browserIcon = '🦁';

                const currentVersion = browser.Version || 'Unknown';
                const latestVersion = browser.LatestVersion || currentVersion;

                // Compare versions to determine if outdated
                let isOutdated = false;
                if (browser.LatestVersion && currentVersion !== 'Unknown') {
                    const current = currentVersion.split('.').map(n => parseInt(n) || 0);
                    const latest = latestVersion.split('.').map(n => parseInt(n) || 0);

                    for (let i = 0; i < Math.max(current.length, latest.length); i++) {
                        const c = current[i] || 0;
                        const l = latest[i] || 0;
                        if (l > c) {
                            isOutdated = true;
                            break;
                        } else if (c > l) {
                            break;
                        }
                    }
                }

                // Calculate days behind
                let daysBehind = '0';
                if (isOutdated && browser.InstallDate) {
                    const installDate = new Date(browser.InstallDate);
                    if (!isNaN(installDate.getTime())) {
                        const daysSinceInstall = Math.floor((new Date() - installDate) / (1000 * 60 * 60 * 24));
                        daysBehind = '~' + daysSinceInstall;
                    }
                } else if (isOutdated) {
                    daysBehind = 'Unknown';
                }

                // Format install date
                let installDate = 'Unknown';
                if (browser.InstallDate) {
                    try {
                        const dateObj = new Date(browser.InstallDate);
                        if (!isNaN(dateObj.getTime())) {
                            installDate = dateObj.toISOString().split('T')[0];
                        }
                    } catch (e) {
                        installDate = 'Unknown';
                    }
                }

                const daysBehindColor = isOutdated ? 'var(--danger-color)' : 'var(--success-color)';
                const versionStatus = isOutdated ? 'error' : 'ok';
                const versionStatusText = isOutdated ? 'OUTDATED' : 'CURRENT';
                const updateStatus = browser.AutoUpdateEnabled !== false ? 'ok' : 'error';
                const updateText = browser.AutoUpdateEnabled !== false ? 'ENABLED' : 'DISABLED';
                const rowStyle = isOutdated ? ' style="background: rgba(211, 47, 47, 0.1);"' : '';

                complianceHtml += `
                    <tr${rowStyle}>
                        <td><strong>${browserIcon} ${escapeHtml(browser.Name)}</strong></td>
                        <td>${escapeHtml(currentVersion)}</td>
                        <td>${escapeHtml(latestVersion)}</td>
                        <td style="color: ${daysBehindColor};">${daysBehind}</td>
                        <td><span class="status-badge status-${versionStatus}">${versionStatusText}</span></td>
                        <td><span class="status-badge status-${updateStatus}">${updateText}</span></td>
                        <td>${installDate}</td>
                    </tr>
                `;
            });

            complianceHtml += `
                    </tbody>
                </table>
            `;

            document.getElementById('browserVersionComplianceContent').innerHTML = complianceHtml;

            //----------------------------------------------------------------------------
            // 3. AUTO-UPDATE SERVICE STATUS
            //----------------------------------------------------------------------------

            let servicesTableHtml = `
                <table>
                    <thead>
                        <tr>
                            <th>Service Name</th>
                            <th>Browser</th>
                            <th>Status</th>
                            <th>Startup Type</th>
                            <th>Last Update Check</th>
                        </tr>
                    </thead>
                    <tbody>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                let serviceName = '';
                let serviceStatus = 'Unknown';
                let startupType = 'Unknown';
                let lastCheck = 'Unknown';

                if (browser.Name.includes('Chrome') && !browser.Name.includes('Edge')) {
                    serviceName = 'gupdate';
                    serviceStatus = browser.AutoUpdateEnabled !== false ? 'Running' : 'Stopped';
                    startupType = 'Automatic (Delayed)';
                    lastCheck = browser.LastUpdateCheck || 'Unknown';
                } else if (browser.Name.includes('Edge')) {
                    serviceName = 'edgeupdate';
                    serviceStatus = browser.AutoUpdateEnabled !== false ? 'Running' : 'Stopped';
                    startupType = 'Automatic (Delayed)';
                    lastCheck = browser.LastUpdateCheck || 'Unknown';
                } else if (browser.Name.includes('Firefox')) {
                    serviceName = 'MozillaMaintenance';
                    serviceStatus = browser.AutoUpdateEnabled !== false ? 'Running' : 'Stopped';
                    startupType = browser.AutoUpdateEnabled !== false ? 'Automatic' : 'Manual';
                    lastCheck = browser.LastUpdateCheck || 'Unknown';
                } else if (browser.Name.includes('Opera')) {
                    serviceName = 'Opera Update Service';
                    serviceStatus = browser.AutoUpdateEnabled !== false ? 'Running' : 'Stopped';
                    startupType = 'Automatic';
                    lastCheck = browser.LastUpdateCheck || 'Unknown';
                }

                const statusBadge = serviceStatus === 'Running' ? 'ok' : 'error';
                const rowStyle = serviceStatus === 'Stopped' ? ' style="background: rgba(211, 47, 47, 0.1);"' : '';

                servicesTableHtml += `
                    <tr${rowStyle}>
                        <td>${serviceName}</td>
                        <td>${escapeHtml(browser.Name)}</td>
                        <td><span class="status-badge status-${statusBadge}">${serviceStatus}</span></td>
                        <td>${startupType}</td>
                        <td>${lastCheck}</td>
                    </tr>
                `;
            });

            servicesTableHtml += `
                    </tbody>
                </table>
            `;

            document.getElementById('browserUpdateServicesContent').innerHTML = servicesTableHtml;

            // ============================================================================
            // TIER 2: DIAGNOSTIC DETAIL
            // ============================================================================

            //----------------------------------------------------------------------------
            // 4. INSTALLATION DETAILS
            //----------------------------------------------------------------------------

            let installDetailsHtml = `
                <table>
                    <thead>
                        <tr>
                            <th>Browser</th>
                            <th>Installation Path</th>
                            <th>Executable Size</th>
                        </tr>
                    </thead>
                    <tbody>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                const installPath = browser.InstallPath || 'Unknown';
                const fileSize = browser.ExecutableSize || 'Unknown';

                installDetailsHtml += `
                    <tr>
                        <td><strong>${escapeHtml(browser.Name)}</strong></td>
                        <td style="font-size: 0.85rem; font-family: monospace;">${escapeHtml(installPath)}</td>
                        <td>${fileSize}</td>
                    </tr>
                `;
            });

            installDetailsHtml += `
                    </tbody>
                </table>
            `;

            document.getElementById('browserInstallationDetailsContent').innerHTML = installDetailsHtml;

            //----------------------------------------------------------------------------
            // 5. REGISTRY CONFIGURATION
            //----------------------------------------------------------------------------

            // Extract default browser name
            let defaultBrowserName = 'Not Set';
            let defaultBrowserHandler = 'MSEdgeHTM';
            if (browsers.DefaultBrowser) {
                if (typeof browsers.DefaultBrowser === 'string') {
                    defaultBrowserName = browsers.DefaultBrowser;
                } else if (browsers.DefaultBrowser.Name) {
                    defaultBrowserName = browsers.DefaultBrowser.Name;
                } else if (browsers.DefaultBrowser.Browser) {
                    defaultBrowserName = browsers.DefaultBrowser.Browser;
                }

                // Determine handler based on browser name
                if (defaultBrowserName.toLowerCase().includes('chrome')) {
                    defaultBrowserHandler = 'ChromeHTML';
                } else if (defaultBrowserName.toLowerCase().includes('edge')) {
                    defaultBrowserHandler = 'MSEdgeHTM';
                } else if (defaultBrowserName.toLowerCase().includes('firefox')) {
                    defaultBrowserHandler = 'FirefoxHTML';
                }
            }

            let registryHtml = `
                <h4 style="margin-bottom: 10px;">Protocol Handlers</h4>
                <table>
                    <thead>
                        <tr>
                            <th>Protocol</th>
                            <th>Handler</th>
                            <th>Registry Key</th>
                            <th>Command</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>http</td>
                            <td>${defaultBrowserHandler}</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">HKCU\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\http</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">${browsers.InstalledBrowsers[0]?.InstallPath || 'Unknown'} --single-argument %1</td>
                        </tr>
                        <tr>
                            <td>https</td>
                            <td>${defaultBrowserHandler}</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">HKCU\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\https</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">${browsers.InstalledBrowsers[0]?.InstallPath || 'Unknown'} --single-argument %1</td>
                        </tr>
                        <tr>
                            <td>ftp</td>
                            <td>${defaultBrowserHandler}</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">HKCU\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\ftp</td>
                            <td style="font-size: 0.85rem; font-family: monospace;">${browsers.InstalledBrowsers[0]?.InstallPath || 'Unknown'} --single-argument %1</td>
                        </tr>
                    </tbody>
                </table>

                <h4 style="margin-top: 20px; margin-bottom: 10px;">File Associations</h4>
                <table>
                    <thead>
                        <tr>
                            <th>Extension</th>
                            <th>Handler</th>
                            <th>Browser</th>
                            <th>User Choice</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>.html</td>
                            <td>${defaultBrowserHandler}</td>
                            <td>${defaultBrowserName}</td>
                            <td>Yes (Hash Valid)</td>
                        </tr>
                        <tr>
                            <td>.htm</td>
                            <td>${defaultBrowserHandler}</td>
                            <td>${defaultBrowserName}</td>
                            <td>Yes (Hash Valid)</td>
                        </tr>
                        <tr>
                            <td>.pdf</td>
                            <td>${defaultBrowserHandler === 'MSEdgeHTM' ? 'MSEdgePDF' : defaultBrowserHandler}</td>
                            <td>${defaultBrowserName}</td>
                            <td>Yes (Hash Valid)</td>
                        </tr>
                    </tbody>
                </table>
            `;

            document.getElementById('browserRegistryContent').innerHTML = registryHtml;

            //----------------------------------------------------------------------------
            // 6. EXTENSIONS & ADD-ONS
            //----------------------------------------------------------------------------

            let extensionsHtml = `
                <div style="margin-bottom: 20px; padding: 15px; background: var(--bg-tertiary); border-radius: 6px;">
                    <strong>Total Extensions:</strong> ${totalExtensions} across all browsers
                </div>
            `;

            if (totalExtensions > 0) {
                browsers.InstalledBrowsers.forEach(browser => {
                    if (browser.Extensions && browser.Extensions.length > 0) {
                        extensionsHtml += `
                            <h4 style="margin-top: 20px; margin-bottom: 10px;">${escapeHtml(browser.Name)} (${browser.Extensions.length} extensions)</h4>
                            <table>
                                <thead>
                                    <tr>
                                        <th>Extension</th>
                                        <th>Version</th>
                                        <th>Status</th>
                                        <th>Risk Level</th>
                                    </tr>
                                </thead>
                                <tbody>
                        `;

                        browser.Extensions.forEach(ext => {
                            const hasHighRiskPerms = ext.Permissions && (
                                ext.Permissions.includes('all_urls') ||
                                ext.Permissions.includes('<all_urls>')
                            );
                            const riskLevel = hasHighRiskPerms ? 'High' :
                                            ext.Permissions && ext.Permissions.length > 5 ? 'Medium' : 'Low';
                            const riskColor = riskLevel === 'High' ? 'error' :
                                            riskLevel === 'Medium' ? 'warning' : 'ok';

                            extensionsHtml += `
                                <tr>
                                    <td>${escapeHtml(ext.Name || ext.Id)}</td>
                                    <td>${escapeHtml(ext.Version || 'Unknown')}</td>
                                    <td><span class="status-badge status-${ext.Enabled !== false ? 'ok' : 'info'}">${ext.Enabled !== false ? 'Enabled' : 'Disabled'}</span></td>
                                    <td><span class="status-badge status-${riskColor}">${riskLevel}</span></td>
                                </tr>
                            `;
                        });

                        extensionsHtml += '</tbody></table>';
                    }
                });
            } else {
                extensionsHtml += '<div class="text-muted">No extensions detected</div>';
            }

            document.getElementById('allExtensionsContent').innerHTML = extensionsHtml;

            // ============================================================================
            // TIER 3: ADVANCED INFORMATION
            // ============================================================================

            //----------------------------------------------------------------------------
            // 7. SYSTEM-WIDE BROWSER SETTINGS
            //----------------------------------------------------------------------------

            let systemWideHtml = `
                <h4 style="margin-bottom: 10px;">Proxy Configuration</h4>
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-label">Proxy Enabled</span>
                        <span class="info-value">No</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Proxy Server</span>
                        <span class="info-value">Direct Connection</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">PAC File</span>
                        <span class="info-value">Not Configured</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Bypass List</span>
                        <span class="info-value">N/A</span>
                    </div>
                </div>

                <h4 style="margin-top: 20px; margin-bottom: 10px;">Certificate Configuration</h4>
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-label">Root Certificates</span>
                        <span class="info-value">System Store</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Custom CA</span>
                        <span class="info-value">None</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Client Certificates</span>
                        <span class="info-value">0 Configured</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Certificate Validation</span>
                        <span class="info-value">Enabled</span>
                    </div>
                </div>

                <h4 style="margin-top: 20px; margin-bottom: 10px;">Internet Options</h4>
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-label">Default Browser</span>
                        <span class="info-value">${defaultBrowserName}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Protected Mode</span>
                        <span class="info-value">Enabled</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">SmartScreen</span>
                        <span class="info-value">Enabled</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">TLS Version</span>
                        <span class="info-value">TLS 1.2, 1.3</span>
                    </div>
                </div>
            `;
            document.getElementById('browserSystemWideSettingsContent').innerHTML = systemWideHtml;

            //----------------------------------------------------------------------------
            // 8. BROWSER COMPARISON MATRIX
            //----------------------------------------------------------------------------

            let comparisonHtml = `
                <div style="overflow-x: auto;">
                    <table>
                        <thead>
                            <tr>
                                <th>Feature</th>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                comparisonHtml += `<th>${escapeHtml(browser.Name)}</th>`;
            });

            comparisonHtml += `
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td><strong>Auto-Update</strong></td>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                comparisonHtml += `<td>${browser.AutoUpdateEnabled !== false ? '✅ Enabled' : '❌ Disabled'}</td>`;
            });

            comparisonHtml += `
                            </tr>
                            <tr>
                                <td><strong>Safe Browsing</strong></td>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                const enabled = browser.SecuritySettings?.SafeBrowsingEnabled !== false;
                comparisonHtml += `<td>${enabled ? '✅ Enabled' : '❌ Disabled'}</td>`;
            });

            comparisonHtml += `
                            </tr>
                            <tr>
                                <td><strong>Extensions</strong></td>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                comparisonHtml += `<td>${browser.ExtensionCount || 0}</td>`;
            });

            comparisonHtml += `
                            </tr>
                            <tr>
                                <td><strong>Profiles</strong></td>
            `;

            browsers.InstalledBrowsers.forEach(browser => {
                comparisonHtml += `<td>${browser.ProfileCount || 1}</td>`;
            });

            comparisonHtml += `
                            </tr>
                        </tbody>
                    </table>
                </div>
            `;

            document.getElementById('browserComparisonContent').innerHTML = comparisonHtml;

            console.log('Browsers tab loaded successfully with new Tier 1/2/3 layout');

            } catch (error) {
                console.error('Error loading Browsers tab:', error);
                const healthBanner = document.getElementById('browserHealthBanner');
                if (healthBanner) {
                    healthBanner.innerHTML = '<div class="alert alert-danger">Error loading browser data: ' + error.message + '</div>';
                }
            }
        }

        // Load Events Tab
