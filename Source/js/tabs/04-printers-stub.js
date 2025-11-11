        function loadPrintersTab() {
            const printers = systemData.Printers;
            if (!printers) {
                document.getElementById('printerHealthBanner').innerHTML =
                    '<div style="padding: 20px; text-align: center; color: var(--text-muted);">No printer data available</div>';
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            loadPrinterHealthBanner(printers);
            loadPrinterStatusDashboard(printers);
            loadPrinterCriticalSection(printers);

            // TIER 2: DIAGNOSTIC DETAIL
            loadInstalledPrintersSection(printers);
            loadPrintQueueSection(printers);

            // TIER 3: ADVANCED INFORMATION
            loadPrinterDriversSection(printers);
            loadSpoolerConfigSection(printers);
        }

        function loadPrinterHealthBanner(printers) {
            const banner = document.getElementById('printerHealthBanner');
            if (!banner) return;

            const criticalIssues = [];
            const warningIssues = [];

            // Check for printer errors
            const errorPrinters = (printers.Printers || []).filter(p =>
                p.Status && p.Status !== 'Ready' && p.Status !== 'Idle' && p.Status !== 'Waiting'
            );
            if (errorPrinters.length > 0) {
                criticalIssues.push(`${errorPrinters.length} printer${errorPrinters.length > 1 ? 's' : ''} reporting errors`);
            }

            // Check spooler health
            if (printers.SpoolerHealth && printers.SpoolerHealth.ServiceStatus !== 'Running') {
                criticalIssues.push('Print Spooler service is not running');
            }

            // Check for stuck jobs
            const queuedJobs = (printers.PrintQueue || []).length;
            if (queuedJobs > 10) {
                warningIssues.push(`${queuedJobs} jobs in print queue - possible backup`);
            }

            // Check for offline network printers
            const offlineNetworkPrinters = (printers.NetworkPrinters || []).filter(p => p.Online === false);
            if (offlineNetworkPrinters.length > 0) {
                warningIssues.push(`${offlineNetworkPrinters.length} network printer${offlineNetworkPrinters.length > 1 ? 's' : ''} offline`);
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
                        <strong>Printer System Health: ${healthText}</strong>
                        <span style="color: var(--text-secondary); display: block; margin-top: 5px;">
                            ${criticalIssues.length + warningIssues.length > 0 ?
                                `${criticalIssues.length + warningIssues.length} issue${criticalIssues.length + warningIssues.length > 1 ? 's' : ''} detected` :
                                'No critical printer issues detected'}
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

        function loadPrinterStatusDashboard(printers) {
            const section = document.getElementById('printerStatusDashboard');
            if (!section) return;

            const totalPrinters = (printers.Printers || []).length;
            const spoolerStatus = printers.SpoolerHealth?.ServiceStatus || 'Unknown';
            const spoolerColor = spoolerStatus === 'Running' ? 'var(--success-color)' : 'var(--danger-color)';
            const queuedJobs = (printers.PrintQueue || []).length;
            const errorCount = (printers.Issues || []).length;
            const errorColor = errorCount === 0 ? 'var(--success-color)' : errorCount > 5 ? 'var(--danger-color)' : 'var(--warning-color)';

            let dashboardHtml = `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${totalPrinters > 0 ? 'var(--success-color)' : 'inherit'};">${totalPrinters}</div>
                        <div class="metric-label">Total Printers</div>
                        <div class="metric-sublabel">${totalPrinters > 0 ? 'Installed' : 'No printers'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${spoolerColor};">${spoolerStatus === 'Running' ? 'Ready' : spoolerStatus}</div>
                        <div class="metric-label">Spooler Status</div>
                        <div class="metric-sublabel">${spoolerStatus === 'Running' ? 'Running normally' : 'Service issue'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${queuedJobs}</div>
                        <div class="metric-label">Print Queue</div>
                        <div class="metric-sublabel">${queuedJobs === 0 ? 'No pending jobs' : queuedJobs === 1 ? '1 job pending' : `${queuedJobs} jobs pending`}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${errorColor};">${errorCount}</div>
                        <div class="metric-label">Error Count</div>
                        <div class="metric-sublabel">${errorCount === 0 ? 'No errors' : errorCount === 1 ? '1 error' : `${errorCount} errors`}</div>
                    </div>
                </div>
            `;

            section.innerHTML = dashboardHtml;
        }

        function loadPrinterCriticalSection(printers) {
            const section = document.getElementById('printerCriticalSection');
            if (!section) return;

            const issues = printers.Issues || [];
            const spoolerIssue = printers.SpoolerHealth?.ServiceStatus !== 'Running';

            let html = '<div style="padding: 20px;">';

            if (issues.length === 0 && !spoolerIssue) {
                html += `
                    <div class="alert alert-info">
                        <div style="display: flex; align-items: center; gap: 15px;">
                            <div style="font-size: 2.5rem;">✓</div>
                            <div>
                                <strong>No Critical Issues Detected</strong>
                                <p style="margin-top: 10px; color: var(--text-secondary);">All printers are operational and the print spooler is running normally.</p>
                            </div>
                        </div>
                    </div>
                `;
            } else {
                html += `<div class="alert alert-danger">
                    <div style="display: flex; align-items: center; gap: 15px;">
                        <div style="font-size: 2.5rem;">⚠️</div>
                        <div style="flex: 1;">
                            <strong>Critical Issues Detected</strong>
                            <ul style="margin-top: 10px; margin-left: 20px;">
                `;

                if (spoolerIssue) {
                    html += `<li>Print Spooler service is ${printers.SpoolerHealth?.ServiceStatus || 'not running'}</li>`;
                }

                issues.forEach(issue => {
                    html += `<li>${escapeHtml(issue.Description || issue)}</li>`;
                });

                html += `</ul></div></div></div>`;
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadInstalledPrintersSection(printers) {
            const section = document.getElementById('installedPrintersSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            const installedPrinters = printers.Printers || [];

            if (installedPrinters.length === 0) {
                html += '<div style="text-align: center; color: var(--text-muted);">No printers installed</div>';
            } else {
                installedPrinters.forEach((printer, index) => {
                    const isDefault = printer.IsDefault || index === 0;
                    const isReady = printer.Status === 'Ready' || printer.Status === 'Idle' || printer.Status === 'Waiting';
                    const printerType = printer.Type || 'Unknown';

                    html += `
                        <div style="background: var(--bg-tertiary); border-radius: 6px; padding: 15px; margin-bottom: 15px; ${isDefault && isReady ? 'border-left: 4px solid var(--success-color);' : ''}">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                                <strong style="font-size: 1.1rem;">${escapeHtml(printer.Name || 'Unknown Printer')}${isDefault ? ' (Default)' : ''}</strong>
                                <span class="status-badge ${isReady ? 'status-healthy' : 'status-warning'}">
                                    ${printer.Status || 'Unknown'}
                                </span>
                            </div>
                            <div class="grid grid-3">
                                <div>
                                    <strong>Type:</strong> ${printerType}<br>
                                    <strong>Location:</strong> ${escapeHtml(printer.Location || 'N/A')}<br>
                                    <strong>Status:</strong> ${printer.WorkOffline ? 'Offline' : 'Idle'}
                                </div>
                                <div>
                                    <strong>Port:</strong> ${escapeHtml(printer.PortName || 'N/A')}<br>
                                    <strong>Driver:</strong> ${escapeHtml(printer.DriverName || 'N/A')}<br>
                                    <strong>Shared:</strong> ${printer.IsShared ? 'Yes' : 'No'}
                                </div>
                                <div>
                                    <strong>Jobs Printed:</strong> ${printer.TotalJobsPrinted || 0}<br>
                                    <strong>Pages Printed:</strong> ${printer.TotalPagesPrinted || 0}<br>
                                    <strong>Queue:</strong> ${printer.JobsInQueue > 0 ? printer.JobsInQueue + ' jobs' : 'Empty'}
                                </div>
                            </div>
                        </div>
                    `;
                });
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadPrintQueueSection(printers) {
            const section = document.getElementById('printQueueSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            const printQueue = printers.PrintQueue || [];

            if (printQueue.length === 0) {
                html += `
                    <div style="display: flex; align-items: center; gap: 15px; padding: 20px; background: linear-gradient(135deg, rgba(56, 142, 60, 0.1) 0%, rgba(56, 142, 60, 0.05) 100%); border-radius: 8px; border-left: 4px solid var(--success-color);">
                        <div style="font-size: 2.5rem;">✅</div>
                        <div>
                            <h3 style="margin: 0; color: var(--success-color);">No Active Print Jobs</h3>
                            <p style="margin: 5px 0 0 0; color: var(--text-secondary);">All print queues are clear</p>
                        </div>
                    </div>
                `;
            } else {
                html += `<div class="alert alert-warning">
                    <strong>⚠️ ${printQueue.length} Active Print Job${printQueue.length > 1 ? 's' : ''}</strong>
                    <div style="margin-top: 15px;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <thead>
                                <tr style="border-bottom: 1px solid var(--border-color);">
                                    <th style="text-align: left; padding: 8px;">Document</th>
                                    <th style="text-align: left; padding: 8px;">Printer</th>
                                    <th style="text-align: left; padding: 8px;">Status</th>
                                    <th style="text-align: right; padding: 8px;">Pages</th>
                                </tr>
                            </thead>
                            <tbody>
                `;

                printQueue.slice(0, 10).forEach(job => {
                    html += `
                        <tr style="border-bottom: 1px solid var(--border-color);">
                            <td style="padding: 8px;">${escapeHtml(job.DocumentName || 'Unknown')}</td>
                            <td style="padding: 8px;">${escapeHtml(job.PrinterName || 'N/A')}</td>
                            <td style="padding: 8px;">${escapeHtml(job.Status || 'Queued')}</td>
                            <td style="text-align: right; padding: 8px;">${job.TotalPages || 0}</td>
                        </tr>
                    `;
                });

                html += `</tbody></table></div></div>`;
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadPrinterDriversSection(printers) {
            const section = document.getElementById('printerDriversSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            const drivers = printers.PrinterDrivers || [];

            if (drivers.length === 0) {
                html += '<div style="text-align: center; color: var(--text-muted);">No printer drivers found</div>';
            } else {
                html += `
                    <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                        <h3 style="margin-bottom: 10px; color: var(--accent-color);">Installed Drivers</h3>
                        <div style="display: grid; gap: 10px;">
                `;

                drivers.forEach(driver => {
                    html += `
                        <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px;">
                            <strong>${escapeHtml(driver.Name || 'Unknown Driver')}</strong>${driver.Version ? ` - Version ${escapeHtml(driver.Version)}` : ''}
                        </div>
                    `;
                });

                html += '</div></div>';
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadSpoolerConfigSection(printers) {
            const section = document.getElementById('spoolerConfigSection');
            if (!section) return;

            const spooler = printers.SpoolerHealth || {};
            const spoolerStatus = spooler.ServiceStatus || 'Unknown';
            const spoolerStartType = spooler.StartMode || 'Unknown';
            const spoolerColor = spoolerStatus === 'Running' ? 'var(--success-color)' : 'var(--danger-color)';
            const spoolDirectory = spooler.SpoolFolderPath || 'C:\\Windows\\System32\\spool';
            const restartCount = spooler.RecentCrashes || 0;

            let html = `
                <div class="grid grid-3">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${spoolerColor};">${spoolerStatus}</div>
                        <div class="metric-label">Service Status</div>
                        <div class="metric-sublabel">${spoolerStartType} startup</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="font-size: 1.2rem;">${escapeHtml(spoolDirectory)}</div>
                        <div class="metric-label" style="font-size: 0.85rem;">Spool Directory</div>
                        <div class="metric-sublabel">Default location</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${restartCount}</div>
                        <div class="metric-label">Spooler Restarts</div>
                        <div class="metric-sublabel">Last 30 days</div>
                    </div>
                </div>
            `;

            section.innerHTML = html;
        }

        // Load Software Tab
