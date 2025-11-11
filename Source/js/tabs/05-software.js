        function loadSoftwareTab() {
            const sw = systemData.Software;
            if (!sw) {
                document.getElementById('softwareHealthBanner').innerHTML =
                    '<div style="padding: 20px; text-align: center; color: var(--text-muted);">No software data available</div>';
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            loadSoftwareHealthBanner(sw);
            loadSoftwareStatusDashboard(sw);
            loadApplicationHealthIssues(sw);

            // TIER 2: DIAGNOSTIC DETAIL
            loadInstalledApplicationsSection(sw);
            loadStartupProgramsSection(sw);

            // TIER 3: ADVANCED INFORMATION
            loadPerformanceMetricsSection(sw);
            loadLicenseStatusSection(sw);
        }

        function loadSoftwareHealthBanner(sw) {
            const banner = document.getElementById('softwareHealthBanner');
            if (!banner) return;

            const criticalIssues = [];
            const warningIssues = [];

            // Check for crashes
            let totalCrashes = sw.ApplicationHealth?.Summary?.TotalCrashes72h || 0;
            if (typeof totalCrashes === 'object') totalCrashes = totalCrashes?.Sum || 0;
            totalCrashes = Number(totalCrashes) || 0;

            if (totalCrashes > 10) {
                criticalIssues.push(`${totalCrashes} application crashes in last 72 hours`);
            } else if (totalCrashes > 5) {
                warningIssues.push(`${totalCrashes} application crashes in last 72 hours`);
            }

            // Check for hangs
            let totalHangs = sw.ApplicationHealth?.Summary?.TotalHangs72h || 0;
            if (typeof totalHangs === 'object') totalHangs = totalHangs?.Sum || 0;
            totalHangs = Number(totalHangs) || 0;

            if (totalHangs > 10) {
                warningIssues.push(`${totalHangs} application hangs in last 72 hours`);
            }

            // Check for high startup program count
            let startupPrograms = sw.StartupPrograms?.Items || [];
            if (!Array.isArray(startupPrograms)) startupPrograms = [];
            const startupCount = startupPrograms.length;
            if (startupCount > 20) {
                warningIssues.push(`${startupCount} startup programs may slow boot time`);
            }

            // Determine overall status
            let overallHealthStatus = 'healthy';
            let healthIcon = '✅';
            let healthText = 'All Systems Operational';

            if (criticalIssues.length > 0) {
                overallHealthStatus = 'critical';
                healthIcon = '🔴';
                healthText = 'Critical Issues Detected';
            } else if (warningIssues.length > 0) {
                overallHealthStatus = 'warning';
                healthIcon = '⚠️';
                healthText = 'Warnings Detected';
            }

            let healthBannerHtml = `
                <div class="health-status">
                    <span class="health-icon">${healthIcon}</span>
                    <div>
                        <strong>Software System Health: ${healthText}</strong>
                        <span style="color: var(--text-secondary); display: block; margin-top: 5px;">
                            ${criticalIssues.length + warningIssues.length > 0 ?
                                `${criticalIssues.length + warningIssues.length} issue${criticalIssues.length + warningIssues.length > 1 ? 's' : ''} detected` :
                                'No critical software issues detected'}
                        </span>
                    </div>
                </div>
            `;

            if (criticalIssues.length > 0 || warningIssues.length > 0) {
                healthBannerHtml += `
                    <div class="health-reasons">
                        <strong>Issues Detected:</strong>
                        <ul>
                `;
                criticalIssues.forEach(issue => {
                    healthBannerHtml += `<li>${escapeHtml(issue)}</li>`;
                });
                warningIssues.forEach(issue => {
                    healthBannerHtml += `<li>${escapeHtml(issue)}</li>`;
                });
                healthBannerHtml += `</ul></div>`;
            }

            banner.className = `health-banner ${overallHealthStatus}`;
            banner.innerHTML = healthBannerHtml;
        }

        function loadSoftwareStatusDashboard(sw) {
            const section = document.getElementById('softwareStatusDashboard');
            if (!section) return;

            const totalApps = sw.InstalledApplications?.TotalCount || 0;

            let totalCrashes = sw.ApplicationHealth?.Summary?.TotalCrashes72h || 0;
            if (typeof totalCrashes === 'object') totalCrashes = totalCrashes?.Sum || 0;
            totalCrashes = Number(totalCrashes) || 0;

            let startupPrograms = sw.StartupPrograms?.Items || [];
            if (!Array.isArray(startupPrograms)) startupPrograms = [];
            const startupCount = startupPrograms.length;
            const healthScore = sw.HealthScore || 0;

            const crashColor = totalCrashes === 0 ? 'var(--success-color)' : totalCrashes > 5 ? 'var(--danger-color)' : 'var(--warning-color)';
            const startupColor = startupCount > 20 ? 'var(--warning-color)' : 'inherit';
            const healthColor = healthScore >= 80 ? 'var(--success-color)' : healthScore >= 60 ? 'var(--warning-color)' : 'var(--danger-color)';

            let dashboardHtml = `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${totalApps > 0 ? 'var(--success-color)' : 'inherit'};\">${totalApps}</div>
                        <div class="metric-label">Installed Apps</div>
                        <div class="metric-sublabel">Total installed</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${crashColor};">${totalCrashes}</div>
                        <div class="metric-label">Recent Crashes</div>
                        <div class="metric-sublabel">Last 72 hours</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${startupColor};">${startupCount}</div>
                        <div class="metric-label">Startup Programs</div>
                        <div class="metric-sublabel">Auto-start enabled</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${healthColor};">${healthScore}</div>
                        <div class="metric-label">Health Score</div>
                        <div class="metric-sublabel">${healthScore >= 80 ? 'Excellent' : healthScore >= 60 ? 'Fair' : 'Poor'}</div>
                    </div>
                </div>
            `;

            section.innerHTML = dashboardHtml;
        }

        function loadApplicationHealthIssues(sw) {
            const section = document.getElementById('applicationHealthIssues');
            if (!section) return;

            const crashes = sw.ApplicationHealth?.Crashes || [];
            const hangs = sw.ApplicationHealth?.Hangs || [];

            let html = '<div style="padding: 20px;">';

            if (crashes.length === 0 && hangs.length === 0) {
                html += `
                    <div class="alert alert-info">
                        <div style="display: flex; align-items: center; gap: 15px;">
                            <div style="font-size: 2.5rem;">✓</div>
                            <div>
                                <strong>No Critical Issues Detected</strong>
                                <p style="margin-top: 10px; color: var(--text-secondary);">All applications are running normally with no recent crashes or errors.</p>
                            </div>
                        </div>
                    </div>
                `;
            } else {
                if (crashes.length > 0) {
                    html += `
                        <div class="alert alert-danger" style="margin-bottom: 15px;">
                            <strong>⚠️ Application Crashes Detected</strong>
                            <table style="width: 100%; margin-top: 15px; border-collapse: collapse;">
                                <thead>
                                    <tr style="border-bottom: 1px solid var(--border-color);">
                                        <th style="text-align: left; padding: 8px;">Application</th>
                                        <th style="text-align: left; padding: 8px;">Count</th>
                                        <th style="text-align: left; padding: 8px;">Last Crash</th>
                                    </tr>
                                </thead>
                                <tbody>
                    `;

                    crashes.slice(0, 5).forEach(crash => {
                        const lastCrashTime = crash.LastCrash ? formatTimeAgo(new Date(crash.LastCrash)) : 'Unknown';
                        html += `
                            <tr style="border-bottom: 1px solid var(--border-color);">
                                <td style="padding: 8px;">${escapeHtml(crash.Application)}</td>
                                <td style="padding: 8px;">${crash.CrashCount}</td>
                                <td style="padding: 8px;">${lastCrashTime}</td>
                            </tr>
                        `;
                    });

                    html += `</tbody></table></div>`;
                }

                if (hangs.length > 0) {
                    html += `
                        <div class="alert alert-warning">
                            <strong>⚠️ Application Hangs Detected</strong>
                            <table style="width: 100%; margin-top: 15px; border-collapse: collapse;">
                                <thead>
                                    <tr style="border-bottom: 1px solid var(--border-color);">
                                        <th style="text-align: left; padding: 8px;">Application</th>
                                        <th style="text-align: left; padding: 8px;">Count</th>
                                        <th style="text-align: left; padding: 8px;">Last Hang</th>
                                    </tr>
                                </thead>
                                <tbody>
                    `;

                    hangs.slice(0, 5).forEach(hang => {
                        const lastHangTime = hang.LastHang ? formatTimeAgo(new Date(hang.LastHang)) : 'Unknown';
                        html += `
                            <tr style="border-bottom: 1px solid var(--border-color);">
                                <td style="padding: 8px;">${escapeHtml(hang.Application)}</td>
                                <td style="padding: 8px;">${hang.HangCount}</td>
                                <td style="padding: 8px;">${lastHangTime}</td>
                            </tr>
                        `;
                    });

                    html += `</tbody></table></div>`;
                }
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadInstalledApplicationsSection(sw) {
            const section = document.getElementById('installedApplicationsSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            const applications = sw.InstalledApplications?.Applications || [];

            if (applications.length === 0) {
                html += '<div style="text-align: center; color: var(--text-muted);">No applications found</div>';
            } else {
                // Sort to show apps with size data first, then by size descending
                const sortedApps = [...applications].sort((a, b) => {
                    const aSizeMB = parseFloat(a.SizeMB) || 0;
                    const bSizeMB = parseFloat(b.SizeMB) || 0;
                    const aHasDate = a.InstallDate && a.InstallDate !== null;
                    const bHasDate = b.InstallDate && b.InstallDate !== null;

                    // Prioritize apps with BOTH size and date
                    const aScore = (aSizeMB > 0 ? 2 : 0) + (aHasDate ? 1 : 0);
                    const bScore = (bSizeMB > 0 ? 2 : 0) + (bHasDate ? 1 : 0);

                    if (aScore !== bScore) return bScore - aScore;

                    // Then sort by size descending
                    return bSizeMB - aSizeMB;
                });

                const displayApps = sortedApps; // Show all apps

                // Add collapsible wrapper
                html += `
                    <div style="margin-bottom: 15px;">
                        <button onclick="document.getElementById('allAppsContent').style.display = document.getElementById('allAppsContent').style.display === 'none' ? 'block' : 'none'; this.textContent = this.textContent.includes('Show') ? '▼ Hide All Applications' : '▶ Show All Applications'"
                                style="padding: 10px 20px; background: var(--accent-color); color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 1rem; font-weight: 500;">
                            ▶ Show All Applications (${applications.length})
                        </button>
                    </div>
                    <div id="allAppsContent" style="display: none;">
                `;

                displayApps.forEach(app => {
                    // Parse install date properly
                    let installDate = null;
                    let installDateStr = 'N/A';
                    if (app.InstallDate) {
                        try {
                            installDate = new Date(app.InstallDate);
                            if (!isNaN(installDate.getTime())) {
                                installDateStr = installDate.toLocaleDateString();
                            }
                        } catch (e) {
                            installDateStr = 'N/A';
                        }
                    }

                    const isRecent = installDate && ((new Date() - installDate) / (1000 * 60 * 60 * 24)) < 14;
                    const isLarge = app.SizeMB && app.SizeMB > 1024;

                    html += `
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px; margin-bottom: 15px;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                                <strong>${escapeHtml(app.Name || 'Unknown Application')}</strong>
                                <span class="status-badge ${isRecent ? 'status-healthy' : 'status-warning'}">
                                    ${isRecent ? 'Recent' : 'Current'}
                                </span>
                            </div>
                            <div class="grid grid-3" style="font-size: 0.9rem;">
                                <div>
                                    <strong>Version:</strong> ${escapeHtml(app.Version || 'Unknown')}<br>
                                    <strong>Publisher:</strong> ${escapeHtml(app.Publisher || 'Unknown')}
                                </div>
                                <div>
                                    <strong>Installed:</strong> ${installDateStr}<br>
                                    <strong>Size:</strong> ${(() => {
                                        const sizeMB = parseFloat(app.SizeMB);
                                        if (!isNaN(sizeMB) && sizeMB > 0) {
                                            if (sizeMB > 1024) {
                                                return `${(sizeMB / 1024).toFixed(1)} GB`;
                                            } else {
                                                return `${sizeMB.toFixed(0)} MB`;
                                            }
                                        }
                                        return 'N/A';
                                    })()}
                                </div>
                                <div>
                                    <strong>Install Location:</strong> ${escapeHtml(app.InstallLocation || 'N/A')}<br>
                                    <strong>Updates:</strong> Auto
                                </div>
                            </div>
                        </div>
                    `;
                });

                // Close collapsible content
                html += `
                    <div style="margin-top: 15px; padding: 12px; background: var(--bg-secondary); border-radius: 6px; border-left: 3px solid var(--info-color);">
                        <small style="color: var(--text-secondary);">
                            <strong>ℹ️ Note:</strong> Applications are sorted by data completeness (those with install dates and sizes appear first).
                            Many applications (especially Windows Store apps, built-in components, and some third-party software)
                            don't store install dates or size information in the Windows registry. "N/A" values are expected and normal.
                        </small>
                    </div>
                    </div>
                `;
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadStartupProgramsSection(sw) {
            const section = document.getElementById('startupProgramsSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            // Ensure startupPrograms is an array
            let startupPrograms = sw.StartupPrograms?.Items || [];
            if (!Array.isArray(startupPrograms)) {
                startupPrograms = [];
            }

            if (startupPrograms.length === 0) {
                html += `
                    <div style="display: flex; align-items: center; gap: 15px; padding: 20px; background: linear-gradient(135deg, rgba(56, 142, 60, 0.1) 0%, rgba(56, 142, 60, 0.05) 100%); border-radius: 8px; border-left: 4px solid var(--success-color);">
                        <div style="font-size: 2.5rem;">✅</div>
                        <div>
                            <h3 style="margin: 0; color: var(--success-color);">No Startup Programs</h3>
                            <p style="margin: 5px 0 0 0; color: var(--text-secondary);">No auto-start applications configured</p>
                        </div>
                    </div>
                `;
            } else {
                // Add collapsible wrapper
                html += `
                    <div style="margin-bottom: 15px;">
                        <button onclick="document.getElementById('startupProgramsContent').style.display = document.getElementById('startupProgramsContent').style.display === 'none' ? 'block' : 'none'; this.textContent = this.textContent.includes('Show') ? '▼ Hide Startup Programs' : '▶ Show Startup Programs'"
                                style="padding: 10px 20px; background: var(--accent-color); color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 1rem; font-weight: 500;">
                            ▶ Show Startup Programs (${startupPrograms.length})
                        </button>
                    </div>
                    <div id="startupProgramsContent" style="display: none;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <thead>
                                <tr style="border-bottom: 1px solid var(--border-color);">
                                    <th style="text-align: left; padding: 8px;">Program</th>
                                    <th style="text-align: left; padding: 8px;">Location</th>
                                    <th style="text-align: left; padding: 8px;">Command</th>
                                </tr>
                            </thead>
                            <tbody>
                `;

                startupPrograms.forEach(program => {
                    html += `
                        <tr style="border-bottom: 1px solid var(--border-color);">
                            <td style="padding: 8px;"><strong>${escapeHtml(program.Name || 'Unknown')}</strong></td>
                            <td style="padding: 8px;">${escapeHtml(program.Location || 'N/A')}</td>
                            <td style="padding: 8px; font-family: monospace; font-size: 0.85rem;">${escapeHtml(program.Command || 'N/A')}</td>
                        </tr>
                    `;
                });

                html += `</tbody></table></div>`;
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadPerformanceMetricsSection(sw) {
            const section = document.getElementById('performanceMetricsSection');
            if (!section) return;

            const perf = sw.Performance || {};
            const cpuUsage = perf.CPU?.CurrentUsage || 0;
            const processCount = perf.ProcessCount?.Total || perf.ProcessCount || 0;

            const memoryUsagePercent = perf.Memory?.UsagePercent || 0;
            const memoryUsedGB = perf.Memory?.UsedGB || 0;
            const memoryTotalGB = perf.Memory?.TotalGB || 0;

            const cpuColor = cpuUsage > 75 ? 'var(--danger-color)' : cpuUsage > 50 ? 'var(--warning-color)' : 'var(--success-color)';
            const memoryColor = memoryUsagePercent > 80 ? 'var(--danger-color)' : memoryUsagePercent > 60 ? 'var(--warning-color)' : 'var(--success-color)';

            let html = `
                <div class="grid grid-3">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${cpuColor};">${typeof cpuUsage === 'number' ? cpuUsage.toFixed(1) + '%' : 'N/A'}</div>
                        <div class="metric-label">CPU Usage</div>
                        <div class="metric-sublabel">${cpuUsage > 75 ? 'High' : cpuUsage > 50 ? 'Moderate' : 'Normal'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${processCount}</div>
                        <div class="metric-label">Running Processes</div>
                        <div class="metric-sublabel">Active processes</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${memoryColor};">${typeof memoryUsagePercent === 'number' ? memoryUsagePercent.toFixed(0) + '%' : 'N/A'}</div>
                        <div class="metric-label">Memory Usage</div>
                        <div class="metric-sublabel">${memoryUsedGB.toFixed(1)} GB / ${memoryTotalGB.toFixed(1)} GB</div>
                    </div>
                </div>
            `;

            section.innerHTML = html;
        }

        function loadLicenseStatusSection(sw) {
            const section = document.getElementById('licenseStatusSection');
            if (!section) return;

            const license = sw.LicenseStatus?.Windows || {};
            const status = license.Status || 'Unknown';
            const statusColor = status === 'Licensed' ? 'var(--success-color)' : 'var(--danger-color)';

            let html = `
                <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                    <h3 style="margin-bottom: 10px; color: var(--accent-color);">Windows Licensing</h3>
                    <div class="grid grid-2" style="font-size: 0.95rem;">
                        <div>
                            <strong>Status:</strong> <span style="color: ${statusColor};">${escapeHtml(status)}</span><br>
                            <strong>Edition:</strong> ${escapeHtml(license.Edition || 'Unknown')}<br>
                            <strong>Product Key:</strong> ${escapeHtml(license.PartialProductKey ? '...' + license.PartialProductKey : 'N/A')}
                        </div>
                        <div>
                            <strong>Activation Method:</strong> ${escapeHtml(license.Description || 'N/A')}<br>
                            <strong>Grace Period:</strong> ${license.GracePeriodRemaining ? license.GracePeriodRemaining + ' days' : 'N/A'}<br>
                            <strong>Status Color:</strong> <span style="display: inline-block; width: 20px; height: 20px; border-radius: 50%; background: ${license.StatusColor === 'Green' ? 'var(--success-color)' : license.StatusColor === 'Yellow' ? 'var(--warning-color)' : 'var(--danger-color)'};"></span>
                        </div>
                    </div>
                </div>
            `;

            section.innerHTML = html;
        }

        // Load Drivers Tab - Redesigned with priority-based layout
