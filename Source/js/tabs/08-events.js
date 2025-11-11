        function loadEventsTab() {
            const eventsData = window.systemData.Events;

            if (!eventsData) {
                const eventsTab = document.getElementById('events');
                if (eventsTab) {
                    eventsTab.innerHTML = '<p style="padding: 20px; color: var(--text-secondary);">No event data available</p>';
                }
                return;
            }

            // TIER 1: CRITICAL TRIAGE
            // 0. Overall Event Health Status Banner
            loadEventHealthBanner(eventsData);

            // 1. Event Health Dashboard (metrics)
            loadEventHealthDashboard(eventsData);

            // 2. Critical Issues & Immediate Actions
            loadCriticalIssuesSection(eventsData);

            // TIER 2: DIAGNOSTIC DETAIL
            // 3. Event Pattern Analysis
            loadEventPatternSection(eventsData);

            // 4. Event Overview & Statistics
            loadEventOverviewSection(eventsData);

            // 5. Recent Critical Events Timeline
            loadEventTimelineSection(eventsData);

            // TIER 3: ADVANCED INFORMATION
            // 6. Detailed Event Logs
            loadDetailedEventsSection(eventsData);

            // Setup event search
            setupEventSearch();
        }
        
        function loadEventHealthBanner(eventsData) {
            const banner = document.getElementById('eventHealthBanner');
            if (!banner) return;

            const summary = eventsData.Summary || {};
            const criticalCount = summary.Critical || 0;
            const errorCount = summary.Errors || 0;
            const warningCount = summary.Warnings || 0;

            // Check for recent critical events
            const recentCritical = eventsData.Events?.Critical?.filter(e => {
                const time = e.RelativeTime || '';
                return time.includes('minute') || time.includes('hour') || (time.includes('day') && parseInt(time) <= 1);
            }) || [];

            // Determine overall health status
            let criticalIssues = [];
            let warningIssues = [];
            let overallHealthStatus = 'healthy';

            if (criticalCount > 0) {
                criticalIssues.push(`${criticalCount} critical event${criticalCount > 1 ? 's' : ''} detected`);
            }

            if (recentCritical.length > 0) {
                criticalIssues.push(`${recentCritical.length} critical event${recentCritical.length > 1 ? 's' : ''} in last 24 hours`);
            }

            if (errorCount > 20) {
                warningIssues.push(`${errorCount} error events in last 30 days`);
            } else if (errorCount > 10) {
                warningIssues.push(`${errorCount} error events detected`);
            }

            if (warningCount > 100) {
                warningIssues.push(`${warningCount} warning events in last 30 days`);
            }

            // Check for patterns
            const patterns = eventsData.PatternAnalysis?.Patterns || [];
            const highSeverityPatterns = patterns.filter(p => p.Severity === 'High' || p.Count > 20);
            if (highSeverityPatterns.length > 0) {
                warningIssues.push(`${highSeverityPatterns.length} recurring pattern${highSeverityPatterns.length > 1 ? 's' : ''} detected`);
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
                               overallHealthStatus === 'warning' ? 'Warnings Detected' : 'System Healthy';

            const allIssues = [...criticalIssues, ...warningIssues];

            let healthBannerHtml = `
                <div class="health-status">
                    <span class="health-icon">${healthIcon}</span>
                    <strong>Event System Health: ${healthText}</strong>
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

        function loadEventHealthDashboard(eventsData) {
            const section = document.getElementById('eventHealthDashboard');
            if (!section) return;

            const summary = eventsData.Summary || {};
            const criticalCount = summary.Critical || 0;
            const errorCount = summary.Errors || 0;
            const warningCount = summary.Warnings || 0;
            const totalEvents = summary.TotalEvents || 0;

            // Calculate health score
            let healthScore = 100;
            healthScore -= (criticalCount * 10); // Each critical reduces by 10
            healthScore -= (errorCount * 2);     // Each error reduces by 2
            healthScore -= (warningCount * 0.5); // Each warning reduces by 0.5
            healthScore = Math.max(0, Math.min(100, healthScore));

            let healthStatus = 'Healthy';
            let healthColor = 'var(--success-color)';
            if (healthScore < 50) {
                healthStatus = 'Critical';
                healthColor = 'var(--danger-color)';
            } else if (healthScore < 70) {
                healthStatus = 'Unhealthy';
                healthColor = '#fd7e14';
            } else if (healthScore < 90) {
                healthStatus = 'Warning';
                healthColor = 'var(--warning-color)';
            }

            // Check for recent critical events
            const recentCritical = eventsData.Events?.Critical?.filter(e => {
                const time = e.RelativeTime || '';
                return time.includes('minute') || time.includes('hour') || (time.includes('day') && parseInt(time) <= 1);
            }) || [];

            let dashboardHtml = `
                <div class="grid grid-4" style="margin-bottom: 25px;">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${healthColor};">${healthScore}</div>
                        <div class="metric-label">Health Score</div>
                        <div class="metric-sublabel">${healthStatus}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--danger-color);">${criticalCount}</div>
                        <div class="metric-label">Critical Events</div>
                        <div class="metric-sublabel">${recentCritical.length > 0 ? `${recentCritical.length} recent` : 'None recent'}</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: #fd7e14;">${errorCount}</div>
                        <div class="metric-label">Error Events</div>
                        <div class="metric-sublabel">Last 30 days</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--warning-color);">${warningCount}</div>
                        <div class="metric-label">Warning Events</div>
                        <div class="metric-sublabel">Last 30 days</div>
                    </div>
                </div>
            `;

            // Add visual event distribution bar
            if (totalEvents > 0) {
                const criticalPercent = (criticalCount / totalEvents) * 100;
                const errorPercent = (errorCount / totalEvents) * 100;
                const warningPercent = (warningCount / totalEvents) * 100;
                const infoPercent = 100 - criticalPercent - errorPercent - warningPercent;

                dashboardHtml += `
                    <div style="margin-bottom: 20px;">
                        <h4 style="margin-bottom: 10px;">Event Distribution</h4>
                        <div style="display: flex; height: 30px; border-radius: 6px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            ${criticalPercent > 0 ? `<div style="width: ${criticalPercent}%; background: var(--danger-color); display: flex; align-items: center; justify-content: center; color: white; font-size: 0.8rem;">${criticalPercent > 5 ? Math.round(criticalPercent) + '%' : ''}</div>` : ''}
                            ${errorPercent > 0 ? `<div style="width: ${errorPercent}%; background: #fd7e14; display: flex; align-items: center; justify-content: center; color: white; font-size: 0.8rem;">${errorPercent > 5 ? Math.round(errorPercent) + '%' : ''}</div>` : ''}
                            ${warningPercent > 0 ? `<div style="width: ${warningPercent}%; background: var(--warning-color); display: flex; align-items: center; justify-content: center; color: black; font-size: 0.8rem;">${warningPercent > 5 ? Math.round(warningPercent) + '%' : ''}</div>` : ''}
                            ${infoPercent > 0 ? `<div style="width: ${infoPercent}%; background: var(--info-color); display: flex; align-items: center; justify-content: center; color: white; font-size: 0.8rem;">${infoPercent > 5 ? Math.round(infoPercent) + '%' : ''}</div>` : ''}
                        </div>
                        <div style="display: flex; justify-content: space-between; margin-top: 8px; font-size: 0.8rem; color: var(--text-muted);">
                            <span>🔴 Critical</span>
                            <span>🟠 Errors</span>
                            <span>🟡 Warnings</span>
                            <span>🔵 Information</span>
                        </div>
                    </div>
                `;
            }

            section.innerHTML = dashboardHtml;
        }

        function loadCriticalIssuesSection(eventsData) {
            const section = document.getElementById('criticalIssuesSection');
            if (!section) return;
            
            let html = '';
            const criticalEvents = eventsData.Events?.Critical || [];
            const crashes = criticalEvents.filter(e => e.Id === 1001 || e.Id === 1074);
            const shutdowns = criticalEvents.filter(e => e.Id === 41 || e.Id === 6008);
            const recurringErrors = eventsData.PatternAnalysis?.Patterns?.filter(p => p.Severity === 'High') || [];
            
            // Update priority indicator
            
            if (crashes.length === 0 && shutdowns.length === 0 && recurringErrors.length === 0 && criticalEvents.length === 0) {
                html = `
                    <div style="display: flex; align-items: center; gap: 15px; padding: 20px; background: linear-gradient(135deg, rgba(40, 167, 69, 0.1) 0%, rgba(40, 167, 69, 0.05) 100%); border-radius: 8px; border-left: 4px solid var(--success-color);">
                        <div style="font-size: 2.5rem;">✅</div>
                        <div>
                            <h3 style="margin: 0; color: var(--success-color);">All Systems Operational</h3>
                            <p style="margin: 5px 0 0 0; color: var(--text-secondary);">No critical issues detected in recent event logs</p>
                        </div>
                    </div>
                `;
            } else {
                html = '<div style="display: grid; gap: 15px;">';

                // System crashes
                if (crashes.length > 0) {
                    html += `
                        <div class="event-severity-card critical" style="border: 1px solid rgba(220, 53, 69, 0.3);">
                            <div style="display: flex; gap: 20px;">
                                <div style="font-size: 3rem;">💥</div>
                                <div style="flex: 1;">
                                    <h3 style="margin: 0 0 10px 0; color: var(--danger-color);">System Crash Detected</h3>
                                    <div style="display: grid; gap: 8px;">
                                        <div><strong>Frequency:</strong> ${crashes.length} crash${crashes.length > 1 ? 'es' : ''} detected</div>
                                        <div><strong>Most Recent:</strong> ${crashes[0].RelativeTime || 'Unknown'}</div>
                                        <div><strong>Event ID:</strong> ${crashes[0].Id}</div>
                                    </div>
                                    <div style="margin-top: 15px; padding: 10px; background: rgba(0,0,0,0.1); border-radius: 4px; font-size: 0.9rem;">
                                        ${escapeHtml(crashes[0].Message || 'No additional details available')}
                                    </div>
                                    <div style="margin-top: 10px;">
                                        <button class="status-badge status-critical" style="border: none; padding: 6px 12px; cursor: pointer;" onclick="filterEvents('crashes')">
                                            View All Crashes →
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                // Unexpected shutdowns
                if (shutdowns.length > 0) {
                    const recentShutdowns = shutdowns.filter(e => {
                        const time = e.RelativeTime || '';
                        return time.includes('hour') || time.includes('minute') || time.includes('day');
                    });

                    html += `
                        <div class="event-severity-card error" style="border: 1px solid rgba(253, 126, 20, 0.3);">
                            <div style="display: flex; gap: 20px;">
                                <div style="font-size: 3rem;">🔌</div>
                                <div style="flex: 1;">
                                    <h3 style="margin: 0 0 10px 0; color: #fd7e14;">Unexpected Shutdowns</h3>
                                    <div style="display: grid; gap: 8px;">
                                        <div><strong>Total Count:</strong> ${shutdowns.length} shutdown${shutdowns.length > 1 ? 's' : ''}</div>
                                        ${recentShutdowns.length > 0 ? `<div><strong>Most Recent:</strong> ${recentShutdowns[0].RelativeTime}</div>` : ''}
                                        ${recentShutdowns.length > 0 ? `<div><strong>Event ID:</strong> ${recentShutdowns[0].Id}</div>` : ''}
                                    </div>
                                    <div style="margin-top: 15px; padding: 10px; background: rgba(0,0,0,0.1); border-radius: 4px; font-size: 0.9rem;">
                                        ${shutdowns[0].Id === 41 ? '📌 Note: Event ID 41 may include user-initiated restarts' : escapeHtml(shutdowns[0].Message || 'No additional details available')}
                                    </div>
                                    <div style="margin-top: 10px;">
                                        <button class="status-badge" style="background: #fd7e14; color: white; border: none; padding: 6px 12px; cursor: pointer;" onclick="filterEvents('shutdowns')">
                                            View All Shutdowns →
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }
                
                // Recurring high-severity patterns
                recurringErrors.forEach(pattern => {
                    html += `
                        <div class="event-severity-card warning" style="border: 1px solid rgba(255, 193, 7, 0.3);">
                            <div style="display: flex; gap: 20px;">
                                <div style="font-size: 3rem;">🔁</div>
                                <div style="flex: 1;">
                                    <h3 style="margin: 0 0 10px 0; color: var(--warning-color);">Recurring Pattern: ${pattern.Type}</h3>
                                    <div style="display: grid; gap: 8px;">
                                        <div><strong>Frequency:</strong> ${pattern.Count} occurrences</div>
                                        <div><strong>First Seen:</strong> ${formatDateISO(new Date(pattern.FirstOccurrence))}</div>
                                        <div><strong>Last Seen:</strong> ${formatDateISO(new Date(pattern.LastOccurrence))}</div>
                                    </div>
                                    <div style="margin-top: 15px; padding: 10px; background: rgba(0,0,0,0.1); border-radius: 4px; font-size: 0.9rem;">
                                        ${escapeHtml(pattern.Message)}
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                });

                // BugCheck (Blue Screen) Events
                if (eventsData.BugCheckEvents && eventsData.BugCheckEvents.length > 0) {
                    html += `
                        <div class="event-severity-card critical" style="border: 1px solid rgba(220, 53, 69, 0.3); background: linear-gradient(135deg, rgba(220, 53, 69, 0.05) 0%, rgba(220, 53, 69, 0.02) 100%);">
                            <div style="display: flex; gap: 20px;">
                                <div style="font-size: 3rem;">💻</div>
                                <div style="flex: 1;">
                                    <h3 style="margin: 0 0 10px 0; color: var(--danger-color);">🔵 Blue Screen of Death (BSOD)</h3>
                                    <div style="display: grid; gap: 8px;">
                                        <div><strong>Total BSODs:</strong> ${eventsData.BugCheckEvents.length} event${eventsData.BugCheckEvents.length > 1 ? 's' : ''}</div>
                                        <div><strong>System Stability:</strong> <span class="status-badge status-critical">Compromised</span></div>
                                    </div>
                                    <div style="margin-top: 15px;">
                                        <strong>Recent Blue Screen Events:</strong>
                                        ${eventsData.BugCheckEvents.slice(0, 3).map(bugcheck => `
                                            <div style="padding: 10px; margin-top: 10px; background: rgba(0,0,0,0.2); border-radius: 4px; border-left: 3px solid var(--danger-color);">
                                                <div style="display: flex; justify-content: space-between; align-items: center;">
                                                    <strong>${bugcheck.RelativeTime || 'Unknown time'}</strong>
                                                    <span class="status-badge status-critical">BSOD</span>
                                                </div>
                                                <div style="margin-top: 5px; font-size: 0.9rem; color: var(--text-secondary);">
                                                    ${escapeHtml((bugcheck.Message || 'No details available').substring(0, 300))}${bugcheck.Message?.length > 300 ? '...' : ''}
                                                </div>
                                            </div>
                                        `).join('')}
                                    </div>
                                </div>
                            </div>
                        </div>
                    `;
                }

                html += '</div>'; // Close the grid
            }
            
            section.innerHTML = html;
        }
        
        function loadEventPatternSection(eventsData) {
            const section = document.getElementById('eventPatternSection');
            if (!section) return;
            
            const analysis = eventsData.PatternAnalysis;
            let html = '';
            
            // Pattern metrics
            const patterns = analysis?.Patterns || [];
            const insights = analysis?.Insights || [];
            const errorEvents = eventsData.Events?.Error || [];
            const warningEvents = eventsData.Events?.Warning || [];
            
            html += `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${patterns.length > 0 ? 'var(--danger-color)' : 'inherit'}">
                            ${patterns.length}
                        </div>
                        <div class="metric-label">Patterns Detected</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: ${errorEvents.length > 10 ? 'var(--warning-color)' : 'inherit'}">
                            ${errorEvents.length}
                        </div>
                        <div class="metric-label">Error Events</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${warningEvents.length}</div>
                        <div class="metric-label">Warning Events</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">${analysis?.TopSource || 'N/A'}</div>
                        <div class="metric-label">Most Common Source</div>
                    </div>
                </div>
            `;
            
            // Key Insights
            if (insights.length > 0) {
                html += '<div style="margin-top: 20px;"><h3>Key Insights</h3><ul style="list-style: none; padding: 0;">';
                insights.forEach(insight => {
                    html += `
                        <li style="padding: 10px; background: var(--bg-tertiary); border-radius: 6px; margin-bottom: 10px;">
                            ${escapeHtml(insight)}
                        </li>
                    `;
                });
                html += '</ul></div>';
            }
            
            // Detected Patterns
            if (patterns.length > 0) {
                html += '<div style="margin-top: 20px;"><h3>Detected Patterns</h3>';
                patterns.forEach(pattern => {
                    const severityColor = pattern.Severity === 'High' ? 'var(--danger-color)' : 
                                         pattern.Severity === 'Medium' ? 'var(--warning-color)' : 'var(--info-color)';
                    html += `
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px; margin-bottom: 10px; border-left: 4px solid ${severityColor};">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <strong>${pattern.Type}</strong>
                                <span class="status-badge status-${pattern.Severity === 'High' ? 'critical' : pattern.Severity === 'Medium' ? 'warning' : 'info'}">
                                    ${pattern.Severity} Priority
                                </span>
                            </div>
                            <div style="margin-top: 10px; color: var(--text-secondary);">${escapeHtml(pattern.Message)}</div>
                            <div style="margin-top: 10px; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; font-size: 0.9rem;">
                                <div><strong>Count:</strong> ${pattern.Count}</div>
                                <div><strong>First:</strong> ${formatDateISO(new Date(pattern.FirstOccurrence))}</div>
                                <div><strong>Last:</strong> ${formatDateISO(new Date(pattern.LastOccurrence))}</div>
                                ${pattern.EventIds ? `<div><strong>Event IDs:</strong> ${Array.isArray(pattern.EventIds) ? pattern.EventIds.join(', ') : pattern.EventIds}</div>` : ''}
                                ${pattern.TopService ? `<div><strong>Top Failing Service:</strong> ${pattern.TopService} (${pattern.TopServiceFailures} failures)</div>` : ''}
                            </div>
                        </div>
                    `;
                });
                html += '</div>';
            }

            // Add Insights section if available
            if (insights && insights.length > 0) {
                html += `
                    <div style="margin-top: 20px;">
                        <h4 style="margin-bottom: 10px;">📊 Analysis Insights</h4>
                        <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px;">
                            <ul style="margin: 0; padding-left: 20px;">
                                ${insights.map(insight => `<li style="margin-bottom: 8px;">${insight}</li>`).join('')}
                            </ul>
                        </div>
                    </div>
                `;
            }

            if (patterns.length === 0 && insights.length === 0) {
                html += '<div style="margin-top: 20px; padding: 20px; text-align: center; color: var(--text-secondary);">No significant patterns detected in recent events</div>';
            }
            
            section.innerHTML = html;
        }
        
        function loadEventOverviewSection(eventsData) {
            const section = document.getElementById('eventOverviewSection');
            if (!section) return;
            
            const summary = eventsData.Summary || {};
            
            let html = `
                <div class="grid grid-4">
                    <div class="metric-card">
                        <div class="metric-value">${summary.TotalEvents || 0}</div>
                        <div class="metric-label">Total Events</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--danger-color);">${summary.Critical || 0}</div>
                        <div class="metric-label">Critical</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--warning-color);">${summary.Errors || 0}</div>
                        <div class="metric-label">Errors</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value" style="color: var(--info-color);">${summary.Warnings || 0}</div>
                        <div class="metric-label">Warnings</div>
                    </div>
                </div>

                <div class="event-filters" style="margin-top: 20px;">
                    <button class="filter-btn active" data-filter="all">All Events</button>
                    <button class="filter-btn" data-filter="crashes">System Crashes</button>
                    <button class="filter-btn" data-filter="shutdowns">Unexpected Shutdowns</button>
                    <button class="filter-btn" data-filter="applications">Application Errors</button>
                    <button class="filter-btn" data-filter="services">Service Issues</button>
                    <button class="filter-btn" data-filter="security">Security</button>
                    <button class="filter-btn" data-filter="hardware">Hardware</button>
                    <button class="filter-btn" data-filter="updates">Updates</button>
                </div>
            `;

            // Add Top Event Sources if available
            if (eventsData.TopSources && eventsData.TopSources.length > 0) {
                // Calculate what percentage each source represents
                const totalEvents = eventsData.Summary?.TotalEvents || eventsData.TopSources.reduce((sum, s) => sum + s.Count, 0);

                html += `
                    <div style="margin-top: 30px;">
                        <h4 style="margin-bottom: 15px;">Top Event Sources (Most Active)</h4>
                        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 10px;">
                            ${eventsData.TopSources.slice(0, 6).map(source => {
                                const percentage = totalEvents > 0 ? Math.round((source.Count / totalEvents) * 100) : 0;

                                // Determine if this source is problematic based on the name and count
                                let statusColor = 'var(--text-muted)';
                                let statusText = 'Normal';

                                // Known problematic sources
                                if (source.Source && (
                                    source.Source.includes('Application Error') ||
                                    source.Source.includes('Application Hang') ||
                                    source.Source.includes('Windows Error Reporting') ||
                                    source.Source.includes('Application Popup')
                                )) {
                                    statusColor = 'var(--danger-color)';
                                    statusText = 'Issues Detected';
                                } else if (source.Count > 50) {
                                    statusColor = 'var(--warning-color)';
                                    statusText = 'High Volume';
                                } else if (source.Source && (
                                    source.Source.includes('DCOM') ||
                                    source.Source.includes('DistributedCOM')
                                )) {
                                    statusColor = 'var(--warning-color)';
                                    statusText = 'Permission Issues';
                                }

                                return `
                                    <div style="background: var(--bg-tertiary); padding: 12px; border-radius: 4px; border-left: 3px solid ${statusColor};">
                                        <div style="font-weight: 600; font-size: 0.9rem; margin-bottom: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHtml(source.Source || 'Unknown')}">
                                            ${escapeHtml(source.Source || 'Unknown')}
                                        </div>
                                        <div style="display: flex; justify-content: space-between; align-items: center;">
                                            <div>
                                                <div style="font-size: 1.2rem; color: var(--accent-color);">${source.Count} events</div>
                                                <div style="font-size: 0.8rem; color: var(--text-muted);">${percentage}% of total</div>
                                            </div>
                                            <div style="font-size: 0.75rem; color: ${statusColor};">
                                                ${statusText}
                                            </div>
                                        </div>
                                    </div>
                                `;
                            }).join('')}
                        </div>
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-tertiary); border-radius: 4px; font-size: 0.85rem; color: var(--text-muted);">
                            💡 <strong>Tip:</strong> High event counts from error reporting sources indicate application stability issues.
                            DCOM events often indicate permission problems. Service Control Manager events are typically normal unless excessive.
                        </div>
                    </div>
                `;
            }

            // Add Categories breakdown if available
            if (eventsData.Categories) {
                html += `
                    <div style="margin-top: 30px;">
                        <h4 style="margin-bottom: 15px;">Events by Category</h4>
                        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 15px;">
                `;

                const categoryInfo = {
                    'SystemCrashes': {
                        icon: '💥',
                        name: 'System Crashes',
                        critical: 1,  // Even 1 is critical
                        warning: 0,   // Any amount is bad
                        normalText: 'No crashes',
                        warningText: 'Stability issues',
                        criticalText: 'System unstable',
                        description: 'Blue screens, unexpected shutdowns'
                    },
                    'ApplicationErrors': {
                        icon: '⚠️',
                        name: 'Application Errors',
                        critical: 10,
                        warning: 5,
                        normalText: 'Apps stable',
                        warningText: 'Some app issues',
                        criticalText: 'Apps crashing frequently',
                        description: 'Program crashes and hangs'
                    },
                    'ServiceIssues': {
                        icon: '⚙️',
                        name: 'Service Issues',
                        critical: 10,
                        warning: 5,
                        normalText: 'Services healthy',
                        warningText: 'Service disruptions',
                        criticalText: 'Multiple service failures',
                        description: 'Windows service failures'
                    },
                    'UpdateEvents': {
                        icon: '🔄',
                        name: 'Update Events',
                        critical: -1,  // Never critical
                        warning: -1,   // Never warning
                        normalText: 'Updates logged',
                        warningText: '',
                        criticalText: '',
                        description: 'Windows Update activity'
                    },
                    'SecurityEvents': {
                        icon: '🔒',
                        name: 'Security Events',
                        critical: 50,
                        warning: 20,
                        normalText: 'Security normal',
                        warningText: 'Auth failures detected',
                        criticalText: 'Possible attack',
                        description: 'Login failures, lockouts'
                    },
                    'HardwareEvents': {
                        icon: '🖥️',
                        name: 'Hardware Events',
                        critical: 20,
                        warning: 10,
                        normalText: 'Hardware OK',
                        warningText: 'Hardware warnings',
                        criticalText: 'Hardware problems',
                        description: 'DCOM, device errors'
                    }
                };

                for (const [category, events] of Object.entries(eventsData.Categories)) {
                    if (events && events.length > 0) {
                        const info = categoryInfo[category] || {
                            icon: '📋',
                            name: category,
                            critical: 50,
                            warning: 20,
                            normalText: 'Normal',
                            warningText: 'Elevated',
                            criticalText: 'High',
                            description: ''
                        };

                        // Determine status
                        let statusColor = 'var(--success-color)';
                        let statusText = info.normalText;
                        let borderColor = 'var(--border-color)';

                        if (info.critical > 0 && events.length >= info.critical) {
                            statusColor = 'var(--danger-color)';
                            statusText = info.criticalText;
                            borderColor = 'var(--danger-color)';
                        } else if (info.warning > 0 && events.length >= info.warning) {
                            statusColor = 'var(--warning-color)';
                            statusText = info.warningText;
                            borderColor = 'var(--warning-color)';
                        }

                        // Get most recent event IDs (unique)
                        const recentEventIds = [...new Set(events.slice(0, 5).map(e => e.Id))].join(', ');

                        html += `
                            <div style="background: var(--bg-tertiary); padding: 15px; border-radius: 6px; border-left: 4px solid ${borderColor};">
                                <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 10px;">
                                    <div style="font-weight: 600;">
                                        ${info.icon} ${info.name}
                                    </div>
                                    <span style="font-size: 0.8rem; color: ${statusColor}; font-weight: 500;">
                                        ${statusText}
                                    </span>
                                </div>
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                                    <div style="font-size: 1.8rem; color: var(--accent-color);">${events.length}</div>
                                    <div style="text-align: right; font-size: 0.85rem;">
                                        <div style="color: var(--text-muted);">Latest: ${events[0]?.RelativeTime || 'Unknown'}</div>
                                    </div>
                                </div>
                                <div style="font-size: 0.8rem; color: var(--text-muted);">
                                    ${info.description}
                                </div>
                                ${recentEventIds ? `
                                    <div style="font-size: 0.75rem; color: var(--text-muted); margin-top: 5px;">
                                        Event IDs: ${recentEventIds}
                                    </div>
                                ` : ''}
                            </div>
                        `;
                    }
                }

                html += `
                        </div>
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-tertiary); border-radius: 4px; font-size: 0.85rem; color: var(--text-muted);">
                            💡 <strong>Action Guide:</strong> System crashes require immediate investigation.
                            Application errors >10 indicate software instability.
                            Security events >20 may indicate brute force attempts.
                            Hardware events often point to driver or permission issues.
                        </div>
                    </div>
                `;
            }

            html += `
            `;
            
            section.innerHTML = html;
            
            // Setup filter buttons
            section.querySelectorAll('.filter-btn').forEach(btn => {
                btn.addEventListener('click', function() {
                    section.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                    this.classList.add('active');
                    
                    const filter = this.dataset.filter;
                    document.querySelectorAll('.timeline-event').forEach(event => {
                        if (filter === 'all' || event.dataset.category === filter) {
                            event.style.display = 'block';
                        } else {
                            event.style.display = 'none';
                        }
                    });
                });
            });
        }
        
        function loadEventTimelineSection(eventsData) {
            const section = document.getElementById('eventTimelineContent');
            if (!section) return;
            
            // Only show critical events in this section
            const criticalEvents = eventsData.Events?.Critical || [];
            const timelineEvents = [...criticalEvents]
                .sort((a, b) => {
                    // Sort by time if available
                    if (a.TimeCreated && b.TimeCreated) {
                        return new Date(b.TimeCreated) - new Date(a.TimeCreated);
                    }
                    return 0;
                })
                .slice(0, 20); // Show max 20 critical events in timeline
            
            if (timelineEvents.length === 0) {
                section.innerHTML = '<div style="padding: 20px; text-align: center; color: var(--text-secondary);">No critical events to display</div>';
                return;
            }
            
            let html = '<div class="event-timeline" style="padding: 20px;">';
            
            timelineEvents.forEach(event => {
                const category = getEventCategory(event.Id);
                
                html += `
                    <div class="timeline-event critical" data-category="${category}" style="display: flex; margin-bottom: 20px; padding-left: 30px; position: relative;">
                        <div style="position: absolute; left: 10px; top: 8px; width: 8px; height: 8px; border-radius: 50%; background: var(--danger-color);"></div>
                        <div style="flex: 1;">
                            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 5px;">
                                <strong>${escapeHtml(event.EventName || `Event ${event.Id}`)}</strong>
                                <span class="status-badge status-critical">Critical</span>
                            </div>
                            <div style="color: var(--text-secondary); font-size: 0.9rem;">
                                ${event.RelativeTime || ''} • Event ID: ${event.Id} • Source: ${escapeHtml(event.ProviderName || 'Unknown')} • Log: ${event.LogName || 'Unknown'}
                            </div>
                            <div style="margin-top: 5px;">${escapeHtml((event.Message || '').substring(0, 200))}${event.Message?.length > 200 ? '...' : ''}</div>
                        </div>
                    </div>
                `;
            });
            
            html += '</div>';
            section.innerHTML = html;
        }
        
        function loadDetailedEventsSection(eventsData) {
            const section = document.getElementById('detailedEventsSection');
            if (!section) return;

            const criticalEvents = eventsData.Events?.Critical || [];
            const errorEvents = eventsData.Events?.Error || [];
            const warningEvents = eventsData.Events?.Warning || [];
            const infoEvents = eventsData.Events?.Information || [];

            let html = '';

            // Critical Events (expanded by default)
            html += `
                <div class="collapsible-section">
                    <button class="collapsible-header" aria-expanded="true" onclick="toggleEventCollapsible(this)">
                        <span class="collapsible-icon">▼</span>
                        <h3 class="collapsible-title">🔴 Critical Events (${criticalEvents.length})</h3>
                    </button>
                    <div class="collapsible-content">
            `;

            if (criticalEvents.length > 0) {
                criticalEvents.forEach(event => {
                    html += createDetailedEventHTML(event, 'critical');
                });
            } else {
                html += '<p style="color: var(--text-secondary); padding: 10px;">No critical events</p>';
            }
            html += '</div></div>';

            // Error Events (collapsed by default)
            html += `
                <div class="collapsible-section">
                    <button class="collapsible-header" aria-expanded="false" onclick="toggleEventCollapsible(this)">
                        <span class="collapsible-icon">▼</span>
                        <h3 class="collapsible-title">🟠 Error Events (${errorEvents.length})</h3>
                    </button>
                    <div class="collapsible-content collapsed">
            `;

            if (errorEvents.length > 0) {
                errorEvents.forEach(event => {
                    html += createDetailedEventHTML(event, 'error');
                });
            } else {
                html += '<p style="color: var(--text-secondary); padding: 10px;">No error events</p>';
            }
            html += '</div></div>';

            // Warning Events (collapsed by default)
            html += `
                <div class="collapsible-section">
                    <button class="collapsible-header" aria-expanded="false" onclick="toggleEventCollapsible(this)">
                        <span class="collapsible-icon">▼</span>
                        <h3 class="collapsible-title">🟡 Warning Events (${warningEvents.length})</h3>
                    </button>
                    <div class="collapsible-content collapsed">
            `;

            if (warningEvents.length > 0) {
                warningEvents.forEach(event => {
                    html += createDetailedEventHTML(event, 'warning');
                });
            } else {
                html += '<p style="color: var(--text-secondary); padding: 10px;">No warning events</p>';
            }
            html += '</div></div>';

            // Information Events (collapsed by default)
            if (infoEvents.length > 0) {
                html += `
                    <div class="collapsible-section">
                        <button class="collapsible-header" aria-expanded="false" onclick="toggleEventCollapsible(this)">
                            <span class="collapsible-icon">▼</span>
                            <h3 class="collapsible-title">🔵 Information Events (${infoEvents.length})</h3>
                        </button>
                        <div class="collapsible-content collapsed">
                `;

                infoEvents.slice(0, 50).forEach(event => {
                    html += createDetailedEventHTML(event, 'info');
                });

                if (infoEvents.length > 50) {
                    html += `<p style="color: var(--text-secondary); text-align: center; padding: 10px;">Showing first 50 of ${infoEvents.length} information events</p>`;
                }
                html += '</div></div>';
            }

            section.innerHTML = html;
        }

        // Toggle function specific to event collapsibles
        function toggleEventCollapsible(button) {
            const isExpanded = button.getAttribute('aria-expanded') === 'true';
            const content = button.nextElementSibling;

            button.setAttribute('aria-expanded', !isExpanded);

            if (isExpanded) {
                content.classList.add('collapsed');
            } else {
                content.classList.remove('collapsed');
            }
        }
        
        function createDetailedEventHTML(event, severity) {
            return `
                <div style="background: var(--bg-tertiary); padding: 10px; border-radius: 4px; margin-bottom: 10px; border-left: 3px solid ${
                    severity === 'critical' ? 'var(--danger-color)' : 
                    severity === 'error' ? 'var(--warning-color)' : 
                    severity === 'warning' ? 'var(--info-color)' : 'var(--border-color)'
                };">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 5px;">
                        <strong>${escapeHtml(event.EventName || `Event ${event.Id}`)}</strong>
                        <span style="font-size: 0.9rem; color: var(--text-secondary);">${event.RelativeTime || ''}</span>
                    </div>
                    <div style="font-size: 0.9rem; color: var(--text-secondary); margin-bottom: 5px;">
                        Event ID: ${event.Id} • Source: ${escapeHtml(event.ProviderName || 'Unknown')} • Log: ${event.LogName || 'Unknown'}
                    </div>
                    <div style="font-size: 0.95rem;">${escapeHtml(event.Message || 'No message available')}</div>
                </div>
            `;
        }
        
        function toggleCollapsible(element) {
            const content = element.nextElementSibling;
            const icon = element.querySelector('span');
            
            if (content.style.display === 'none') {
                content.style.display = 'block';
                icon.textContent = '▼';
            } else {
                content.style.display = 'none';
                icon.textContent = '▶';
            }
        }

        function getEventCategory(eventId) {
            const categories = {
                crashes: [1001, 1074],  // BSODs and system shutdown/restart
                shutdowns: [41, 6008],  // Unexpected shutdowns (kernel power, dirty shutdown)
                applications: [1000, 1002],
                services: [7034, 7035, 7036],
                security: [4625, 4740, 4776],
                updates: [19, 20, 43, 44]
            };
            
            for (const [category, ids] of Object.entries(categories)) {
                if (ids.includes(eventId)) return category;
            }
            return 'other';
        }


        function setupEventSearch() {
            const searchInput = document.getElementById('event-search-input');
            if (searchInput) {
                searchInput.addEventListener('input', function() {
                    const searchTerm = this.value.toLowerCase();
                    const events = document.querySelectorAll('.event-item');
                    
                    events.forEach(event => {
                        const text = event.textContent.toLowerCase();
                        event.style.display = text.includes(searchTerm) ? 'block' : 'none';
                    });
                });
            }
        }


        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text || '';
            return div.innerHTML;
        }

        function updateBadges() {
            // Count issues for each tab
            const badges = {
                os: 0,
                hardware: 0,
                network: 0,
                printers: 0,
                software: 0,
                drivers: 0,
                browsers: 0,
                events: 0
            };
            
            // OS issues
            if (systemData.OS?.AllUserProfiles?.Summary?.HasTemporaryProfiles) badges.os++;
            if (systemData.OS?.Services?.StoppedCritical?.length > 0) badges.os += systemData.OS.Services.StoppedCritical.length;
            if (systemData.OS?.Services?.DisabledCritical?.length > 0) badges.os += systemData.OS.Services.DisabledCritical.length;
            if (systemData.OS?.Services?.Issues?.length > 0) badges.os += systemData.OS.Services.Issues.length;
            
            // Hardware issues
            if (systemData.Hardware?.Storage?.CriticalDevices > 0) badges.hardware += systemData.Hardware.Storage.CriticalDevices;
            
            // Network issues - only count if there are actual critical connectivity failures
            if (systemData.Network?.ConnectivityTests?.Tests) {
                const criticalTests = systemData.Network.ConnectivityTests.Tests.filter(t => 
                    t.Status === 'Critical' && (t.Test === 'Internet' || t.Test === 'DNS' || t.Test === 'Gateway')
                );
                if (criticalTests.length > 0) {
                    badges.network = criticalTests.length;
                }
            }
            
            // Printer issues
            if (systemData.Printers?.Summary?.StuckJobs > 0) badges.printers += systemData.Printers.Summary.StuckJobs;
            if (systemData.Printers?.Summary?.OfflinePrinters > 0) badges.printers += systemData.Printers.Summary.OfflinePrinters;
            
            // Software issues
            let softwareCrashes = systemData.Software?.ApplicationHealth?.Summary?.TotalCrashes72h || 0;
            // Handle case where it might be an object from Measure-Object
            if (typeof softwareCrashes === 'object') softwareCrashes = softwareCrashes?.Sum || 0;
            softwareCrashes = Number(softwareCrashes) || 0;
            if (softwareCrashes > 0) 
                badges.software += softwareCrashes;
            
            // Driver issues - only count actual problems
            if (systemData.Drivers?.ProblemDevices) {
                const actualProblemDrivers = systemData.Drivers.ProblemDevices.filter(device => 
                    device.ProblemCode && device.ProblemCode !== 0 && device.ProblemCode !== null
                );
                badges.drivers += actualProblemDrivers.length;
            }
            if (systemData.Drivers?.AllDrivers) {
                const missingDrivers = systemData.Drivers.AllDrivers.filter(driver => 
                    driver.ProblemCode === 28 || (driver.ProblemDescription && driver.ProblemDescription.includes('not installed'))
                );
                badges.drivers += missingDrivers.length;
            }
            
            // Browser issues - only count Critical and Warning, not Info
            if (systemData.Browsers?.Summary?.CriticalIssues > 0) badges.browsers += systemData.Browsers.Summary.CriticalIssues;
            if (systemData.Browsers?.Summary?.WarningIssues > 0) badges.browsers += systemData.Browsers.Summary.WarningIssues;
            
            // Events issues - only Critical events
            if (systemData.Events?.Summary?.Critical > 0) badges.events += systemData.Events.Summary.Critical;

            // Update badge displays
            Object.keys(badges).forEach(tab => {
                const badge = document.getElementById(`${tab}Badge`);
                if (badge) {
                    if (badges[tab] > 0) {
                        badge.textContent = badges[tab];
                        badge.classList.remove('hidden');
                    } else {
                        badge.classList.add('hidden');
                    }
                }
            });
        }

        function loadTicketNotesTab() {
            // Don't auto-generate - wait for user to click button
            // Reset the display when switching to the tab
            document.getElementById('ticket-notes-placeholder').style.display = 'block';
            document.getElementById('ticket-notes-text').style.display = 'none';
            document.getElementById('copy-ticket-notes-btn').style.display = 'none';
        }
        
        function generateAndDisplayTicketNotes() {
            const ticketNotesText = document.getElementById('ticket-notes-text');
            const placeholder = document.getElementById('ticket-notes-placeholder');
            const copyBtn = document.getElementById('copy-ticket-notes-btn');
            
            // Generate the notes
            const summary = generateTicketNotes();
            ticketNotesText.textContent = summary;
            
            // Show the notes and copy button, hide placeholder
            placeholder.style.display = 'none';
            ticketNotesText.style.display = 'block';
            copyBtn.style.display = 'inline-block';
        }

        // Ticket Notes Functions
        function generateTicketNotes(data) {
            if (!data) data = window.systemData;
            if (!data) return 'No system data available';

            let notes = [];

            // Format date helper
            const formatDateISO = (dateValue) => {
                if (!dateValue) return 'Unknown';
                const date = parseNetDate(dateValue) || new Date(dateValue);
                if (!date || isNaN(date) || isNaN(date.getTime())) return 'Unknown';
                return new Intl.DateTimeFormat('en-US', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                }).format(date);
            };

            // Analyze system health
            const criticalIssues = [];
            const warningIssues = [];
            const recommendations = [];
            const systemInfo = [];
            
            // Check disk space
            if (data.Hardware?.Storage?.SystemDrive) {
                const disk = data.Hardware.Storage.SystemDrive;
                const freePercent = disk.FreeSpacePercent || (disk.FreeSpaceGB && disk.SizeGB ? Math.round((disk.FreeSpaceGB / disk.SizeGB) * 100) : 0);
                if (freePercent < 10 && freePercent > 0) {
                    criticalIssues.push(`C: Drive critically low - ${freePercent}% free (${disk.FreeSpaceGB}GB/${disk.SizeGB}GB)`);
                    recommendations.push('FREE UP DISK SPACE - System drive critically low');
                } else if (freePercent < 20 && freePercent > 0) {
                    warningIssues.push(`C: Drive space low - ${freePercent}% free (${disk.FreeSpaceGB}GB/${disk.SizeGB}GB)`);
                    recommendations.push('MONITOR DISK SPACE - System drive getting full');
                }
            }
            
            // Check memory usage
            if (data.Hardware?.Memory) {
                const mem = data.Hardware.Memory;
                if (mem.UsagePercent > 90) {
                    criticalIssues.push(`Critical memory pressure: ${mem.UsagePercent}% (${mem.UsedGB}GB/${mem.TotalGB}GB)`);
                    recommendations.push('CHECK MEMORY - Close applications or consider adding RAM');
                } else if (mem.UsagePercent > 80) {
                    warningIssues.push(`High memory usage: ${mem.UsagePercent}% (${mem.UsedGB}GB/${mem.TotalGB}GB)`);
                }
            }
            
            // Check for critical events
            if (data.Events?.Summary) {
                if (data.Events.Summary.Critical > 0) {
                    // Look for specific critical events
                    let unexpectedShutdowns = 0;
                    let bsods = 0;
                    
                    if (data.Events.Events?.Critical) {
                        data.Events.Events.Critical.forEach(event => {
                            if (event.Id === 41) unexpectedShutdowns++;
                            if (event.Id === 1001) bsods++;
                        });
                    }
                    
                    // Only critical if multiple shutdowns (pattern suggests hardware issue)
                    if (unexpectedShutdowns >= 3) {
                        criticalIssues.push(`System had ${unexpectedShutdowns} unexpected shutdowns in last 24 hours (Event ID 41) - possible hardware issue`);
                        recommendations.push('INVESTIGATE SHUTDOWNS - Multiple Event ID 41s suggest hardware/power issues');
                    } else if (unexpectedShutdowns > 0) {
                        warningIssues.push(`System had ${unexpectedShutdowns} unexpected shutdown${unexpectedShutdowns > 1 ? 's' : ''} in last 24 hours (Event ID 41)`);
                        if (unexpectedShutdowns === 1) {
                            recommendations.push('MONITOR SYSTEM - Single shutdown may be user-initiated or power loss');
                        } else {
                            recommendations.push('CHECK POWER - Review Event ID 41 details for cause');
                        }
                    }

                    // BSODs are always critical
                    if (bsods > 0) {
                        criticalIssues.push(`System had ${bsods} BSOD${bsods > 1 ? 's' : ''} in last 24 hours`);
                        recommendations.push('ANALYZE CRASHES - Review minidump files for BSOD causes');
                    }
                }
                
                // Check for application crashes
                let appCrashes = {};
                if (data.Events.Categories?.ApplicationErrors) {
                    data.Events.Categories.ApplicationErrors.forEach(event => {
                        if (event.Id === 1000) {
                            const appName = event.ProviderName || 'Unknown App';
                            appCrashes[appName] = (appCrashes[appName] || 0) + 1;
                        }
                    });
                    
                    const crashList = Object.entries(appCrashes)
                        .filter(([app, count]) => count > 1)
                        .sort((a, b) => b[1] - a[1])
                        .slice(0, 3)
                        .map(([app, count]) => `${app} (${count}x)`)
                        .join(', ');
                    
                    if (crashList) {
                        warningIssues.push(`Application crashes detected: ${crashList}`);
                        recommendations.push('CHECK APPLICATIONS - Frequent crashes detected');
                    }
                }
            }
            
            // Check drivers
            if (data.Drivers?.Summary) {
                if (data.Drivers.Summary.MissingDrivers > 0) {
                    criticalIssues.push(`${data.Drivers.Summary.MissingDrivers} missing driver${data.Drivers.Summary.MissingDrivers > 1 ? 's' : ''}`);
                    recommendations.push('INSTALL DRIVERS - Critical drivers missing');
                }
                if (data.Drivers.Summary.ProblemDrivers > 0) {
                    warningIssues.push(`${data.Drivers.Summary.ProblemDrivers} driver${data.Drivers.Summary.ProblemDrivers > 1 ? 's' : ''} with errors in Device Manager`);
                    recommendations.push('UPDATE DRIVERS - Devices showing errors');
                }
            }
            
            // Check Windows Updates
            if (data.OS?.WindowsUpdate) {
                const pendingCritical = data.OS.WindowsUpdate.PendingCritical || 0;
                const pendingOptional = data.OS.WindowsUpdate.PendingOptional || 0;
                if (pendingCritical > 0) {
                    warningIssues.push(`Windows Updates pending: ${pendingCritical} critical${pendingOptional > 0 ? `, ${pendingOptional} optional` : ''}`);
                    recommendations.push('INSTALL UPDATES - Critical updates pending');
                }
            }
            
            // Check Security Status
            if (data.OS?.Security) {
                const security = data.OS.Security;
                
                // Windows Defender
                if (security.WindowsDefender && !security.WindowsDefender.Enabled) {
                    criticalIssues.push('Windows Defender real-time protection is disabled');
                    recommendations.push('ENABLE ANTIVIRUS - Windows Defender is not protecting the system');
                }
                
                // Firewall status - use correct property names
                if (security.Firewall) {
                    const fw = security.Firewall;
                    // Check for both possible formats of firewall profile data
                    const domainEnabled = fw.DomainProfile === true || 
                                        fw.DomainProfile?.value === 1 || 
                                        fw.DomainProfile?.Value === 'True';
                    const privateEnabled = fw.PrivateProfile === true || 
                                         fw.PrivateProfile?.value === 1 || 
                                         fw.PrivateProfile?.Value === 'True';
                    const publicEnabled = fw.PublicProfile === true || 
                                        fw.PublicProfile?.value === 1 || 
                                        fw.PublicProfile?.Value === 'True';
                    
                    const allDisabled = !domainEnabled && !privateEnabled && !publicEnabled;
                    const partiallyEnabled = domainEnabled || privateEnabled || publicEnabled;
                    
                    if (allDisabled) {
                        criticalIssues.push('Windows Firewall is completely disabled');
                        recommendations.push('ENABLE FIREWALL - System has no firewall protection');
                    } else if (!domainEnabled || !privateEnabled || !publicEnabled) {
                        const disabledProfiles = [];
                        if (!domainEnabled) disabledProfiles.push('Domain');
                        if (!privateEnabled) disabledProfiles.push('Private');
                        if (!publicEnabled) disabledProfiles.push('Public');
                        if (disabledProfiles.length > 0) {
                            warningIssues.push(`Windows Firewall disabled for: ${disabledProfiles.join(', ')} network(s)`);
                            recommendations.push('REVIEW FIREWALL - Some network profiles unprotected');
                        }
                    }
                }
            }
            
            // Check Critical Windows Services
            if (data.OS?.Services) {
                const services = data.OS.Services;
                
                // Stopped critical services
                if (services.StoppedCritical?.length > 0) {
                    criticalIssues.push(`${services.StoppedCritical.length} critical Windows service(s) stopped: ${services.StoppedCritical.slice(0, 3).join(', ')}`);
                    recommendations.push('START SERVICES - Critical system services not running');
                }
                
                // Disabled critical services
                if (services.DisabledCritical?.length > 0) {
                    warningIssues.push(`${services.DisabledCritical.length} critical service(s) disabled: ${services.DisabledCritical.slice(0, 3).join(', ')}`);
                    recommendations.push('ENABLE SERVICES - Critical services set to disabled');
                }
            }

            // CPU temperature monitoring removed - inconsistent support across Dell/HP/Lenovo

            // Check Reboot Requirements
            if (data.OS?.WindowsUpdate?.RebootStatus?.Required) {
                const daysPending = data.OS.WindowsUpdate.RebootStatus.DaysPending || 0;
                if (daysPending > 7) {
                    criticalIssues.push(`System requires reboot for ${daysPending} days - critical updates not applied`);
                    recommendations.push('REBOOT SYSTEM IMMEDIATELY - Updates waiting too long');
                } else if (daysPending > 0) {
                    warningIssues.push(`System requires reboot for ${daysPending} days - updates pending`);
                    recommendations.push('REBOOT SYSTEM - Updates waiting for restart');
                }
            }
            
            // Check User Profile Issues
            if (data.OS?.AllUserProfiles?.Summary?.HasTemporaryProfiles) {
                criticalIssues.push('User has temporary profile - data will be lost on logout');
                recommendations.push('FIX PROFILE - User profile corruption detected, backup data immediately');
            }
            
            // Check network issues
            if (data.Network?.SpeedTest) {
                const speed = data.Network.SpeedTest;
                if (speed.Download && speed.Download < 10) {
                    warningIssues.push(`Very slow internet speed: ${speed.Download} Mbps download`);
                    recommendations.push('CHECK NETWORK - Internet speed below acceptable levels');
                }
            }
            
            // Check printer issues
            const printers = data.Printers?.Installed || [];
            const offlinePrinters = printers.filter(p => p.Status === 'Offline' || p.WorkOffline === true);
            const errorPrinters = printers.filter(p => p.Status === 'Error' || p.PrinterStatus === 'Error');
            
            if (errorPrinters.length > 0) {
                criticalIssues.push(`${errorPrinters.length} printer${errorPrinters.length > 1 ? 's' : ''} in error state`);
                recommendations.push('FIX PRINTERS - Printers showing errors');
            } else if (offlinePrinters.length > 0) {
                warningIssues.push(`${offlinePrinters.length} printer${offlinePrinters.length > 1 ? 's' : ''} offline`);
                recommendations.push('CHECK PRINTERS - Some printers are offline');
            }
            
            // Check print spooler issues - fixed property path
            if (data.Printers?.SpoolerHealth?.ServiceStatus && data.Printers.SpoolerHealth.ServiceStatus !== 'Running') {
                criticalIssues.push('Print Spooler service not running');
                recommendations.push('START SPOOLER - Print Spooler service needs to be started');
            }

            // Check Browser Security Issues
            if (data.Browsers?.SecurityIssues && Array.isArray(data.Browsers.SecurityIssues)) {
                const criticalBrowserIssues = data.Browsers.SecurityIssues.filter(i => i.Severity === 'Critical');
                const warningBrowserIssues = data.Browsers.SecurityIssues.filter(i => i.Severity === 'Warning');

                if (criticalBrowserIssues.length > 0) {
                    criticalBrowserIssues.forEach(issue => {
                        const browserName = issue.Browser || 'Browser';
                        const issueText = issue.Issue || 'Security issue detected';
                        criticalIssues.push(`${browserName}: ${issueText}`);
                    });
                    recommendations.push('ADDRESS BROWSER SECURITY - Critical vulnerabilities detected');
                }

                if (warningBrowserIssues.length > 0) {
                    if (warningBrowserIssues.length <= 3) {
                        warningBrowserIssues.forEach(issue => {
                            const browserName = issue.Browser || 'Browser';
                            const issueText = issue.Issue || 'Security warning';
                            warningIssues.push(`${browserName}: ${issueText}`);
                        });
                    } else {
                        warningIssues.push(`${warningBrowserIssues.length} browser security warnings detected`);
                    }
                    recommendations.push('UPDATE BROWSERS - Security warnings detected');
                }
            }

            // Collect basic system info for header
            const computerManufacturer = data.Hardware?.SystemBoard?.Computer?.Manufacturer || '';
            const computerModel = data.Hardware?.SystemBoard?.Computer?.Model || '';
            const modelInfo = computerManufacturer && computerModel ? `${computerManufacturer} ${computerModel}` : 'Unknown Model';

            const osInfo = data.OS?.SystemInfo;
            const osName = osInfo?.WindowsVersion || data.OS?.OperatingSystem || 'Windows';
            const osBuild = osInfo?.Build || data.OS?.Build || 'Unknown';
            const ram = data.Hardware?.Memory?.TotalGB || 'Unknown';

            // Determine overall health status
            let healthStatus = 'HEALTHY';
            let healthText = 'No issues detected';
            if (criticalIssues.length > 0) {
                healthStatus = 'CRITICAL';
                healthText = `${criticalIssues.length} critical issue${criticalIssues.length > 1 ? 's' : ''} detected`;
            } else if (warningIssues.length > 0) {
                healthStatus = 'ATTENTION NEEDED';
                healthText = `${warningIssues.length} warning${warningIssues.length > 1 ? 's' : ''} detected`;
            }

            // Determine support priority/risk level
            let riskLevel = 'LOW';
            if (criticalIssues.length >= 3) {
                riskLevel = 'HIGH';
            } else if (criticalIssues.length > 0) {
                riskLevel = 'MEDIUM-HIGH';
            } else if (warningIssues.length >= 5) {
                riskLevel = 'MEDIUM';
            } else if (warningIssues.length > 0) {
                riskLevel = 'LOW-MEDIUM';
            }

            // Build the formatted ticket notes - PROBLEM-FOCUSED FORMAT
            notes.push('=== WINDAS DIAGNOSTIC SUMMARY ===');
            notes.push(`Computer: ${data.Metadata?.ComputerName || 'Unknown'} (${modelInfo})`);
            notes.push(`User: ${data.Metadata?.UserName || 'Unknown'} | Generated: ${formatDateISO(new Date())}`);
            notes.push(`OS: ${osName} Build ${osBuild} | RAM: ${ram}GB`);
            notes.push('');
            notes.push(`STATUS: ${healthStatus} - ${healthText}`);
            notes.push(`PRIORITY: ${riskLevel} RISK`);
            notes.push('='.repeat(60));
            notes.push('');

            // Show issues if found, otherwise show clean bill of health with ACTUAL DATA
            if (criticalIssues.length === 0 && warningIssues.length === 0) {
                notes.push('** NO ISSUES DETECTED **');
                notes.push('');
                notes.push('System scan completed successfully. All diagnostics passed:');

                // Disk space - show actual numbers for OS drive
                if (data.Hardware?.Storage?.SystemDrive) {
                    const disk = data.Hardware.Storage.SystemDrive;
                    const freeGB = disk.FreeSpaceGB != null ? Math.round(disk.FreeSpaceGB) : null;
                    const totalGB = disk.SizeGB != null ? Math.round(disk.SizeGB) : null;
                    const usedGB = (freeGB != null && totalGB != null) ? (totalGB - freeGB) : null;
                    const usedPercent = (usedGB != null && totalGB != null && totalGB > 0) ? Math.round((usedGB / totalGB) * 100) : null;

                    if (usedGB != null && totalGB != null && usedPercent != null) {
                        const status = usedPercent > 90 ? 'LOW SPACE' : usedPercent > 80 ? 'WARNING' : 'OK';
                        notes.push(`  - Disk space (C:): ${usedGB}GB/${totalGB}GB (${usedPercent}% used) - ${status}`);
                    } else {
                        notes.push('  - Disk space: OK');
                    }
                } else {
                    notes.push('  - Disk space: OK');
                }

                // Memory usage - show actual numbers
                if (data.Hardware?.Memory) {
                    const mem = data.Hardware.Memory;
                    // Calculate usage percent from PercentFree (collector provides PercentFree, not UsagePercent)
                    const usagePercent = mem.PercentFree != null ? Math.round(100 - mem.PercentFree) : 0;
                    const usedGB = mem.UsedGB != null ? Math.round(mem.UsedGB) : 'Unknown';
                    const totalGB = mem.TotalGB != null ? Math.round(mem.TotalGB) : 'Unknown';
                    notes.push(`  - Memory usage: ${usagePercent}% (${usedGB}GB/${totalGB}GB) - Normal`);
                } else {
                    notes.push('  - Memory usage: Normal');
                }

                // Security status - show actual status
                let securityDetail = 'Unknown';
                if (data.OS?.Security) {
                    const security = data.OS.Security;
                    const defenderOn = security.WindowsDefender?.Enabled ? 'ENABLED' : 'DISABLED';

                    let firewallStatus = 'DISABLED';
                    if (security.Firewall) {
                        const fw = security.Firewall;
                        const domainEnabled = fw.DomainProfile === true;
                        const privateEnabled = fw.PrivateProfile === true;
                        const publicEnabled = fw.PublicProfile === true;

                        if (domainEnabled && privateEnabled && publicEnabled) {
                            firewallStatus = 'ENABLED';
                        } else if (domainEnabled || privateEnabled || publicEnabled) {
                            firewallStatus = 'PARTIAL';
                        }
                    }
                    securityDetail = `Defender ${defenderOn}, Firewall ${firewallStatus}`;
                }
                notes.push(`  - Security: ${securityDetail} - Active`);

                // Drivers - show actual counts
                if (data.Drivers?.Summary) {
                    const driverSum = data.Drivers.Summary;
                    const total = driverSum.TotalDrivers || 0;
                    const problem = driverSum.ProblemDrivers || 0;
                    const missing = driverSum.MissingDrivers || 0;
                    notes.push(`  - Drivers: ${total} scanned, ${problem} problems, ${missing} missing - OK`);
                } else {
                    notes.push('  - Drivers: No problems detected');
                }

                // Services - show actual status
                if (data.OS?.Services) {
                    const services = data.OS.Services;
                    const stoppedCritical = services.StoppedCritical?.length || 0;
                    const disabledCritical = services.DisabledCritical?.length || 0;
                    const totalRunning = services.Running || 'Unknown';
                    notes.push(`  - Services: ${totalRunning} running, ${stoppedCritical} critical stopped - OK`);
                } else {
                    notes.push('  - Services: All critical services running');
                }

                // Windows Updates - show actual update info
                let updateInfo = 'Unknown';
                if (data.OS?.WindowsUpdate?.LastCumulativeUpdate) {
                    const lastUpdate = data.OS.WindowsUpdate.LastCumulativeUpdate;
                    if (typeof lastUpdate === 'object' && lastUpdate !== null) {
                        const kbNumber = lastUpdate.KBNumber || lastUpdate.Title || 'Unknown KB';
                        const updateDate = lastUpdate.InstalledOn || lastUpdate.InstalledDate;
                        const dateStr = updateDate ? formatDateISO(updateDate) : 'Unknown date';
                        updateInfo = `Last update ${kbNumber} installed ${dateStr}`;
                    } else {
                        updateInfo = `Last update: ${lastUpdate}`;
                    }
                } else if (data.OS?.Updates?.LatestCumulative) {
                    const update = data.OS.Updates.LatestCumulative;
                    const kbNumber = update.Name || update.Title || 'Unknown';
                    const installedDate = update.InstalledOn || update.InstalledDate;
                    const dateStr = installedDate ? formatDateISO(installedDate) : 'Unknown date';
                    updateInfo = `Last update ${kbNumber} installed ${dateStr}`;
                }
                const pendingCritical = data.OS?.WindowsUpdate?.PendingCritical || 0;
                const pendingOptional = data.OS?.WindowsUpdate?.PendingOptional || 0;
                notes.push(`  - Updates: ${updateInfo} - Current`);
                if (pendingCritical > 0 || pendingOptional > 0) {
                    notes.push(`    (${pendingCritical} critical, ${pendingOptional} optional pending)`);
                }

                // Event logs - show actual event counts
                if (data.Events?.Summary) {
                    const critical = data.Events.Summary.Critical || 0;
                    const errors = data.Events.Summary.Errors || 0;
                    const warnings = data.Events.Summary.Warnings || 0;
                    notes.push(`  - Event logs: ${critical} critical, ${errors} errors, ${warnings} warnings (last 7 days) - Clean`);
                } else {
                    notes.push('  - Event logs: No critical errors in last 24 hours');
                }

                // Browsers - show installed versions and update status
                if (data.Browsers?.InstalledBrowsers && data.Browsers.InstalledBrowsers.length > 0) {
                    const browsers = data.Browsers.InstalledBrowsers;
                    const browserInfo = [];

                    browsers.forEach(browser => {
                        const name = browser.Name || 'Unknown';
                        const version = browser.Version || 'Unknown';
                        let status = '';

                        // Check if outdated
                        if (browser.LatestVersion && browser.Version && browser.Version !== 'Unknown') {
                            const current = browser.Version.split('.').map(n => parseInt(n) || 0);
                            const latest = browser.LatestVersion.split('.').map(n => parseInt(n) || 0);

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
                                status = `OUTDATED (latest: ${browser.LatestVersion})`;
                            } else {
                                status = 'Up to date';
                            }
                        } else if (browser.AutoUpdateEnabled === false) {
                            status = 'Auto-update disabled';
                        } else {
                            status = 'OK';
                        }

                        browserInfo.push(`${name} ${version} - ${status}`);
                    });

                    notes.push(`  - Browsers: ${browserInfo.join(', ')}`);
                } else {
                    notes.push('  - Browsers: No browsers detected');
                }

                notes.push('');
                notes.push('System appears healthy and functioning normally.');
            } else {
                // Critical issues
                if (criticalIssues.length > 0) {
                    notes.push(`[CRITICAL ISSUES] - ${criticalIssues.length} found`);
                    criticalIssues.forEach((issue, index) => {
                        notes.push(`${index + 1}. ${issue}`);
                    });
                    notes.push('');
                }

                // Warning issues
                if (warningIssues.length > 0) {
                    notes.push(`[WARNING ISSUES] - ${warningIssues.length} found`);
                    warningIssues.forEach((issue, index) => {
                        notes.push(`${index + 1}. ${issue}`);
                    });
                    notes.push('');
                }
            }

            // Add recommendations if any issues found
            if (recommendations.length > 0) {
                notes.push('[RECOMMENDED ACTIONS]');
                recommendations.forEach((rec, index) => {
                    notes.push(`${index + 1}. ${rec}`);
                });
                notes.push('');
            }

            // Add minimal system context
            notes.push('[SYSTEM CONTEXT]');

            // Uptime
            let uptimeStr = 'Unknown';
            const lastBoot = osInfo?.LastBootTime || data.OS?.LastBootTime;
            if (osInfo?.Uptime) {
                uptimeStr = osInfo.Uptime;
            } else if (lastBoot) {
                const bootDate = parseNetDate(lastBoot) || new Date(lastBoot);
                if (bootDate && !isNaN(bootDate)) {
                    const now = new Date();
                    const uptimeMs = now - bootDate;
                    const days = Math.floor(uptimeMs / (1000 * 60 * 60 * 24));
                    const hours = Math.floor((uptimeMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
                    uptimeStr = `${days}d ${hours}h`;
                }
            }
            notes.push(`Uptime: ${uptimeStr} | Last boot: ${formatDateISO(lastBoot)}`);

            // Domain
            const domain = data.Metadata?.DomainName || osInfo?.Domain || data.OS?.Domain || 'WORKGROUP';
            notes.push(`Domain: ${domain}`);

            // IP Address
            const activeAdapter = data.Network?.Adapters?.find(a => a.Status === 'Up' || a.ConnectionStatus === 'Connected') || data.Network?.Adapters?.[0];
            if (activeAdapter) {
                const ipAddress = activeAdapter.IPAddress || activeAdapter.IPv4Address || 'Not assigned';
                notes.push(`IP Address: ${ipAddress}`);
            }

            notes.push('');
            notes.push('='.repeat(60));
            notes.push('[End of WinDAS diagnostic - Full report in HTML file]');
            
            return notes.join('\n');
        }

        // Original detailed notes generator for backwards compatibility
        function generateDetailedTicketNotes(data) {
            if (!data) data = window.systemData;
            if (!data) return 'No system data available';
            
            let notes = [];
            
            // Format date helper
            const formatDateISO = (dateValue) => {
                if (!dateValue) return 'Unknown';
                const date = parseNetDate(dateValue) || new Date(dateValue);
                if (!date || isNaN(date) || isNaN(date.getTime())) return 'Unknown';
                return new Intl.DateTimeFormat('en-US', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit'
                }).format(date);
            };
            
            // Issues Found - Only show actual issues found in the data
            notes.push('=== Issues Summary ===');
            const issues = [];
            
            // Hardware issues - Check for actual hardware problems
            if (data.Hardware?.Issues && Array.isArray(data.Hardware.Issues) && data.Hardware.Issues.length > 0) {
                data.Hardware.Issues.forEach(issue => {
                    if (issue.Issue || issue.Description) {
                        issues.push(`[${escapeHtml(issue.Severity || 'Warning')}] Hardware: ${escapeHtml(issue.Issue || issue.Description)}`);
                    }
                });
            }
            
            // Check for disk health issues
            if (data.Hardware?.Storage?.Disks && Array.isArray(data.Hardware.Storage.Disks)) {
                data.Hardware.Storage.Disks.forEach(disk => {
                    if (disk.Health === 'Warning' || disk.Health === 'Critical' || disk.Health === 'Unhealthy') {
                        issues.push(`[${disk.Health === 'Critical' ? 'Critical' : 'Warning'}] Storage: ${escapeHtml(disk.Model || 'Disk')} health status - ${escapeHtml(disk.Health)}`);
                    }
                    // Check for low disk space on system drive
                    if (disk.DriveLetter === 'C:' && disk.FreeSpacePercent && disk.FreeSpacePercent < 10) {
                        issues.push(`[Warning] Storage: System drive has only ${disk.FreeSpacePercent}% free space`);
                    }
                });
            }
            
            // Check system drive specifically
            if (data.Hardware?.Storage?.SystemDrive?.FreeSpacePercent && data.Hardware.Storage.SystemDrive.FreeSpacePercent < 10) {
                issues.push(`[Warning] Storage: System drive low on space (${data.Hardware.Storage.SystemDrive.FreeSpacePercent}% free)`);
            }
            
            // Memory issues - Check for high memory usage
            if (data.Hardware?.Memory?.UsagePercent && data.Hardware.Memory.UsagePercent > 90) {
                issues.push(`[Warning] Memory: High memory usage (${data.Hardware.Memory.UsagePercent}%)`);
            }
            
            // Driver issues - Only if we have actual missing or problem drivers
            if (data.Drivers?.Summary) {
                if (data.Drivers.Summary.MissingDrivers && data.Drivers.Summary.MissingDrivers > 0) {
                    issues.push(`[Critical] Drivers: ${data.Drivers.Summary.MissingDrivers} missing driver${data.Drivers.Summary.MissingDrivers > 1 ? 's' : ''}`);
                }
                if (data.Drivers.Summary.ProblemDrivers && data.Drivers.Summary.ProblemDrivers > 0) {
                    issues.push(`[Critical] Drivers: ${data.Drivers.Summary.ProblemDrivers} driver${data.Drivers.Summary.ProblemDrivers > 1 ? 's' : ''} with problems`);
                }
                // Only flag outdated drivers if there are many
                if (data.Drivers.Summary.OutdatedDrivers && data.Drivers.Summary.OutdatedDrivers > 20) {
                    issues.push(`[Warning] Drivers: ${data.Drivers.Summary.OutdatedDrivers} outdated drivers`);
                }
            }
            
            // Check for specific problem drivers
            if (data.Drivers?.AllDrivers && Array.isArray(data.Drivers.AllDrivers)) {
                const problemDrivers = data.Drivers.AllDrivers.filter(d => d.ProblemCode && d.ProblemCode !== 0);
                if (problemDrivers.length > 0 && !data.Drivers?.Summary?.ProblemDrivers) {
                    // Only add if not already added from summary
                    issues.push(`[Critical] Drivers: ${problemDrivers.length} device${problemDrivers.length > 1 ? 's' : ''} with driver problems`);
                }
            }
            
            // Printer issues - Only if there are actual printer problems
            if (data.Printers?.Issues && data.Printers.Issues.Issue) {
                issues.push(`[${data.Printers.Issues.Severity || 'Warning'}] Printers: ${data.Printers.Issues.Issue}`);
            }
            
            // Check for stopped print spooler - fixed property path
            if (data.Printers?.SpoolerHealth?.ServiceStatus === 'Stopped') {
                issues.push(`[Critical] Printers: Print Spooler service is stopped`);
            }
            
            // Software issues - Check for crashes
            if (data.Software?.Summary?.Crashes72h && data.Software.Summary.Crashes72h > 0) {
                issues.push(`[Warning] Software: ${data.Software.Summary.Crashes72h} application crash${data.Software.Summary.Crashes72h > 1 ? 'es' : ''} in last 24 hours`);
            }

            // Check event logs for crashes
            if (data.OS?.Events?.ApplicationCrashes24h && data.OS.Events.ApplicationCrashes24h > 0) {
                if (!data.Software?.Summary?.Crashes72h) { // Avoid duplicate
                    issues.push(`[Warning] Events: ${data.OS.Events.ApplicationCrashes24h} application crash${data.OS.Events.ApplicationCrashes24h > 1 ? 'es' : ''} in last 24 hours`);
                }
            }

            // Check for system errors
            if (data.OS?.Events?.SystemErrors24h && data.OS.Events.SystemErrors24h > 10) {
                issues.push(`[Warning] Events: ${data.OS.Events.SystemErrors24h} system errors in last 24 hours`);
            }

            // Check for blue screens
            if (data.OS?.Events?.BlueScreens24h && data.OS.Events.BlueScreens24h > 0) {
                issues.push(`[Critical] System: ${data.OS.Events.BlueScreens24h} blue screen${data.OS.Events.BlueScreens24h > 1 ? 's' : ''} in last 24 hours`);
            }
            
            // Network issues - Check for actual connectivity failures
            if (data.Network?.Connectivity?.Summary?.Failed && data.Network.Connectivity.Summary.Failed > 0) {
                issues.push(`[Critical] Network: ${data.Network.Connectivity.Summary.Failed} connectivity test${data.Network.Connectivity.Summary.Failed > 1 ? 's' : ''} failed`);
            }
            
            // Check for specific failed tests
            if (data.Network?.Connectivity?.Tests && Array.isArray(data.Network.Connectivity.Tests)) {
                const failedTests = data.Network.Connectivity.Tests.filter(t => t.Result === 'Fail' || t.Result === 'Failed');
                if (failedTests.length > 0 && !data.Network?.Connectivity?.Summary?.Failed) {
                    const criticalTests = failedTests.filter(t => t.Test === 'Internet' || t.Test === 'DNS' || t.Test === 'Gateway');
                    if (criticalTests.length > 0) {
                        issues.push(`[Critical] Network: Failed connectivity - ${criticalTests.map(t => t.Test).join(', ')}`);
                    }
                }
            }
            
            // Check for high packet loss
            
            // OS and Update issues
            if (data.OS?.WindowsUpdate?.DaysSinceUpdate && data.OS.WindowsUpdate.DaysSinceUpdate > 60) {
                issues.push(`[Critical] Updates: Windows Updates are ${data.OS.WindowsUpdate.DaysSinceUpdate} days old`);
            } else if (data.OS?.WindowsUpdate?.DaysSinceUpdate && data.OS.WindowsUpdate.DaysSinceUpdate > 30) {
                issues.push(`[Warning] Updates: Windows Updates are ${data.OS.WindowsUpdate.DaysSinceUpdate} days old`);
            }
            
            // Check for pending reboot
            if (data.OS?.WindowsUpdate?.RebootRequired === true || data.OS?.PendingReboot === true) {
                issues.push(`[Warning] System: Reboot required for updates`);
            }
            
            // Security issues
            if (data.OS?.Security?.DefenderStatus && data.OS.Security.DefenderStatus !== 'Enabled' && data.OS.Security.DefenderStatus !== 'Active') {
                issues.push(`[Critical] Security: Windows Defender is ${data.OS.Security.DefenderStatus}`);
            }
            
            if (data.OS?.Security?.FirewallStatus && data.OS.Security.FirewallStatus !== 'Enabled' && data.OS.Security.FirewallStatus !== 'Active') {
                issues.push(`[Warning] Security: Firewall is ${data.OS.Security.FirewallStatus}`);
            }
            
            // Check for outdated antivirus definitions
            if (data.OS?.Security?.LastDefinitionUpdate) {
                const lastUpdate = parseNetDate(data.OS.Security.LastDefinitionUpdate) || new Date(data.OS.Security.LastDefinitionUpdate);
                if (lastUpdate && !isNaN(lastUpdate)) {
                    const daysSince = Math.floor((new Date() - lastUpdate) / (1000 * 60 * 60 * 24));
                    if (daysSince > 7) {
                        issues.push(`[Warning] Security: Antivirus definitions are ${daysSince} days old`);
                    }
                }
            }
            
            // Check for stopped critical services
            const services = data.OS?.Services?.Services || data.OS?.Services || [];
            if (Array.isArray(services)) {
                const criticalStopped = services.filter(s => 
                    s.Status !== 'Running' && 
                    (s.StartType === 'Automatic' || s.StartType === 'Auto') &&
                    (s.Category === 'Critical' || s.DisplayName?.includes('Windows Update') || s.DisplayName?.includes('Windows Defender'))
                );
                if (criticalStopped.length > 0) {
                    issues.push(`[Warning] Services: ${criticalStopped.length} critical service${criticalStopped.length > 1 ? 's' : ''} stopped`);
                }
            }
            
            // Display issues or indicate no issues
            if (issues.length === 0) {
                notes.push('No critical issues detected');
            } else {
                issues.forEach((issue, index) => {
                    notes.push(`${index + 1}. ${issue}`);
                });
            }
            notes.push('');
            
            // Critical Services - Check for stopped automatic services (reuse services variable from above)
            const stoppedServices = Array.isArray(services) ? services.filter(s => 
                s.Status !== 'Running' && (s.StartType === 'Automatic' || s.StartType === 'Auto' || s.Category === 'Critical')
            ) : [];
            
            if (stoppedServices.length > 0) {
                notes.push('=== Critical Services Stopped ===');
                stoppedServices.forEach(s => {
                    notes.push(`${escapeHtml(s.DisplayName || s.Name)}: ${escapeHtml(s.Status)}`);
                });
                notes.push('');
            }
            
            // Recent Events
            notes.push('=== Recent Events (Last 24h) ===');
            notes.push(`Application Crashes: ${data.OS?.Events?.ApplicationCrashes24h || data.Software?.CrashCount || 0}`);
            notes.push(`System Errors: ${data.OS?.Events?.SystemErrors24h || data.OS?.ErrorCount || 0}`);
            notes.push(`Blue Screens: ${data.OS?.Events?.BlueScreens24h || data.OS?.BlueScreenCount || 0}`);
            notes.push('');
            
            // Security Status
            notes.push('=== Security Status ===');
            if (data.OS?.Security) {
                const sec = data.OS.Security;
                notes.push(`Windows Defender: ${sec.DefenderStatus || 'Unknown'}`);
                notes.push(`Firewall: ${sec.FirewallStatus || 'Unknown'}`);
                notes.push(`Last AV Update: ${formatDateISO(sec.LastDefinitionUpdate)}`);
                notes.push(`UAC Level: ${sec.UACLevel || 'Unknown'}`);
            } else {
                notes.push('Security information unavailable');
            }
            notes.push('');
            
            // Required Actions - Based on actual issues found
            const actions = [];
            
            // Reboot required
            if (data.OS?.WindowsUpdate?.RebootRequired === true || data.OS?.PendingReboot === true) {
                actions.push('- Reboot system to complete pending updates');
            }
            
            // Windows updates needed
            if (data.OS?.WindowsUpdate?.DaysSinceUpdate && data.OS.WindowsUpdate.DaysSinceUpdate > 30) {
                actions.push('- Install pending Windows updates');
            }
            
            // Services need restart
            if (stoppedServices.length > 0) {
                if (stoppedServices.length === 1) {
                    actions.push(`- Restart stopped service: ${escapeHtml(stoppedServices[0].DisplayName || stoppedServices[0].Name)}`);
                } else {
                    actions.push(`- Restart ${stoppedServices.length} stopped critical services`);
                }
            }
            
            // Missing drivers
            if (data.Drivers?.Summary?.MissingDrivers && data.Drivers.Summary.MissingDrivers > 0) {
                actions.push(`- Install ${data.Drivers.Summary.MissingDrivers} missing driver${data.Drivers.Summary.MissingDrivers > 1 ? 's' : ''}`);
            }
            
            // Problem drivers
            if (data.Drivers?.Summary?.ProblemDrivers && data.Drivers.Summary.ProblemDrivers > 0) {
                actions.push(`- Fix ${data.Drivers.Summary.ProblemDrivers} driver${data.Drivers.Summary.ProblemDrivers > 1 ? 's' : ''} with problems`);
            }
            
            // Disk health issues
            if (data.Hardware?.Storage?.Disks && Array.isArray(data.Hardware.Storage.Disks)) {
                const unhealthyDisks = data.Hardware.Storage.Disks.filter(d => 
                    d.Health === 'Warning' || d.Health === 'Critical' || d.Health === 'Unhealthy'
                );
                if (unhealthyDisks.length > 0) {
                    unhealthyDisks.forEach(disk => {
                        actions.push(`- Check disk health: ${escapeHtml(disk.Model || 'Unknown')} - ${escapeHtml(disk.Health)} status`);
                    });
                }
            }
            
            // Low disk space
            if (data.Hardware?.Storage?.SystemDrive?.FreeSpacePercent && data.Hardware.Storage.SystemDrive.FreeSpacePercent < 10) {
                actions.push(`- Free up disk space on system drive (only ${data.Hardware.Storage.SystemDrive.FreeSpacePercent}% free)`);
            }
            
            // High memory usage
            if (data.Hardware?.Memory?.UsagePercent && data.Hardware.Memory.UsagePercent > 90) {
                actions.push(`- Investigate high memory usage (${data.Hardware.Memory.UsagePercent}%)`);
            }
            
            // Printer issues - fixed property path
            if (data.Printers?.SpoolerHealth?.ServiceStatus === 'Stopped') {
                actions.push('- Start Print Spooler service');
            } else if (data.Printers?.Issues?.Severity === 'Critical') {
                actions.push(`- Resolve printer issue: ${data.Printers.Issues.Issue}`);
            }
            
            // Network connectivity issues
            if (data.Network?.Connectivity?.Summary?.Failed && data.Network.Connectivity.Summary.Failed > 0) {
                actions.push('- Troubleshoot network connectivity issues');
            }
            
            // High packet loss
            
            // Security issues
            if (data.OS?.Security?.DefenderStatus && data.OS.Security.DefenderStatus !== 'Enabled' && data.OS.Security.DefenderStatus !== 'Active') {
                actions.push(`- Enable Windows Defender (currently ${data.OS.Security.DefenderStatus})`);
            }
            
            if (data.OS?.Security?.FirewallStatus && data.OS.Security.FirewallStatus !== 'Enabled' && data.OS.Security.FirewallStatus !== 'Active') {
                actions.push(`- Enable Windows Firewall (currently ${data.OS.Security.FirewallStatus})`);
            }
            
            // Outdated antivirus definitions
            if (data.OS?.Security?.LastDefinitionUpdate) {
                const lastUpdate = parseNetDate(data.OS.Security.LastDefinitionUpdate) || new Date(data.OS.Security.LastDefinitionUpdate);
                if (lastUpdate && !isNaN(lastUpdate)) {
                    const daysSince = Math.floor((new Date() - lastUpdate) / (1000 * 60 * 60 * 24));
                    if (daysSince > 7) {
                        actions.push(`- Update antivirus definitions (${daysSince} days old)`);
                    }
                }
            }
            
            // Blue screens
            if (data.OS?.Events?.BlueScreens24h && data.OS.Events.BlueScreens24h > 0) {
                actions.push(`- Investigate blue screen error${data.OS.Events.BlueScreens24h > 1 ? 's' : ''} (${data.OS.Events.BlueScreens24h} in last 24h)`);
            }
            
            if (actions.length > 0) {
                notes.push('=== Required Actions ===');
                actions.forEach(a => notes.push(a));
                notes.push('');
            }
            
            // Additional Details
            notes.push('=== Additional Information ===');
            notes.push(`Report Generated: ${formatDateISO(new Date())}`);
            notes.push(`WinDAS Version: ${data.Metadata?.CollectorVersion || '1.1.0'}`);
            notes.push(`Author: Joshua Walderbach`);
            notes.push(`Collection Duration: ${data.Metadata?.CollectionDuration || 'Unknown'}s`);
            if (data.Metadata?.CollectorsFailed > 0) {
                notes.push(`Warning: ${data.Metadata.CollectorsFailed} collectors failed`);
            }
            
            // Network Status
            notes.push('=== Network Status ===');
            const activeAdapter = data.Network?.ActiveAdapter || 
                                 (data.Network?.Adapters && data.Network.Adapters.find(a => a.Status === 'Up' || a.Status === 'Connected')) ||
                                 (data.Network?.Adapters && data.Network.Adapters[0]);
            
            if (activeAdapter) {
                notes.push(`Adapter: ${escapeHtml(activeAdapter.Name)}`);
                notes.push(`IP Address: ${activeAdapter.IPAddress || 'Unknown'}`);
                notes.push(`MAC Address: ${activeAdapter.MACAddress || 'Unknown'}`);
                notes.push(`Link Speed: ${activeAdapter.LinkSpeed || 'Unknown'}`);
                notes.push(`Gateway: ${activeAdapter.DefaultGateway || 'Unknown'}`);
            }
            
            // Network Performance
            
            // Connectivity Tests
            if (data.Network?.Connectivity?.Tests) {
                const tests = data.Network.Connectivity.Tests;
                const failedTests = tests.filter(t => t.Result !== 'Pass');
                if (failedTests.length > 0) {
                    notes.push(`Connectivity Issues: ${failedTests.map(t => t.Test).join(', ')}`);
                } else {
                    notes.push('Connectivity: All tests passed');
                }
            }
            
            // WiFi Details
            if (data.Network?.WiFi?.SSID) {
                notes.push(`WiFi Network: ${data.Network.WiFi.SSID}`);
                notes.push(`Signal Strength: ${data.Network.WiFi.SignalQuality || 'Unknown'}%`);
            }
            
            return notes.join('\n');
        }

        function selectAllText(element) {
            if (window.getSelection) {
                const selection = window.getSelection();
                const range = document.createRange();
                range.selectNodeContents(element);
                selection.removeAllRanges();
                selection.addRange(range);
            }
        }

        async function copyToClipboard() {
            const ticketSummary = document.getElementById('ticketSummary');
            const copyFeedback = document.getElementById('copyFeedback');
            
            if (!ticketSummary.textContent.trim()) {
                // Generate the summary if it's empty
                const summary = generateTicketNotes();
                ticketSummary.textContent = summary;
            }
            
            try {
                await navigator.clipboard.writeText(ticketSummary.textContent);
                copyFeedback.classList.remove('hidden');
                setTimeout(() => {
                    copyFeedback.classList.add('hidden');
                }, 2000);
            } catch (err) {
                // Fallback for older browsers
                selectAllText(ticketSummary);
                try {
                    document.execCommand('copy');
                    copyFeedback.classList.remove('hidden');
                    setTimeout(() => {
                        copyFeedback.classList.add('hidden');
                    }, 2000);
                } catch (fallbackErr) {
                    alert('Copy failed. Please select and copy manually.');
                }
            }
        }

        function copyTicketNotes() {
            const text = document.getElementById('ticket-notes-text').textContent;
            
            // Modern clipboard API
            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(text).then(() => {
                    showCopyFeedback();
                }).catch(err => {
                    // Fallback to older method
                    copyTextFallback(text);
                });
            } else {
                // Fallback for older browsers
                copyTextFallback(text);
            }
        }

        function copyTextFallback(text) {
            const textArea = document.createElement("textarea");
            textArea.value = text;
            textArea.style.position = "fixed";
            textArea.style.left = "-999999px";
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            try {
                document.execCommand('copy');
                showCopyFeedback();
            } catch (err) {
                alert('Failed to copy. Please select the text manually and copy.');
            }
            document.body.removeChild(textArea);
        }

        function showCopyFeedback() {
            const feedback = document.getElementById('copy-feedback');
            if (feedback) {
                feedback.style.display = 'inline';
                setTimeout(() => {
                    feedback.style.display = 'none';
                }, 3000);
            }
        }

        // Initialize Event Listeners
        function initializeEventListeners() {
            // Copy button event listener
            const copyButton = document.getElementById('copyButton');
            if (copyButton) {
                copyButton.addEventListener('click', copyToClipboard);
            }
            
            // Add keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                // Ctrl+P for print
                if (e.ctrlKey && e.key === 'p') {
                    e.preventDefault();
                    window.print();
                }
            });
            
            // Removed auto-generation - now handled by button click
        }

        // Health Summary Dashboard Functions
        function loadHealthSummaryDashboard() {
            try {
                const healthData = analyzeSystemHealth();
                updateTabProblems(healthData);
                // renderFloatingHealthNav removed - using sticky top navigation instead
            } catch (error) {
                console.error('Error loading health dashboard:', error);
            }
        }

        function renderFloatingHealthNav(healthData) {
            const healthNavItems = document.getElementById('healthNavItems');
            const categories = [
                { key: 'operatingSystem', name: 'Operating System', icon: '🖥️', tab: 'os' },
                { key: 'hardware', name: 'Hardware', icon: '⚙️', tab: 'hardware' },
                { key: 'network', name: 'Network', icon: '🌐', tab: 'network' },
                { key: 'software', name: 'Software', icon: '📱', tab: 'software' },
                { key: 'printers', name: 'Printers', icon: '🖨️', tab: 'printers' },
                { key: 'events', name: 'Events', icon: '📊', tab: 'events' },
                { key: 'drivers', name: 'Drivers', icon: '🔧', tab: 'drivers' },
                { key: 'browsers', name: 'Browsers', icon: '🌐', tab: 'browsers' },
                { key: 'ticketnotes', name: 'Ticket Notes', icon: '📝', tab: 'ticketnotes' }
            ].sort((a, b) => a.name.localeCompare(b.name));

            healthNavItems.innerHTML = categories.map(category => {
                const health = healthData.categories[category.key] || { status: 'healthy', issues: [] };
                const statusClass = health.status === 'healthy' ? 'healthy' :
                                  health.status === 'warning' ? 'warning' : 'critical';
                const issueCount = health.issues.length;

                return `
                    <button type="button"
                            class="health-nav-item"
                            data-tab="${category.tab}"
                            onclick="switchTabFromNav('${category.tab}')"
                            aria-label="${category.name} - ${health.status} status${issueCount > 0 ? ', ' + issueCount + ' issues' : ''}">
                        <div class="health-nav-icon" aria-hidden="true">${category.icon}</div>
                        <div class="health-nav-content">
                            <div class="health-nav-name">${category.name}</div>
                            <div class="health-nav-status">
                                <div class="health-status-indicator ${statusClass}" aria-hidden="true"></div>
                                ${issueCount > 0 ? `<div class="health-nav-badge" aria-hidden="true">${issueCount}</div>` : ''}
                            </div>
                        </div>
                    </button>
                `;
            }).join('');

            // Set initial active state
            updateActiveNavItem();
        }

        function switchTabFromNav(tabName) {
            switchTab(tabName);
            updateActiveNavItem(tabName);
        }

        function updateActiveNavItem(activeTab) {
            // Get current active tab if not specified
            if (!activeTab) {
                const activeTabContent = document.querySelector('.tab-content[style*="block"], .tab-content.active');
                activeTab = activeTabContent ? activeTabContent.id : 'os';
            }

            // Update nav item states
            document.querySelectorAll('.health-nav-item').forEach(item => {
                item.classList.remove('active');
                if (item.dataset.tab === activeTab) {
                    item.classList.add('active');
                }
            });
        }

        function analyzeSystemHealth() {
            const health = {
                categories: {
                    operatingSystem: { status: 'healthy', issues: [], score: 100 },
                    hardware: { status: 'healthy', issues: [], score: 100 },
                    network: { status: 'healthy', issues: [], score: 100 },
                    software: { status: 'healthy', issues: [], score: 100 },
                    printers: { status: 'healthy', issues: [], score: 100 },
                    events: { status: 'healthy', issues: [], score: 100 },
                    drivers: { status: 'healthy', issues: [], score: 100 },
                    browsers: { status: 'healthy', issues: [], score: 100 },
                    ticketnotes: { status: 'healthy', issues: [], score: 100 }
                },
                criticalAlerts: [],
                overallStatus: 'healthy'
            };

            // Analyze Operating System
            if (window.systemData?.OS) {
                const os = window.systemData.OS;

                // Check critical services
                if (os.CriticalServices) {
                    const failedServices = os.CriticalServices.filter(s => !s.IsHealthy && s.IsCritical);
                    if (failedServices.length > 0) {
                        health.categories.operatingSystem.status = 'critical';
                        health.categories.operatingSystem.score = Math.max(0, 100 - (failedServices.length * 20));
                        failedServices.forEach(svc => {
                            const alert = `Critical service failed: ${escapeHtml(svc.DisplayName)}`;
                            health.categories.operatingSystem.issues.push(alert);
                            health.criticalAlerts.push(alert);
                        });
                    }
                }

                // Check domain authentication
                if (os.DomainAuthentication && os.DomainAuthentication.IsDomainJoined) {
                    if (os.DomainAuthentication.TrustRelationship !== 'Healthy') {
                        health.categories.operatingSystem.status = 'critical';
                        health.categories.operatingSystem.score = Math.max(0, health.categories.operatingSystem.score - 30);
                        const alert = 'Domain trust relationship broken';
                        health.categories.operatingSystem.issues.push(alert);
                        health.criticalAlerts.push(alert);
                    }
                    if (os.DomainAuthentication.DCConnectivity !== 'Success') {
                        health.categories.operatingSystem.status = health.categories.operatingSystem.status === 'critical' ? 'critical' : 'warning';
                        health.categories.operatingSystem.score = Math.max(0, health.categories.operatingSystem.score - 20);
                        health.categories.operatingSystem.issues.push('Domain controller connectivity issues');
                    }
                }

                // Check time sync
                if (os.TimeSynchronization && os.TimeSynchronization.NTPStatus !== 'Synchronized') {
                    health.categories.operatingSystem.status = health.categories.operatingSystem.status === 'critical' ? 'critical' : 'warning';
                    health.categories.operatingSystem.score = Math.max(0, health.categories.operatingSystem.score - 15);
                    health.categories.operatingSystem.issues.push('Time synchronization issues');
                }

                // Check performance
                if (os.Performance) {
                    if (os.Performance.Memory?.PercentUsed > 90) {
                        health.categories.operatingSystem.status = health.categories.operatingSystem.status === 'critical' ? 'critical' : 'warning';
                        health.categories.operatingSystem.score = Math.max(0, health.categories.operatingSystem.score - 15);
                        health.categories.operatingSystem.issues.push('High memory usage (>90%)');
                    }
                    if (os.Performance.CPU?.CurrentUsage > 80) {
                        health.categories.operatingSystem.status = health.categories.operatingSystem.status === 'critical' ? 'critical' : 'warning';
                        health.categories.operatingSystem.score = Math.max(0, health.categories.operatingSystem.score - 10);
                        health.categories.operatingSystem.issues.push('High CPU usage (>80%)');
                    }
                }
            }

            // Analyze Hardware
            if (window.systemData?.Hardware) {
                const hw = window.systemData.Hardware;

                if (hw.Memory?.Status === 'Critical') {
                    health.categories.hardware.status = 'critical';
                    health.categories.hardware.score = Math.max(0, 100 - 40);
                    const alert = 'Critical memory issues detected';
                    health.categories.hardware.issues.push(alert);
                    health.criticalAlerts.push(alert);
                }

                if (hw.Storage?.Issues?.length > 0) {
                    const criticalStorage = hw.Storage.Issues.filter(i => i.Severity === 'Critical');
                    if (criticalStorage.length > 0) {
                        health.categories.hardware.status = 'critical';
                        health.categories.hardware.score = Math.max(0, health.categories.hardware.score - 30);
                        criticalStorage.forEach(issue => {
                            health.categories.hardware.issues.push(`Storage: ${escapeHtml(issue.Description)}`);
                            health.criticalAlerts.push(`Critical storage issue: ${escapeHtml(issue.Description)}`);
                        });
                    }
                }
            }

            // Analyze Network
            if (window.systemData?.Network) {
                const net = window.systemData.Network;

                if (net.Adapters) {
                    const connectedAdapters = net.Adapters.filter(a => a.Status === 'Connected');
                    if (connectedAdapters.length === 0) {
                        health.categories.network.status = 'critical';
                        health.categories.network.score = 0;
                        const alert = 'No active network connections';
                        health.categories.network.issues.push(alert);
                        health.criticalAlerts.push(alert);
                    }
                }
            }

            // Analyze Software
            if (window.systemData?.Software) {
                const sw = window.systemData.Software;

                if (sw.ApplicationHealth?.Summary?.TotalCrashes72h > 5) {
                    health.categories.software.status = 'warning';
                    health.categories.software.score = Math.max(0, 100 - 20);
                    health.categories.software.issues.push(`High application crash rate: ${sw.ApplicationHealth.Summary.TotalCrashes72h} crashes in 72h`);
                }
            }

            // Determine overall status
            const statuses = Object.values(health.categories).map(c => c.status);
            if (statuses.includes('critical')) {
                health.overallStatus = 'critical';
            } else if (statuses.includes('warning')) {
                health.overallStatus = 'warning';
            } else {
                health.overallStatus = 'healthy';
            }

            return health;
        }


        function updateTabProblems(healthData) {
            // Update tab navigation with problem counts
            const tabMapping = {
                'operatingSystem': 'os',
                'hardware': 'hardware',
                'network': 'network',
                'software': 'software',
                'printers': 'printers',
                'events': 'events',
                'drivers': 'drivers',
                'browsers': 'browsers'
            };

            Object.keys(healthData.categories).forEach(category => {
                const health = healthData.categories[category];
                const tabName = tabMapping[category] || category;
                const badge = document.getElementById(`${tabName}Badge`);

                if (badge && health.issues.length > 0) {
                    badge.textContent = health.issues.length;
                    badge.classList.remove('hidden');
                }
            });
        }

        function scrollToFirstProblem() {
            // Find first element with critical or warning status
            const problemElements = document.querySelectorAll('.status-danger, .status-warning');
            if (problemElements.length > 0) {
                problemElements[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }

        function generateSummaryReport() {
            const healthData = analyzeSystemHealth();
            let summary = `=== WINDAS SYSTEM HEALTH SUMMARY ===\\n\\n`;

            summary += `Computer: ${systemData.Metadata?.ComputerName || 'Unknown'}\\n`;
            summary += `Scan Date: ${new Date().toLocaleString()}\\n`;
            summary += `Overall Status: ${healthData.overallStatus.toUpperCase()}\\n\\n`;

            if (healthData.criticalAlerts.length > 0) {
                summary += `CRITICAL ISSUES (${healthData.criticalAlerts.length}):\\n`;
                healthData.criticalAlerts.forEach((alert, i) => {
                    summary += `${i + 1}. ${alert}\\n`;
                });
                summary += '\\n';
            }

            summary += 'CATEGORY BREAKDOWN:\\n';
            Object.entries(healthData.categories).forEach(([key, health]) => {
                const name = key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
                summary += `${name}: ${health.status.toUpperCase()} (${health.score}/100)\\n`;
                if (health.issues.length > 0) {
                    health.issues.forEach(issue => summary += `  - ${issue}\\n`);
                }
            });

            // Copy to clipboard
            navigator.clipboard.writeText(summary).then(() => {
                alert('Health summary copied to clipboard!');
            }).catch(() => {
                // Fallback - show in alert
                alert(summary);
            });
        }

        // Enhanced tab switching with problem highlighting - RESTORED ORIGINAL FUNCTIONALITY
        function switchTab(tabName, isInitialLoad = false) {
            // Hide all tab contents and remove active class
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
                tab.style.display = 'none';
            });
            document.querySelectorAll('.tab-button').forEach(btn => {
                btn.classList.remove('active');
            });

            // Show selected tab content and mark button as active
            const targetTab = document.getElementById(tabName);
            if (targetTab) {
                targetTab.classList.add('active');
                targetTab.style.display = 'block';
            }

            // Mark the clicked button as active
            const activeButton = document.querySelector(`[onclick="switchTab('${tabName}')"]`);
            if (activeButton) {
                activeButton.classList.add('active');
            }

            // Scroll to top of page when switching tabs
            if (!isInitialLoad) {
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
        }

        // Collapsible Sections Functionality - Accessible
        function toggleCollapsible(button) {
            const section = button.closest('.collapsible-section');
            const isExpanded = section.classList.contains('expanded');

            section.classList.toggle('expanded');

            // Update ARIA state
            button.setAttribute('aria-expanded', !isExpanded);

            // Announce to screen readers
            const headerText = button.querySelector('span:first-child').textContent;
            announceToScreenReader(headerText + (!isExpanded ? ' expanded' : ' collapsed'));
        }

        function makeCollapsible(sectionSelector, headerText) {
            const sections = document.querySelectorAll(sectionSelector);
            sections.forEach((section, index) => {
                if (!section.classList.contains('collapsible-section')) {
                    // Generate unique IDs for ARIA
                    const headerId = `collapsible-header-${index}`;
                    const contentId = `collapsible-content-${index}`;

                    // Wrap content in collapsible structure with accessible button
                    const content = section.innerHTML;
                    section.innerHTML = `
                        <button type="button"
                                class="collapsible-header"
                                aria-expanded="false"
                                aria-controls="${contentId}"
                                id="${headerId}"
                                onclick="toggleCollapsible(this)">
                            <span>${headerText}</span>
                            <span class="collapsible-icon" aria-hidden="true">▼</span>
                        </button>
                        <div class="collapsible-content"
                             id="${contentId}"
                             role="region"
                             aria-labelledby="${headerId}">
                            ${content}
                        </div>
                    `;
                    section.classList.add('collapsible-section');
                }
            });
        }

        // Initialize collapsible sections and fix navigation after page load
        document.addEventListener('DOMContentLoaded', function() {
            // Scroll to top first
            window.scrollTo(0, 0);

            // Ensure OS tab is properly shown on load
            setTimeout(() => {
                switchTab('os', true); // Pass true to indicate initial load

                // Make performance metrics collapsible
                makeCollapsible('.performance-section', 'Performance Details');
                makeCollapsible('.detailed-specs', 'Detailed Specifications');

                // Auto-expand sections with issues
                try {
                    const healthData = analyzeSystemHealth();
                    Object.keys(healthData.categories).forEach(category => {
                        const health = healthData.categories[category];
                        if (health.status !== 'healthy') {
                            // Keep problem sections expanded
                            const tabMapping = {
                                'operatingSystem': 'os',
                                'hardware': 'hardware',
                                'network': 'network',
                                'software': 'software',
                                'printers': 'printers',
                                'events': 'events',
                                'drivers': 'drivers',
                                'browsers': 'browsers'
                            };
                            const tabName = tabMapping[category] || category;
                            const problemSections = document.querySelectorAll(`#${tabName} .collapsible-section`);
                            problemSections.forEach(section => section.classList.add('expanded'));
                        }
                    });
                } catch (error) {
                    console.log('Health analysis not yet available:', error);
                }
            }, 500);
        });

