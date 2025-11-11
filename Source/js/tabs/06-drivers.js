        function loadDriversTab() {
            const drivers = systemData.Drivers;
            if (!drivers) {
                document.getElementById('criticalDriverIssues').innerHTML = '<div class="text-center text-muted">No driver data available</div>';
                return;
            }
        }
        
        // Note: Duplicate function stubs removed - actual implementations follow later in file
        
        /* BROKEN CODE REMOVED - Network HTML template strings that were incorrectly placed here 
                                        `<div style="margin-top: 10px;"><strong>Search Domains:</strong><br>
                                        ${net.Configuration.SearchDomains.map(d => `• ${d}`).join('<br>')}</div>` : ''}
                                </div>
                            </div>
                            ${adapter.Statistics ? `
                                <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid var(--border-color);">
                                    <h4 style="margin-bottom: 10px;">Traffic Statistics</h4>
                                    <div class="grid grid-4">
                                        <div><strong>Sent:</strong> ${adapter.Statistics.BytesSent}</div>
                                        <div><strong>Received:</strong> ${adapter.Statistics.BytesReceived}</div>
                                        <div><strong>Packets Sent:</strong> ${adapter.Statistics.PacketsSent || 'N/A'}</div>
                                        <div><strong>Packets Received:</strong> ${adapter.Statistics.PacketsReceived || 'N/A'}</div>
                                        ${adapter.Statistics.SendErrors ? `<div><strong>Send Errors:</strong> ${adapter.Statistics.SendErrors}</div>` : ''}
                                        ${adapter.Statistics.ReceiveErrors ? `<div><strong>Receive Errors:</strong> ${adapter.Statistics.ReceiveErrors}</div>` : ''}
                                        ${adapter.Statistics.Discards ? `<div><strong>Discards:</strong> ${adapter.Statistics.Discards}</div>` : ''}
                                    </div>
                                </div>
                            ` : ''}
                        </div>
                    `;
                    }).join('');
                } else if (net.Configuration) {
                    // If no active adapters but we have configuration, show configuration only
                    adaptersHtml += `
                        <div class="card" style="margin: 10px 0;">
                            <div class="card-header">
                                <strong>Primary Network Configuration</strong>
                            </div>
                            <div class="grid grid-2">
                                <div>
                                    <h4>IP Configuration</h4>
                                    <div style="margin-top: 10px;">
                                        <strong>Primary IP:</strong> ${net.Configuration.PrimaryIP || 'Not configured'}<br>
                                        <strong>Subnet Mask:</strong> ${net.Configuration.SubnetMask || 'Not configured'}<br>
                                        <strong>Default Gateway:</strong> ${net.Configuration.DefaultGateway || 'Not configured'}<br>
                                        <strong>DHCP Enabled:</strong> ${net.Configuration.DHCPEnabled ? 'Yes' : 'No'}<br>
                                        ${net.Configuration.DHCPServer ? `<strong>DHCP Server:</strong> ${net.Configuration.DHCPServer}<br>` : ''}
                                    </div>
                                </div>
                                <div>
                                    <h4>DNS Configuration</h4>
                                    <div style="margin-top: 10px;">
                                        <strong>Primary DNS:</strong> ${net.Configuration.PrimaryDNS || 'Not configured'}<br>
                                        <strong>Secondary DNS:</strong> ${net.Configuration.SecondaryDNS || 'Not configured'}<br>
                                        ${net.Configuration.DNSSuffix && net.Configuration.DNSSuffix.length > 0 ? 
                                            `<strong>DNS Suffixes:</strong><br><ol style="margin: 5px 0; padding-left: 20px;">${
                                                Array.isArray(net.Configuration.DNSSuffix) 
                                                    ? net.Configuration.DNSSuffix.map(suffix => `<li>${suffix}</li>`).join('')
                                                    : `<li>${net.Configuration.DNSSuffix}</li>`
                                            }</ol>` : ''}
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                document.getElementById('adaptersContent').innerHTML = adaptersHtml;
                document.getElementById('adapterCount').textContent = net.ActiveAdapters ? 
                    `${net.ActiveAdapters.length} active adapter${net.ActiveAdapters.length !== 1 ? 's' : ''}` : 
                    'Configuration only';
            }
            
            // Network Performance Metrics
            if (net.Performance) {
                let performanceHealth = 'Healthy';
                const perf = net.Performance;
                
                // Determine performance health status
                if (perf.PacketLoss > 3) performanceHealth = 'Critical';
                else if (perf.PacketLoss > 1) performanceHealth = 'Warning';
                else if (perf.TCPRetransmissions > 50) performanceHealth = 'Critical';
                else if (perf.TCPRetransmissions > 10) performanceHealth = 'Warning';
                else if (perf.NetworkQueueLength > 10) performanceHealth = 'Critical';
                else if (perf.NetworkQueueLength > 2) performanceHealth = 'Warning';
                
                updateHealthStatus('performanceHealthStatus', performanceHealth);
                
                // Build performance metrics HTML
                let performanceHtml = `
                    <div class="grid grid-4" style="margin-bottom: 20px;">
                        <div class="metric-card">
                            <div class="metric-label">Total Bandwidth Usage</div>
                            <div class="metric-value">${perf.BandwidthUsage}</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-label">Packet Loss</div>
                            <div class="metric-value" data-status="${perf.PacketLoss > 3 ? 'critical' : perf.PacketLoss > 1 ? 'warning' : 'healthy'}">${perf.PacketLoss}%</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-label">TCP Retransmissions/sec</div>
                            <div class="metric-value" data-status="${perf.TCPRetransmissions > 50 ? 'critical' : perf.TCPRetransmissions > 10 ? 'warning' : 'healthy'}">${perf.TCPRetransmissions}</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-label">Active Connections</div>
                            <div class="metric-value">${perf.ActiveConnections}</div>
                        </div>
                    </div>
                `;
                
                // Connection Metrics
                if (perf.ConnectionMetrics) {
                    const conn = perf.ConnectionMetrics;
                    performanceHtml += `
                        <div class="grid grid-2" style="margin-bottom: 20px;">
                            <div class="card" style="padding: 15px;">
                                <h3>TCP Connection States</h3>
                                <div class="grid grid-2" style="margin-top: 10px;">
                                    <div><strong>Established:</strong> ${conn.Established || 0}</div>
                                    <div><strong>Listening:</strong> ${conn.Listening || 0}</div>
                                    <div><strong>Time Wait:</strong> ${conn.TimeWait || 0}</div>
                                    <div><strong>Close Wait:</strong> ${conn.CloseWait || 0}</div>
                                </div>
                                <div style="margin-top: 10px;"><strong>Total Connections:</strong> ${conn.Total || 0}</div>
                            </div>
                            <div class="card" style="padding: 15px;">
                                <h3>TCP Performance</h3>
                                <div style="margin-top: 10px;">
                                    ${conn.SegmentsSentSec !== undefined ? `<div><strong>Segments Sent/sec:</strong> ${conn.SegmentsSentSec}</div>` : ''}
                                    ${conn.SegmentsReceivedSec !== undefined ? `<div><strong>Segments Received/sec:</strong> ${conn.SegmentsReceivedSec}</div>` : ''}
                                    ${conn.Failures !== undefined ? `<div><strong>Connection Failures:</strong> ${conn.Failures}</div>` : ''}
                                    ${conn.Resets !== undefined ? `<div><strong>Connection Resets:</strong> ${conn.Resets}</div>` : ''}
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                // Interface Statistics Summary
                if (perf.InterfaceStatistics) {
                    const ifStats = perf.InterfaceStatistics;
                    performanceHtml += `
                        <div class="card" style="padding: 15px; margin-bottom: 20px;">
                            <h3>Interface Statistics Summary</h3>
                            <div class="grid grid-3" style="margin-top: 10px;">
                                <div><strong>Total Interfaces:</strong> ${ifStats.TotalInterfaces}</div>
                                <div><strong>Combined Throughput:</strong> ${ifStats.TotalThroughput}</div>
                                <div><strong>Average Utilization:</strong> ${ifStats.AvgUtilization}%</div>
                                <div><strong>Total Packets/sec:</strong> ${ifStats.TotalPacketsPerSec}</div>
                                <div><strong>Max Queue Length:</strong> ${ifStats.MaxQueueLength}</div>
                            </div>
                        </div>
                    `;
                }
                
                // Per-Interface Metrics
                if (perf.ThroughputMetrics && Object.keys(perf.ThroughputMetrics).length > 0) {
                    performanceHtml += `
                        <div class="collapsible" onclick="toggleCollapsible(this)" style="cursor: pointer; padding: 10px; border: 1px solid var(--border-color); border-radius: 4px; margin-bottom: 10px;">
                            <h3>Per-Interface Detailed Metrics</h3>
                            <span>▼</span>
                        </div>
                        <div class="collapsible-content" style="display: none;">
                    `;
                    
                    Object.entries(perf.ThroughputMetrics).forEach(([interfaceName, metrics]) => {
                        const utilStatus = metrics.UtilizationPercent > 80 ? 'critical' : 
                                          metrics.UtilizationPercent > 60 ? 'warning' : 'healthy';
                        
                        performanceHtml += `
                            <div class="card" style="padding: 15px; margin-bottom: 10px;">
                                <div class="card-header" style="padding-bottom: 10px;">
                                    <strong>${interfaceName}</strong>
                                    <span class="status-badge status-${utilStatus}">${metrics.UtilizationPercent}% Utilization</span>
                                </div>
                                <div class="grid grid-3">
                                    <div><strong>Total:</strong> ${metrics.BytesTotalSec}</div>
                                    <div><strong>Sent:</strong> ${metrics.BytesSentSec}</div>
                                    <div><strong>Received:</strong> ${metrics.BytesReceivedSec}</div>
                                    <div><strong>Packets/sec:</strong> ${metrics.PacketsSec}</div>
                                    <div><strong>Queue Length:</strong> ${metrics.QueueLength}</div>
                                </div>
                            </div>
                        `;
                    });
                    
                    performanceHtml += `</div>`;
                }
                
                document.getElementById('networkPerformanceContent').innerHTML = performanceHtml;
            } else {
                document.getElementById('networkPerformanceContent').innerHTML = 
                    '<div class="text-center text-muted">Network performance data not available</div>';
            }
            
            // Connectivity Tests
            if (net.ConnectivityTests?.Tests) {
                const testsHtml = `
                    <table>
                        <thead>
                            <tr>
                                <th>Test</th>
                                <th>Target</th>
                                <th>Result</th>
                                <th>Latency</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${net.ConnectivityTests.Tests.map(test => `
                                <tr>
                                    <td>${test.Test}</td>
                                    <td>${test.Target}</td>
                                    <td>
                                        <span class="status-badge status-${test.Result === 'Pass' ? 'healthy' : 'critical'}">
                                            ${test.Result}
                                        </span>
                                    </td>
                                    <td>${test.Latency}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                `;
                document.getElementById('connectivityContent').innerHTML = testsHtml;
                updateHealthStatus('connectivityStatus', net.ConnectivityTests.Summary?.OverallStatus);
            }
            
            // WiFi Details
            if (net.WiFiDetails && net.WiFiDetails.State === 'connected') {
                document.getElementById('wifiCard').classList.remove('hidden');
                const wifiHtml = `
                    <div class="grid grid-2">
                        <div><strong>SSID:</strong> ${net.WiFiDetails.SSID}</div>
                        <div><strong>Signal:</strong> ${net.WiFiDetails.SignalStrength}% (${net.WiFiDetails.SignalQuality})</div>
                        <div><strong>Band:</strong> ${net.WiFiDetails.Band}</div>
                        <div><strong>Channel:</strong> ${net.WiFiDetails.Channel}</div>
                        <div><strong>Transmit Rate:</strong> ${net.WiFiDetails.TransmitRate}</div>
                        <div><strong>Security:</strong> ${net.WiFiDetails.SecurityType}</div>
                    </div>
                `;
                document.getElementById('wifiContent').innerHTML = wifiHtml;
                updateHealthStatus('wifiStatus', net.WiFiDetails.Status);
            }
            
            // Additional Network Configuration (Firewall, Network Profiles, etc.)
            if (net.Configuration) {
                const config = net.Configuration;
                let configHtml = '';
                
                // Add section header if we have any additional configuration to show
                if ((config.RoutingTable && config.RoutingTable.length > 0) || 
                    config.NetworkProfiles || config.NetworkDiscovery || config.FileSharing) {
                    configHtml += '<h3 style="margin-top: 30px; margin-bottom: 15px;">Additional Network Settings</h3>';
                }
                
                // Routing Table Summary
                if (config.RoutingTable && config.RoutingTable.length > 0) {
                    configHtml += `
                        <div style="margin-top: 15px;">
                            <h4>Routing Table (${config.RoutingTable.length} routes)</h4>
                            <table style="width: 100%; margin-top: 10px;">
                                <thead>
                                    <tr>
                                        <th>Destination</th>
                                        <th>Gateway</th>
                                        <th>Interface</th>
                                        <th>Metric</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${config.RoutingTable.slice(0, 10).map(route => `
                                        <tr>
                                            <td>${route.Destination}</td>
                                            <td>${route.Gateway}</td>
                                            <td>${route.Interface}</td>
                                            <td>${route.Metric}</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                            ${config.RoutingTable.length > 10 ? 
                                `<div class="text-muted" style="margin-top: 10px;">Showing first 10 of ${config.RoutingTable.length} routes</div>` : ''}
                        </div>`;
                }
                
                
                // Network Profiles
                if (config.NetworkProfiles && config.NetworkProfiles.length > 0) {
                    configHtml += `
                        <div style="margin-top: 15px;">
                            <h4>Network Profiles</h4>
                            <div class="grid grid-2" style="margin-top: 10px;">
                                ${config.NetworkProfiles.map(profile => `
                                    <div class="card" style="padding: 10px;">
                                        <strong>${escapeHtml(profile.Name)}</strong>
                                        <div style="margin-top: 5px; font-size: 0.9em;">
                                            <div>Interface: ${escapeHtml(profile.InterfaceAlias)}</div>
                                            <div>Category: ${escapeHtml(profile.NetworkCategory)}</div>
                                            <div>IPv4: ${escapeHtml(profile.IPv4Connectivity || 'N/A')}</div>
                                            <div>IPv6: ${escapeHtml(profile.IPv6Connectivity || 'N/A')}</div>
                                        </div>
                                    </div>
                                `).join('')}
                            </div>
                        </div>`;
                }
                
                // Network Discovery and File Sharing
                if (config.NetworkDiscovery || config.FileSharing) {
                    configHtml += `
                        <div style="margin-top: 15px;">
                            <h4>Network Features</h4>
                            <div class="grid grid-2" style="margin-top: 10px;">
                                ${config.NetworkDiscovery ? `
                                    <div>
                                        <strong>Network Discovery:</strong>
                                        <span class="status-badge status-${config.NetworkDiscovery === 'Enabled' ? 'healthy' : 'warning'}">
                                            ${config.NetworkDiscovery}
                                        </span>
                                    </div>` : ''}
                                ${config.FileSharing ? `
                                    <div>
                                        <strong>File & Printer Sharing:</strong>
                                        <span class="status-badge status-${config.FileSharing === 'Enabled' ? 'healthy' : 'warning'}">
                                            ${config.FileSharing}
                                        </span>
                                    </div>` : ''}
                            </div>
                        </div>`;
                }
                
                // Only render if we have content
                if (configHtml) {
                    document.getElementById('networkConfigContent').innerHTML = configHtml;
                } else {
                    document.getElementById('networkConfigContent').innerHTML = '';
                }
            } else {
                document.getElementById('networkConfigContent').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">Network configuration data not available</div>';
            }
            
            // Routing Table
            if (net.RoutingTable && net.RoutingTable.length > 0) {
                const routingHtml = `
                    <div style="overflow-x: auto;">
                        <table style="width: 100%;">
                            <thead>
                                <tr>
                                    <th>Destination</th>
                                    <th>Next Hop</th>
                                    <th>Interface</th>
                                    <th>Metric</th>
                                    <th>Type</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${net.RoutingTable.map(route => `
                                    <tr>
                                        <td><code>${route.DestinationPrefix || 'Unknown'}</code></td>
                                        <td><code>${route.NextHop || '-'}</code></td>
                                        <td>${route.InterfaceAlias || 'Unknown'}</td>
                                        <td>${route.RouteMetric || '-'}</td>
                                        <td><span class="status-badge status-info">${route.Type && typeof route.Type === 'object' ? (route.Type.Name || route.Type.Value || JSON.stringify(route.Type)) : (route.Type || route.Protocol || 'Unknown')}</span></td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>`;
                
                document.getElementById('routingTableContent').innerHTML = routingHtml;
                document.getElementById('routingTableCount').textContent = `${net.RoutingTable.length} routes`;
            } else {
                document.getElementById('routingTableContent').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">No routing table data available</div>';
                document.getElementById('routingTableCount').textContent = '0 routes';
            }
            
            // Firewall Rules
            if (net.FirewallRules) {
                const fw = net.FirewallRules;
                let firewallHtml = '';
                
                // Firewall Summary
                if (fw.Summary) {
                    const allEnabled = fw.Summary.DomainEnabled && fw.Summary.PrivateEnabled && fw.Summary.PublicEnabled;
                    updateHealthStatus('firewallStatus', allEnabled ? 'Healthy' : 'Warning');
                    
                    firewallHtml += `
                        <div class="grid grid-3" style="margin-bottom: 20px;">
                            <div class="metric-card">
                                <div class="metric-label">Domain Profile</div>
                                <div class="status-badge status-${fw.Summary.DomainEnabled ? 'healthy' : 'critical'}">
                                    ${fw.Summary.DomainEnabled ? 'Enabled' : 'Disabled'}
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Private Profile</div>
                                <div class="status-badge status-${fw.Summary.PrivateEnabled ? 'healthy' : 'critical'}">
                                    ${fw.Summary.PrivateEnabled ? 'Enabled' : 'Disabled'}
                                </div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Public Profile</div>
                                <div class="status-badge status-${fw.Summary.PublicEnabled ? 'healthy' : 'critical'}">
                                    ${fw.Summary.PublicEnabled ? 'Enabled' : 'Disabled'}
                                </div>
                            </div>
                        </div>`;
                    
                    firewallHtml += `
                        <div class="grid grid-2" style="margin-bottom: 20px;">
                            <div class="metric-card">
                                <div class="metric-label">Total Rules</div>
                                <div class="metric-value">${fw.Summary.TotalRules || 0}</div>
                            </div>
                            <div class="metric-card">
                                <div class="metric-label">Enabled Rules</div>
                                <div class="metric-value">${fw.Summary.EnabledRules || 0}</div>
                            </div>
                        </div>`;
                }
                
                // Profile Details
                if (fw.Profiles && fw.Profiles.length > 0) {
                    firewallHtml += `
                        <div class="card" style="margin: 15px 0;">
                            <div class="card-header collapsible" onclick="toggleCollapsible(this)" style="cursor: pointer;">
                                <strong>Profile Details</strong>
                                <span style="float: right;">▼</span>
                            </div>
                            <div class="collapsible-content" style="display: none;">
                                <table style="width: 100%;">
                                    <thead>
                                        <tr>
                                            <th>Profile</th>
                                            <th>Status</th>
                                            <th>Default Inbound</th>
                                            <th>Default Outbound</th>
                                            <th>Notifications</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${fw.Profiles.map(profile => `
                                            <tr>
                                                <td><strong>${escapeHtml(profile.Name)}</strong></td>
                                                <td>
                                                    <span class="status-badge status-${profile.Enabled ? 'healthy' : 'critical'}">
                                                        ${profile.Enabled ? 'Enabled' : 'Disabled'}
                                                    </span>
                                                </td>
                                                <td>${escapeHtml(profile.DefaultInboundAction || 'Block')}</td>
                                                <td>${escapeHtml(profile.DefaultOutboundAction || 'Allow')}</td>
                                                <td>${profile.NotifyOnListen ? 'Yes' : 'No'}</td>
                                            </tr>
                                        `).join('')}
                                    </tbody>
                                </table>
                            </div>
                        </div>`;
                }
                
                // Top Applications
                if (fw.TopApplications && fw.TopApplications.length > 0) {
                    firewallHtml += `
                        <div class="card" style="margin: 15px 0;">
                            <div class="card-header collapsible" onclick="toggleCollapsible(this)" style="cursor: pointer;">
                                <strong>Top Applications with Rules</strong>
                                <span style="float: right;">▼</span>
                            </div>
                            <div class="collapsible-content" style="display: none;">
                                <table style="width: 100%;">
                                    <thead>
                                        <tr>
                                            <th>Application</th>
                                            <th>Rule Count</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${fw.TopApplications.map(app => `
                                            <tr>
                                                <td>${escapeHtml(app.Application || 'Any')}</td>
                                                <td>${app.RuleCount || app.Count || 0}</td>
                                            </tr>
                                        `).join('')}
                                    </tbody>
                                </table>
                            </div>
                        </div>`;
                }
                
                document.getElementById('firewallContent').innerHTML = firewallHtml;
            } else {
                document.getElementById('firewallContent').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">Firewall configuration data not available</div>';
                updateHealthStatus('firewallStatus', 'Unknown');
            }
            
        }
        */ // END OF BROKEN CODE REMOVAL

        // Load Printers Tab (OLD - DISABLED)
        function loadPrintersTab_OLD() {
            const printers = systemData.Printers;
            if (!printers) {
                // No printers data - show empty state
                document.getElementById('printersOverview').innerHTML = 
                    '<div class="text-center text-muted">No printer data available</div>';
                return;
            }
            
            // Determine overall health status
            let healthStatus = 'Healthy';
            if (printers.SpoolerHealth?.ServiceStatus === 'Stopped') healthStatus = 'Critical';
            else if (printers.Summary?.StuckJobs > 0) healthStatus = 'Warning';
            else if (printers.Summary?.OfflinePrinters === printers.Summary?.TotalPrinters && 
                     printers.Summary?.TotalPrinters > 0) healthStatus = 'Critical';
            
            updateHealthStatus('printersHealthStatus', healthStatus);
            
            // Critical Printer Issues Alert
            const criticalIssues = [];
            if (printers.SpoolerHealth?.ServiceStatus === 'Stopped') {
                criticalIssues.push('Print spooler service is stopped');
            }
            if (printers.Summary?.TotalPrinters > 0 && 
                printers.Summary?.OfflinePrinters === printers.Summary?.TotalPrinters) {
                criticalIssues.push('All printers are offline');
            }
            if (printers.Summary?.StuckJobs > 0) {
                criticalIssues.push(`${printers.Summary.StuckJobs} print job(s) stuck for >1 hour`);
            }
            if (printers.Summary?.FailedJobs > 0) {
                criticalIssues.push(`${printers.Summary.FailedJobs} failed print job(s)`);
            }
            if (printers.Summary?.DriverErrors > 0) {
                criticalIssues.push(`${printers.Summary.DriverErrors} driver error(s) detected`);
            }
            
            if (criticalIssues.length > 0) {
                const alertHtml = `
                    <div class="alert alert-critical mb-20">
                        <strong>⚠️ Critical Printer Issues Detected:</strong>
                        <ul style="margin: 10px 0 0 20px;">
                            ${criticalIssues.map(issue => `<li>${issue}</li>`).join('')}
                        </ul>
                        <div class="mt-20">
                            <strong>Recommended Actions:</strong>
                            ${printers.SpoolerHealth?.ServiceStatus === 'Stopped' ? 
                                '<br>• Restart the Print Spooler service' : ''}
                            ${printers.Summary?.StuckJobs > 0 ? 
                                '<br>• Clear stuck print jobs or restart spooler' : ''}
                            ${printers.Summary?.DriverErrors > 0 ? 
                                '<br>• Update or reinstall printer drivers' : ''}
                        </div>
                    </div>
                `;
                document.getElementById('printersOverview').innerHTML = alertHtml;
            }
            
            // Printer Health Summary
            if (printers.Summary) {
                const summaryHtml = `
                    <div class="grid grid-4">
                        <div class="metric-card">
                            <div class="metric-value">${printers.Summary.TotalPrinters || 0}</div>
                            <div class="metric-label">Total Printers</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: var(--success-color);">
                                ${printers.Summary.OnlinePrinters || 0}
                            </div>
                            <div class="metric-label">Online</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: var(--danger-color);">
                                ${printers.Summary.OfflinePrinters || 0}
                            </div>
                            <div class="metric-label">Offline</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: ${printers.Summary.StuckJobs > 0 ? 'var(--warning-color)' : 'inherit'};">
                                ${printers.Summary.TotalPrintJobs || 0}
                            </div>
                            <div class="metric-label">Queue Jobs</div>
                        </div>
                    </div>
                    <div class="text-center text-muted mt-20">
                        Printer data collected at: ${formatDateISO(new Date(printers.CollectionTimestamp || systemData.CollectionTimestamp))}
                    </div>
                `;
                document.getElementById('printersOverview').innerHTML += summaryHtml;
            }
            
            // Installed Printers - Enhanced display
            if (printers.Printers && printers.Printers.length > 0) {
                const printersHtml = printers.Printers.map(printer => {
                    // Map status codes to display status
                    let statusClass = 'unknown';
                    let statusText = printer.Status || 'Unknown';
                    
                    switch(printer.PrinterStatus) {
                        case 0: case 'Ready': statusClass = 'healthy'; statusText = 'Ready'; break;
                        case 1: case 'Paused': statusClass = 'info'; statusText = 'Paused'; break;
                        case 2: case 'Error': statusClass = 'critical'; statusText = 'Error'; break;
                        case 3: statusClass = 'critical'; statusText = 'Deleting'; break;
                        case 4: statusClass = 'critical'; statusText = 'Paper Jam'; break;
                        case 5: statusClass = 'warning'; statusText = 'Paper Out'; break;
                        case 6: statusClass = 'warning'; statusText = 'Manual Feed'; break;
                        case 7: statusClass = 'warning'; statusText = 'Paper Problem'; break;
                        case 8: case 'Offline': statusClass = 'critical'; statusText = 'Offline'; break;
                        case 9: statusClass = 'healthy'; statusText = 'Printing'; break;
                        case 10: statusClass = 'warning'; statusText = 'Busy'; break;
                        default: 
                            if (printer.Status === 'Ready') statusClass = 'healthy';
                            else if (printer.Status === 'Offline') statusClass = 'critical';
                            else statusClass = 'warning';
                    }
                    
                    // Adjust status if printer has jobs
                    if (printer.JobCount > 0 && statusClass === 'healthy') {
                        statusClass = 'warning';
                        statusText = `Ready (${printer.JobCount} jobs)`;
                    }
                    
                    return `
                        <div class="card" style="margin: 10px 0;">
                            <div class="card-header">
                                <strong>${escapeHtml(printer.Name)}</strong>
                                <span class="status-badge status-${statusClass}">${statusText}</span>
                            </div>
                            <div class="grid grid-2">
                                <div><strong>Driver:</strong> ${escapeHtml(printer.DriverName)} v${escapeHtml(printer.DriverVersion || 'Unknown')}</div>
                                <div><strong>Port:</strong> ${escapeHtml(printer.PortName)}</div>
                                <div><strong>Type:</strong> ${escapeHtml(printer.Type || 'Local')}</div>
                                <div><strong>Sharing:</strong> ${printer.Shared ? `Shared as ${escapeHtml(printer.ShareName)}` : 'Not Shared'}</div>
                            </div>
                            ${printer.IsDefault ? '<div class="mt-20">✅ Default Printer</div>' : ''}
                            ${printer.JobCount > 0 ? `
                                <div class="progress mt-20">
                                    <div class="progress-bar ${printer.JobCount > 10 ? 'warning' : 'info'}" 
                                         style="width: ${Math.min(printer.JobCount * 10, 100)}%">
                                        ${printer.JobCount} job(s) in queue
                                    </div>
                                </div>
                            ` : ''}
                        </div>
                    `;
                }).join('');
                
                document.getElementById('printersContent').innerHTML = printersHtml;
                document.getElementById('printerCount').textContent = 
                    `${printers.Printers.length} printer${printers.Printers.length !== 1 ? 's' : ''}`;
            } else {
                // No printers installed
                document.getElementById('printersContent').innerHTML = `
                    <div class="text-center text-muted p-20">
                        <h3>No Printers Installed</h3>
                        <p>To add a printer, go to Settings > Devices > Printers & scanners</p>
                    </div>
                `;
                document.getElementById('printerCount').textContent = '0 printers';
            }
            
            // Print Queue Monitor - Enhanced with priorities
            if (printers.PrintQueue && printers.PrintQueue.length > 0) {
                document.getElementById('printQueueCard').classList.remove('hidden');
                
                // Sort queue by priority: stuck/failed first, then printing, then pending
                const sortedQueue = [...printers.PrintQueue].sort((a, b) => {
                    if (a.IsStuck && !b.IsStuck) return -1;
                    if (!a.IsStuck && b.IsStuck) return 1;
                    if (a.Status === 'Error' && b.Status !== 'Error') return -1;
                    if (a.Status !== 'Error' && b.Status === 'Error') return 1;
                    if (a.Status === 'Printing' && b.Status !== 'Printing') return -1;
                    if (a.Status !== 'Printing' && b.Status === 'Printing') return 1;
                    return b.TimeInQueueMinutes - a.TimeInQueueMinutes; // Oldest first
                });
                
                // Limit to first 20 jobs initially
                const displayJobs = sortedQueue.slice(0, 20);
                const hasMore = sortedQueue.length > 20;
                
                const queueHtml = `
                    <table>
                        <thead>
                            <tr>
                                <th>Printer</th>
                                <th>Document</th>
                                <th>Status</th>
                                <th>Time in Queue</th>
                                <th>Size</th>
                                <th>User</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${displayJobs.map(job => {
                                let rowClass = '';
                                let timeClass = '';
                                
                                if (job.IsStuck || job.TimeInQueueMinutes > 60) {
                                    rowClass = 'alert-critical';
                                    timeClass = 'text-critical';
                                } else if (job.TimeInQueueMinutes > 30) {
                                    rowClass = 'alert-warning';
                                    timeClass = 'text-warning';
                                }
                                
                                return `
                                    <tr class="${rowClass}">
                                        <td>${escapeHtml(job.PrinterName)}</td>
                                        <td title="${escapeHtml(job.DocumentName)}">${job.DocumentName.length > 30 ?
                                            escapeHtml(job.DocumentName.substring(0, 30)) + '...' : escapeHtml(job.DocumentName)}</td>
                                        <td>
                                            <span class="status-badge status-${
                                                job.Status === 'Error' ? 'critical' :
                                                job.Status === 'Printing' ? 'healthy' :
                                                job.Status === 'Paused' ? 'warning' : 'info'
                                            }">
                                                ${escapeHtml(job.Status)}
                                            </span>
                                        </td>
                                        <td class="${timeClass}">
                                            ${job.TimeInQueueMinutes} min
                                            ${job.IsStuck ? ' ⚠️ STUCK' : ''}
                                        </td>
                                        <td>${job.SizeMB ? job.SizeMB.toFixed(2) + ' MB' : 'Unknown'}</td>
                                        <td>${escapeHtml(job.UserName || 'Unknown')}</td>
                                    </tr>
                                `;
                            }).join('')}
                        </tbody>
                    </table>
                    ${hasMore ? `
                        <div class="text-center mt-20">
                            <button class="action-button" onclick="showAllPrintJobs()">
                                Show All ${sortedQueue.length} Jobs
                            </button>
                        </div>
                    ` : ''}
                `;
                document.getElementById('queueContent').innerHTML = queueHtml;
                document.getElementById('queueCount').textContent = 
                    `${printers.PrintQueue.length} job${printers.PrintQueue.length !== 1 ? 's' : ''} (${printers.Summary?.StuckJobs || 0} stuck)`;
            } else {
                // Hide queue section if empty
                document.getElementById('printQueueCard').classList.add('hidden');
            }
            
            // Print Spooler Health - Enhanced display
            if (printers.SpoolerHealth) {
                const spooler = printers.SpoolerHealth;
                const statusClass = spooler.ServiceStatus === 'Running' ? 'healthy' : 'critical';
                
                // Determine spooler health warnings
                const spoolerWarnings = [];
                if (spooler.MemoryUsageMB > 1000) {
                    spoolerWarnings.push(`High memory usage: ${spooler.MemoryUsageMB} MB`);
                } else if (spooler.MemoryUsageMB > 500) {
                    spoolerWarnings.push(`Elevated memory usage: ${spooler.MemoryUsageMB} MB`);
                }
                
                if (spooler.SpoolFolderSizeMB > 5000) {
                    spoolerWarnings.push(`Critical spool folder size: ${(spooler.SpoolFolderSizeMB / 1024).toFixed(2)} GB`);
                } else if (spooler.SpoolFolderSizeMB > 1000) {
                    spoolerWarnings.push(`Large spool folder: ${(spooler.SpoolFolderSizeMB / 1024).toFixed(2)} GB`);
                }
                
                if (spooler.RecentCrashes > 5) {
                    spoolerWarnings.push(`Critical: ${spooler.RecentCrashes} crashes in last 24 hours`);
                } else if (spooler.RecentCrashes > 2) {
                    spoolerWarnings.push(`Warning: ${spooler.RecentCrashes} crashes in last 24 hours`);
                }
                
                const spoolerHtml = `
                    <div class="grid grid-2">
                        <div>
                            <strong>Service Status:</strong> 
                            <span class="status-badge status-${statusClass}">
                                ${spooler.ServiceStatus}
                            </span>
                        </div>
                        <div><strong>Memory Usage:</strong> ${spooler.MemoryUsageMB} MB</div>
                        <div><strong>Spool Folder:</strong> ${spooler.SpoolFolder || 'C:\\Windows\\System32\\spool\\PRINTERS'}</div>
                        <div><strong>Spool Size:</strong> ${(spooler.SpoolFolderSizeMB / 1024).toFixed(2)} GB</div>
                        <div><strong>Last Restart:</strong> ${spooler.LastRestart ? 
                            formatDateISO(new Date(spooler.LastRestart)) : 'Unknown'}</div>
                        <div><strong>Recent Crashes:</strong> ${spooler.RecentCrashes} (last 24 hours)</div>
                    </div>
                    ${spoolerWarnings.length > 0 ? `
                        <div class="alert alert-warning mt-20">
                            <strong>Spooler Health Issues:</strong>
                            <ul style="margin: 10px 0 0 20px;">
                                ${spoolerWarnings.map(warning => `<li>${warning}</li>`).join('')}
                            </ul>
                            ${spooler.ServiceStatus === 'Stopped' ? 
                                '<br><strong>Action:</strong> Restart the Print Spooler service' :
                                spooler.RecentCrashes > 2 ? 
                                '<br><strong>Action:</strong> Check Event Logs for spooler errors' : ''}
                        </div>
                    ` : ''}
                    ${spooler.EventLogErrors && spooler.EventLogErrors.length > 0 ? `
                        <div class="mt-20">
                            <strong>Recent Spooler Errors:</strong>
                            <ul style="margin: 10px 0 0 20px;">
                                ${spooler.EventLogErrors.slice(0, 5).map(error =>
                                    `<li>${escapeHtml(error.Message)} (${formatDateISO(new Date(error.TimeCreated))})</li>`
                                ).join('')}
                            </ul>
                        </div>
                    ` : ''}
                `;
                document.getElementById('spoolerContent').innerHTML = spoolerHtml;
                updateHealthStatus('spoolerStatus', 
                    spooler.ServiceStatus === 'Running' ? 
                        (spoolerWarnings.length > 0 ? 'Warning' : 'Healthy') : 'Critical');
            }
            
            // Add additional sections if available
            addPrinterDriversSection(printers);
            addPrinterUsageStatistics(printers);
        }
        
        // Helper function to show all print jobs
        window.showAllPrintJobs = function() {
            const printers = systemData.Printers;
            if (!printers || !printers.PrintQueue) return;
            
            // Re-render with all jobs
            const sortedQueue = [...printers.PrintQueue].sort((a, b) => {
                if (a.IsStuck && !b.IsStuck) return -1;
                if (!a.IsStuck && b.IsStuck) return 1;
                return b.TimeInQueueMinutes - a.TimeInQueueMinutes;
            });
            
            const queueHtml = `
                <table>
                    <thead>
                        <tr>
                            <th>Printer</th>
                            <th>Document</th>
                            <th>Status</th>
                            <th>Time in Queue</th>
                            <th>Size</th>
                            <th>User</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${sortedQueue.map(job => {
                            let rowClass = job.IsStuck || job.TimeInQueueMinutes > 60 ? 'alert-critical' :
                                          job.TimeInQueueMinutes > 30 ? 'alert-warning' : '';
                            
                            return `
                                <tr class="${rowClass}">
                                    <td>${escapeHtml(job.PrinterName)}</td>
                                    <td title="${escapeHtml(job.DocumentName)}">${escapeHtml(job.DocumentName)}</td>
                                    <td>${escapeHtml(job.Status)}</td>
                                    <td>${job.TimeInQueueMinutes} min ${job.IsStuck ? ' ⚠️' : ''}</td>
                                    <td>${job.SizeMB ? job.SizeMB.toFixed(2) + ' MB' : 'Unknown'}</td>
                                    <td>${escapeHtml(job.UserName || 'Unknown')}</td>
                                </tr>
                            `;
                        }).join('')}
                    </tbody>
                </table>
            `;
            document.getElementById('queueContent').innerHTML = queueHtml;
        };
        
        // Add Printer Drivers Section
        function addPrinterDriversSection(printers) {
            if (!printers || !printers.PrinterDrivers) {
                document.getElementById('printerDriversContent').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">No printer driver data available</div>';
                document.getElementById('driverCount').textContent = '0 drivers';
                return;
            }
            
            const drivers = printers.PrinterDrivers;
            if (drivers.length === 0) {
                document.getElementById('printerDriversContent').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">No printer drivers installed</div>';
                document.getElementById('driverCount').textContent = '0 drivers';
                return;
            }
            
            const driversHtml = `
                <table style="width: 100%;">
                    <thead>
                        <tr>
                            <th>Driver Name</th>
                            <th>Version</th>
                            <th>Environment</th>
                            <th>Printers Using</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${drivers.map(driver => {
                            return `
                                <tr>
                                    <td><strong>${escapeHtml(driver.Name)}</strong></td>
                                    <td>${escapeHtml(driver.DriverVersion || 'Unknown')}</td>
                                    <td>${escapeHtml(driver.Environment || 'Windows x64')}</td>
                                    <td>${driver.PrintersUsing ? escapeHtml(driver.PrintersUsing.join(', ')) : 'None'}</td>
                                </tr>
                            `;
                        }).join('')}
                    </tbody>
                </table>`;
            
            document.getElementById('printerDriversContent').innerHTML = driversHtml;
            document.getElementById('driverCount').textContent = `${drivers.length} drivers`;
        }
        
        
        // Add Printer Usage Statistics
        function addPrinterUsageStatistics(printers) {
            if (!printers.UsageStatistics) return;
            
            const stats = printers.UsageStatistics;
            const usageCard = document.createElement('div');
            usageCard.className = 'card';
            usageCard.innerHTML = `
                <div class="collapsible" onclick="toggleCollapsible(this)">
                    <h2 class="card-title">Usage Statistics</h2>
                    <span>▼</span>
                </div>
                <div class="collapsible-content">
                    <div class="grid grid-4" style="margin-top: 15px;">
                        <div class="metric-card">
                            <div class="metric-value">${stats.TotalPagesToday || 0}</div>
                            <div class="metric-label">Pages Today</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${stats.TotalJobsToday || 0}</div>
                            <div class="metric-label">Jobs Today</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${stats.AverageJobSize || 0}</div>
                            <div class="metric-label">Avg Job Size</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${stats.MostActivePrinter || 'None'}</div>
                            <div class="metric-label">Most Active</div>
                        </div>
                    </div>
                </div>
            `;
            document.getElementById('printers').appendChild(usageCard);
        }
        
        // Toggle Collapsible Sections - unified version
        window.toggleCollapsible = function(element) {
            const content = element.nextElementSibling;
            const arrow = element.querySelector('span:last-child') || element.querySelector('span');
            
            // Handle both display style and show class
            if (content.style.display === 'none' || content.style.display === '') {
                content.style.display = 'block';
                if (content.classList) content.classList.add('show');
                if (arrow) arrow.textContent = '▼';
            } else {
                content.style.display = 'none';
                if (content.classList) content.classList.remove('show');
                if (arrow) arrow.textContent = '▶';
            }
        };

        // SECTION 1: Critical Print Issues & Spooler Health
        function loadPrinterHealthDashboard(printers) {
            const section = document.getElementById('printerHealthDashboard');
            if (!section) return;

            const summary = printers.Summary || {};
            const spoolerStatus = printers.SpoolerHealth?.ServiceStatus || 'Unknown';
            const isSpoolerRunning = spoolerStatus === 'Running';

            // Calculate health score
            let healthScore = 100;
            if (!isSpoolerRunning) healthScore -= 50;
            if (summary.OfflinePrinters > 0) healthScore -= (summary.OfflinePrinters * 10);
            if (summary.StuckJobs > 0) healthScore -= (summary.StuckJobs * 5);
            if (summary.FailedJobs > 0) healthScore -= (summary.FailedJobs * 5);
            healthScore = Math.max(0, Math.min(100, healthScore));

            let healthStatus = 'Healthy';
            let healthColor = 'var(--success-color)';
            if (healthScore < 50) {
                healthStatus = 'Critical';
                healthColor = 'var(--danger-color)';
            } else if (healthScore < 70) {
                healthStatus = 'Poor';
                healthColor = '#fd7e14';
            } else if (healthScore < 90) {
                healthStatus = 'Fair';
                healthColor = 'var(--warning-color)';
            }

            let dashboardHtml = `
                <div class="printer-health-dashboard">
                    <div class="grid grid-4">
                        <div class="event-severity-card ${healthStatus.toLowerCase()}">
                            <div style="text-align: center;">
                                <div style="font-size: 3rem; margin-bottom: 10px;">📊</div>
                                <div class="metric-value" style="font-size: 2.5rem; font-weight: bold; color: ${healthColor};">${healthScore}</div>
                                <div class="metric-label">Health Score</div>
                                <div style="margin-top: 8px;">
                                    <span class="status-badge status-${healthStatus.toLowerCase()}">${healthStatus}</span>
                                </div>
                            </div>
                        </div>
                        <div class="event-severity-card ${isSpoolerRunning ? 'success' : 'critical'}">
                            <div style="text-align: center;">
                                <div class="spooler-icon ${isSpoolerRunning ? 'running' : 'stopped'}">
                                    ${isSpoolerRunning ? '▶️' : '⏸️'}
                                </div>
                                <div class="metric-value" style="font-size: 1.2rem; margin-top: 10px;">${spoolerStatus}</div>
                                <div class="metric-label">Spooler Service</div>
                            </div>
                        </div>
                        <div class="event-severity-card">
                            <div style="text-align: center;">
                                <div style="font-size: 3rem; margin-bottom: 10px;">🖨️</div>
                                <div class="metric-value" style="font-size: 2.5rem;">${summary.TotalPrinters || 0}</div>
                                <div class="metric-label">Total Printers</div>
                                <div style="margin-top: 8px; display: flex; justify-content: center; gap: 10px;">
                                    <span class="printer-status-indicator online">🟢 ${summary.OnlinePrinters || 0}</span>
                                    <span class="printer-status-indicator offline">🔴 ${summary.OfflinePrinters || 0}</span>
                                </div>
                            </div>
                        </div>
                        <div class="event-severity-card ${summary.StuckJobs > 0 || summary.FailedJobs > 0 ? 'warning' : ''}">
                            <div style="text-align: center;">
                                <div style="font-size: 3rem; margin-bottom: 10px;">📄</div>
                                <div class="metric-value" style="font-size: 2.5rem; color: ${summary.StuckJobs > 0 || summary.FailedJobs > 0 ? 'var(--warning-color)' : 'inherit'};">
                                    ${(summary.StuckJobs || 0) + (summary.FailedJobs || 0)}
                                </div>
                                <div class="metric-label">Problem Jobs</div>
                                <div style="margin-top: 8px; font-size: 0.8rem; color: var(--text-muted);">
                                    ${summary.StuckJobs > 0 ? `${summary.StuckJobs} stuck` : ''}
                                    ${summary.StuckJobs > 0 && summary.FailedJobs > 0 ? ', ' : ''}
                                    ${summary.FailedJobs > 0 ? `${summary.FailedJobs} failed` : ''}
                                    ${!summary.StuckJobs && !summary.FailedJobs ? 'No issues' : ''}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;

            section.innerHTML = dashboardHtml;
        }

        function loadPrinterCriticalSection(printers) {
            let html = '';
            
            // Spooler service status (most critical) - check both SpoolerHealth and Issues
            let spoolerStatus = printers.SpoolerHealth?.ServiceStatus || 'Unknown';
            
            // If status is Unknown but there's a spooler issue, use that info
            if (spoolerStatus === 'Unknown' && printers.Issues && printers.Issues.Category === 'Spooler') {
                spoolerStatus = 'Stopped';
            }
            
            const isSpoolerRunning = spoolerStatus === 'Running';
            
            // Enhanced spooler status card
            html += `
                <div class="spooler-status" style="margin-bottom: 20px;">
                    <div class="spooler-icon ${isSpoolerRunning ? 'running' : 'stopped'}">
                        ${isSpoolerRunning ? '✓' : '✗'}
                    </div>
                    <div style="flex: 1;">
                        <h3 style="margin: 0; color: ${isSpoolerRunning ? 'var(--success-color)' : 'var(--danger-color)'};">Print Spooler Service</h3>
                        <div style="margin-top: 5px;">
                            <span class="status-badge status-${isSpoolerRunning ? 'healthy' : 'critical'}">
                                ${isSpoolerRunning ? '▶ ' : '⏹ '}${spoolerStatus}
                            </span>
                            ${!isSpoolerRunning ? '<button style="margin-left: 10px; padding: 4px 10px; background: var(--danger-color); color: white; border: none; border-radius: 4px; cursor: pointer;">Start Service</button>' : ''}
                        </div>
                    </div>
                </div>
            `;
            
            // Identify critical issues
            const criticalIssues = [];
            if (!isSpoolerRunning) {
                criticalIssues.push('Print spooler service is stopped - No printing possible');
            }
            if (printers.Summary?.TotalPrinters > 0 && printers.Summary?.OfflinePrinters === printers.Summary?.TotalPrinters) {
                criticalIssues.push(`All ${printers.Summary.TotalPrinters} printers are offline`);
            }
            if (printers.Summary?.StuckJobs > 0) {
                criticalIssues.push(`${printers.Summary.StuckJobs} print job(s) stuck for >1 hour`);
            }
            if (printers.Summary?.FailedJobs > 0) {
                criticalIssues.push(`${printers.Summary.FailedJobs} failed print job(s)`);
            }
            
            if (criticalIssues.length > 0) {
                html += '<div style="display: grid; gap: 15px;">';

                criticalIssues.forEach((issue, index) => {
                    let icon = '⚠️';
                    let severity = 'warning';
                    if (issue.includes('spooler')) {
                        icon = '🛑';
                        severity = 'critical';
                    } else if (issue.includes('offline')) {
                        icon = '🔌';
                        severity = 'error';
                    } else if (issue.includes('stuck')) {
                        icon = '📋';
                        severity = 'warning';
                    }

                    html += `
                        <div class="event-severity-card ${severity}" style="border: 1px solid var(--${severity === 'critical' ? 'danger' : severity === 'error' ? 'warning' : 'warning'}-color);">
                            <div style="display: flex; gap: 15px; align-items: start;">
                                <div style="font-size: 2.5rem;">${icon}</div>
                                <div style="flex: 1;">
                                    <h4 style="margin: 0 0 10px 0; color: var(--${severity === 'critical' ? 'danger' : 'warning'}-color);">${issue}</h4>
                                    <div style="font-size: 0.9rem; color: var(--text-secondary);">
                                        ${!isSpoolerRunning && issue.includes('spooler') ? 'The print spooler service must be running for any printing to work.' : ''}
                                        ${issue.includes('offline') ? 'Check printer power, cables, and network connectivity.' : ''}
                                        ${issue.includes('stuck') ? 'Jobs stuck for over an hour may need manual clearing.' : ''}
                                        ${issue.includes('failed') ? 'Failed jobs may need to be resubmitted after resolving issues.' : ''}
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                });

                html += '</div>';
            } else {
                html += `
                    <div style="display: flex; align-items: center; gap: 15px; padding: 20px; background: linear-gradient(135deg, rgba(40, 167, 69, 0.1) 0%, rgba(40, 167, 69, 0.05) 100%); border-radius: 8px; border-left: 4px solid var(--success-color);">
                        <div style="font-size: 2.5rem;">✅</div>
                        <div>
                            <h3 style="margin: 0; color: var(--success-color);">Print System Healthy</h3>
                            <p style="margin: 5px 0 0 0; color: var(--text-secondary);">All printers and print services are functioning normally</p>
                        </div>
                    </div>
                `;
            }
            
            document.getElementById('printerCriticalSection').innerHTML = html;
        }
        
        // SECTION 2: Printer System Overview
        function loadPrinterOverviewSection(printers) {
            let html = '';
            
            // Overview metrics
            if (printers.Summary) {
                html += `
                    <div class="grid grid-4">
                        <div class="metric-card">
                            <div class="metric-value">${printers.Summary.TotalPrinters || 0}</div>
                            <div class="metric-label">Total Printers</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: #28a745;">${printers.Summary.OnlinePrinters || 0}</div>
                            <div class="metric-label">Online</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: #dc3545;">${printers.Summary.OfflinePrinters || 0}</div>
                            <div class="metric-label">Offline</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value" style="color: ${printers.Summary.StuckJobs > 0 ? '#ffc107' : 'inherit'};">${printers.Summary.TotalPrintJobs || 0}</div>
                            <div class="metric-label">Queue Jobs</div>
                        </div>
                    </div>
                `;
            }
            
            // Spooler health details
            if (printers.SpoolerHealth) {
                const spooler = printers.SpoolerHealth;
                html += `
                    <div style="margin-top: 20px;">
                        <h3 style="margin-bottom: 15px;">Spooler Health Details</h3>
                        <div class="grid grid-2">
                            <div>
                                <strong>Service Status:</strong> ${spooler.ServiceStatus || 'Unknown'}<br>
                                <strong>Memory Usage:</strong> ${spooler.MemoryUsageMB || 0} MB<br>
                                <strong>Recent Crashes:</strong> ${spooler.RecentCrashes || 0} in last 24 hours
                            </div>
                            <div>
                                <strong>Spool Folder:</strong> ${spooler.SpoolFolderPath || 'Unknown'}<br>
                                <strong>Folder Size:</strong> ${spooler.SpoolFolderSizeMB ? (spooler.SpoolFolderSizeMB / 1024).toFixed(2) + ' GB' : '0 MB'}<br>
                                <strong>Last Restart:</strong> ${spooler.LastRestartTime ? formatDateISO(new Date(spooler.LastRestartTime)) : 'Never'}
                            </div>
                        </div>
                    </div>
                `;
            }
            
            document.getElementById('printerOverviewSection').innerHTML = html;
        }
        
        // SECTION 3: Active Print Queue
        function loadPrinterQueueSection(printers) {
            if (!printers.PrintQueue || printers.PrintQueue.length === 0) {
                document.getElementById('printQueueCard').style.display = 'none';
                return;
            }
            
            document.getElementById('printQueueCard').style.display = 'block';
            
            
            // Sort queue: stuck jobs first, then by time
            const sortedQueue = [...printers.PrintQueue].sort((a, b) => {
                if (a.IsStuck && !b.IsStuck) return -1;
                if (!a.IsStuck && b.IsStuck) return 1;
                return b.TimeInQueueMinutes - a.TimeInQueueMinutes;
            });
            
            let html = `
                <table>
                    <thead>
                        <tr>
                            <th>Printer</th>
                            <th>Document</th>
                            <th>Status</th>
                            <th>Time in Queue</th>
                            <th>Size</th>
                            <th>User</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            sortedQueue.slice(0, 20).forEach(job => {
                const isStuck = job.IsStuck || job.TimeInQueueMinutes > 60;
                const isDelayed = job.TimeInQueueMinutes > 30;
                const rowStyle = isStuck ? 'background: rgba(220, 53, 69, 0.2);' : 
                               isDelayed ? 'background: rgba(255, 193, 7, 0.2);' : '';
                const timeColor = isStuck ? '#dc3545' : isDelayed ? '#ffc107' : 'inherit';
                
                html += `
                    <tr style="${rowStyle}">
                        <td>${escapeHtml(job.PrinterName || 'Unknown')}</td>
                        <td>${job.DocumentName ? escapeHtml(job.DocumentName.length > 30 ? job.DocumentName.substring(0, 30) + '...' : job.DocumentName) : 'Unknown'}</td>
                        <td><span class="status-badge status-${job.Status === 'Error' ? 'critical' : job.Status === 'Printing' ? 'healthy' : job.Status === 'Paused' ? 'warning' : 'info'}">${escapeHtml(job.Status || 'Unknown')}</span></td>
                        <td style="color: ${timeColor};">${job.TimeInQueueMinutes || 0} min${isStuck ? ' ⚠️ STUCK' : ''}</td>
                        <td>${job.SizeMB ? job.SizeMB.toFixed(2) + ' MB' : 'Unknown'}</td>
                        <td>${escapeHtml(job.UserName || 'Unknown')}</td>
                    </tr>
                `;
            });
            
            html += '</tbody></table>';
            
            if (sortedQueue.length > 20) {
                html += `<p style="text-align: center; color: var(--text-secondary); margin-top: 10px;">Showing first 20 of ${sortedQueue.length} jobs</p>`;
            }
            
            document.getElementById('printerQueueSection').innerHTML = html;
        }
        
        // SECTION 4: Printer Details & Configuration
        function loadPrinterDetailsSection(printers) {
            let html = '';
            
            if (printers.Printers && printers.Printers.length > 0) {
                printers.Printers.forEach(printer => {
                    // Determine status
                    let statusClass = 'unknown';
                    let statusText = printer.Status || 'Unknown';
                    
                    if (printer.Status === 'Ready' || printer.PrinterStatus === 0) {
                        statusClass = 'healthy';
                        statusText = 'Ready';
                    } else if (printer.Status === 'Offline' || printer.PrinterStatus === 7) {
                        statusClass = 'critical';
                        statusText = 'Offline';
                    } else if (printer.Status === 'Paused' || printer.PrinterStatus === 8) {
                        statusClass = 'warning';
                        statusText = 'Paused';
                    } else if (printer.Status === 'Error' || printer.PrinterStatus === 9) {
                        statusClass = 'critical';
                        statusText = 'Error';
                    }
                    
                    // Determine printer icon
                    let printerIcon = '🖨️';
                    if (printer.IsNetwork) printerIcon = '🌐';
                    else if (printer.Type?.includes('PDF')) printerIcon = '📄';
                    else if (printer.Type?.includes('Fax')) printerIcon = '📠';

                    html += `
                        <div class="printer-card ${statusClass.replace('healthy', 'online').replace('critical', 'offline')}" style="margin-bottom: 20px;">
                            <div style="display: flex; gap: 20px;">
                                <div class="printer-icon">${printerIcon}</div>
                                <div style="flex: 1;">
                                    <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 15px;">
                                        <div>
                                            <h3 style="margin: 0; color: var(--text-primary);">
                                                ${escapeHtml(printer.Name)}
                                                ${printer.IsDefault ? '<span class="status-badge" style="margin-left: 10px; background: var(--primary-color); color: white;">★ DEFAULT</span>' : ''}
                                            </h3>
                                            <div style="margin-top: 5px;">
                                                <span class="printer-status-indicator ${statusClass.replace('healthy', 'online').replace('critical', 'offline').replace('warning', 'error')}">
                                                    ${statusClass === 'healthy' ? '🟢' : statusClass === 'critical' ? '🔴' : '🟡'} ${statusText}
                                                </span>
                                                ${printer.IsNetwork ? '<span class="status-badge" style="margin-left: 8px;">Network</span>' : ''}
                                                ${printer.IsShared ? '<span class="status-badge" style="margin-left: 8px;">Shared</span>' : ''}
                                            </div>
                                        </div>
                                        ${printer.JobCount > 0 ? `
                                            <div style="text-align: center; padding: 10px; background: var(--bg-secondary); border-radius: 6px;">
                                                <div style="font-size: 1.5rem; font-weight: bold; color: var(--accent-color);">${printer.JobCount}</div>
                                                <div style="font-size: 0.8rem; color: var(--text-muted);">Jobs in Queue</div>
                                            </div>
                                        ` : ''}
                                    </div>
                                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
                                        <div>
                                            <strong style="color: var(--text-muted); font-size: 0.85rem;">DRIVER</strong>
                                            <div style="margin-top: 4px;">${escapeHtml(printer.DriverName || 'Unknown')}</div>
                                        </div>
                                        <div>
                                            <strong style="color: var(--text-muted); font-size: 0.85rem;">PORT</strong>
                                            <div style="margin-top: 4px;">${escapeHtml(printer.PortName || 'Unknown')}</div>
                                        </div>
                                        ${printer.Location ? `
                                            <div>
                                                <strong style="color: var(--text-muted); font-size: 0.85rem;">LOCATION</strong>
                                                <div style="margin-top: 4px;">${escapeHtml(printer.Location)}</div>
                                            </div>
                                        ` : ''}
                                        <div>
                                            <strong style="color: var(--text-muted); font-size: 0.85rem;">TYPE</strong>
                                            <div style="margin-top: 4px;">${escapeHtml(printer.Type || 'Local Printer')}</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                });
            } else {
                html = '<p style="color: #aaa; text-align: center; padding: 20px;">No printers installed</p>';
            }
            
            document.getElementById('printerDetailsSection').innerHTML = html;
        }
        
        // SECTION 5: Printer Drivers & Advanced Settings
        function loadPrinterAdvancedSection(printers) {
            let html = '';
            
            // Printer Drivers
            html += `
                <div class="collapsible" onclick="toggleCollapsible(this)" style="background: #333; padding: 15px; border-radius: 6px; margin-bottom: 10px; cursor: pointer;">
                    <h3 style="margin: 0;"><span style="display: inline-block; width: 20px;">▼</span> Installed Printer Drivers (${printers.PrinterDrivers?.length || 0})</h3>
                </div>
                <div class="collapsible-content" style="display: block; padding: 15px; background: #2a2a2a; border-radius: 0 0 6px 6px; margin-top: -10px; margin-bottom: 10px;">
            `;
            
            if (printers.PrinterDrivers && printers.PrinterDrivers.length > 0) {
                html += `
                    <table>
                        <thead>
                            <tr>
                                <th>Driver Name</th>
                                <th>Version</th>
                                <th>Environment</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                `;
                
                printers.PrinterDrivers.forEach(driver => {
                    const isUsed = printers.Printers?.some(p => p.DriverName === driver.Name);
                    html += `
                        <tr>
                            <td><strong>${escapeHtml(driver.Name)}</strong></td>
                            <td>${escapeHtml(driver.Version || driver.DriverVersion || '4.0')}</td>
                            <td>${escapeHtml(driver.Environment || 'Windows x64')}</td>
                            <td><span class="status-badge status-${isUsed ? 'healthy' : 'warning'}">${isUsed ? 'Active' : 'Unused'}</span></td>
                        </tr>
                    `;
                });
                
                html += '</tbody></table>';
            } else {
                html += '<p style="color: #aaa;">No printer drivers available</p>';
            }
            html += '</div>';
            
            
            // Print Server Configuration
            html += `
                <div class="collapsible" onclick="toggleCollapsible(this)" style="background: #333; padding: 15px; border-radius: 6px; margin-bottom: 10px; cursor: pointer;">
                    <h3 style="margin: 0;"><span style="display: inline-block; width: 20px;">▶</span> Print Server Configuration</h3>
                </div>
                <div class="collapsible-content" style="display: none; padding: 15px; background: #2a2a2a; border-radius: 0 0 6px 6px; margin-top: -10px;">
                    <div class="grid grid-2">
                        <div>
                            <strong>Print Server Role:</strong> Not Configured<br>
                            <strong>Shared Printers:</strong> ${printers.Printers?.filter(p => p.IsShared).length || 0}<br>
                            <strong>Print Policies:</strong> Default
                        </div>
                        <div>
                            <strong>Event Log Monitoring:</strong> Enabled<br>
                            <strong>Security Auditing:</strong> Basic<br>
                            <strong>Driver Installation:</strong> Admin Only
                        </div>
                    </div>
                </div>
            `;
            
            document.getElementById('printerAdvancedSection').innerHTML = html;
        }
        

        // Load Software Tab
        function loadSoftwareTab_OLD_REMOVE() {
            const sw = systemData.Software;
            if (!sw) return;
            
            updateHealthStatus('softwareHealthStatus', 
                sw.HealthScore >= 80 ? 'Healthy' : 
                sw.HealthScore >= 60 ? 'Warning' : 'Critical');
            
            // Software Overview
            if (sw.Summary) {
                const overviewHtml = `
                    <div class="grid grid-4">
                        <div class="metric-card">
                            <div class="metric-value">${sw.Summary.ApplicationCount}</div>
                            <div class="metric-label">Applications</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${typeof sw.Summary.Crashes72h === 'object' ?
                                (sw.Summary.Crashes72h?.value || sw.Summary.Crashes72h?.Value ||
                                 sw.Summary.Crashes72h?.count || sw.Summary.Crashes72h?.Count ||
                                 sw.Summary.TotalCrashes72h || 0) :
                                (sw.Summary.Crashes72h || sw.Summary.TotalCrashes72h || 0)}</div>
                            <div class="metric-label">Crashes (72h)</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${sw.Summary.StartupImpact}</div>
                            <div class="metric-label">Startup Impact</div>
                        </div>
                    </div>
                `;
                document.getElementById('softwareOverview').innerHTML = overviewHtml;
            }
            
            // Performance Metrics
            if (sw.Performance) {
                const perfHtml = `
                    <div class="metric-card">
                        <div class="metric-value">${sw.Performance.CPU?.CurrentUsage || 0}%</div>
                        <div class="metric-label">CPU Usage</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${sw.Performance.Memory?.PercentUsed || 0}%</div>
                        <div class="metric-label">Memory Used</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${sw.Performance.DiskQueue?.Current || 0}</div>
                        <div class="metric-label">Disk Queue</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${sw.Performance.ProcessCount?.Total || 0}</div>
                        <div class="metric-label">Processes</div>
                    </div>
                `;
                document.getElementById('performanceMetrics').innerHTML = perfHtml;
                updateHealthStatus('performanceStatus', sw.Performance.CPU?.Status || 'Unknown');
            }
            
            // Resource Consumers
            if (sw.ResourceConsumers) {
                const consumersHtml = `
                    <div>
                        <h3>Top CPU Processes</h3>
                        <table>
                            <thead>
                                <tr><th>Process</th><th>Runtime</th></tr>
                            </thead>
                            <tbody>
                                ${sw.ResourceConsumers.TopCPU?.slice(0, 5).map(p => `
                                    <tr>
                                        <td>${p.Process}</td>
                                        <td>${p.Runtime}</td>
                                    </tr>
                                `).join('') || '<tr><td colspan="2">No data</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                    <div>
                        <h3>Top Memory Processes</h3>
                        <table>
                            <thead>
                                <tr><th>Process</th><th>Memory</th><th>Status</th></tr>
                            </thead>
                            <tbody>
                                ${sw.ResourceConsumers.TopMemory?.slice(0, 5).map(p => `
                                    <tr>
                                        <td>${p.Process}</td>
                                        <td>${p.MemoryMB} MB</td>
                                        <td>
                                            <span class="status-badge status-${p.Status.toLowerCase()}">
                                                ${p.Status}
                                            </span>
                                        </td>
                                    </tr>
                                `).join('') || '<tr><td colspan="3">No data</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                `;
                document.getElementById('resourceConsumers').innerHTML = consumersHtml;
            }
            
            // Application Health
            if (sw.ApplicationHealth) {
                // Ensure crash and hang values are numbers, not objects
                let crashCount = sw.ApplicationHealth.Summary.TotalCrashes72h || 0;
                let hangCount = sw.ApplicationHealth.Summary.TotalHangs72h || 0;
                
                // Handle case where Measure-Object returns an object
                if (typeof crashCount === 'object') crashCount = crashCount?.Sum || 0;
                if (typeof hangCount === 'object') hangCount = hangCount?.Sum || 0;
                
                crashCount = Number(crashCount) || 0;
                hangCount = Number(hangCount) || 0;
                
                const appHealthHtml = sw.ApplicationHealth.Summary ? `
                    <div class="grid grid-2">
                        <div>
                            <strong>Crashes (72h):</strong> ${crashCount}<br>
                            <strong>Unique Apps Crashed:</strong> ${sw.ApplicationHealth.Summary.UniqueAppsCrashed || 0}
                        </div>
                        <div>
                            <strong>Hangs (72h):</strong> ${hangCount}<br>
                            <strong>Status:</strong> 
                            <span class="status-badge status-${sw.ApplicationHealth.Summary.Status.toLowerCase()}">
                                ${sw.ApplicationHealth.Summary.Status}
                            </span>
                        </div>
                    </div>
                    ${sw.ApplicationHealth.Crashes?.length > 0 ? `
                        <h4 class="mt-20">Recent Crashes</h4>
                        <table>
                            <thead>
                                <tr><th>Application</th><th>Count</th><th>Last Crash</th></tr>
                            </thead>
                            <tbody>
                                ${sw.ApplicationHealth.Crashes.map(crash => `
                                    <tr>
                                        <td>${crash.Application}</td>
                                        <td>${crash.CrashCount}</td>
                                        <td>${formatDateISO(new Date(crash.LastCrash))}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    ` : ''}
                ` : '<div class="text-center text-muted">No application health data</div>';
                
                document.getElementById('appHealthContent').innerHTML = appHealthHtml;
                updateHealthStatus('appHealthStatus', sw.ApplicationHealth?.Summary?.Status || 'Unknown');
            }
            
            // Startup Programs
            if (sw.StartupPrograms?.Summary) {
                const startupHtml = `
                    <div class="grid grid-3">
                        <div class="metric-card">
                            <div class="metric-value">${sw.StartupPrograms.Summary.TotalCount}</div>
                            <div class="metric-label">Total Items</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${sw.StartupPrograms.Summary.HighImpact}</div>
                            <div class="metric-label">High Impact</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${sw.StartupPrograms.Summary.BootDuration}s</div>
                            <div class="metric-label">Boot Time</div>
                        </div>
                    </div>
                `;
                document.getElementById('startupContent').innerHTML = startupHtml;
                updateHealthStatus('startupStatus', sw.StartupPrograms.Summary.Status);
            }
        }

        // Load Driver Health Banner
        function loadDriverHealthBanner(drivers) {
            const banner = document.getElementById('driverHealthBanner');
            if (!banner) return;

            const problemDevices = drivers.ProblemDevices?.filter(device =>
                device.ProblemCode && device.ProblemCode !== 0 && device.ProblemCode !== null
            ) || [];
            const unsignedDrivers = drivers.UnsignedDrivers || [];
            const missingDrivers = problemDevices.filter(d =>
                d.ProblemCode === 28 || (d.ProblemDescription && d.ProblemDescription.includes('not installed'))
            );

            // Determine overall health status
            let criticalIssues = [];
            let warningIssues = [];
            let overallHealthStatus = 'healthy';

            if (unsignedDrivers.length > 0) {
                criticalIssues.push(`${unsignedDrivers.length} unsigned driver${unsignedDrivers.length > 1 ? 's' : ''} detected (security risk)`);
            }

            if (problemDevices.length > 0) {
                criticalIssues.push(`${problemDevices.length} problem device${problemDevices.length > 1 ? 's' : ''} with driver issues`);
            }

            if (missingDrivers.length > 0) {
                criticalIssues.push(`${missingDrivers.length} device${missingDrivers.length > 1 ? 's' : ''} with missing drivers`);
            }

            // Determine status
            if (criticalIssues.length > 0) {
                overallHealthStatus = 'critical';
            } else if (warningIssues.length > 0) {
                overallHealthStatus = 'warning';
            }

            // Build health banner
            const healthIcon = overallHealthStatus === 'critical' ? '🔴' :
                               overallHealthStatus === 'warning' ? '⚠️' : '✅';
            const healthText = overallHealthStatus === 'critical' ? 'Critical Issues Detected' :
                               overallHealthStatus === 'warning' ? 'Warnings Detected' : 'Drivers Healthy';

            const allIssues = [...criticalIssues, ...warningIssues];

            let healthBannerHtml = `
                <div class="health-status">
                    <span class="health-icon">${healthIcon}</span>
                    <strong>Driver Health: ${healthText}</strong>
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

        // Load Drivers Tab - Redesigned with priority-based layout
        function loadDriversTab() {
            const drivers = systemData.Drivers;
            if (!drivers) {
                document.getElementById('criticalDriverIssues').innerHTML = '<div class="text-center text-muted">No driver data available</div>';
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            // 0. Overall Driver Health Status Banner
            loadDriverHealthBanner(drivers);

            // 1. Critical Driver Issues
            const problemDevices = drivers.ProblemDevices?.filter(device =>
                device.ProblemCode && device.ProblemCode !== 0 && device.ProblemCode !== null
            ) || [];
            const unsignedDrivers = drivers.UnsignedDrivers || [];
            const missingDrivers = problemDevices.filter(d =>
                d.ProblemCode === 28 || (d.ProblemDescription && d.ProblemDescription.includes('not installed'))
            );

            const overallStatus = (unsignedDrivers.length > 0 || problemDevices.length > 0) ? 'Critical' : 'Healthy';

            const totalDrivers = drivers.Summary?.TotalDrivers ||
                (drivers.DriverCategories ? Object.values(drivers.DriverCategories).reduce((sum, cat) => sum + cat.length, 0) : 0);
            const workingDrivers = totalDrivers - problemDevices.length;
            const healthPercentage = totalDrivers > 0 ? Math.round((workingDrivers / totalDrivers) * 100) : 100;

            let criticalIssuesHtml = `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value">${totalDrivers}</div>
                        <div class="metric-label">Total Drivers</div>
                        <div class="metric-sublabel">Installed on system</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${workingDrivers === totalDrivers ? 'var(--success-color)' : 'inherit'}">
                            ${workingDrivers}
                        </div>
                        <div class="metric-label">Working Properly</div>
                        <div class="metric-sublabel">${healthPercentage}% healthy</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${unsignedDrivers.length > 0 ? 'var(--danger-color)' : 'inherit'}">
                            ${unsignedDrivers.length}
                        </div>
                        <div class="metric-label">Unsigned Drivers</div>
                        <div class="metric-sublabel">${unsignedDrivers.length > 0 ? 'Security risk' : 'None found'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${problemDevices.length > 0 ? 'var(--danger-color)' : 'inherit'}">
                            ${problemDevices.length}
                        </div>
                        <div class="metric-label">Problem Devices</div>
                        <div class="metric-sublabel">${missingDrivers.length > 0 ? `${missingDrivers.length} missing` : 'None'}</div>
                    </div>
                </div>
            `;
            
            // Unsigned Drivers Alert
            if (unsignedDrivers.length > 0) {
                criticalIssuesHtml += `
                    <div class="alert alert-danger" style="margin-top: 20px;">
                        <strong>⚠️ Security Risk: Unsigned Drivers Detected</strong>
                        <p style="margin-top: 10px;">Unsigned drivers can compromise system security and stability. These drivers have not been verified by Microsoft.</p>
                        <table style="margin-top: 15px;">
                            <thead>
                                <tr>
                                    <th>Device</th>
                                    <th>Driver</th>
                                    <th>Version</th>
                                    <th>Risk Level</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${unsignedDrivers.map(driver => `
                                    <tr>
                                        <td><strong>${escapeHtml(driver.DeviceName)}</strong></td>
                                        <td>${escapeHtml(driver.DriverName || 'Unknown')}</td>
                                        <td>${escapeHtml(driver.DriverVersion || 'Unknown')}</td>
                                        <td>
                                            <span class="status-badge status-critical">
                                                ${driver.IsSystemDriver ? 'SYSTEM DRIVER' : 'High Risk'}
                                            </span>
                                        </td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                `;
            }
            
            // Problem Devices - ENHANCED with prioritization
            if (problemDevices.length > 0) {
                // Categorize by severity and device importance
                const criticalDeviceKeywords = ['network', 'ethernet', 'wifi', 'wireless', 'display', 'video', 'graphics', 'storage', 'disk', 'ssd', 'nvme', 'sata'];
                const highPriorityKeywords = ['audio', 'sound', 'touchpad', 'trackpad', 'keyboard', 'mouse', 'usb controller', 'pci', 'chipset', 'bluetooth'];
                const lowPriorityKeywords = ['rgb', 'led', 'illumination', 'card reader', 'fingerprint', 'camera', 'composite', 'virtual', 'microsoft device association'];

                const categorizedDevices = problemDevices.map(device => {
                    const nameLower = device.DeviceName?.toLowerCase() || '';
                    const idLower = device.DeviceID?.toLowerCase() || '';
                    const descLower = device.ProblemDescription?.toLowerCase() || '';
                    const searchText = `${nameLower} ${idLower} ${descLower}`;

                    let priority = 'medium';
                    let impact = 'Unknown impact';
                    let recommendation = 'Update or reinstall driver';
                    let canIgnore = false;

                    // Determine priority
                    if (criticalDeviceKeywords.some(keyword => searchText.includes(keyword))) {
                        priority = 'critical';
                        if (searchText.includes('network') || searchText.includes('ethernet') || searchText.includes('wifi')) {
                            impact = '🚨 Network connectivity may be affected - system cannot connect to network';
                            recommendation = 'Install network driver immediately - download from manufacturer website on another device';
                        } else if (searchText.includes('display') || searchText.includes('video') || searchText.includes('graphics')) {
                            impact = '⚠️ Display issues - poor performance, resolution problems, or missing features';
                            recommendation = 'Update graphics driver from manufacturer (NVIDIA/AMD/Intel)';
                        } else if (searchText.includes('storage') || searchText.includes('disk')) {
                            impact = '🚨 Storage device issues - data access problems or boot failures possible';
                            recommendation = 'Update storage controller driver immediately';
                        }
                    } else if (highPriorityKeywords.some(keyword => searchText.includes(keyword))) {
                        priority = 'high';
                        if (searchText.includes('audio') || searchText.includes('sound')) {
                            impact = '⚠️ Audio not working - no sound output';
                            recommendation = 'Update audio driver from manufacturer website';
                        } else if (searchText.includes('touchpad') || searchText.includes('trackpad')) {
                            impact = '⚠️ Touchpad not working - use external mouse temporarily';
                            recommendation = 'Update touchpad driver from laptop manufacturer';
                        } else if (searchText.includes('bluetooth')) {
                            impact = '⚠️ Bluetooth devices cannot connect';
                            recommendation = 'Update Bluetooth driver or check if adapter is disabled';
                        } else {
                            impact = '⚠️ Device functionality impaired';
                            recommendation = 'Update driver from manufacturer';
                        }
                    } else if (lowPriorityKeywords.some(keyword => searchText.includes(keyword))) {
                        priority = 'low';
                        canIgnore = true;
                        if (searchText.includes('rgb') || searchText.includes('led') || searchText.includes('illumination')) {
                            impact = 'ℹ️ Cosmetic only - RGB lighting not working (no functional impact)';
                            recommendation = 'Optional: Update RGB software from manufacturer. Can be safely ignored.';
                        } else if (searchText.includes('card reader')) {
                            impact = 'ℹ️ Card reader not working - usually unused';
                            recommendation = 'Optional: Update if needed. Can be safely ignored if not used.';
                        } else if (searchText.includes('virtual') || searchText.includes('composite')) {
                            impact = 'ℹ️ Virtual/composite device - likely not affecting functionality';
                            recommendation = 'Usually safe to ignore - may be disabled device or software component';
                        } else if (searchText.includes('microsoft device association')) {
                            impact = 'ℹ️ Microsoft composite device - typically benign';
                            recommendation = 'Safe to ignore - Windows manages these automatically';
                        } else {
                            impact = 'ℹ️ Non-critical device - minimal impact on daily use';
                            recommendation = 'Low priority - update only if needed';
                        }
                    } else {
                        priority = 'medium';
                        impact = 'Unknown device type - may affect functionality';
                        recommendation = 'Investigate device purpose and update driver if important';
                    }

                    // Check for specific problem codes
                    if (device.ProblemCode === 28) {
                        recommendation = '🔴 Driver missing: Install driver from manufacturer website';
                    } else if (device.ProblemCode === 10) {
                        recommendation = '⚠️ Device cannot start: Update driver or check hardware';
                    } else if (device.ProblemCode === 12) {
                        recommendation = '⚠️ Resource conflict: Check Device Manager for resource settings';
                    } else if (device.ProblemCode === 22) {
                        recommendation = 'ℹ️ Device disabled by user - Enable in Device Manager if needed';
                        canIgnore = true;
                    }

                    return { ...device, priority, impact, recommendation, canIgnore };
                });

                // Sort by priority
                const priorityOrder = { 'critical': 1, 'high': 2, 'medium': 3, 'low': 4 };
                categorizedDevices.sort((a, b) => priorityOrder[a.priority] - priorityOrder[b.priority]);

                const criticalCount = categorizedDevices.filter(d => d.priority === 'critical').length;
                const highCount = categorizedDevices.filter(d => d.priority === 'high').length;
                const canIgnoreCount = categorizedDevices.filter(d => d.canIgnore).length;

                criticalIssuesHtml += `
                    <div style="margin-top: 20px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                            <h3>Problem Devices (${problemDevices.length})</h3>
                            <div style="font-size: 0.9rem; color: var(--text-secondary);">
                                ${criticalCount > 0 ? `<span style="color: var(--danger-color); font-weight: 600;">${criticalCount} Critical</span> • ` : ''}
                                ${highCount > 0 ? `<span style="color: var(--warning-color);">${highCount} High Priority</span> • ` : ''}
                                ${canIgnoreCount > 0 ? `<span style="color: var(--text-muted);">${canIgnoreCount} Can Ignore</span>` : ''}
                            </div>
                        </div>
                `;

                // Priority section explanations
                if (criticalCount > 0 || highCount > 0) {
                    criticalIssuesHtml += `
                        <div class="alert alert-warning" style="margin-bottom: 20px;">
                            <strong>📋 Priority Guide:</strong>
                            <ul style="margin: 8px 0 0 20px; font-size: 0.9rem;">
                                ${criticalCount > 0 ? '<li><strong style="color: var(--danger-color);">Critical:</strong> Affects core functionality (network, display, storage) - fix immediately</li>' : ''}
                                ${highCount > 0 ? '<li><strong style="color: var(--warning-color);">High:</strong> Impairs important features - fix when convenient</li>' : ''}
                                <li><strong>Low:</strong> Cosmetic or rarely-used devices - optional to fix</li>
                            </ul>
                        </div>
                    `;
                }

                categorizedDevices.forEach(device => {
                    const priorityColors = {
                        'critical': 'var(--danger-color)',
                        'high': 'var(--warning-color)',
                        'medium': 'var(--info-color)',
                        'low': 'var(--text-muted)'
                    };
                    const priorityColor = priorityColors[device.priority];

                    criticalIssuesHtml += `
                        <div style="background: var(--bg-tertiary); border-radius: 6px; padding: 15px; margin-bottom: 15px; border-left: 4px solid ${priorityColor};">
                            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                                <div>
                                    <span style="font-weight: 600; font-size: 1.05rem;">${escapeHtml(device.DeviceName)}</span>
                                    <div style="margin-top: 5px;">
                                        <span class="status-badge" style="background: ${priorityColor}; color: white; font-size: 0.75rem; padding: 2px 8px;">
                                            ${device.priority.toUpperCase()} PRIORITY
                                        </span>
                                        <span class="status-badge status-${device.ProblemCode === 28 ? 'critical' : 'warning'}" style="margin-left: 5px; font-size: 0.75rem;">
                                            Code ${device.ProblemCode}
                                        </span>
                                        ${device.canIgnore ? '<span class="status-badge" style="background: var(--text-muted); color: white; margin-left: 5px; font-size: 0.75rem;">Can Ignore</span>' : ''}
                                    </div>
                                </div>
                            </div>

                            <div style="font-size: 0.9rem; margin-bottom: 12px;">
                                <div style="background: var(--bg-secondary); padding: 10px; border-radius: 4px; margin-bottom: 8px;">
                                    <strong>Impact:</strong> ${device.impact}
                                </div>
                                <strong>Issue:</strong> ${escapeHtml(device.ProblemDescription)}<br>
                                <strong>Device ID:</strong> <span style="font-size: 0.85rem; font-family: monospace; color: var(--text-secondary);">${escapeHtml(device.DeviceID)}</span>
                            </div>

                            <div style="background: var(--bg-secondary); padding: 12px; border-radius: 4px; border-left: 3px solid var(--info-color);">
                                <strong style="color: var(--info-color);">🔧 Recommended Action:</strong><br>
                                <span style="font-size: 0.9rem;">${device.recommendation}</span>
                            </div>
                        </div>
                    `;
                });

                // Overall recommendations
                criticalIssuesHtml += `
                    <div style="margin-top: 20px; padding: 15px; background: var(--bg-secondary); border-radius: 8px; border-left: 4px solid var(--info-color);">
                        <h4 style="margin-bottom: 10px;">💡 General Troubleshooting Steps</h4>
                        <ol style="margin: 5px 0 0 20px; font-size: 0.9rem; line-height: 1.8;">
                            <li><strong>Access Device Manager:</strong> <code style="background: var(--bg-primary); padding: 2px 6px; border-radius: 3px;">devmgmt.msc</code> or right-click Start → Device Manager</li>
                            <li><strong>Check manufacturer support:</strong> Visit PC/device manufacturer website for latest drivers</li>
                            <li><strong>Windows Update:</strong> Many drivers install automatically via Windows Update</li>
                            <li><strong>Disable unwanted devices:</strong> Right-click in Device Manager → Disable (if device is unused)</li>
                            <li><strong>Check BIOS settings:</strong> Some devices can be enabled/disabled in BIOS</li>
                        </ol>
                    </div>
                `;

                criticalIssuesHtml += '</div>';
            }
            
            document.getElementById('criticalDriverIssues').innerHTML = criticalIssuesHtml;

            // SECTION 2: Driver Overview
            // (totalDrivers and workingDrivers already declared above in Section 1)

            let overviewHtml = `
                <div class="grid grid-3">
                    <div class="metric-card">
                        <div class="metric-value">${totalDrivers}</div>
                        <div class="metric-label">Total Drivers</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${workingDrivers}</div>
                        <div class="metric-label">Working Properly</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${drivers.RecentChanges?.length || 0}</div>
                        <div class="metric-label">Recent Changes</div>
                    </div>
                </div>
            `;

            // Drivers by Category - Visual Grid Overview
            if (drivers.DriverCategories) {
                overviewHtml += '<h3 style="margin-top: 30px; margin-bottom: 15px;">Drivers by Category</h3>';

                const allCategories = Object.entries(drivers.DriverCategories)
                    .sort((a, b) => b[1].length - a[1].length);

                // Category icons mapping
                const categoryIcons = {
                    'Display': '🖥️',
                    'Network': '🌐',
                    'Audio': '🔊',
                    'Storage': '💾',
                    'Input': '⌨️',
                    'USB': '🔌',
                    'System': '⚙️',
                    'Processor': '⚡',
                    'Battery': '🔋',
                    'Camera': '📷',
                    'Bluetooth': '📶',
                    'Printer': '🖨️',
                    'Security': '🔒',
                    'Human Interface Devices': '🖱️'
                };

                // Create category grid
                overviewHtml += '<div class="grid grid-6" style="margin-bottom: 20px;">';

                allCategories.forEach(([category, categoryDrivers]) => {
                    const problemCount = categoryDrivers.filter(d => d.Status !== 'OK').length;
                    const statusColor = problemCount > 0 ? 'var(--warning-color)' : 'var(--success-color)';
                    const icon = categoryIcons[category] || '📦';
                    const categoryId = `driver-cat-${category.replace(/[^a-zA-Z0-9]/g, '-')}`;

                    overviewHtml += `
                        <div class="metric-card" style="cursor: pointer; transition: all 0.2s ease;"
                             onclick="toggleDriverCategory('${categoryId}')"
                             onmouseover="this.style.transform='translateY(-2px)'; this.style.boxShadow='0 4px 12px rgba(0,0,0,0.3)';"
                             onmouseout="this.style.transform='translateY(0)'; this.style.boxShadow='none';">
                            <div style="font-size: 2rem; margin-bottom: 8px;">${icon}</div>
                            <div class="metric-value" style="color: ${statusColor};">${categoryDrivers.length}</div>
                            <div class="metric-label">${category}</div>
                            <div class="metric-sublabel">
                                ${problemCount > 0 ? `${problemCount} issue${problemCount > 1 ? 's' : ''}` : 'All healthy'}
                            </div>
                        </div>
                    `;
                });

                overviewHtml += '</div>';

                // Create expandable sections for each category
                allCategories.forEach(([category, categoryDrivers]) => {
                    const categoryId = `driver-cat-${category.replace(/[^a-zA-Z0-9]/g, '-')}`;
                    const icon = categoryIcons[category] || '📦';

                    overviewHtml += `
                        <div id="${categoryId}" class="collapsible-section" style="display: none; margin-bottom: 15px;">
                            <div class="card">
                                <div class="card-header" style="display: flex; justify-content: space-between; align-items: center;">
                                    <h4 style="margin: 0; display: flex; align-items: center; gap: 10px;">
                                        <span style="font-size: 1.5rem;">${icon}</span>
                                        ${category} Drivers
                                    </h4>
                                    <button onclick="toggleDriverCategory('${categoryId}')"
                                            style="background: var(--bg-tertiary); border: 1px solid var(--border-color);
                                                   padding: 5px 15px; border-radius: 4px; cursor: pointer; color: var(--text-primary);">
                                        Close
                                    </button>
                                </div>
                                <div class="table-responsive">
                                    <table>
                                        <thead>
                                            <tr>
                                                <th>Device Name</th>
                                                <th>Driver Version</th>
                                                <th>Driver Date</th>
                                                <th>Status</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            ${categoryDrivers.map(driver => {
                                                const driverStatus = driver.Status || 'OK';
                                                const statusClass = driverStatus === 'OK' ? 'healthy' : 'warning';
                                                const statusDisplay = driverStatus === 'OK' ? '✓ OK' : driverStatus;

                                                return `
                                                    <tr>
                                                        <td>${escapeHtml(driver.DeviceName || driver.Name || 'Unknown')}</td>
                                                        <td>${escapeHtml(driver.DriverVersion || driver.Version || 'Unknown')}</td>
                                                        <td>${escapeHtml(driver.DriverDate || driver.Date || 'Unknown')}</td>
                                                        <td><span class="status-badge status-${statusClass}">${statusDisplay}</span></td>
                                                    </tr>
                                                `;
                                            }).join('')}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    `;
                });
            }

            document.getElementById('driverOverviewSection').innerHTML = overviewHtml;
            


            // SECTION 4: Driver History & Performance
            
            // Performance Impact
            let performanceHtml = `
                <div class="alert alert-info">
                    <strong>System Impact Analysis</strong><br>
            `;
            
            // Calculate some performance metrics
            const driverCount = drivers.Summary?.TotalDrivers || 
                (drivers.DriverCategories ? Object.values(drivers.DriverCategories).reduce((sum, cat) => sum + cat.length, 0) : 0);
            const bootImpact = Math.round(driverCount * 0.05); // Estimate 0.05s per driver
            const memoryUsage = Math.round(driverCount * 0.6); // Estimate 0.6MB per driver
            
            performanceHtml += `
                    • Boot time impact: <strong>~${bootImpact} seconds</strong> (${driverCount} drivers loading at startup)<br>
                    • Estimated memory usage: <strong>~${memoryUsage} MB</strong> allocated to drivers<br>
            `;
            
            if (problemDevices.length > 0) {
                performanceHtml += `
                    • <span style="color: var(--warning-color);">⚠️ ${problemDevices.length} problem driver${problemDevices.length > 1 ? 's' : ''} may impact system stability</span><br>
                `;
            }
            
            if (unsignedDrivers.length > 0) {
                performanceHtml += `
                    • <span style="color: var(--danger-color);">⚠️ ${unsignedDrivers.length} unsigned driver${unsignedDrivers.length > 1 ? 's' : ''} pose security risks</span><br>
                `;
            }
            
            performanceHtml += '</div>';
            
            document.getElementById('driverPerformanceImpact').innerHTML = performanceHtml;
            
            // Recent Driver Changes
            if (drivers.RecentChanges && drivers.RecentChanges.length > 0) {
                const changesHtml = `
                    <div style="max-height: 300px; overflow-y: auto;">
                        ${drivers.RecentChanges.map(change => {
                            const daysAgo = change.DaysAgo || 0;
                            const changeType = change.Type || 'Updated';
                            const typeColor = changeType === 'Installed' ? 'var(--success-color)' : 
                                            changeType === 'Removed' ? 'var(--danger-color)' : 'var(--info-color)';
                            
                            return `
                                <div style="padding: 10px; border-left: 3px solid ${typeColor}; margin-bottom: 10px; background: var(--bg-secondary);">
                                    <div style="display: flex; justify-content: space-between;">
                                        <strong>${change.DeviceName}</strong>
                                        <span class="text-muted">${daysAgo} days ago</span>
                                    </div>
                                    <div style="margin-top: 5px;">
                                        <span class="status-badge" style="background: ${typeColor};">${changeType}</span>
                                        ${change.OldVersion && change.NewVersion ?
                                            `<span class="text-muted">v${escapeHtml(change.OldVersion)} → v${escapeHtml(change.NewVersion)}</span>` :
                                            change.Version ? `<span class="text-muted">v${escapeHtml(change.Version)}</span>` : ''}
                                    </div>
                                </div>
                            `;
                        }).join('')}
                    </div>
                `;
                document.getElementById('recentDriverChanges').innerHTML = changesHtml;
            } else {
                document.getElementById('recentDriverChanges').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">No recent driver changes detected</div>';
            }
            
            // Driver Performance Impact
            if (drivers.PerformanceImpact) {
                const perf = drivers.PerformanceImpact;
                let perfHtml = '<div class="grid grid-2">';
                
                // High impact drivers
                if (perf.HighImpactDrivers && perf.HighImpactDrivers.length > 0) {
                    perfHtml += `
                        <div>
                            <h4>High Performance Impact Drivers</h4>
                            <ul style="list-style: none; padding: 0;">
                                ${perf.HighImpactDrivers.slice(0, 5).map(driver => `
                                    <li style="padding: 5px 0; border-bottom: 1px solid var(--border-color);">
                                        <strong>${escapeHtml(driver.Name)}</strong>
                                        <span class="status-badge status-warning" style="float: right;">
                                            ${escapeHtml(driver.Impact || 'High')}
                                        </span>
                                        <br>
                                        <small class="text-muted">${escapeHtml(driver.Reason || 'Performance degradation detected')}</small>
                                    </li>
                                `).join('')}
                            </ul>
                        </div>`;
                }
                
                // Driver latency issues
                if (perf.LatencyIssues && perf.LatencyIssues.length > 0) {
                    perfHtml += `
                        <div>
                            <h4>Driver Latency Issues</h4>
                            <ul style="list-style: none; padding: 0;">
                                ${perf.LatencyIssues.slice(0, 5).map(issue => `
                                    <li style="padding: 5px 0; border-bottom: 1px solid var(--border-color);">
                                        <strong>${escapeHtml(issue.Driver)}</strong>
                                        <span class="text-muted" style="float: right;">
                                            ${issue.Latency}ms
                                        </span>
                                        <br>
                                        <small class="text-muted">${escapeHtml(issue.Type || 'DPC Latency')}</small>
                                    </li>
                                `).join('')}
                            </ul>
                        </div>`;
                }
                
                perfHtml += '</div>';
                
                // Overall performance score
                if (perf.OverallScore !== undefined) {
                    const scoreColor = perf.OverallScore >= 80 ? 'var(--success-color)' : 
                                      perf.OverallScore >= 60 ? 'var(--warning-color)' : 'var(--danger-color)';
                    perfHtml += `
                        <div style="margin-top: 15px; text-align: center;">
                            <h4>Driver Performance Score</h4>
                            <div style="font-size: 2em; color: ${scoreColor}; font-weight: bold;">
                                ${perf.OverallScore}/100
                            </div>
                        </div>`;
                }
                
                document.getElementById('driverPerformanceImpact').innerHTML = perfHtml;
            } else {
                document.getElementById('driverPerformanceImpact').innerHTML = 
                    '<div class="text-muted p-20" style="text-align: center;">Driver performance data not available</div>';
            }
        }

        // Load Browsers Tab - Redesigned with Priority-Based Layout
