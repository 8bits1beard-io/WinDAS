        function loadHardwareHealthBanner(hw) {
            const banner = document.getElementById('hardwareHealthBanner');
            if (!banner) return;

            const criticalIssues = [];
            const warningIssues = [];
            let overallHealthStatus = 'healthy';

            // CPU temperature check removed - inconsistent support across vendors

            // Check memory usage
            const memoryFreePercent = hw.Memory?.PercentFree || 100;
            const memoryFreeGB = hw.Memory?.AvailableGB || 0;
            if (memoryFreePercent < 10) {
                warningIssues.push(`Memory usage high: only ${memoryFreeGB.toFixed(1)} GB free of ${hw.Memory?.TotalGB || 0} GB`);
            } else if (memoryFreePercent < 20) {
                warningIssues.push(`Memory usage elevated at ${100 - memoryFreePercent}%`);
            }

            // Check storage capacity
            if (hw.Storage?.Disks) {
                hw.Storage.Disks.forEach(disk => {
                    if (disk.PercentFull >= 90) {
                        warningIssues.push(`${disk.Drive} drive is ${disk.PercentFull}% full (${disk.FreeSpaceGB.toFixed(1)} GB remaining)`);
                    }
                });
            }

            // Check SMART status
            if (hw.Storage?.Disks) {
                const unhealthyDisks = hw.Storage.Disks.filter(d => d.SMARTStatus && d.SMARTStatus !== 'OK');
                if (unhealthyDisks.length > 0) {
                    criticalIssues.push(`${unhealthyDisks.length} disk${unhealthyDisks.length > 1 ? 's' : ''} reporting SMART errors - data loss risk`);
                }
            }

            // Determine overall status
            if (criticalIssues.length > 0) {
                overallHealthStatus = 'critical';
            } else if (warningIssues.length > 0) {
                overallHealthStatus = 'warning';
            }

            // Build health banner
            const healthIcon = overallHealthStatus === 'critical' ? '🔴' :
                               overallHealthStatus === 'warning' ? '⚠️' : '✅';
            const healthText = overallHealthStatus === 'critical' ? 'Critical Issues Detected' :
                               overallHealthStatus === 'warning' ? 'Warnings Detected' : 'Hardware Healthy';

            const allIssues = [...criticalIssues, ...warningIssues];

            let healthBannerHtml = `
                <div class="health-status">
                    <span class="health-icon">${healthIcon}</span>
                    <strong>Hardware Health: ${healthText}</strong>
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

            banner.className = `health-banner ${overallHealthStatus}`;
            banner.innerHTML = healthBannerHtml;
        }

        function loadHardwareTab() {
            const hw = systemData.Hardware;
            if (!hw) {
                document.getElementById('hardwareHealthDashboard').innerHTML = '<div class="text-center text-muted">No hardware data available</div>';
                document.getElementById('activePerformanceIssues').innerHTML = '';
                document.getElementById('storageHealthSection').innerHTML = '';
                document.getElementById('memoryConfigSection').innerHTML = '';
                document.getElementById('otherComponentsSection').innerHTML = '';
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            // 0. Overall Hardware Health Status Banner
            loadHardwareHealthBanner(hw);

            // COMBINED SECTION: Hardware Health & Performance
            const criticalIssues = [];
            let overallHealth = 'Healthy';

            // CPU temperature check removed - inconsistent support across vendors

            // Check memory usage
            const memoryFreePercent = hw.Memory?.PercentFree || 100;
            const memoryFreeGB = hw.Memory?.AvailableGB || 0;
            if (memoryFreePercent < 10) {
                criticalIssues.push(`<strong>Memory:</strong> Only ${memoryFreeGB.toFixed(1)} GB free of ${hw.Memory?.TotalGB || 0} GB - system may be slow`);
                if (overallHealth === 'Healthy') overallHealth = 'Warning';
            }

            // Check storage space
            let storageIssues = 0;
            if (hw.Storage?.Devices) {
                hw.Storage.Devices.forEach(device => {
                    if (device.PercentFree < 10) {
                        criticalIssues.push(`<strong>Storage ${escapeHtml(device.DeviceID || device.Model)}:</strong> Only ${device.PercentFree.toFixed(1)}% free space remaining`);
                        storageIssues++;
                        if (overallHealth === 'Healthy') overallHealth = 'Warning';
                    }
                });
            }

            // Hardware Health Dashboard - just the 3 metric cards (CPU temp removed)
            let dashboardHtml = `
                <div class="grid grid-3">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${memoryFreePercent < 10 ? 'var(--warning-color)' : 'inherit'}">
                            ${(100 - memoryFreePercent).toFixed(0)}%
                        </div>
                        <div class="metric-label">Memory Usage</div>
                        <div class="metric-sublabel">${memoryFreeGB.toFixed(1)} GB free</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${storageIssues > 0 ? 'var(--warning-color)' : 'inherit'}">
                            ${storageIssues}
                        </div>
                        <div class="metric-label">Storage Warnings</div>
                        <div class="metric-sublabel">${storageIssues === 0 ? 'All drives OK' : 'Low space detected'}</div>
                    </div>
                    ${(() => {
                        const totalDisks = hw.Storage?.Disks?.length || 0;
                        const unhealthyDisks = hw.Storage?.Disks?.filter(d => d.SMARTStatus && d.SMARTStatus !== 'OK')?.length || 0;
                        const healthyDisks = totalDisks - unhealthyDisks;
                        return `
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${unhealthyDisks > 0 ? 'var(--danger-color)' : 'var(--success-color)'}">
                            ${healthyDisks}/${totalDisks}
                        </div>
                        <div class="metric-label">SMART Status</div>
                        <div class="metric-sublabel">${unhealthyDisks > 0 ? 'Disk errors detected' : 'All disks healthy'}</div>
                    </div>
                        `;
                    })()}
                </div>
            `;

            document.getElementById('hardwareHealthDashboard').innerHTML = dashboardHtml;

            // Active Performance & Resource Usage section removed - redundant with health banner and metric cards

            // TIER 2: DIAGNOSTIC DETAIL
            // Storage Health & Capacity - ENHANCED
            let storageHtml = '';

            // Check for SMART warnings first
            const smartWarnings = [];
            const smartCritical = [];

            if (hw.Storage?.Disks) {
                hw.Storage.Disks.forEach(disk => {
                    const smartStatus = disk.SMARTStatus || disk.HealthStatus || disk.Status;
                    if (smartStatus && smartStatus !== 'OK' && smartStatus !== 'Healthy' && smartStatus !== 'Normal') {
                        const diskInfo = {
                            name: disk.Drive || disk.DeviceID || 'Unknown Disk',
                            status: smartStatus,
                            mediaType: disk.MediaType || 'Unknown'
                        };

                        if (smartStatus === 'Pred Fail' || smartStatus === 'Failed' || smartStatus === 'Bad') {
                            smartCritical.push(diskInfo);
                        } else {
                            smartWarnings.push(diskInfo);
                        }
                    }
                });
            }

            // Display SMART warnings at top if present
            if (smartCritical.length > 0 || smartWarnings.length > 0) {
                const isCritical = smartCritical.length > 0;
                const warningColor = isCritical ? 'var(--danger-color)' : 'var(--warning-color)';
                const warningIcon = isCritical ? '🔴' : '⚠️';
                const warningText = isCritical ? 'DISK FAILURE IMMINENT' : 'DISK HEALTH WARNING';

                storageHtml += `
                    <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid ${warningColor}; margin-bottom: 20px;">
                        <div style="font-size: 1.1rem; font-weight: bold; color: ${warningColor}; margin-bottom: 8px;">
                            ${warningIcon} ${warningText}
                        </div>
                        <div style="font-size: 0.95rem; color: var(--text-primary); margin-bottom: 10px;">
                            ${isCritical ?
                                'One or more disks are reporting imminent failure. DATA LOSS IS LIKELY. Back up immediately.' :
                                'One or more disks are showing signs of degradation. Failure may occur soon.'}
                        </div>
                `;

                [...smartCritical, ...smartWarnings].forEach(disk => {
                    storageHtml += `
                        <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px; margin-top: 10px;">
                            <strong>${escapeHtml(disk.name)}</strong> (${escapeHtml(disk.mediaType)})<br>
                            <span style="color: ${warningColor}; font-weight: 600;">Status: ${escapeHtml(disk.status)}</span>
                        </div>
                    `;
                });

                storageHtml += `
                        <div style="margin-top: 15px; padding: 12px; background: var(--bg-tertiary); border-radius: 4px; border-left: 3px solid var(--info-color);">
                            <strong style="color: var(--info-color);">🔧 Required Actions:</strong>
                            <ol style="margin: 8px 0 0 20px; font-size: 0.9rem; line-height: 1.8;">
                                ${isCritical ?
                                    '<li style="color: var(--danger-color); font-weight: 600;">BACKUP ALL DATA IMMEDIATELY - Disk may fail at any time</li>' :
                                    '<li><strong>Back up important data soon</strong> - Disk showing early failure signs</li>'}
                                <li>Run disk diagnostics: <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">wmic diskdrive get status</code></li>
                                <li>Check manufacturer website for disk diagnostic tools</li>
                                ${isCritical ?
                                    '<li style="color: var(--danger-color);">Order replacement disk immediately</li>' :
                                    '<li>Plan for disk replacement in near future</li>'}
                                <li>If under warranty, contact manufacturer for RMA</li>
                            </ol>
                        </div>
                    </div>
                `;
            }

            // Storage Devices - Enhanced with SMART interpretation
            if (hw.Storage?.Devices && hw.Storage.Devices.length > 0) {
                hw.Storage.Devices.forEach(device => {
                    const usedPercent = 100 - (device.PercentFree || 0);
                    const usedGB = device.UsedSpaceGB || (device.SizeGB - device.FreeSpaceGB) || 0;
                    const totalGB = device.SizeGB || 0;
                    const freeGB = device.FreeSpaceGB || 0;

                    // Determine color based on usage
                    let barColor = 'var(--success-color)';
                    if (usedPercent > 90) barColor = 'var(--danger-color)';
                    else if (usedPercent > 75) barColor = 'var(--warning-color)';

                    // Build type and details line
                    const mediaType = device.MediaType || 'Unknown';
                    const smartStatus = device.HealthStatus || device.Status || 'Unknown';

                    // SMART status interpretation
                    let smartBadge = '';
                    let smartColor = 'var(--success-color)';
                    let smartText = 'Healthy';

                    if (smartStatus === 'OK' || smartStatus === 'Healthy' || smartStatus === 'Normal') {
                        smartColor = 'var(--success-color)';
                        smartText = '✓ Healthy';
                    } else if (smartStatus === 'Pred Fail' || smartStatus === 'Failed' || smartStatus === 'Bad') {
                        smartColor = 'var(--danger-color)';
                        smartText = '🔴 FAILING';
                    } else if (smartStatus === 'Warning' || smartStatus === 'Degraded') {
                        smartColor = 'var(--warning-color)';
                        smartText = '⚠️ Warning';
                    } else if (smartStatus === 'Unknown' || smartStatus === 'Not Available') {
                        smartColor = 'var(--text-muted)';
                        smartText = 'Unknown';
                    }

                    smartBadge = `<span style="color: ${smartColor}; font-weight: 600;">SMART: ${smartText}</span>`;

                    let detailsLine = `Type: ${escapeHtml(mediaType)} | ${smartBadge}`;

                    // Add performance specs if available
                    if (mediaType.includes('SSD')) {
                        if (device.ReadSpeed) detailsLine += ` | Read: ${device.ReadSpeed} MB/s`;
                        if (device.WriteSpeed) detailsLine += ` | Write: ${device.WriteSpeed} MB/s`;
                    } else {
                        if (device.RPM) detailsLine += ` | RPM: ${device.RPM}`;
                    }

                    storageHtml += `
                        <div style="margin-bottom: 25px;">
                            <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                                <strong>${escapeHtml(device.DeviceID || device.Caption || 'Storage Device')}</strong>
                                <span>${usedGB.toFixed(0)} GB / ${totalGB.toFixed(0)} GB (${usedPercent.toFixed(0)}%)</span>
                            </div>
                            <div style="width: 100%; height: 25px; background: var(--bg-tertiary); border-radius: 6px; overflow: hidden;">
                                <div style="height: 100%; width: ${usedPercent}%; background: ${barColor}; display: flex; align-items: center; justify-content: center; color: white; font-size: 0.85rem; font-weight: 600; transition: width 0.3s ease;">
                                    ${usedPercent > 10 ? `${usedPercent.toFixed(0)}% Used` : ''}
                                </div>
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-muted); margin-top: 5px;">
                                ${detailsLine}
                            </div>
                        </div>
                    `;
                });
            }

            // SMART Status Explanation
            if (!smartCritical.length && !smartWarnings.length && hw.Storage?.Devices?.length > 0) {
                storageHtml += `
                    <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; border-left: 3px solid var(--success-color); margin-top: 20px;">
                        <div style="font-size: 0.9rem;">
                            <strong style="color: var(--success-color);">✓ All Disks Healthy</strong><br>
                            <span style="color: var(--text-secondary); font-size: 0.85rem;">
                                SMART (Self-Monitoring, Analysis, and Reporting Technology) monitors disk health.
                                All drives are reporting normal operation with no predictive failure indicators.
                            </span>
                        </div>
                    </div>
                `;
            }

            document.getElementById('storageHealthSection').innerHTML = storageHtml || '<div style="padding: 20px; text-align: center;">No storage devices found</div>';

            // Memory Configuration - Metric cards + module list like demo
            let memoryHtml = '';

            if (hw.Memory) {
                const totalGB = hw.Memory.TotalGB || 0;
                const usedGB = hw.Memory.UsedGB || 0;
                const availableGB = hw.Memory.AvailableGB || 0;
                const usedPercent = 100 - (hw.Memory.PercentFree || 0);
                const memoryType = hw.Memory.Type || 'Unknown';
                const memorySpeed = hw.Memory.Speed || 'Unknown';

                // Determine color for "In Use" metric
                let inUseColor = 'inherit';
                if (hw.Memory.PercentFree < 10) inUseColor = 'var(--danger-color)';
                else if (hw.Memory.PercentFree < 20) inUseColor = 'var(--warning-color)';

                // Determine color for "Available" metric
                let availableColor = 'var(--success-color)';
                if (hw.Memory.PercentFree < 10) availableColor = 'var(--danger-color)';
                else if (hw.Memory.PercentFree < 20) availableColor = 'var(--warning-color)';

                memoryHtml += `
                    <div class="grid grid-3">
                        <div class="metric-card">
                            <div class="metric-value">${totalGB} GB</div>
                            <div class="metric-label">Total RAM</div>
                            <div class="metric-sublabel">${escapeHtml(memoryType)} ${memorySpeed !== 'Unknown' ? memorySpeed : ''}</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: ${inUseColor};">${usedGB.toFixed(1)} GB</div>
                            <div class="metric-label">In Use</div>
                            <div class="metric-sublabel">${usedPercent.toFixed(0)}% utilized</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: ${availableColor};">${availableGB.toFixed(1)} GB</div>
                            <div class="metric-label">Available</div>
                            <div class="metric-sublabel">${(100 - usedPercent).toFixed(0)}% free</div>
                        </div>
                    </div>
                `;

                // Memory Module Details removed - WMI data unreliable (reports incorrect slot counts on many systems)
            }
            document.getElementById('memoryConfigSection').innerHTML = memoryHtml || '<div style="padding: 20px; text-align: center;">No memory data available</div>';

            // TIER 3: ADVANCED INFORMATION
            // Other Components (CPU, GPU, System Board)
            let componentsHtml = '<div style="display: grid; gap: 20px;">';

            // CPU Details
            if (hw.CPU) {
                componentsHtml += `
                    <div>
                        <h3 style="margin-bottom: 10px; color: var(--accent-color);">🖥️ Processor (CPU)</h3>
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                            <div style="display: grid; gap: 8px;">
                                <div><strong>Model:</strong> ${escapeHtml(hw.CPU.Model || 'Unknown')}</div>
                                <div><strong>Cores:</strong> ${hw.CPU.PhysicalCores || 0} | <strong>Threads:</strong> ${hw.CPU.LogicalProcessors || 0}</div>
                                <div><strong>Base Clock:</strong> ${hw.CPU.MaxSpeed || hw.CPU.CurrentSpeed || 'N/A'} GHz${hw.CPU.CurrentSpeed && hw.CPU.MaxSpeed !== hw.CPU.CurrentSpeed ? ` | <strong>Current:</strong> ${hw.CPU.CurrentSpeed} GHz` : ''}</div>
                                ${hw.CPU.L3CacheSize ? `<div><strong>Cache:</strong> ${escapeHtml(hw.CPU.L3CacheSize)}</div>` : ''}
                            </div>
                        </div>
                    </div>
                `;
            }

            // Graphics/GPU
            if (hw.Graphics?.Devices && hw.Graphics.Devices.length > 0) {
                const gpu = hw.Graphics.Devices[0]; // Show first GPU
                const statusColor = gpu.Status === 'OK' ? 'var(--success-color)' : 'var(--warning-color)';

                componentsHtml += `
                    <div>
                        <h3 style="margin-bottom: 10px; color: var(--accent-color);">🎮 Graphics Card (GPU)</h3>
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                            <div style="display: grid; gap: 8px;">
                                <div><strong>Model:</strong> ${escapeHtml(gpu.Name || 'Unknown')}</div>
                                <div><strong>VRAM:</strong> ${gpu.VRAMSizeGB || 'N/A'} GB</div>
                                <div><strong>Driver Version:</strong> ${escapeHtml(gpu.DriverVersion || 'Unknown')}</div>
                                <div><strong>Resolution:</strong> ${escapeHtml(gpu.CurrentResolution || 'Unknown')}</div>
                                <div><strong>Status:</strong> <span style="color: ${statusColor};">${gpu.Status || 'Unknown'}</span></div>
                            </div>
                        </div>
                    </div>
                `;
            }
            // System Board (Motherboard + BIOS)
            if (hw.SystemBoard) {
                const manufacturer = hw.SystemBoard.Motherboard?.Manufacturer || hw.SystemBoard.Manufacturer || 'Unknown';
                const model = hw.SystemBoard.Motherboard?.Product || hw.SystemBoard.Product || hw.SystemBoard.Model || 'Unknown';
                const chipset = hw.SystemBoard.Chipset || 'Unknown';
                const biosVersion = hw.SystemBoard.BIOS?.Version || hw.SystemBoard.BIOSVersion || 'Unknown';
                const biosDate = hw.SystemBoard.BIOS?.ReleaseDate || hw.SystemBoard.BIOSReleaseDate || 'N/A';

                componentsHtml += `
                    <div>
                        <h3 style="margin-bottom: 10px; color: var(--accent-color);">⚙️ System Board</h3>
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                            <div style="display: grid; gap: 8px;">
                                <div><strong>Manufacturer:</strong> ${escapeHtml(manufacturer)}</div>
                                <div><strong>Model:</strong> ${escapeHtml(model)}</div>
                                ${chipset !== 'Unknown' ? `<div><strong>Chipset:</strong> ${escapeHtml(chipset)}</div>` : ''}
                                <div><strong>BIOS Version:</strong> ${escapeHtml(biosVersion)}${biosDate !== 'N/A' ? ` (${escapeHtml(biosDate)})` : ''}</div>
                            </div>
                        </div>
                    </div>
                `;
            }

            componentsHtml += '</div>'; // Close the display: grid wrapper

            document.getElementById('otherComponentsSection').innerHTML = componentsHtml || '<div style="padding: 20px; text-align: center;">No component data available</div>';

            // Peripherals & Power - single-column stacked layout for better balance
            let peripheralsHtml = '<div style="display: grid; gap: 20px;">';

            // Connected Devices section
            peripheralsHtml += '<div><h4 style="margin-bottom: 10px;">Connected Devices</h4>';

            // USB Devices - show detailed list if available (collapsed by default)
            if (hw.USB?.Devices && hw.USB.Devices.length > 0) {
                peripheralsHtml += `
                    <div style="background: var(--bg-secondary); padding: 12px; border-radius: 6px; margin-bottom: 10px;">
                        <details style="cursor: pointer;">
                            <summary style="font-weight: 600; list-style: none; display: flex; align-items: center; gap: 8px; user-select: none;">
                                <span style="font-size: 1rem;">▶</span>
                                <span>🔌 USB Devices (${hw.USB.ConnectedDevices} total)</span>
                            </summary>
                            <div style="display: grid; gap: 6px; margin-top: 10px;">
                `;

                hw.USB.Devices.forEach(device => {
                    const statusColor = device.Status === 'OK' ? 'var(--success-color)' : 'var(--warning-color)';
                    const statusIcon = device.Status === 'OK' ? '✓' : '⚠️';
                    peripheralsHtml += `
                        <div style="background: var(--bg-tertiary); padding: 8px; border-radius: 4px; display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <div style="font-size: 0.9rem; font-weight: 500;">${escapeHtml(device.Name || 'Unknown Device')}</div>
                                ${device.Manufacturer && device.Manufacturer !== 'Unknown' ? `<div style="font-size: 0.8rem; color: var(--text-secondary);">${escapeHtml(device.Manufacturer)}</div>` : ''}
                            </div>
                            <span style="color: ${statusColor}; font-size: 0.85rem;">${statusIcon} ${escapeHtml(device.Status || 'Unknown')}</span>
                        </div>
                    `;
                });

                peripheralsHtml += `
                            </div>
                        </details>
                    </div>
                `;
            } else if (hw.USB?.ConnectedDevices > 0) {
                peripheralsHtml += `
                    <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px; margin-bottom: 10px;">
                        🔌 ${hw.USB.ConnectedDevices} USB Device${hw.USB.ConnectedDevices > 1 ? 's' : ''} Connected (details not available)
                    </div>
                `;
            }

            // Audio Devices
            if (hw.Audio?.PlaybackDevice || hw.Audio?.RecordingDevice) {
                if (hw.Audio?.PlaybackDevice) {
                    peripheralsHtml += `
                        <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px; margin-bottom: 6px;">
                            🎧 ${escapeHtml(hw.Audio.PlaybackDevice)}
                        </div>
                    `;
                }
                if (hw.Audio?.RecordingDevice && hw.Audio.RecordingDevice !== hw.Audio.PlaybackDevice) {
                    peripheralsHtml += `
                        <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px;">
                            🎤 ${escapeHtml(hw.Audio.RecordingDevice)}
                        </div>
                    `;
                }
            }

            // Fallback if no devices found
            if (!hw.USB?.ConnectedDevices && !hw.Audio?.PlaybackDevice && !hw.Audio?.RecordingDevice) {
                peripheralsHtml += `
                    <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px; color: var(--text-muted);">
                        No connected device details available
                    </div>
                `;
            }

            peripheralsHtml += '</div>'; // Close Connected Devices section

            // Power Management - ENHANCED with battery health
            peripheralsHtml += '<div><h4 style="margin-bottom: 10px;">Power Management</h4>';

            if (hw.Power) {
                const powerPlan = hw.Power.PowerPlan || hw.Power.ActivePlan || 'Unknown';
                const sleepTimeout = hw.Power.SleepTimeout || 'Never';
                const battery = hw.Power.Battery;

                // Basic power info
                peripheralsHtml += `
                    <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; margin-bottom: 15px;">
                        <strong>Power Plan:</strong> ${escapeHtml(powerPlan)}<br>
                        <strong>Sleep Settings:</strong> ${escapeHtml(sleepTimeout)}
                    </div>
                `;

                // Battery health (if laptop)
                if (battery) {
                    const healthPercent = battery.HealthPercent || null;
                    const chargeRemaining = battery.EstimatedChargeRemaining || 0;
                    const status = battery.Status || 'Unknown';
                    const designCapacity = battery.DesignCapacity || null;
                    const fullChargeCapacity = battery.FullChargeCapacity || null;
                    const cycleCount = battery.CycleCount || null;

                    // Determine health status
                    let healthStatus = 'Unknown';
                    let healthColor = 'var(--text-muted)';
                    let healthIcon = '❓';
                    let healthText = 'Battery health unknown';
                    let recommendation = 'Unable to assess battery condition';

                    if (healthPercent) {
                        if (healthPercent >= 80) {
                            healthStatus = 'Excellent';
                            healthColor = 'var(--success-color)';
                            healthIcon = '✅';
                            healthText = 'Battery is in excellent condition';
                            recommendation = 'No action needed. Battery is healthy.';
                        } else if (healthPercent >= 60) {
                            healthStatus = 'Degraded';
                            healthColor = 'var(--warning-color)';
                            healthIcon = '⚠️';
                            healthText = 'Battery capacity has degraded significantly';
                            recommendation = 'Battery holds ' + healthPercent.toFixed(0) + '% of original capacity. Consider replacement if runtime is insufficient.';
                        } else {
                            healthStatus = 'Poor - Replace Soon';
                            healthColor = 'var(--danger-color)';
                            healthIcon = '🔴';
                            healthText = 'Battery is severely degraded';
                            recommendation = 'Battery holds only ' + healthPercent.toFixed(0) + '% of original capacity. Replacement recommended.';
                        }
                    }

                    peripheralsHtml += `
                        <div style="padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid ${healthColor}; margin-bottom: 15px;">
                            <div style="font-size: 1.05rem; font-weight: bold; margin-bottom: 8px;">
                                🔋 Battery Status
                            </div>

                            <div style="margin-bottom: 12px;">
                                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 4px;">Current Charge</div>
                                <div style="display: flex; align-items: center; gap: 10px;">
                                    <div style="flex: 1; height: 20px; background: var(--bg-tertiary); border-radius: 4px; overflow: hidden;">
                                        <div style="height: 100%; width: ${chargeRemaining}%; background: ${chargeRemaining < 20 ? 'var(--danger-color)' : chargeRemaining < 50 ? 'var(--warning-color)' : 'var(--success-color)'}; transition: width 0.3s ease;"></div>
                                    </div>
                                    <div style="font-weight: 600; min-width: 45px;">${chargeRemaining}%</div>
                                </div>
                                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 4px;">
                                    ${status === 'Charging' ? '⚡ Charging' : status === 'AC Power' ? '🔌 Plugged In' : status === 'Discharging' ? '🔋 On Battery' : escapeHtml(status)}
                                </div>
                            </div>
                    `;

                    if (healthPercent) {
                        peripheralsHtml += `
                            <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 12px;">
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                                    <div style="font-weight: 600;">Battery Health</div>
                                    <div style="font-size: 1.3rem; font-weight: bold; color: ${healthColor};">
                                        ${healthPercent.toFixed(0)}%
                                    </div>
                                </div>
                                <div style="font-size: 0.9rem; color: ${healthColor}; font-weight: 600; margin-bottom: 6px;">
                                    ${healthIcon} ${healthStatus}
                                </div>
                                <div style="font-size: 0.85rem; color: var(--text-secondary);">
                                    ${healthText}
                                </div>
                            </div>

                            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 4px; font-size: 0.85rem;">
                                ${designCapacity ? `<div style="margin-bottom: 4px;"><strong>Design Capacity:</strong> ${designCapacity.toLocaleString()} mWh</div>` : ''}
                                ${fullChargeCapacity ? `<div style="margin-bottom: 4px;"><strong>Full Charge Capacity:</strong> ${fullChargeCapacity.toLocaleString()} mWh</div>` : ''}
                                ${cycleCount ? `<div><strong>Charge Cycles:</strong> ${cycleCount.toLocaleString()}</div>` : ''}
                            </div>

                            <div style="padding: 12px; background: var(--bg-tertiary); border-radius: 4px; border-left: 3px solid var(--info-color); margin-top: 12px;">
                                <strong style="color: var(--info-color); font-size: 0.9rem;">💡 Recommendation:</strong><br>
                                <span style="font-size: 0.85rem;">${recommendation}</span>
                            </div>
                        `;
                    } else {
                        peripheralsHtml += `
                            <div style="padding: 10px; background: var(--bg-tertiary); border-radius: 4px; color: var(--text-secondary); font-size: 0.9rem;">
                                Battery health information not available. Run <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">powercfg /batteryreport</code> for detailed diagnostics.
                            </div>
                        `;
                    }

                    peripheralsHtml += '</div>';

                    // Battery Health Thresholds Guide
                    if (healthPercent) {
                        peripheralsHtml += `
                            <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px; margin-top: 15px;">
                                <div style="font-weight: 600; margin-bottom: 8px; font-size: 0.9rem;">📊 Battery Health Guide</div>
                                <div style="font-size: 0.85rem; line-height: 1.8;">
                                    <div style="color: var(--success-color);">✓ 80-100%: Excellent - Battery is healthy</div>
                                    <div style="color: var(--warning-color);">⚠️ 60-79%: Degraded - Reduced runtime, replacement optional</div>
                                    <div style="color: var(--danger-color);">🔴 Below 60%: Poor - Replacement recommended</div>
                                </div>
                            </div>
                        `;
                    }
                } else {
                    // Desktop (no battery)
                    peripheralsHtml += `
                        <div style="padding: 12px; background: var(--bg-secondary); border-radius: 6px;">
                            <div style="font-size: 1.05rem; font-weight: 600; margin-bottom: 6px;">🖥️ Desktop PC</div>
                            <div style="font-size: 0.9rem; color: var(--text-secondary);">
                                No battery detected - system running on AC power
                            </div>
                        </div>
                    `;
                }
            } else {
                peripheralsHtml += `
                    <div class="alert alert-info">
                        <strong>Power Management:</strong> Information not available
                    </div>
                `;
            }

            peripheralsHtml += '</div></div>'; // Close Power Management section and overall grid

            document.getElementById('peripheralsPowerSection').innerHTML = peripheralsHtml;
        }

        // Load Network Tab - Redesigned with priority-based layout
