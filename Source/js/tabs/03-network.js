        function loadNetworkTab() {
            const net = systemData.Network;
            if (!net) {
                document.getElementById('networkHealthBanner').innerHTML = '<div class="text-center text-muted">No network data available</div>';
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            loadNetworkHealthBanner(net);
            loadNetworkStatusDashboard(net);
            loadConnectivityTestsSection(net);

            // TIER 2: DIAGNOSTIC DETAIL
            loadActiveAdaptersSection(net);
            loadFirewallSecuritySection(net);

            // TIER 3: ADVANCED INFORMATION
            loadDnsConfigSection(net);
            loadRoutingTableSection(net);
        }

        function loadNetworkHealthBanner(net) {
            const banner = document.getElementById('networkHealthBanner');
            if (!banner) return;

            const isConnected = net.Summary?.ConnectionStatus === 'Connected';
            const hasConnectivityIssues = (net.ConnectivityTests?.Tests && Array.isArray(net.ConnectivityTests.Tests)) ?
                net.ConnectivityTests.Tests.some(test => test.Result !== 'Pass') : false;

            let criticalIssues = [];
            let warningIssues = [];

            // Check connection status
            if (!isConnected) {
                criticalIssues.push('No internet connection detected');
            }

            // Check connectivity test failures
            if (hasConnectivityIssues) {
                const failedTests = net.ConnectivityTests.Tests.filter(test => test.Result !== 'Pass');
                failedTests.forEach(test => {
                    if (test.Test === 'Internet' || test.Test === 'Gateway') {
                        criticalIssues.push(`${test.Test} connectivity failed - unable to reach ${test.Target}`);
                    } else {
                        warningIssues.push(`${test.Test} test failed - ${test.Target} unreachable`);
                    }
                });
            }

            // Check for adapter errors
            const primaryAdapter = net.ActiveAdapters?.find(a => a.DefaultGateway) || net.ActiveAdapters?.[0];
            if (primaryAdapter && primaryAdapter.Statistics) {
                const errorRate = (parseInt(primaryAdapter.Statistics.SendErrors || 0) + parseInt(primaryAdapter.Statistics.ReceiveErrors || 0));
                if (errorRate > 1000) {
                    warningIssues.push(`High error rate detected on primary adapter: ${errorRate} errors`);
                }
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
                        <strong>Network Health: ${healthText}</strong>
                        <span style="color: var(--text-secondary); display: block; margin-top: 5px;">
                            ${criticalIssues.length + warningIssues.length > 0 ?
                                `${criticalIssues.length + warningIssues.length} issue${criticalIssues.length + warningIssues.length > 1 ? 's' : ''} detected` :
                                'No critical network issues detected'}
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

        function loadNetworkStatusDashboard(net) {
            const section = document.getElementById('networkStatusDashboard');
            if (!section) return;

            const isConnected = net.Summary?.ConnectionStatus === 'Connected';

            // Parse latency
            let latencyMs = 0;
            let latencyStatus = 'Unknown';
            let latencyDisplay = 'N/A';

            if (net.ConnectivityTests?.Tests && net.ConnectivityTests.Tests.length > 0) {
                const testsWithLatency = net.ConnectivityTests.Tests
                    .filter(test => test.Latency && test.Latency !== 'N/A' && test.Result === 'Pass')
                    .map(test => {
                        const latencyStr = test.Latency.toString();
                        return parseInt(latencyStr.replace(/[^0-9]/g, '')) || 0;
                    })
                    .filter(lat => lat > 0);

                if (testsWithLatency.length > 0) {
                    latencyMs = Math.round(testsWithLatency.reduce((sum, lat) => sum + lat, 0) / testsWithLatency.length);
                    latencyDisplay = `${latencyMs}ms`;

                    if (latencyMs < 20) latencyStatus = 'Excellent';
                    else if (latencyMs < 50) latencyStatus = 'Good';
                    else if (latencyMs < 100) latencyStatus = 'Fair';
                    else latencyStatus = 'Poor';
                }
            }

            const latencyColor = latencyMs < 20 ? 'var(--success-color)' :
                                latencyMs < 50 ? 'var(--success-color)' :
                                latencyMs < 100 ? 'var(--warning-color)' : 'var(--danger-color)';

            // Connection type
            const primaryAdapter = net.ActiveAdapters?.find(a => a.DefaultGateway) || net.ActiveAdapters?.[0];

            // Determine connection type from adapter name or type
            let connectionType = 'Unknown';
            if (primaryAdapter) {
                const adapterName = (primaryAdapter.Name || '').toLowerCase();
                if (adapterName.includes('wi-fi') || adapterName.includes('wireless') || adapterName.includes('wifi')) {
                    connectionType = primaryAdapter.Standard || 'Wi-Fi';
                } else if (adapterName.includes('ethernet') || adapterName.includes('realtek') || adapterName.includes('intel') && adapterName.includes('gigabit')) {
                    connectionType = 'Ethernet';
                } else if (adapterName.includes('bluetooth')) {
                    connectionType = 'Bluetooth';
                } else if (primaryAdapter.AdapterType) {
                    connectionType = primaryAdapter.AdapterType;
                } else if (primaryAdapter.ConnectionType) {
                    connectionType = primaryAdapter.ConnectionType;
                }
            }

            const linkSpeed = primaryAdapter?.LinkSpeed || primaryAdapter?.Speed || 'Unknown';

            // Packet loss/errors
            const sendErrors = parseInt(primaryAdapter?.Statistics?.SendErrors || 0);
            const receiveErrors = parseInt(primaryAdapter?.Statistics?.ReceiveErrors || 0);
            const totalErrors = sendErrors + receiveErrors;
            const errorColor = totalErrors === 0 ? 'var(--success-color)' : totalErrors > 100 ? 'var(--danger-color)' : 'var(--warning-color)';

            let dashboardHtml = `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${isConnected ? 'var(--success-color)' : 'var(--danger-color)'};">
                            ${isConnected ? 'Connected' : 'Disconnected'}
                        </div>
                        <div class="metric-label">Connection Status</div>
                        <div class="metric-sublabel">${isConnected ? 'Internet accessible' : 'No connection'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${latencyColor};">${latencyDisplay}</div>
                        <div class="metric-label">Network Latency</div>
                        <div class="metric-sublabel">${latencyStatus}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${escapeHtml(connectionType)}</div>
                        <div class="metric-label">Connection Type</div>
                        <div class="metric-sublabel">${escapeHtml(linkSpeed)}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${errorColor};">${totalErrors}</div>
                        <div class="metric-label">Packet Errors</div>
                        <div class="metric-sublabel">${totalErrors === 0 ? 'No errors' : 'Errors detected'}</div>
                    </div>
                </div>
            `;

            section.innerHTML = dashboardHtml;
        }

        function loadConnectivityTestsSection(net) {
            const section = document.getElementById('connectivityTestsSection');
            if (!section) return;

            let html = '';

            if (net.ConnectivityTests?.Tests && net.ConnectivityTests.Tests.length > 0) {
                const passedTests = net.ConnectivityTests.Tests.filter(test => test.Result === 'Pass');
                const failedTests = net.ConnectivityTests.Tests.filter(test => test.Result !== 'Pass');

                if (failedTests.length === 0) {
                    // All tests passed
                    html = `
                        <div style="padding: 20px;">
                            <div class="alert alert-info">
                                <div style="display: flex; align-items: center; gap: 15px;">
                                    <div style="font-size: 2.5rem;">✓</div>
                                    <div style="flex: 1;">
                                        <strong>All Connectivity Tests Passed</strong>
                                        <div style="margin-top: 10px; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
                                            ${passedTests.map(test => {
                                                const latency = test.Latency && test.Latency !== 'N/A' ? ` (${test.Latency})` : '';
                                                return `<div>✓ ${escapeHtml(test.Test || test.Target)}${latency}</div>`;
                                            }).join('')}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                } else {
                    // Some tests failed
                    html = `
                        <div style="padding: 20px;">
                            <div class="alert alert-danger">
                                <div style="display: flex; align-items: center; gap: 15px;">
                                    <div style="font-size: 2.5rem;">⚠️</div>
                                    <div style="flex: 1;">
                                        <strong>Connectivity Issues Detected (${failedTests.length} failed)</strong>
                                        <div style="margin-top: 15px;">
                                            <strong>Failed Tests:</strong>
                                            <div style="margin-top: 10px; display: grid; gap: 8px;">
                                                ${failedTests.map(test => `
                                                    <div style="padding: 10px; background: rgba(0,0,0,0.2); border-radius: 4px;">
                                                        ✗ ${escapeHtml(test.Test || test.Target)} - ${test.Latency === 'Timeout' ? 'Connection timeout' : 'Unreachable'}
                                                    </div>
                                                `).join('')}
                                            </div>
                                        </div>
                                        ${passedTests.length > 0 ? `
                                            <div style="margin-top: 15px;">
                                                <strong>Passed Tests:</strong>
                                                <div style="margin-top: 10px; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
                                                    ${passedTests.map(test => {
                                                        const latency = test.Latency && test.Latency !== 'N/A' ? ` (${test.Latency})` : '';
                                                        return `<div>✓ ${escapeHtml(test.Test || test.Target)}${latency}</div>`;
                                                    }).join('')}
                                                </div>
                                            </div>
                                        ` : ''}
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }
            } else {
                html = '<div style="padding: 20px; text-align: center; color: var(--text-muted);">No connectivity tests available</div>';
            }

            section.innerHTML = html;
        }

        function loadActiveAdaptersSection(net) {
            const section = document.getElementById('activeAdaptersSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            if (net.ActiveAdapters && net.ActiveAdapters.length > 0) {
                net.ActiveAdapters.forEach((adapter, index) => {
                    const isPrimary = adapter.DefaultGateway || index === 0;
                    const isConnected = adapter.Status === 'Up' || adapter.Status === 'Connected';

                    // Build column content based on connection status
                    let col1, col2, col3;

                    if (isConnected) {
                        // Connected adapter - show network details
                        col1 = `
                            <strong>IP Address:</strong> ${escapeHtml(adapter.IPAddress || 'N/A')}<br>
                            <strong>MAC Address:</strong> ${escapeHtml(adapter.MacAddress || 'N/A')}<br>
                            <strong>Speed:</strong> ${escapeHtml(adapter.LinkSpeed || adapter.Speed || 'N/A')}
                        `;
                        col2 = `
                            <strong>Gateway:</strong> ${escapeHtml(adapter.DefaultGateway || 'N/A')}<br>
                            <strong>DNS Servers:</strong> ${escapeHtml(adapter.DNSServers || 'N/A')}<br>
                            <strong>DHCP:</strong> ${adapter.DHCPEnabled !== undefined ? (adapter.DHCPEnabled ? 'Enabled' : 'Disabled') : 'N/A'}
                        `;

                        // Third column - wireless info or general info
                        if (adapter.SignalStrength || adapter.Channel || adapter.Security) {
                            col3 = `
                                <strong>Signal Strength:</strong> ${escapeHtml(adapter.SignalStrength || 'N/A')}<br>
                                <strong>Channel:</strong> ${escapeHtml(adapter.Channel || 'N/A')}<br>
                                <strong>Security:</strong> ${escapeHtml(adapter.Security || 'N/A')}
                            `;
                        } else {
                            col3 = `
                                <strong>Type:</strong> ${escapeHtml(adapter.AdapterType || adapter.ConnectionType || 'N/A')}<br>
                                <strong>Driver Version:</strong> ${escapeHtml(adapter.DriverVersion || 'N/A')}<br>
                                <strong>Driver Date:</strong> ${escapeHtml(adapter.DriverDate || 'N/A')}
                            `;
                        }
                    } else {
                        // Disconnected adapter - show hardware/driver info
                        col1 = `
                            <strong>Type:</strong> ${escapeHtml(adapter.AdapterType || adapter.ConnectionType || 'Ethernet')}<br>
                            <strong>Status:</strong> ${escapeHtml(adapter.StatusDescription || 'Cable unplugged')}<br>
                            <strong>Speed:</strong> N/A
                        `;
                        col2 = `
                            <strong>MAC Address:</strong> ${escapeHtml(adapter.MacAddress || 'N/A')}<br>
                            <strong>DHCP:</strong> ${adapter.DHCPEnabled !== undefined ? (adapter.DHCPEnabled ? 'Enabled' : 'Disabled') : 'N/A'}<br>
                            <strong>Wake-on-LAN:</strong> ${escapeHtml(adapter.WakeOnLAN || 'Unknown')}
                        `;
                        col3 = `
                            <strong>Driver Version:</strong> ${escapeHtml(adapter.DriverVersion || 'N/A')}<br>
                            <strong>Driver Date:</strong> ${escapeHtml(adapter.DriverDate || 'N/A')}
                        `;
                    }

                    html += `
                        <div style="background: var(--bg-tertiary); border-radius: 6px; padding: 15px; margin-bottom: 15px; ${isPrimary && isConnected ? 'border-left: 4px solid var(--success-color);' : ''}">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                                <strong style="font-size: 1.1rem;">${escapeHtml(adapter.Name || 'Network Adapter')}${isPrimary ? ' (Primary)' : ''}</strong>
                                <span class="status-badge ${isConnected ? 'status-healthy' : ''}" style="${!isConnected ? 'background: #666; color: white;' : ''}">
                                    ${isConnected ? 'Connected' : 'Disconnected'}
                                </span>
                            </div>
                            <div class="grid grid-3">
                                <div>${col1}</div>
                                <div>${col2}</div>
                                <div>${col3}</div>
                            </div>
                        </div>
                    `;
                });
            } else {
                html += '<div style="text-align: center; color: var(--text-muted);">No active network adapters found</div>';
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadFirewallSecuritySection(net) {
            const section = document.getElementById('firewallSecuritySection');
            if (!section) return;

            const firewallEnabled = net.Firewall?.Enabled !== false;
            const firewallProfiles = net.Firewall?.ActiveProfiles || net.Firewall?.Profile || 'Unknown';
            const networkProfile = net.Configuration?.NetworkCategory || net.Configuration?.NetworkProfile || 'Unknown';

            let html = `
                <div class="grid grid-3">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${firewallEnabled ? 'var(--success-color)' : 'var(--danger-color)'};">
                            ${firewallEnabled ? '✓' : '✗'}
                        </div>
                        <div class="metric-label">Windows Firewall</div>
                        <div class="metric-sublabel">${firewallEnabled ? 'Enabled' : 'Disabled'}${firewallProfiles !== 'Unknown' ? ` (${escapeHtml(firewallProfiles)})` : ''}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${net.Security?.NetworkProtection ? 'var(--success-color)' : 'inherit'};">
                            ${net.Security?.NetworkProtection ? '✓' : '—'}
                        </div>
                        <div class="metric-label">Network Protection</div>
                        <div class="metric-sublabel">${net.Security?.NetworkProtection ? 'Active' : 'Not configured'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${escapeHtml(networkProfile)}</div>
                        <div class="metric-label">Network Profile</div>
                        <div class="metric-sublabel">${networkProfile === 'Private' || networkProfile === 'DomainAuthenticated' ? 'Trusted network' : networkProfile === 'Public' ? 'Public network' : 'Unknown'}</div>
                    </div>
                </div>
            `;

            section.innerHTML = html;
        }

        function loadDnsConfigSection(net) {
            const section = document.getElementById('dnsConfigSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            // DNS Servers
            const primaryDNS = net.Configuration?.PrimaryDNS || net.DNS?.Primary || 'N/A';
            const secondaryDNS = net.Configuration?.SecondaryDNS || net.DNS?.Secondary || 'N/A';
            const dnsSuffix = net.DNS?.Suffix || net.Configuration?.DNSSuffix || 'None';

            html += `
                <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px; margin-bottom: 15px;">
                    <h3 style="margin-bottom: 10px; color: var(--accent-color);">DNS Servers</h3>
                    <div style="display: grid; gap: 8px;">
                        <div><strong>Primary:</strong> ${escapeHtml(primaryDNS)}</div>
                        ${secondaryDNS !== 'N/A' ? `<div><strong>Secondary:</strong> ${escapeHtml(secondaryDNS)}</div>` : ''}
                        <div><strong>DNS Suffix:</strong> ${escapeHtml(dnsSuffix)}</div>
                    </div>
                </div>
            `;

            // DNS Cache Statistics (if available)
            if (net.DNS?.Cache) {
                html += `
                    <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                        <h3 style="margin-bottom: 10px; color: var(--accent-color);">DNS Cache Statistics</h3>
                        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                            ${net.DNS.Cache.Entries ? `<div><strong>Cached Entries:</strong> ${net.DNS.Cache.Entries}</div>` : ''}
                            ${net.DNS.Cache.Hits ? `<div><strong>Cache Hits:</strong> ${net.DNS.Cache.Hits.toLocaleString()}</div>` : ''}
                            ${net.DNS.Cache.Misses ? `<div><strong>Cache Misses:</strong> ${net.DNS.Cache.Misses.toLocaleString()}</div>` : ''}
                            ${net.DNS.Cache.HitRate ? `<div><strong>Hit Rate:</strong> ${net.DNS.Cache.HitRate}%</div>` : ''}
                        </div>
                    </div>
                `;
            }

            html += '</div>';
            section.innerHTML = html;
        }

        function loadRoutingTableSection(net) {
            const section = document.getElementById('routingTableSection');
            if (!section) return;

            let html = '<div style="padding: 20px;">';

            if (net.RoutingTable && net.RoutingTable.length > 0) {
                html += '<div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;"><div style="display: grid; gap: 10px;">';

                // Filter to show only important routes
                const importantRoutes = [];

                // 1. Default IPv4 route
                const defaultRoute = net.RoutingTable.find(r =>
                    (r.DestinationPrefix === '0.0.0.0/0' || r.Destination === '0.0.0.0/0') && r.NextHop && r.NextHop !== 'On-link' && r.NextHop !== '0.0.0.0' && r.NextHop !== '::'
                );
                if (defaultRoute) {
                    importantRoutes.push({
                        label: 'Default Route',
                        destination: '0.0.0.0/0',
                        gateway: defaultRoute.NextHop || defaultRoute.Gateway
                    });
                }

                // 2. Local network routes (private IP ranges, excluding host routes)
                const localRoutes = net.RoutingTable.filter(r => {
                    const dest = r.DestinationPrefix || r.Destination || '';
                    return (dest.startsWith('192.168.') || dest.startsWith('10.') || dest.startsWith('172.16.') || dest.startsWith('172.17.') || dest.startsWith('172.18.') || dest.startsWith('172.19.') || dest.startsWith('172.2') || dest.startsWith('172.30.') || dest.startsWith('172.31.')) &&
                           !dest.includes('/32') && // Exclude host routes
                           dest.includes('/');
                });
                if (localRoutes.length > 0) {
                    const localRoute = localRoutes[0]; // Take first local network route
                    importantRoutes.push({
                        label: 'Local Network',
                        destination: localRoute.DestinationPrefix || localRoute.Destination,
                        gateway: '(Direct)'
                    });
                }

                // 3. Loopback route
                const loopbackRoute = net.RoutingTable.find(r => {
                    const dest = r.DestinationPrefix || r.Destination || '';
                    return dest.startsWith('127.') || dest === '127.0.0.0/8';
                });
                if (loopbackRoute) {
                    importantRoutes.push({
                        label: 'Loopback',
                        destination: loopbackRoute.DestinationPrefix || loopbackRoute.Destination || '127.0.0.0/8',
                        gateway: '(Direct)'
                    });
                }

                // Display important routes
                importantRoutes.forEach(route => {
                    html += `
                        <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px;">
                            <strong>${route.label}:</strong> ${escapeHtml(route.destination)} ${route.gateway ? (route.gateway === '(Direct)' ? route.gateway : `via ${escapeHtml(route.gateway)}`) : ''}
                        </div>
                    `;
                });

                // If no important routes found, show fallback
                if (importantRoutes.length === 0) {
                    html += `
                        <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px; color: var(--text-muted);">
                            No standard routes found
                        </div>
                    `;
                }

                html += '</div></div>';
            } else {
                // Show basic routing info if detailed table not available
                const defaultGateway = net.Configuration?.DefaultGateway;
                const subnet = net.Configuration?.Subnet || net.ActiveAdapters?.[0]?.Subnet;

                html += `
                    <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                        <div style="display: grid; gap: 10px;">
                            ${defaultGateway ? `
                                <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px;">
                                    <strong>Default Route:</strong> 0.0.0.0/0 via ${escapeHtml(defaultGateway)}
                                </div>
                            ` : ''}
                            ${subnet ? `
                                <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px;">
                                    <strong>Local Network:</strong> ${escapeHtml(subnet)} (Direct)
                                </div>
                            ` : ''}
                            <div style="padding: 10px; background: var(--bg-secondary); border-radius: 4px;">
                                <strong>Loopback:</strong> 127.0.0.0/8 (Direct)
                            </div>
                        </div>
                    </div>
                `;
            }

            html += '</div>';
            section.innerHTML = html;
        }
