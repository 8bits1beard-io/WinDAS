        function loadOSTab() {
            const os = systemData.OS;
            const hw = systemData.Hardware; // Need hardware data for disk/CPU/memory

            if (!os) {
                console.warn('No OS data available');
                return;
            }

    // ============================================================================
    // OS TAB HELPER FUNCTIONS - Define before use
    // ============================================================================

    function loadDomainAuthSection(os) {
            let html = '';

            // Domain info
            const domainName = os.SystemInfo?.DomainName || 'WORKGROUP';
            const isDomainJoined = domainName !== 'WORKGROUP';

            html += `
                <div style="margin-bottom: 15px;">
                    <strong>Domain:</strong> ${domainName}<br>
                    <strong>Computer Name:</strong> ${os.SystemInfo?.ComputerName || 'Unknown'}<br>
                    <strong>Workgroup:</strong> ${isDomainJoined ? 'N/A (Domain Joined)' : domainName}
                </div>
            `;

            // Domain Authentication Status
            if (os.DomainAuthentication) {
                const auth = os.DomainAuthentication;
                const authHealthy = auth.TrustRelationship === 'Healthy' && auth.DCConnectivity === 'Success';

                html += `
                    <div style="margin-top: 15px; padding: 15px; background: var(--bg-secondary); border-radius: 6px;">
                        <h4 style="margin-bottom: 10px;">🔐 Domain Authentication</h4>
                        <div class="grid grid-2" style="margin-bottom: 10px;">
                            <div class="metric-card">
                                <div class="metric-label">Trust Relationship</div>
                                <div class="metric-value">
                                    <span class="status-badge status-${auth.TrustRelationship === 'Healthy' ? 'healthy' : 'danger'}">${auth.TrustRelationship}</span>
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Kerberos Status</div>
                                <div class="metric-value">
                                    <span class="status-badge status-${auth.KerberosStatus === 'Healthy' ? 'healthy' : 'warning'}">${auth.KerberosStatus || 'Unknown'}</span>
                                </div>
                            </div>
                        </div>
                        <div class="grid grid-2">
                            <div><strong>DNS Resolution:</strong> ${auth.DNSResolution || 'Unknown'}</div>
                            <div><strong>Auth Failures (24h):</strong> ${auth.RecentAuthFailures || 0}</div>
                        </div>
                    </div>
                `;
            }

            // Time Synchronization Status
            if (os.TimeSynchronization) {
                const time = os.TimeSynchronization;
                const timeHealthy = time.NTPStatus === 'Synchronized' && time.W32TimeStatus === 'Running';

                html += `
                    <div style="margin-top: 15px; padding: 15px; background: var(--bg-secondary); border-radius: 6px;">
                        <h4 style="margin-bottom: 10px;">⏰ Time Synchronization</h4>
                        <div class="grid grid-2" style="margin-bottom: 10px;">
                            <div class="metric-card">
                                <div class="metric-label">Sync Status</div>
                                <div class="metric-value">
                                    <span class="status-badge status-${timeHealthy ? 'healthy' : 'warning'}">${time.NTPStatus}</span>
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Time Source</div>
                                <div class="metric-value">
                                    <div style="font-size: 0.9em;">${time.TimeSourceType || 'Unknown'}</div>
                                    <div style="font-size: 0.8em; color: var(--text-muted);">${time.NTPSource || 'Not configured'}</div>
                                </div>
                            </div>
                        </div>
                        <div class="grid grid-3">
                            <div><strong>W32Time Service:</strong> ${time.W32TimeStatus || 'Unknown'}</div>
                            <div><strong>Last Sync:</strong> ${time.LastSyncTime ? new Date(time.LastSyncTime).toLocaleString() : 'Never'}</div>
                            <div><strong>Time Drift:</strong> ${time.TimeDrift ? time.TimeDrift.toFixed(2) + 's' : 'Unknown'}</div>
                        </div>
                    </div>
                `;
            }

            document.getElementById('domainAuthContent').innerHTML = html;
        }

        function loadIntuneSection(os) {
            let html = '';

            if (os.IntuneServices) {
                html += loadIntuneHealthSection(os.IntuneServices);
            } else {
                html += `
                    <div style="text-align: center; padding: 20px;">
                        <span class="status-badge status-info">Intune/MDM Not Available</span>
                        <p style="margin-top: 10px; color: var(--text-muted);">Device not enrolled in Intune or MDM services not detected</p>
                    </div>
                `;
            }

            const intuneEl = document.getElementById('intuneContent');
            if (intuneEl) {
                intuneEl.innerHTML = html;
            }
        }

        function loadGroupPolicySection(os) {
            let html = '';

            if (os.GroupPolicy) {
                const gpHealthy = os.GroupPolicy.LastRefreshSuccessful !== false;
                const gpStatus = gpHealthy ? 'Applied' : 'Failed';
                const gpBadge = gpHealthy ? 'healthy' : 'warning';

                html += `
                    <div style="padding: 15px; background: var(--bg-secondary); border-radius: 6px;">
                        <h4 style="margin-bottom: 15px;">📋 Policy Status</h4>
                        <div class="grid grid-2" style="margin-bottom: 10px;">
                            <div class="metric-card">
                                <div class="metric-label">Last Refresh</div>
                                <div class="metric-value">
                                    <span class="status-badge status-${gpBadge}">${gpStatus}</span>
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Applied On</div>
                                <div class="metric-value">
                                    <div style="font-size: 0.9em;">${formatNetDate(os.GroupPolicy.LastRefreshTime, 'Never')}</div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            } else {
                html += `
                    <div style="text-align: center; padding: 20px;">
                        <span class="status-badge status-info">Group Policy Not Available</span>
                        <p style="margin-top: 10px; color: var(--text-muted);">Group Policy information not detected (may be in workgroup)</p>
                    </div>
                `;
            }

            const gpEl = document.getElementById('groupPolicyContent');
            if (gpEl) {
                gpEl.innerHTML = html;
            }
        }

        function loadIntuneHealthSection(intuneData) {
            if (!intuneData) return '<div style="text-align: center; padding: 20px;"><span class="status-badge status-info">Not Available</span></div>';

            let html = '';

            // 1. ENROLLMENT STATUS
            const isEnrolled = intuneData.IsEnrolled || false;
            const enrollmentType = intuneData.EnrollmentType || 'Unknown';
            const deviceId = intuneData.DeviceId || 'N/A';
            const azureAdJoined = intuneData.AzureAdJoined || false;
            const tenantId = intuneData.TenantId || 'N/A';

            let enrollmentStatusClass = isEnrolled ? 'status-healthy' : 'status-warning';
            let enrollmentStatusText = isEnrolled ? enrollmentType : 'Not Enrolled';

            html += `
                <div class="grid grid-2" style="margin-bottom: 15px;">
                    <div class="metric-card">
                        <div class="metric-label">Enrollment Status</div>
                        <div class="metric-value">
                            <span class="status-badge ${enrollmentStatusClass}">${enrollmentStatusText}</span>
                        </div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-label">Azure AD Status</div>
                        <div class="metric-value">
                            <span class="status-badge ${azureAdJoined ? 'status-healthy' : 'status-info'}">${azureAdJoined ? 'Joined' : 'Not Joined'}</span>
                        </div>
                    </div>
                </div>
            `;

            // 2. DEVICE INFORMATION (if enrolled)
            if (isEnrolled) {
                html += `
                    <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                        <h4 style="margin-bottom: 10px;">Device Registration</h4>
                        <div class="grid grid-2">
                            <div><strong>Device ID:</strong> <span class="text-muted" style="font-family: monospace; font-size: 0.9em;">${deviceId}</span></div>
                            <div><strong>Tenant ID:</strong> <span class="text-muted" style="font-family: monospace; font-size: 0.9em;">${tenantId}</span></div>
                        </div>
                    </div>
                `;

                // 2a. SYNC INFORMATION (if enrolled)
                const lastSync = intuneData.LastSyncTime;
                const syncStatus = intuneData.LastSyncStatus || 'Unknown';
                const nextSync = intuneData.NextScheduledSync;
                const syncFreq = intuneData.SyncFrequency || 'Unknown';

                let syncStatusClass = 'status-info';
                if (syncStatus === 'Success') syncStatusClass = 'status-healthy';
                else if (syncStatus === 'Failed') syncStatusClass = 'status-danger';
                else if (syncStatus === 'In Progress') syncStatusClass = 'status-warning';

                let lastSyncText = 'Never';
                let lastSyncAgo = '';
                if (lastSync) {
                    const syncDate = new Date(lastSync);
                    lastSyncText = syncDate.toLocaleString();
                    const now = new Date();
                    const diffMs = now - syncDate;
                    const diffHours = Math.round(diffMs / (1000 * 60 * 60));
                    const diffDays = Math.round(diffHours / 24);

                    if (diffHours < 1) {
                        lastSyncAgo = 'Less than 1 hour ago';
                    } else if (diffHours < 24) {
                        lastSyncAgo = `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
                    } else {
                        lastSyncAgo = `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
                    }
                }

                let nextSyncText = 'Unknown';
                if (nextSync) {
                    const nextSyncDate = new Date(nextSync);
                    nextSyncText = nextSyncDate.toLocaleString();
                }

                html += `
                    <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                        <h4 style="margin-bottom: 10px;">Sync Status</h4>
                        <div class="grid grid-2" style="margin-bottom: 10px;">
                            <div class="metric-card">
                                <div class="metric-label">Last Sync</div>
                                <div class="metric-value">
                                    <div style="font-size: 0.95em;">${lastSyncText}</div>
                                    ${lastSyncAgo ? `<div style="font-size: 0.8em; color: var(--text-muted);">${lastSyncAgo}</div>` : ''}
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Sync Status</div>
                                <div class="metric-value">
                                    <span class="status-badge ${syncStatusClass}">${syncStatus}</span>
                                </div>
                            </div>
                        </div>
                        <div class="grid grid-2">
                            <div><strong>Next Scheduled:</strong> <span style="font-size: 0.9em;">${nextSyncText}</span></div>
                            <div><strong>Frequency:</strong> <span style="font-size: 0.9em;">${syncFreq}</span></div>
                        </div>
                    </div>
                `;
            }

            // 3. SERVICE HEALTH OVERVIEW
            const overallHealth = intuneData.OverallHealth || 'Unknown';
            const isIntuneCapable = intuneData.IsIntuneCapable || false;
            const servicesData = intuneData.Services || [];
            const requiredIssues = intuneData.RequiredIssues || [];
            const optionalIssues = intuneData.OptionalIssues || [];

            let healthStatusClass = 'status-info';
            if (overallHealth === 'Healthy') healthStatusClass = 'status-healthy';
            else if (overallHealth === 'Warning') healthStatusClass = 'status-warning';
            else if (overallHealth === 'Critical') healthStatusClass = 'status-danger';

            html += `
                <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                    <h4 style="margin-bottom: 10px;">Service Health</h4>
                    <div class="grid grid-3">
                        <div class="metric-card">
                            <div class="metric-label">Overall Health</div>
                            <div class="metric-value">
                                <span class="status-badge ${healthStatusClass}">${overallHealth}</span>
                            </div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-label">Intune Capable</div>
                            <div class="metric-value">
                                <span class="status-badge ${isIntuneCapable ? 'status-healthy' : 'status-warning'}">${isIntuneCapable ? 'Yes' : 'Limited'}</span>
                            </div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-label">Services Status</div>
                            <div class="metric-value">
                                ${requiredIssues.length === 0 ? '<span class="status-badge status-healthy">All Core OK</span>' : `<span class="status-badge status-danger">${requiredIssues.length} Issues</span>`}
                            </div>
                        </div>
                    </div>
                </div>
            `;

            // 4. CRITICAL SERVICE ISSUES (if any)
            if (requiredIssues.length > 0) {
                html += `
                    <div class="alert alert-danger" style="margin-bottom: 15px;">
                        <strong>⚠️ Critical Service Issues Found</strong>
                        <p>The following required services have issues that may impact Intune functionality:</p>
                        <ul style="margin: 10px 0; padding-left: 20px;">
                `;

                requiredIssues.forEach(issue => {
                    html += `<li><strong>${escapeHtml(issue.DisplayName)}</strong> - ${escapeHtml(issue.HealthReason)}</li>`;
                });

                html += `
                        </ul>
                        <p><strong>Impact:</strong> Device may not receive policies, apps, or updates properly.</p>
                    </div>
                `;
            }

            // 5. OPTIONAL SERVICE WARNINGS (if any)
            if (optionalIssues.length > 0 && optionalIssues.length <= 3) {
                html += `
                    <div class="alert alert-warning" style="margin-bottom: 15px;">
                        <strong>Optional Service Notes</strong>
                        <ul style="margin: 5px 0; padding-left: 20px;">
                `;

                optionalIssues.forEach(issue => {
                    html += `<li>${escapeHtml(issue.DisplayName)} - ${escapeHtml(issue.HealthReason)}</li>`;
                });

                html += '</ul></div>';
            }

            return html;
        }

    // ============================================================================
    // TIER 1: CRITICAL TRIAGE DATA - ALWAYS VISIBLE
    // ============================================================================

    // Initialize tracking variables for health assessment
    let criticalIssues = [];
    let warningIssues = [];
    let overallHealthStatus = 'healthy';

    //----------------------------------------------------------------------------
    // 1. OVERALL HEALTH STATUS BANNER
    //----------------------------------------------------------------------------

    // Check for critical issues
    if (os.AllUserProfiles?.Summary?.HasTemporaryProfiles) {
        criticalIssues.push('Temporary profile detected - data will be lost on logout');
    }

    if (os.WindowsUpdate?.RebootStatus?.Required) {
        const daysPending = os.WindowsUpdate.RebootStatus.DaysPending || 0;
        if (daysPending > 7) {
            criticalIssues.push(`Reboot required for ${daysPending} days - security updates not applied`);
        } else {
            warningIssues.push(`Reboot required for ${daysPending} days`);
        }
    }

    if (os.Security?.WindowsDefender?.Enabled === false) {
        criticalIssues.push('Windows Defender real-time protection is disabled');
    }

    if (os.Services?.StoppedCritical?.length > 0) {
        criticalIssues.push(`${os.Services.StoppedCritical.length} critical service(s) stopped`);
    }

    // Check for warning issues
    if (os.WindowsUpdate?.DaysSinceLastCumulative > 30) {
        warningIssues.push(`Windows Updates overdue: last update ${os.WindowsUpdate.DaysSinceLastCumulative} days ago`);
    } else if (os.WindowsUpdate?.PendingUpdates?.CumulativeCount > 0) {
        warningIssues.push(`${os.WindowsUpdate.PendingUpdates.CumulativeCount} Windows Update(s) pending`);
    }

    // Check disk space from Hardware data
    if (hw?.Storage?.Devices) {
        hw.Storage.Devices.forEach(device => {
            const freePercent = Number(device.PercentFree || 0);
            const freeGB = Number(device.FreeSpaceGB || 0);
            const deviceId = device.DeviceID || device.DriveLetter || device.Caption;

            if (freePercent < 10) {
                criticalIssues.push(`${deviceId} critically low on space: ${freeGB.toFixed(1)} GB free (${freePercent.toFixed(0)}%)`);
            } else if (freePercent < 20) {
                warningIssues.push(`${deviceId} low on space: ${freeGB.toFixed(1)} GB free (${freePercent.toFixed(0)}%)`);
            }
        });
    }

    // Determine overall health status
    if (criticalIssues.length > 0) {
        overallHealthStatus = 'critical';
    } else if (warningIssues.length > 0) {
        overallHealthStatus = 'warning';
    }

    // Build full health status banner (matching Browser tab style)
    const healthIcon = overallHealthStatus === 'critical' ? '🔴' :
                       overallHealthStatus === 'warning' ? '⚠️' : '✅';
    const healthText = overallHealthStatus === 'critical' ? 'Critical Issues Detected' :
                       overallHealthStatus === 'warning' ? 'Warnings Detected' : 'System Healthy';
    const issueCount = criticalIssues.length + warningIssues.length;
    const allIssues = [...criticalIssues, ...warningIssues];

    let healthBannerHtml = `
        <div class="health-status">
            <span class="health-icon">${healthIcon}</span>
            <strong>System Health: ${healthText}</strong>
        </div>
    `;

    // Add issues list if there are any
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

    const healthBanner = document.getElementById('osHealthBanner');
    if (healthBanner) {
        healthBanner.className = `health-banner ${overallHealthStatus}`;
        healthBanner.innerHTML = healthBannerHtml;
    }

    //----------------------------------------------------------------------------
    // 2. WINDOWS VERSION & UPTIME
    //----------------------------------------------------------------------------

    const fullVersion = os.SystemInfo?.WindowsVersion || 'Unknown';
    // Extract Windows version and edition from string like "Microsoft Windows 11 Home 10.0.26100"
    const versionMatch = fullVersion.match(/Windows (\d+)\s+(\w+)/);
    const windowsVersion = versionMatch ? `Windows ${versionMatch[1]}` : fullVersion;
    const edition = versionMatch ? versionMatch[2] : '';
    const displayVersion = os.SystemInfo?.DisplayVersion || '';
    const buildNumber = os.SystemInfo?.Build || 'Unknown';

    // Determine color based on Windows version
    let versionColor = 'var(--danger-color)';
    if (windowsVersion.includes('Windows 11')) {
        if (displayVersion.includes('24H2') || displayVersion >= '24H2') {
            versionColor = 'var(--success-color)';
        } else if (displayVersion) {
            versionColor = 'var(--warning-color)';
        }
    }

    // Uptime color coding
    const uptimeDays = os.SystemInfo?.SystemUptime?.Days || 0;
    let uptimeColor = 'var(--success-color)';
    if (uptimeDays >= 21) {
        uptimeColor = 'var(--danger-color)';
    } else if (uptimeDays >= 8) {
        uptimeColor = 'var(--warning-color)';
    }

    const lastBootTime = os.SystemInfo?.LastBootTime || 'Unknown';
    const bootType = os.BootPerformance?.BootType || 'Normal';

    let versionUptimeHtml = `
        <div class="metric-grid">
            <div class="metric-card">
                <div class="metric-value" style="color: ${versionColor};">${windowsVersion} ${edition}</div>
                <div class="metric-label">Operating System</div>
                <div class="metric-sublabel">Version ${displayVersion} (Build ${buildNumber})</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${os.SystemInfo?.Architecture || 'x64'}</div>
                <div class="metric-label">Architecture</div>
                <div class="metric-sublabel">${os.SystemInfo?.ActivationStatus?.Status || 'Unknown'} • Installed ${Math.round(os.SystemInfo?.InstallAgeInDays || 0)} days ago</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" style="color: ${uptimeColor};">
                    ${os.SystemInfo?.SystemUptime ? `${os.SystemInfo.SystemUptime.Days}d ${os.SystemInfo.SystemUptime.Hours}h ${os.SystemInfo.SystemUptime.Minutes || 0}m` : 'Unknown'}
                </div>
                <div class="metric-label">System Uptime</div>
                <div class="metric-sublabel">Last Boot: ${formatNetDate(lastBootTime)} (${bootType})</div>
            </div>
        </div>
    `;

    const versionUptime = document.getElementById('osVersionUptimeContent');
    if (versionUptime) {
        versionUptime.innerHTML = versionUptimeHtml;
    }

    //----------------------------------------------------------------------------
    // 3. WINDOWS UPDATE STATUS (LEFT COLUMN) - ENHANCED
    //----------------------------------------------------------------------------

    if (os.WindowsUpdate) {
        const wu = os.WindowsUpdate;
        const kbNumber = wu.LastCumulativeUpdate?.KBNumber;
        const kbUrl = kbNumber ? `https://support.microsoft.com/help/${kbNumber.replace('KB', '')}` : '#';
        const daysSince = wu.DaysSinceLastCumulative || 0;
        const rebootDays = wu.RebootStatus?.DaysPending || 0;
        const pendingCount = wu.PendingUpdates?.CumulativeCount || 0;

        // Determine severity
        let severity = 'healthy';
        let severityIcon = '✅';
        let severityText = 'UP TO DATE';
        let severityColor = 'var(--success-color)';
        let riskLevel = 'Low Risk';
        let explanation = 'System is receiving regular security updates.';

        if (wu.RebootStatus?.Required && rebootDays > 30) {
            severity = 'critical';
            severityIcon = '🔴';
            severityText = 'SECURITY RISK';
            severityColor = 'var(--danger-color)';
            riskLevel = 'Critical Risk';
            explanation = `Security updates installed but NOT applied. System has been waiting ${rebootDays} days for restart. Vulnerabilities remain unpatched.`;
        } else if (daysSince > 90) {
            severity = 'critical';
            severityIcon = '🔴';
            severityText = 'SEVERELY OUTDATED';
            severityColor = 'var(--danger-color)';
            riskLevel = 'Critical Risk';
            explanation = `System has not received security updates in ${daysSince} days. Multiple vulnerabilities likely unpatched.`;
        } else if (wu.RebootStatus?.Required && rebootDays > 7) {
            severity = 'warning';
            severityIcon = '⚠️';
            severityText = 'RESTART OVERDUE';
            severityColor = 'var(--warning-color)';
            riskLevel = 'Moderate Risk';
            explanation = `Security updates installed ${rebootDays} days ago but require restart to apply. System is vulnerable.`;
        } else if (daysSince > 45) {
            severity = 'warning';
            severityIcon = '⚠️';
            severityText = 'UPDATES OVERDUE';
            severityColor = 'var(--warning-color)';
            riskLevel = 'Moderate Risk';
            explanation = `Last update was ${daysSince} days ago. Microsoft releases monthly updates. System may be missing patches.`;
        } else if (pendingCount > 0) {
            severity = 'info';
            severityIcon = 'ℹ️';
            severityText = 'UPDATES AVAILABLE';
            severityColor = 'var(--info-color)';
            riskLevel = 'Low Risk';
            explanation = `${pendingCount} update(s) ready to install. Schedule installation soon.`;
        } else if (wu.RebootStatus?.Required) {
            severity = 'info';
            severityIcon = 'ℹ️';
            severityText = 'RESTART NEEDED';
            severityColor = 'var(--info-color)';
            riskLevel = 'Low Risk';
            explanation = 'Updates installed recently. Restart to complete installation.';
        }

        // Update badge in header
        const badgeEl = document.getElementById('updateStatusBadge');
        if (badgeEl) {
            badgeEl.innerHTML = `<span class="status-badge status-${severity}">${severityText}</span>`;
        }

        let updateHtml = '<div>';

        // === STATUS HEADER ===
        updateHtml += `
            <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid ${severityColor}; margin-bottom: 20px;">
                <div style="font-size: 1.1rem; font-weight: bold; color: ${severityColor}; margin-bottom: 8px;">
                    ${severityIcon} ${severityText}
                </div>
                <div style="font-size: 0.95rem; color: var(--text-primary); margin-bottom: 10px;">
                    ${explanation}
                </div>
                <div style="padding: 8px; background: var(--bg-tertiary); border-radius: 4px; margin-top: 10px;">
                    <div style="font-size: 0.85rem; color: var(--text-secondary);">Security Risk Level</div>
                    <div style="font-size: 1.1rem; font-weight: 600; color: ${severityColor};">${riskLevel}</div>
                </div>
            </div>
        `;

        // === UPDATE METRICS ===
        updateHtml += `
            <div style="margin-bottom: 20px;">
                <h4 style="margin-bottom: 10px;">Update Status</h4>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;">
        `;

        // Days since last update
        updateHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${daysSince > 90 ? 'var(--danger-color)' : daysSince > 45 ? 'var(--warning-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${daysSince > 90 ? 'var(--danger-color)' : daysSince > 45 ? 'var(--warning-color)' : 'var(--success-color)'};">
                    ${daysSince}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Days Since Update</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    ${daysSince <= 30 ? '✓ Recent' : daysSince <= 60 ? 'Check soon' : 'Overdue'}
                </div>
            </div>
        `;

        // Pending updates
        updateHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${pendingCount > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${pendingCount > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                    ${pendingCount}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Pending Updates</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    ${pendingCount === 0 ? '✓ None' : 'Ready to install'}
                </div>
            </div>
        `;

        // Reboot status
        updateHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${wu.RebootStatus?.Required ? (rebootDays > 30 ? 'var(--danger-color)' : rebootDays > 7 ? 'var(--warning-color)' : 'var(--info-color)') : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${wu.RebootStatus?.Required ? (rebootDays > 30 ? 'var(--danger-color)' : rebootDays > 7 ? 'var(--warning-color)' : 'var(--info-color)') : 'var(--success-color)'};">
                    ${wu.RebootStatus?.Required ? rebootDays : '✓'}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Restart Status</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    ${wu.RebootStatus?.Required ? `${rebootDays} days pending` : 'Not required'}
                </div>
            </div>
        `;

        updateHtml += `
                </div>
            </div>
        `;

        // === LAST UPDATE DETAILS ===
        updateHtml += `
            <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; margin-bottom: 15px;">
                <h4 style="margin-bottom: 8px;">Last Installed Update</h4>
                <div style="font-size: 0.9rem;">
                    ${kbNumber ? `<strong><a href="${kbUrl}" target="_blank" rel="noopener noreferrer" style="color: var(--accent-color);">${kbNumber}</a></strong>` : '<strong>None Found</strong>'}<br>
                    ${wu.LastCumulativeUpdate?.Title ? `<span style="color: var(--text-secondary); font-size: 0.85rem;">${escapeHtml(wu.LastCumulativeUpdate.Title)}</span><br>` : ''}
                    <span style="color: var(--text-secondary); font-size: 0.85rem;">Installed: ${formatNetDate(wu.LastCumulativeUpdate?.InstalledOn) || 'Unknown'}</span>
                </div>
            </div>
        `;

        // === PENDING UPDATES LIST ===
        if (wu.PendingUpdates?.Updates && wu.PendingUpdates.Updates.length > 0) {
            updateHtml += `
                <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; margin-bottom: 15px; border-left: 3px solid var(--info-color);">
                    <h4 style="margin-bottom: 8px;">📦 Available Updates (${pendingCount})</h4>
                    <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
            `;

            wu.PendingUpdates.Updates.filter(u => u.IsCumulative).slice(0, 5).forEach(update => {
                const updateKbUrl = update.KBNumber ?
                    `https://support.microsoft.com/help/${update.KBNumber.replace('KB', '')}` : '#';
                updateHtml += `<li style="margin-bottom: 5px;">${update.KBNumber ? `<a href="${escapeHtml(updateKbUrl)}" target="_blank" rel="noopener noreferrer" style="color: var(--accent-color);">${escapeHtml(update.KBNumber)}</a> - ` : ''}${escapeHtml(update.Title || 'Update')}</li>`;
            });

            if (wu.PendingUpdates.Updates.length > 5) {
                updateHtml += `<li style="color: var(--text-secondary); font-style: italic;">+ ${wu.PendingUpdates.Updates.length - 5} more...</li>`;
            }

            updateHtml += `
                    </ul>
                </div>
            `;
        }

        // === ACTIONABLE RECOMMENDATIONS ===
        if (severity !== 'healthy') {
            updateHtml += `
                <div style="padding: 15px; background: var(--bg-tertiary); border-radius: 8px; border-left: 4px solid ${severityColor}; margin-bottom: 15px;">
                    <h4 style="margin-bottom: 10px;">🔧 Recommended Actions</h4>
            `;

            if (wu.RebootStatus?.Required && rebootDays > 30) {
                updateHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--danger-color);">Priority 1 - RESTART IMMEDIATELY:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>Security updates installed ${rebootDays} days ago are NOT active</li>
                            <li>System is vulnerable to known exploits until restarted</li>
                            <li>→ Schedule maintenance window and restart ASAP</li>
                            <li>→ If restart fails, check for stuck services or pending file operations</li>
                        </ul>
                    </div>
                `;
            } else if (daysSince > 90) {
                updateHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--danger-color);">Priority 1 - Install Updates Immediately:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>System is ${daysSince} days behind on security patches</li>
                            <li>→ Check Windows Update: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">Settings → Update & Security</code></li>
                            <li>→ If managed: Verify WSUS/Intune policy is working</li>
                            <li>→ Check disk space (need 10GB+ free on C: drive)</li>
                            <li>→ Run: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">wuauclt /detectnow</code> to force check</li>
                        </ul>
                    </div>
                `;
            } else if (wu.RebootStatus?.Required && rebootDays > 7) {
                updateHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--warning-color);">Priority 1 - Schedule Restart:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>Updates waiting ${rebootDays} days to be applied</li>
                            <li>→ Restart at end of business day</li>
                            <li>→ Save all work before restarting</li>
                        </ul>
                    </div>
                `;
            } else if (daysSince > 45) {
                updateHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--warning-color);">Priority 1 - Check Windows Update:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>Last update ${daysSince} days ago (Microsoft patches monthly)</li>
                            <li>→ Manually check for updates</li>
                            <li>→ If enterprise-managed, verify connection to update server</li>
                        </ul>
                    </div>
                `;
            } else if (pendingCount > 0) {
                updateHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--info-color);">Recommendation - Install Pending Updates:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>${pendingCount} update(s) ready to install</li>
                            <li>→ Schedule installation during maintenance window</li>
                            <li>→ Plan for restart after installation</li>
                        </ul>
                    </div>
                `;
            }

            updateHtml += `
                </div>
            `;
        }

        updateHtml += '</div>';

        document.getElementById('updateContent').innerHTML = updateHtml;
    }

    //----------------------------------------------------------------------------
    // 4. DISK SPACE FOR ALL DRIVES (LEFT COLUMN) - FROM HARDWARE DATA
    //----------------------------------------------------------------------------

    let diskSpaceHtml = '';
    if (hw?.Storage?.Devices && hw.Storage.Devices.length > 0) {
        diskSpaceHtml = '<div class="disk-list">';

        hw.Storage.Devices.forEach(device => {
            const deviceId = device.DeviceID || device.DriveLetter || device.Caption || 'Unknown';
            const totalGB = Number(device.SizeGB || device.TotalSizeGB || 0);
            const freeGB = Number(device.FreeSpaceGB || 0);
            const usedGB = Number(device.UsedSpaceGB || (totalGB - freeGB));
            const percentUsed = totalGB > 0 ? ((usedGB / totalGB) * 100) : 0;
            const percentFree = Number(device.PercentFree) || (100 - percentUsed);

            let gaugeClass = 'healthy';
            let statusText = '✓ Healthy';
            let statusColor = 'var(--success-color)';

            if (percentFree < 10) {
                gaugeClass = 'critical';
                statusText = '⚠️ Critical';
                statusColor = 'var(--danger-color)';
            } else if (percentFree < 20) {
                gaugeClass = 'warning';
                statusText = '⚠️ Low space';
                statusColor = 'var(--warning-color)';
            }

            const deviceType = device.MediaType || device.Type || '';
            const typeLabel = deviceType.includes('SSD') || deviceType.includes('Solid') ? 'SSD' :
                            deviceType.includes('HDD') || deviceType.includes('Fixed') ? 'HDD' :
                            deviceType.includes('Removable') ? 'Removable' : '';

            diskSpaceHtml += `
                <div class="disk-item">
                    <div class="disk-header">
                        <div>
                            <span class="disk-letter">${deviceId}</span>
                            ${typeLabel ? `<span style="font-size: 0.9rem; color: var(--text-secondary); margin-left: 8px;">${typeLabel}</span>` : ''}
                        </div>
                        <div class="disk-size">${totalGB.toFixed(0)} GB total</div>
                    </div>
                    <div class="disk-gauge-container">
                        <div class="disk-gauge-text">${percentUsed.toFixed(0)}% Used • ${freeGB.toFixed(1)} GB Free</div>
                        <div class="disk-gauge-fill ${gaugeClass}" style="width: ${percentUsed.toFixed(1)}%;"></div>
                    </div>
                    <div class="disk-details">
                        <span style="color: ${statusColor};">${statusText}</span> - ${freeGB.toFixed(1)} GB available
                    </div>
                </div>
            `;
        });

        diskSpaceHtml += '</div>';
    } else {
        diskSpaceHtml = '<div class="text-muted">No disk space data available</div>';
    }

    document.getElementById('osDiskSpaceContent').innerHTML = diskSpaceHtml;

    //----------------------------------------------------------------------------
    // 5. CRITICAL SERVICES (CENTER COLUMN)
    //----------------------------------------------------------------------------

    let servicesHtml = '';
    if (os.Services?.Services) {
        const criticalServices = os.Services.Services.filter(s => s.IsCritical);
        const runningCount = criticalServices.filter(s => s.Status === 'Running').length;
        const totalCount = criticalServices.length;
        const allRunning = runningCount === totalCount;
        const statusColor = allRunning ? 'var(--success-color)' : 'var(--danger-color)';

        // Collapsible summary with running count
        servicesHtml = `
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                <strong>Status:</strong>
                <span style="color: ${statusColor}; font-weight: 600;">
                    ${allRunning ? '✓' : '⚠'} Running: ${runningCount}/${totalCount}
                </span>
            </div>
            <details>
                <summary style="cursor: pointer; font-weight: 600; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 4px;">
                    View All Critical Services
                </summary>
                <div class="service-list" style="margin-top: 10px;">
        `;

        criticalServices.forEach(service => {
            const isRunning = service.Status === 'Running';
            const statusClass = isRunning ? 'running' : 'stopped';

            servicesHtml += `
                <div class="service-row">
                    <span class="service-name">${escapeHtml(service.DisplayName || service.Name)}</span>
                    <span class="status-badge status-${statusClass}">${escapeHtml(service.Status)}</span>
                </div>
            `;
        });

        servicesHtml += '</div></details>';
    } else {
        servicesHtml = '<div class="text-muted">No service data available</div>';
    }

    document.getElementById('servicesContent').innerHTML = servicesHtml;

    //----------------------------------------------------------------------------
    // 6. BOOT PERFORMANCE (CENTER COLUMN)
    //----------------------------------------------------------------------------

    let bootPerfHtml = '';
    if (os.BootPerformance) {
        const bp = os.BootPerformance;
        // LastBootDuration is in milliseconds, BootDurationSeconds would be in seconds
        let bootDuration = Number(bp.BootDurationSeconds || 0);
        if (bootDuration === 0 && bp.LastBootDuration) {
            // Convert milliseconds to seconds
            bootDuration = Number(bp.LastBootDuration) / 1000;
        }

        let durationColor = 'var(--success-color)';
        let durationText = 'Fast boot';

        // Convert seconds to minutes and seconds
        const bootMinutes = Math.floor(bootDuration / 60);
        const bootSeconds = Math.floor(bootDuration % 60);
        const bootDurationFormatted = bootMinutes > 0 ? `${bootMinutes}m ${bootSeconds}s` : `${bootSeconds}s`;

        if (bootDuration > 120) { // > 2 minutes
            durationColor = 'var(--danger-color)';
            durationText = 'Slow boot';
        } else if (bootDuration > 60) { // > 1 minute
            durationColor = 'var(--warning-color)';
            durationText = 'Moderate';
        }

        const bootMode = bp.BootMode || bp.FirmwareType || 'UEFI';
        const secureBootEnabled = bp.SecureBoot?.Enabled || bp.SecureBootEnabled || false;
        const bootTypeDisplay = bp.BootType || 'Normal';

        bootPerfHtml = `
            <div class="metric-grid">
                <div class="metric-card">
                    <div class="metric-value" style="color: ${durationColor};">${bootDurationFormatted}</div>
                    <div class="metric-label">Last Boot Duration</div>
                    <div class="metric-sublabel">${durationText}</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">${bootMode}</div>
                    <div class="metric-label">Boot Mode</div>
                    <div class="metric-sublabel">Secure Boot: ${secureBootEnabled ? 'Enabled' : 'Disabled'}</div>
                </div>
            </div>
            <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid var(--border-color);">
                <div style="font-size: 0.9rem; color: var(--text-secondary);">
                    <strong>Boot Type:</strong> ${bootTypeDisplay}<br>
                    ${bp.FastStartup !== undefined ? `<strong>Fast Startup:</strong> ${bp.FastStartup ? 'Enabled' : 'Disabled'}<br>` : ''}
                    ${bp.PostDuration ? `<strong>POST Time:</strong> ${Number(bp.PostDuration).toFixed(1)}s | ` : ''}${bp.OSInitDuration ? `<strong>OS Init:</strong> ${Number(bp.OSInitDuration).toFixed(1)}s` : ''}
                </div>
            </div>
        `;
    } else {
        bootPerfHtml = '<div class="text-muted">Boot performance data not available</div>';
    }

    document.getElementById('bootPerformanceContent').innerHTML = bootPerfHtml;

    //----------------------------------------------------------------------------
    // 7. SYSTEM FILE INTEGRITY (CENTER COLUMN)
    //----------------------------------------------------------------------------

    let integrityHtml = '';
    if (os.SystemIntegrity) {
        const si = os.SystemIntegrity;

        integrityHtml = '<div style="display: grid; gap: 12px;">';

        // SFC Status - Field names from PowerShell collector
        const sfcStatus = si.SFC?.Status || 'Unknown';
        const sfcBadge = sfcStatus === 'No integrity violations found' || sfcStatus === 'No issues found' || sfcStatus === 'Healthy' ? 'ok' :
                         sfcStatus === 'No recent scan results found' || sfcStatus === 'Unknown' || sfcStatus.includes('No recent SFC scan') ? 'warning' : 'error';
        const sfcDate = si.SFC?.LastScan;  // Will be null if no scan found
        const sfcDateDisplay = sfcDate ? formatNetDate(sfcDate) : 'Never';

        integrityHtml += `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong>System File Checker (SFC)</strong><br>
                    <span style="font-size: 0.85rem; color: var(--text-secondary);">Last Scan: ${sfcDateDisplay}</span>
                </div>
                <span class="status-badge status-${sfcBadge}">${escapeHtml(sfcStatus)}</span>
            </div>
        `;

        // DISM Status - Field names from PowerShell collector
        const dismStatus = si.DISM?.Status || 'Unknown';
        const dismBadge = dismStatus === 'Healthy' || dismStatus === 'No component store corruption' ? 'ok' :
                          dismStatus === 'No recent scan results found' || dismStatus === 'Unknown' ? 'warning' : 'error';
        const dismDate = si.DISM?.LastScan || 'Never';  // Corrected field name

        integrityHtml += `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong>DISM Component Health</strong><br>
                    <span style="font-size: 0.85rem; color: var(--text-secondary);">Last Check: ${formatNetDate(dismDate)}</span>
                </div>
                <span class="status-badge status-${dismBadge}">${dismStatus}</span>
            </div>
        `;

        // CBS.log Status - Get LastWriteTime from the CBS.log file (used by SFC and Windows Update)
        // Note: CBS.log is used by Windows Update, DISM, and SFC - not just SFC
        const cbsDate = si.SFC?.CBSLogLastModified;
        const cbsExists = cbsDate && cbsDate !== 'Never' && cbsDate !== 'Unknown';
        integrityHtml += `
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong>CBS.log Status</strong><br>
                    <span style="font-size: 0.85rem; color: var(--text-secondary);">Last Modified: ${cbsExists ? formatNetDate(cbsDate) : 'Unknown'}</span>
                </div>
                <span class="status-badge status-${cbsExists ? 'ok' : 'warning'}">${cbsExists ? 'Active' : 'Not Found'}</span>
            </div>
        `;

        integrityHtml += '</div>';
    } else {
        integrityHtml = '<div class="text-muted">System integrity data not available</div>';
    }

    document.getElementById('systemIntegrityContent').innerHTML = integrityHtml;

    //----------------------------------------------------------------------------
    // 8. RESOURCE UTILIZATION (RIGHT COLUMN) - FROM HARDWARE DATA
    //----------------------------------------------------------------------------

    let resourceHtml = '';
    if (hw) {
        resourceHtml = '<div style="display: grid; gap: 15px;">';

        // CPU Usage
        const cpuUsage = Number(hw.CPU?.CurrentUtilization || hw.CPU?.CurrentLoad || hw.Performance?.CPUUsage || 0);
        const cpu5min = Number(hw.CPU?.AverageUtilization5Min || hw.CPU?.AverageLoad5Min || cpuUsage);
        const cpu1hr = Number(hw.CPU?.AverageUtilization1Hr || hw.CPU?.AverageLoad1Hr || cpuUsage);
        let cpuClass = 'healthy';
        if (cpuUsage > 85) cpuClass = 'critical';
        else if (cpuUsage > 70) cpuClass = 'warning';

        resourceHtml += `
            <div>
                <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
                    <strong>CPU Usage</strong>
                    <span>${cpuUsage.toFixed(0)}%</span>
                </div>
                <div class="disk-gauge-container">
                    <div class="disk-gauge-fill ${cpuClass}" style="width: ${cpuUsage}%;"></div>
                </div>
                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                    Current: ${cpuUsage.toFixed(0)}% | 5-min avg: ${cpu5min.toFixed(0)}% | 1-hr avg: ${cpu1hr.toFixed(0)}%
                </div>
            </div>
        `;

        // Memory Usage
        const memTotal = Number(hw.Memory?.TotalGB || 0);
        const memUsed = Number(hw.Memory?.UsedGB || 0);
        const memFree = Number(hw.Memory?.AvailableGB || (memTotal - memUsed));
        const memPercent = memTotal > 0 ? ((memUsed / memTotal) * 100) : 0;
        const memCommitted = Number(hw.Memory?.CommittedGB || memUsed);
        const memCommitLimit = Number(hw.Memory?.CommitLimitGB || memTotal);
        let memClass = 'healthy';
        if (memPercent > 95) memClass = 'critical';
        else if (memPercent > 80) memClass = 'warning';

        resourceHtml += `
            <div>
                <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
                    <strong>Memory Usage</strong>
                    <span>${memUsed.toFixed(1)} GB / ${memTotal.toFixed(0)} GB (${memPercent.toFixed(0)}%)</span>
                </div>
                <div class="disk-gauge-container">
                    <div class="disk-gauge-fill ${memClass}" style="width: ${memPercent}%;"></div>
                </div>
                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                    Available: ${memFree.toFixed(1)} GB | Committed: ${memCommitted.toFixed(1)} GB / ${memCommitLimit.toFixed(1)} GB
                </div>
            </div>
        `;

        // Page File (Virtual Memory)
        const pfCurrent = Number(hw.Performance?.PageFile?.CurrentUsageMB || os.Performance?.PageFile?.CurrentUsageMB || 0);
        const pfTotal = Number(hw.Performance?.PageFile?.TotalSizeMB || os.Performance?.PageFile?.TotalSizeMB || 0);
        const pfPercent = pfTotal > 0 ? ((pfCurrent / pfTotal) * 100) : 0;
        const pfPeak = Number(hw.Performance?.PageFile?.PeakUsageMB || os.Performance?.PageFile?.PeakUsageMB || pfCurrent);
        let pfClass = 'healthy';
        if (pfPercent > 85) pfClass = 'warning';

        resourceHtml += `
            <div>
                <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
                    <strong>Page File (Virtual Memory)</strong>
                    <span>${(pfCurrent / 1024).toFixed(1)} GB / ${(pfTotal / 1024).toFixed(1)} GB (${pfPercent.toFixed(0)}%)</span>
                </div>
                <div class="disk-gauge-container">
                    <div class="disk-gauge-fill ${pfClass}" style="width: ${pfPercent}%;"></div>
                </div>
                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                    Peak Usage: ${(pfPeak / 1024).toFixed(1)} GB | Location: C:\\pagefile.sys
                </div>
            </div>
        `;

        resourceHtml += '</div>';
    } else {
        resourceHtml = '<div class="text-muted">Resource utilization data not available (Hardware data missing)</div>';
    }

    document.getElementById('osResourceUtilizationContent').innerHTML = resourceHtml;

    //----------------------------------------------------------------------------
    // 9. STABILITY METRICS (RIGHT COLUMN) - ENHANCED
    //----------------------------------------------------------------------------

    let stabilityHtml = '';
    if (os.Stability || os.EventLogAnalysis) {
        const bsodCount = os.Stability?.BlueScreenEvents7Days || 0;
        const unexpectedShutdowns = os.Stability?.UnexpectedShutdowns?.length || 0;
        const criticalErrors = os.EventLogAnalysis?.CriticalErrors || 0;
        const reliabilityIndex = Number(os.Stability?.ReliabilityIndex || 0);
        const appCrashes = os.EventLogAnalysis?.ApplicationCrashes || 0;
        const serviceFailures = os.EventLogAnalysis?.ServiceFailures || 0;

        // Determine overall health status
        let healthStatus = 'Unknown';
        let healthIcon = '❓';
        let healthColor = 'var(--text-muted)';

        if (reliabilityIndex > 0) {
            if (reliabilityIndex >= 7) {
                healthStatus = 'STABLE';
                healthIcon = '✅';
                healthColor = 'var(--success-color)';
            } else if (reliabilityIndex >= 4) {
                healthStatus = 'UNSTABLE';
                healthIcon = '⚠️';
                healthColor = 'var(--warning-color)';
            } else {
                healthStatus = 'CRITICAL INSTABILITY';
                healthIcon = '🔴';
                healthColor = 'var(--danger-color)';
            }
        }

        // Build the enhanced stability display
        stabilityHtml = '<div>';

        // === WINDOWS RELIABILITY INDEX (SEPARATE SECTION) ===
        stabilityHtml += `
            <div style="padding: 18px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid ${healthColor}; margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 15px;">
                    <div style="flex: 1;">
                        <div style="font-size: 0.95rem; font-weight: 600; color: var(--text-secondary); margin-bottom: 8px;">
                            📊 WINDOWS RELIABILITY INDEX
                        </div>
                        <div style="display: flex; align-items: baseline; gap: 10px; margin-bottom: 8px;">
                            <div style="font-size: 2.5rem; font-weight: bold; color: ${getReliabilityColor(reliabilityIndex)};">
                                ${reliabilityIndex > 0 ? reliabilityIndex.toFixed(1) : 'N/A'}
                            </div>
                            <div style="font-size: 1.2rem; color: var(--text-secondary);">/10</div>
                            <div style="font-size: 1.1rem; font-weight: bold; color: ${healthColor}; margin-left: 10px;">
                                ${healthIcon} ${healthStatus}
                            </div>
                        </div>
                    </div>
                </div>

                <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 12px;">
                    <div style="font-size: 0.9rem; line-height: 1.6; color: var(--text-primary);">
                        ${reliabilityIndex >= 7 ?
                            '✓ System is operating normally with minimal stability issues.' :
                          reliabilityIndex >= 4 ?
                            '⚠️ System is experiencing stability issues that require investigation.' :
                          reliabilityIndex > 0 ?
                            '🔴 System has serious stability problems requiring immediate attention.' :
                            'Unable to calculate reliability index.'}
                    </div>
                </div>

                <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid var(--info-color);">
                    <div style="font-size: 0.85rem; line-height: 1.7; color: var(--text-secondary);">
                        <strong style="color: var(--info-color);">ℹ️ About this score:</strong><br>
                        This is Windows' built-in stability calculation based on the <strong>last 30 days</strong> of crashes, errors, and failures.
                        Our report shows only the <strong>last 7 days</strong> of events for performance reasons.
                        <div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--border-color);">
                            <strong>🔍 To see the full 30-day breakdown:</strong><br>
                            Run <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px; font-size: 0.9em;">perfmon /rel</code>
                            (or Start → type "Reliability Monitor")
                        </div>
                    </div>
                </div>
            </div>
        `;

        // === RECENT STABILITY EVENTS (7 DAYS ONLY) ===
        const hasIssues = bsodCount > 0 || unexpectedShutdowns > 0 || criticalErrors > 0 || appCrashes > 0 || serviceFailures > 0;

        stabilityHtml += `
            <div style="margin-bottom: 20px;">
                <h4 style="margin-bottom: 8px;">Recent Stability Events <span style="font-weight: normal; color: var(--text-secondary); font-size: 0.9rem;">(Last 7 Days Only)</span></h4>
                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 12px;">
                    These events show recent system stability. They may or may not explain the 30-day Reliability Index above.
                </div>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;">
        `;

        // Blue Screens
        stabilityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${bsodCount > 0 ? 'var(--danger-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${bsodCount > 0 ? 'var(--danger-color)' : 'var(--success-color)'};">
                    ${bsodCount}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Blue Screens (BSODs)</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    ${bsodCount === 0 ? '✓ No crashes detected' : 'Critical system crashes'}
                </div>
            </div>
        `;

        // Unexpected Shutdowns
        stabilityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${unexpectedShutdowns > 0 ? 'var(--warning-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${unexpectedShutdowns > 0 ? 'var(--warning-color)' : 'var(--success-color)'};">
                    ${unexpectedShutdowns}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Unexpected Shutdowns</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    ${unexpectedShutdowns === 0 ? '✓ Normal shutdowns only' : 'Event ID 6008'}
                </div>
            </div>
        `;

        // Critical Errors
        stabilityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${criticalErrors > 10 ? 'var(--warning-color)' : criticalErrors > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${criticalErrors > 10 ? 'var(--warning-color)' : criticalErrors > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                    ${criticalErrors}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">Critical Errors (7 days)</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    System event log
                </div>
            </div>
        `;

        // Application Crashes
        stabilityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${appCrashes > 5 ? 'var(--warning-color)' : appCrashes > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                <div style="font-size: 1.5rem; font-weight: bold; color: ${appCrashes > 5 ? 'var(--warning-color)' : appCrashes > 0 ? 'var(--info-color)' : 'var(--success-color)'};">
                    ${appCrashes}
                </div>
                <div style="font-size: 0.85rem; font-weight: 600;">App Crashes (7 days)</div>
                <div style="font-size: 0.75rem; color: var(--text-secondary);">
                    Event ID 1000
                </div>
            </div>
        `;

        stabilityHtml += `
                </div>
        `;

        // === SUMMARY OF RECENT EVENTS ===
        if (hasIssues) {
            stabilityHtml += `
                <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; border-left: 3px solid var(--warning-color); margin-top: 10px;">
                    <div style="font-size: 0.9rem; color: var(--text-primary);">
                        ⚠️ <strong>Recent problems detected</strong> - These events likely contribute to the Reliability Index score.
                    </div>
                </div>
            `;
        } else {
            stabilityHtml += `
                <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; border-left: 3px solid var(--success-color); margin-top: 10px;">
                    <div style="font-size: 0.9rem; color: var(--text-primary);">
                        ✓ <strong>No stability events in the last 7 days.</strong>
                        ${reliabilityIndex > 0 && reliabilityIndex < 7 ?
                            ' If the Reliability Index above is low, problems occurred 8-30 days ago.' :
                            ''}
                    </div>
                </div>
            `;
        }

        stabilityHtml += `
            </div>
        `;

        // === STABILITY EVENTS TIMELINE ===
        if (os.Stability?.UnexpectedShutdowns && os.Stability.UnexpectedShutdowns.length > 0) {
            stabilityHtml += `
                <div style="margin-bottom: 20px; padding: 15px; background: var(--bg-secondary); border-radius: 8px;">
                    <h4 style="margin-bottom: 10px;">⚠️ Recent Unexpected Shutdowns</h4>
                    <div style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 10px;">
                        These events indicate the system was not shut down properly:
                    </div>
            `;

            os.Stability.UnexpectedShutdowns.forEach((shutdown, index) => {
                const timeStr = shutdown.TimeCreated ? formatNetDate(shutdown.TimeCreated, 'Unknown time') : 'Unknown time';
                const msgPreview = shutdown.Message ? escapeHtml(shutdown.Message.substring(0, 100)) : 'No details available';

                stabilityHtml += `
                    <div style="padding: 8px; background: var(--bg-tertiary); border-radius: 4px; margin-bottom: 6px; border-left: 3px solid var(--warning-color);">
                        <div style="font-size: 0.9rem; font-weight: 600;">${timeStr}</div>
                        <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 3px;">${msgPreview}</div>
                    </div>
                `;
            });

            stabilityHtml += `
                </div>
            `;
        }

        // === ACTIONABLE RECOMMENDATIONS ===
        if (hasIssues) {
            stabilityHtml += `
                <div style="margin-bottom: 20px; padding: 15px; background: var(--bg-tertiary); border-radius: 8px; border-left: 4px solid var(--info-color);">
                    <h4 style="margin-bottom: 10px;">🔧 Recommended Actions</h4>
            `;

            let priority = 1;

            // Recommendation for unexpected shutdowns
            if (unexpectedShutdowns > 0) {
                stabilityHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--warning-color);">Priority ${priority++} - Investigate Power/Shutdown Issues:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>${unexpectedShutdowns} unexpected shutdown${unexpectedShutdowns > 1 ? 's' : ''} detected - possible causes:</li>
                            <ul style="margin-left: 15px; font-size: 0.85rem; color: var(--text-secondary);">
                                <li>Power supply failure or unstable power</li>
                                <li>Overheating (check Hardware tab → Temperatures)</li>
                                <li>Driver crash without BSOD (check Drivers tab)</li>
                                <li>Manual power button/reset usage</li>
                            </ul>
                            <li style="margin-top: 5px;">→ Check Windows Reliability Monitor: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">perfmon /rel</code></li>
                        </ul>
                    </div>
                `;
            }

            // Recommendation for BSODs
            if (bsodCount > 0) {
                stabilityHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--danger-color);">Priority ${priority++} - Investigate Blue Screen Crashes:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>${bsodCount} BSOD${bsodCount > 1 ? 's' : ''} detected in last 7 days</li>
                            <li>→ Check minidump files: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">C:\\Windows\\Minidump\\</code></li>
                            <li>→ See Events tab → System Log for BugCheck details</li>
                            <li>→ Update drivers and check for hardware issues</li>
                        </ul>
                    </div>
                `;
            }

            // Recommendation for critical errors
            if (criticalErrors > 10) {
                stabilityHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--warning-color);">Priority ${priority++} - Review Critical System Errors:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>${criticalErrors} critical events in last 7 days</li>
                            <li>→ See Events tab for detailed analysis and patterns</li>
                            <li>→ Check for failing services or hardware issues</li>
                        </ul>
                    </div>
                `;
            }

            // Recommendation for app crashes
            if (appCrashes > 5) {
                stabilityHtml += `
                    <div style="margin-bottom: 12px;">
                        <div style="font-weight: 600; color: var(--info-color);">Priority ${priority++} - Investigate Application Crashes:</div>
                        <ul style="margin: 5px 0 0 20px; font-size: 0.9rem;">
                            <li>${appCrashes} application crashes in last 7 days</li>
                            <li>→ See Software tab → Recent Crashes for details</li>
                            <li>→ Update or reinstall problematic applications</li>
                        </ul>
                    </div>
                `;
            }

            stabilityHtml += `
                </div>
            `;
        }

        // === CROSS-REFERENCES ===
        stabilityHtml += `
            <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; border-left: 3px solid var(--info-color);">
                <div style="font-weight: 600; margin-bottom: 8px;">🔗 Related Diagnostics</div>
                <div style="display: flex; flex-direction: column; gap: 6px; font-size: 0.9rem;">
                    <a href="#" class="cross-ref" onclick="switchTab('events'); return false;">
                        → Events Tab: Complete event log analysis
                    </a>
                    <a href="#" class="cross-ref" onclick="switchTab('drivers'); return false;">
                        → Drivers Tab: Check for problem devices
                    </a>
                    <a href="#" class="cross-ref" onclick="switchTab('hardware'); return false;">
                        → Hardware Tab: Review temperatures and disk health
                    </a>
                </div>
            </div>
        `;

        stabilityHtml += '</div>';
    } else {
        stabilityHtml = '<div class="text-muted">Stability metrics not available</div>';
    }

    document.getElementById('osStabilityMetricsContent').innerHTML = stabilityHtml;

    //----------------------------------------------------------------------------
    // 10. CROSS-TAB ALERTS (RIGHT COLUMN)
    //----------------------------------------------------------------------------

    let crossTabHtml = '';
    const problemDeviceCount = systemData.Drivers?.ProblemDeviceCount || 0;
    const appCrashes = systemData.Software?.RecentCrashes?.length || 0;

    if (problemDeviceCount > 0 || appCrashes > 0 || true) { // Always show for navigation
        crossTabHtml = `
            <div class="alert alert-info">
                <strong>🔗 Related Information</strong>
                <div style="margin-top: 10px; display: flex; flex-direction: column; gap: 8px;">
        `;

        if (problemDeviceCount > 0) {
            crossTabHtml += `
                <a href="#" class="cross-ref" onclick="switchTab('drivers'); return false;">
                    ⚠️ See Drivers tab: ${problemDeviceCount} problem device${problemDeviceCount > 1 ? 's' : ''} detected
                </a>
            `;
        }

        crossTabHtml += `
            <a href="#" class="cross-ref" onclick="switchTab('hardware'); return false;">
                💾 See Hardware tab: Full disk and memory details
            </a>
        `;

        if (appCrashes > 0) {
            crossTabHtml += `
                <a href="#" class="cross-ref" onclick="switchTab('software'); return false;">
                    📦 See Software tab: ${appCrashes} application crash${appCrashes > 1 ? 'es' : ''} this week
                </a>
            `;
        }

        crossTabHtml += `
                </div>
            </div>
        `;
    }

    document.getElementById('osCrossTabAlerts').innerHTML = crossTabHtml;

    // ============================================================================
    // TIER 2: DIAGNOSTIC DETAIL - EXPANDABLE SECTIONS
    // ============================================================================

    //----------------------------------------------------------------------------
    // 11. SECURITY STATUS - ENHANCED
    //----------------------------------------------------------------------------

    let securityHtml = '';
    if (os.Security) {
        const sec = os.Security;

        // Analyze security posture
        const defenderEnabled = sec.WindowsDefender?.Enabled || false;
        const domainFW = sec.Firewall?.DomainProfile?.value === 1 || sec.Firewall?.DomainProfile?.Value === 'True';
        const privateFW = sec.Firewall?.PrivateProfile?.value === 1 || sec.Firewall?.PrivateProfile?.Value === 'True';
        const publicFW = sec.Firewall?.PublicProfile?.value === 1 || sec.Firewall?.PublicProfile?.Value === 'True';
        const allFWEnabled = domainFW && privateFW && publicFW;
        const bitlockerOn = sec.BitLocker?.ProtectionStatus === 'On';
        const secureBoot = sec.SecureBoot?.Enabled || false;

        const securityIssues = [];
        const securityWarnings = [];

        if (!defenderEnabled) {
            securityIssues.push({
                title: 'Windows Defender Disabled',
                severity: 'critical',
                description: 'Real-time antivirus protection is OFF. System is vulnerable to malware.',
                recommendation: 'Enable Windows Defender immediately OR verify third-party antivirus is active'
            });
        }

        if (!allFWEnabled) {
            securityWarnings.push({
                title: 'Firewall Not Fully Enabled',
                severity: 'warning',
                description: `Firewall disabled on some network profiles. System may be exposed to network attacks.`,
                recommendation: 'Enable firewall on all profiles (Domain, Private, Public)'
            });
        }

        if (!secureBoot) {
            securityWarnings.push({
                title: 'Secure Boot Disabled',
                severity: 'warning',
                description: 'Secure Boot is disabled. System may be vulnerable to rootkits and boot-level malware.',
                recommendation: 'Enable Secure Boot in UEFI/BIOS settings (if supported by hardware)'
            });
        }

        // Overall security posture
        let securityRisk = 'Low';
        let securityColor = 'var(--success-color)';
        let securityIcon = '✅';
        let securityStatus = 'PROTECTED';

        if (securityIssues.length > 0) {
            securityRisk = 'Critical';
            securityColor = 'var(--danger-color)';
            securityIcon = '🔴';
            securityStatus = 'UNPROTECTED';
        } else if (securityWarnings.length > 0) {
            securityRisk = 'Moderate';
            securityColor = 'var(--warning-color)';
            securityIcon = '⚠️';
            securityStatus = 'PARTIALLY PROTECTED';
        }

        securityHtml = '<div>';

        // === SECURITY POSTURE HEADER ===
        securityHtml += `
            <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid ${securityColor}; margin-bottom: 20px;">
                <div style="font-size: 1.1rem; font-weight: bold; color: ${securityColor}; margin-bottom: 8px;">
                    ${securityIcon} SECURITY STATUS: ${securityStatus}
                </div>
                <div style="font-size: 0.95rem; color: var(--text-primary); margin-bottom: 10px;">
                    ${securityRisk === 'Critical' ?
                        'Critical security protections are disabled. System is at high risk of infection.' :
                        securityRisk === 'Moderate' ?
                        'Some security features need attention. System has basic protection but could be improved.' :
                        'Core security features are enabled and functioning properly.'}
                </div>
                <div style="padding: 8px; background: var(--bg-tertiary); border-radius: 4px;">
                    <div style="font-size: 0.85rem; color: var(--text-secondary);">Threat Risk Level</div>
                    <div style="font-size: 1.1rem; font-weight: 600; color: ${securityColor};">${securityRisk} Risk</div>
                </div>
            </div>
        `;

        // === SECURITY COMPONENTS STATUS ===
        securityHtml += `
            <div style="margin-bottom: 20px;">
                <h4 style="margin-bottom: 10px;">Security Components</h4>
                <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;">
        `;

        // Windows Defender
        securityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${defenderEnabled ? 'var(--success-color)' : 'var(--danger-color)'};">
                <div style="font-weight: 600; margin-bottom: 4px;">🛡️ Windows Defender</div>
                <div style="color: ${defenderEnabled ? 'var(--success-color)' : 'var(--danger-color)'}; font-weight: 600;">
                    ${defenderEnabled ? '✓ Enabled' : '🔴 DISABLED'}
                </div>
                <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                    ${defenderEnabled ? 'Real-time protection active' : 'NO antivirus protection'}
                </div>
            </div>
        `;

        // Firewall
        securityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${allFWEnabled ? 'var(--success-color)' : 'var(--warning-color)'};">
                <div style="font-weight: 600; margin-bottom: 4px;">🔥 Firewall</div>
                <div style="color: ${allFWEnabled ? 'var(--success-color)' : 'var(--warning-color)'}; font-weight: 600;">
                    ${allFWEnabled ? '✓ All Profiles On' : '⚠️ Partial Protection'}
                </div>
                <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                    Domain: ${domainFW ? 'On' : 'Off'} | Private: ${privateFW ? 'On' : 'Off'} | Public: ${publicFW ? 'On' : 'Off'}
                </div>
            </div>
        `;

        // Secure Boot
        securityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${secureBoot ? 'var(--success-color)' : 'var(--text-muted)'};">
                <div style="font-weight: 600; margin-bottom: 4px;">🔒 Secure Boot</div>
                <div style="color: ${secureBoot ? 'var(--success-color)' : 'var(--text-muted)'}; font-weight: 600;">
                    ${secureBoot ? '✓ Enabled' : 'Disabled'}
                </div>
                <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                    ${secureBoot ? 'Boot-level protection active' : 'Optional security feature'}
                </div>
            </div>
        `;

        // BitLocker
        const bitlockerStatus = sec.BitLocker?.ProtectionStatus || 'Off';
        securityHtml += `
            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; border-left: 3px solid ${bitlockerOn ? 'var(--success-color)' : 'var(--text-muted)'};">
                <div style="font-weight: 600; margin-bottom: 4px;">🔐 BitLocker (C:)</div>
                <div style="color: ${bitlockerOn ? 'var(--success-color)' : 'var(--text-muted)'}; font-weight: 600;">
                    ${bitlockerOn ? '✓ Encrypted' : escapeHtml(bitlockerStatus)}
                </div>
                <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                    ${bitlockerOn ? 'Drive encryption active' : 'Optional data protection'}
                </div>
            </div>
        `;

        securityHtml += `
                </div>
            </div>
        `;

        // === CRITICAL SECURITY ISSUES ===
        if (securityIssues.length > 0) {
            securityHtml += `
                <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid var(--danger-color); margin-bottom: 20px;">
                    <h4 style="margin-bottom: 10px; color: var(--danger-color);">🚨 Critical Security Issues</h4>
            `;

            securityIssues.forEach(issue => {
                securityHtml += `
                    <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 10px;">
                        <div style="font-weight: 600; color: var(--danger-color); margin-bottom: 6px;">
                            ${escapeHtml(issue.title)}
                        </div>
                        <div style="font-size: 0.9rem; margin-bottom: 8px;">
                            <strong>Risk:</strong> ${escapeHtml(issue.description)}
                        </div>
                        <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px; border-left: 3px solid var(--info-color);">
                            <strong style="color: var(--info-color);">🔧 Action Required:</strong><br>
                            <span style="font-size: 0.9rem;">${escapeHtml(issue.recommendation)}</span>
                        </div>
                    </div>
                `;
            });

            securityHtml += '</div>';
        }

        // === SECURITY WARNINGS ===
        if (securityWarnings.length > 0) {
            securityHtml += `
                <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid var(--warning-color); margin-bottom: 20px;">
                    <h4 style="margin-bottom: 10px; color: var(--warning-color);">⚠️ Security Recommendations</h4>
            `;

            securityWarnings.forEach(warning => {
                securityHtml += `
                    <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 10px;">
                        <div style="font-weight: 600; color: var(--warning-color); margin-bottom: 6px;">
                            ${escapeHtml(warning.title)}
                        </div>
                        <div style="font-size: 0.9rem; margin-bottom: 8px;">
                            ${escapeHtml(warning.description)}
                        </div>
                        <div style="font-size: 0.85rem; color: var(--text-secondary);">
                            💡 ${escapeHtml(warning.recommendation)}
                        </div>
                    </div>
                `;
            });

            securityHtml += '</div>';
        }

        // === HOW TO FIX ===
        if (securityIssues.length > 0 || securityWarnings.length > 0) {
            securityHtml += `
                <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid var(--info-color);">
                    <h4 style="margin-bottom: 10px;">🛠️ How to Fix Security Issues</h4>
                    <ol style="margin: 5px 0 0 20px; font-size: 0.9rem; line-height: 1.8;">
            `;

            if (!defenderEnabled) {
                securityHtml += `
                    <li><strong>Enable Windows Defender:</strong>
                        <ul style="margin-left: 15px; font-size: 0.85rem;">
                            <li>Open Windows Security: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">Start → Settings → Update & Security → Windows Security</code></li>
                            <li>Go to "Virus & threat protection"</li>
                            <li>Turn on "Real-time protection"</li>
                            <li>If disabled by policy, check Group Policy or contact IT admin</li>
                            <li>If third-party AV installed, verify it's active and updated</li>
                        </ul>
                    </li>
                `;
            }

            if (!allFWEnabled) {
                securityHtml += `
                    <li><strong>Enable Firewall:</strong>
                        <ul style="margin-left: 15px; font-size: 0.85rem;">
                            <li>Open: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">Control Panel → System and Security → Windows Defender Firewall</code></li>
                            <li>Click "Turn Windows Defender Firewall on or off"</li>
                            <li>Enable for all network types (Domain, Private, Public)</li>
                        </ul>
                    </li>
                `;
            }

            if (!secureBoot) {
                securityHtml += `
                    <li><strong>Enable Secure Boot (Optional but Recommended):</strong>
                        <ul style="margin-left: 15px; font-size: 0.85rem;">
                            <li>Restart computer and enter UEFI/BIOS (usually press F2, F10, DEL, or ESC during boot)</li>
                            <li>Find "Secure Boot" setting (usually in Security or Boot tab)</li>
                            <li>Enable Secure Boot</li>
                            <li>Save and exit</li>
                            <li>Note: Requires UEFI firmware (not available on legacy BIOS systems)</li>
                        </ul>
                    </li>
                `;
            }

            securityHtml += `
                    </ol>
                </div>
            `;
        } else {
            // All secure
            securityHtml += `
                <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid var(--success-color);">
                    <div style="font-size: 0.95rem;">
                        <strong style="color: var(--success-color);">✓ Security Configuration Optimal</strong><br>
                        <span style="color: var(--text-secondary); font-size: 0.85rem;">
                            Core security features are properly configured. Continue regular Windows Updates and antivirus definition updates to maintain protection.
                        </span>
                    </div>
                </div>
            `;
        }

        securityHtml += '</div>';
    } else {
        securityHtml = '<div class="text-muted">Security data not available</div>';
    }

    document.getElementById('securityContent').innerHTML = securityHtml;

    //----------------------------------------------------------------------------
    // 12. WINDOWS FEATURES
    //----------------------------------------------------------------------------

    let featuresHtml = '';
    const wf = os.WindowsFeatures;

    if (wf) {
        // Summary statistics
        featuresHtml = `
            <div class="metric-grid" style="margin-bottom: 20px;">
                <div class="metric-card">
                    <div class="metric-value">${wf.TotalFeatures || 0}</div>
                    <div class="metric-label">Total Features</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value" style="color: var(--success-color);">${wf.EnabledCount || 0}</div>
                    <div class="metric-label">Enabled</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">${wf.DisabledCount || 0}</div>
                    <div class="metric-label">Disabled</div>
                </div>
            </div>
        `;

        // Security warnings
        if (wf.SecurityConcerns && wf.SecurityConcerns.length > 0) {
            featuresHtml += '<div class="alert alert-warning" style="margin-bottom: 15px;"><strong>⚠️ Security Concerns:</strong><ul style="margin: 10px 0 0 20px;">';
            wf.SecurityConcerns.forEach(concern => {
                featuresHtml += `<li>${escapeHtml(concern)}</li>`;
            });
            featuresHtml += '</ul></div>';
        }

        // Show all enabled features (simple, clean list)
        if (wf.EnabledFeatures && wf.EnabledFeatures.length > 0) {
            featuresHtml += '<div style="margin-bottom: 15px;"><strong>Enabled Features:</strong></div>';
            featuresHtml += '<table><thead><tr><th>Feature Name</th></tr></thead><tbody>';

            wf.EnabledFeatures.forEach(feature => {
                featuresHtml += `
                    <tr>
                        <td style="font-size: 0.95rem;">${escapeHtml(feature.FeatureName)}</td>
                    </tr>
                `;
            });
            featuresHtml += '</tbody></table>';
        } else {
            featuresHtml += '<div style="margin-top: 15px; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 4px;">No Windows optional features are currently enabled</div>';
        }

    } else {
        featuresHtml = '<div class="text-muted">Windows Features data not available</div>';
    }

    document.getElementById('windowsFeaturesContent').innerHTML = featuresHtml;

    //----------------------------------------------------------------------------
    // 13. USER PROFILE INFORMATION
    //----------------------------------------------------------------------------

    let profileHtml = '';
    if (os.AllUserProfiles?.Profiles) {
        const currentProfile = os.AllUserProfiles.Profiles.find(p => p.LoadMethod === 'CurrentUser' || p.IsLoaded);

        if (currentProfile) {
            profileHtml = '<div class="info-grid">';

            profileHtml += `
                <div class="info-item">
                    <span class="info-label">Current User</span>
                    <span class="info-value">${escapeHtml(currentProfile.UserName || 'Unknown')}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Profile Type</span>
                    <span class="info-value">${escapeHtml(currentProfile.ProfileType || 'Unknown')}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Profile Path</span>
                    <span class="info-value" style="font-size: 0.85rem;">${escapeHtml(currentProfile.ProfilePath || 'Unknown')}</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Profile Size</span>
                    <span class="info-value">${currentProfile.ProfileSizeGB || 0} GB</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Profile Status</span>
                    <span class="info-value"><span class="status-badge status-${currentProfile.IsTemporary ? 'error' : 'ok'}">${currentProfile.IsTemporary ? 'TEMPORARY' : 'Loaded'}</span></span>
                </div>
                <div class="info-item">
                    <span class="info-label">Last Use</span>
                    <span class="info-value">${formatNetDate(currentProfile.LastUseTime)}</span>
                </div>
            `;

            profileHtml += '</div>';

            if (currentProfile.IsTemporary) {
                profileHtml += '<div class="alert alert-critical" style="margin-top: 15px;"><strong>⚠️ WARNING:</strong> Temporary profile detected! User data will be lost on logout.</div>';
            }
        } else {
            profileHtml = '<div class="text-muted">No current user profile found</div>';
        }
    } else {
        profileHtml = '<div class="text-muted">User profile data not available</div>';
    }

    document.getElementById('userProfileContent').innerHTML = profileHtml;

    //----------------------------------------------------------------------------
    // 14. WINDOWS ACTIVATION
    //----------------------------------------------------------------------------

    let activationHtml = '';
    if (os.SystemInfo?.ActivationStatus) {
        const act = os.SystemInfo.ActivationStatus;
        activationHtml = '<div class="info-grid">';

        activationHtml += `
            <div class="info-item">
                <span class="info-label">Activation Status</span>
                <span class="info-value"><span class="status-badge status-${act.Status === 'Licensed' ? 'ok' : 'warning'}">${escapeHtml(act.Status || 'Unknown')}</span></span>
            </div>
            <div class="info-item">
                <span class="info-label">License Type</span>
                <span class="info-value">${escapeHtml(act.LicenseType || act.Description || 'Unknown')}</span>
            </div>
        `;

        if (act.ProductKey) {
            const lastFive = act.ProductKey.slice(-5);
            activationHtml += `
                <div class="info-item">
                    <span class="info-label">Product Key (Last 5)</span>
                    <span class="info-value">XXXXX-XXXXX-XXXXX-XXXXX-${lastFive}</span>
                </div>
            `;
        }

        activationHtml += '</div>';
    } else {
        activationHtml = '<div class="text-muted">Activation data not available</div>';
    }

    document.getElementById('activationContent').innerHTML = activationHtml;

    //----------------------------------------------------------------------------
    // 15. LOCALE & REGIONAL SETTINGS
    //----------------------------------------------------------------------------

    let localeHtml = '';
    if (os.SystemInfo) {
        localeHtml = '<div class="info-grid">';

        localeHtml += `
            <div class="info-item">
                <span class="info-label">System Locale</span>
                <span class="info-value">${escapeHtml(os.SystemInfo.Locale || os.SystemInfo.Language || 'Unknown')}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Time Zone</span>
                <span class="info-value">${escapeHtml(os.SystemInfo.TimeZone || 'Unknown')}</span>
            </div>
        `;

        if (os.SystemInfo.KeyboardLayout) {
            localeHtml += `
                <div class="info-item">
                    <span class="info-label">Keyboard Layout</span>
                    <span class="info-value">${escapeHtml(os.SystemInfo.KeyboardLayout)}</span>
                </div>
            `;
        }

        localeHtml += '</div>';
    } else {
        localeHtml = '<div class="text-muted">Locale data not available</div>';
    }

    document.getElementById('localeContent').innerHTML = localeHtml;

    //----------------------------------------------------------------------------
    // 16. DOMAIN & AUTHENTICATION - Reuse existing function
    //----------------------------------------------------------------------------

    loadDomainAuthSection(os);

    // ============================================================================
    // TIER 3: ADVANCED - COLLAPSED BY DEFAULT
    // ============================================================================

    //----------------------------------------------------------------------------
    // 17. RELIABILITY MONITOR & EVENT ANALYSIS
    //----------------------------------------------------------------------------

    let reliabilityHtml = '';
    if (os.EventLogAnalysis) {
        const ela = os.EventLogAnalysis;

        reliabilityHtml = '<div>';

        // Event summary
        reliabilityHtml += `
            <div style="margin-bottom: 20px;">
                <h4>Event Log Summary (Last 7 Days)</h4>
                <div class="metric-grid" style="margin-top: 10px;">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${(ela.CriticalCount || 0) > 0 ? 'var(--danger-color)' : 'var(--success-color)'};">${ela.CriticalCount || 0}</div>
                        <div class="metric-label">Critical Events</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${(ela.ErrorCount || 0) > 10 ? 'var(--warning-color)' : 'var(--success-color)'};">${ela.ErrorCount || 0}</div>
                        <div class="metric-label">Error Events</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${ela.WarningCount || 0}</div>
                        <div class="metric-label">Warning Events</div>
                    </div>
                </div>
            </div>
        `;

        // Top event IDs
        if (ela.TopEventIDs && ela.TopEventIDs.length > 0) {
            reliabilityHtml += `
                <div>
                    <h4>Most Frequent Event IDs</h4>
                    <div style="margin-top: 10px;">
            `;

            ela.TopEventIDs.slice(0, 5).forEach(event => {
                reliabilityHtml += `
                    <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 8px;">
                        <strong>Event ID ${event.ID || event.EventID}</strong> (${event.Count || 0} occurrences)<br>
                        <span style="font-size: 0.9rem; color: var(--text-secondary);">${escapeHtml(event.Description || event.Message || 'No description')}</span>
                    </div>
                `;
            });

            reliabilityHtml += '</div></div>';
        }

        reliabilityHtml += '</div>';
    } else {
        reliabilityHtml = '<div class="text-muted">Event log analysis data not available</div>';
    }

    const reliabilityEl = document.getElementById('reliabilityMonitorContent');
    if (reliabilityEl) {
        reliabilityEl.innerHTML = reliabilityHtml;
    }

    //----------------------------------------------------------------------------
    // 18. VIRTUAL MEMORY CONFIGURATION
    //----------------------------------------------------------------------------

    let vmHtml = '';
    if (os.Performance?.PageFile || hw?.Performance?.PageFile) {
        const pf = os.Performance?.PageFile || hw?.Performance?.PageFile;

        vmHtml = '<div class="info-grid">';

        vmHtml += `
            <div class="info-item">
                <span class="info-label">Management Type</span>
                <span class="info-value">${pf.SystemManaged ? 'System Managed' : 'Custom'}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Page File Location</span>
                <span class="info-value">${pf.Location || 'C:\\pagefile.sys'}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Initial Size</span>
                <span class="info-value">${pf.InitialSizeMB || pf.TotalSizeMB || 0} MB ${pf.SystemManaged ? '(Auto)' : ''}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Maximum Size</span>
                <span class="info-value">${pf.MaximumSizeMB || pf.TotalSizeMB || 0} MB ${pf.SystemManaged ? '(Auto)' : ''}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Current Usage</span>
                <span class="info-value">${pf.CurrentUsageMB || 0} MB (${pf.PercentUsed || 0}%)</span>
            </div>
            <div class="info-item">
                <span class="info-label">Peak Usage</span>
                <span class="info-value">${pf.PeakUsageMB || 0} MB</span>
            </div>
        `;

        vmHtml += '</div>';
    } else {
        vmHtml = '<div class="text-muted">Virtual memory configuration data not available</div>';
    }

    const vmEl = document.getElementById('virtualMemoryContent');
    if (vmEl) {
        vmEl.innerHTML = vmHtml;
    }

    //----------------------------------------------------------------------------
    // 19. INTUNE/MDM MANAGEMENT - Reuse existing function
    //----------------------------------------------------------------------------

    loadIntuneSection(os);

    //----------------------------------------------------------------------------
    // 20. GROUP POLICY - Reuse existing function
    //----------------------------------------------------------------------------

    loadGroupPolicySection(os);

    // Done!
    console.log('OS Tab loaded successfully with new Tier 1/2/3 layout');

} // End of loadOSTab()

        // Load Hardware Tab - Redesigned with priority-based layout
