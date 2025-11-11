        // Data placeholder - will be replaced by PowerShell
        window.systemData = {{SYSTEM_DATA}};
        
        // Helper function to parse .NET JSON date format /Date(timestamp)/
        function parseNetDate(dateValue) {
            if (!dateValue) return null;
            
            if (typeof dateValue === 'string' && dateValue.startsWith('/Date(')) {
                const match = dateValue.match(/\/Date\((\d+)\)\//);
                if (match) {
                    const timestamp = parseInt(match[1]);
                    return new Date(timestamp);
                }
            } else if (typeof dateValue === 'string') {
                return new Date(dateValue);
            } else if (dateValue instanceof Date) {
                return dateValue;
            }
            
            return null;
        }
        
        // Helper function to format a .NET date for display in ISO 8601
        function formatNetDate(dateValue, defaultText = 'Never') {
            const date = parseNetDate(dateValue);
            return date ? formatDateISO(date) : defaultText;
        }
        
        // Format date to ISO 8601 format
        function formatDateISO(date) {
            if (!date) return 'Never';
            if (typeof date === 'string') {
                date = new Date(date);
            }
            // Check if date is valid
            if (!date || isNaN(date.getTime())) {
                return 'Invalid Date';
            }
            // Return local ISO string without milliseconds
            const isoString = new Date(date.getTime() - (date.getTimezoneOffset() * 60000)).toISOString();
            return isoString.slice(0, 19).replace('T', ' ');
        }
        
        // Format date as time ago (e.g., "2 hours ago", "3 days ago")
        function formatTimeAgo(date) {
            if (!date) return 'Unknown';
            if (typeof date === 'string') {
                date = new Date(date);
            }
            
            const now = new Date();
            const diffMs = now - date;
            const diffSec = Math.floor(diffMs / 1000);
            const diffMin = Math.floor(diffSec / 60);
            const diffHour = Math.floor(diffMin / 60);
            const diffDay = Math.floor(diffHour / 24);
            
            if (diffDay > 7) {
                return formatDateISO(date);
            } else if (diffDay > 0) {
                return `${diffDay} day${diffDay > 1 ? 's' : ''} ago`;
            } else if (diffHour > 0) {
                return `${diffHour} hour${diffHour > 1 ? 's' : ''} ago`;
            } else if (diffMin > 0) {
                return `${diffMin} minute${diffMin > 1 ? 's' : ''} ago`;
            } else {
                return 'Just now';
            }
        }

        // Initialize the report
        document.addEventListener('DOMContentLoaded', function() {
            loadSystemData();
            initializeEventListeners();

            // Initialize floating health dashboard immediately
            // Disabled - using sticky top navigation instead
            // setTimeout(() => {
            //     try {
            //         const healthData = analyzeSystemHealth();
            //         renderFloatingHealthNav(healthData);
            //     } catch (error) {
            //         console.log('Health dashboard will be initialized later:', error);
            //     }
            // }, 100);
        });

        // Dark theme only - no theme management needed

        // Tab Switching - WCAG 2.1 Accessible
        function switchTab(tabName) {
            // Hide all tab panels
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });

            // Update all tab buttons - ARIA states and tabindex
            document.querySelectorAll('[role="tab"]').forEach(btn => {
                btn.classList.remove('active');
                btn.setAttribute('aria-selected', 'false');
                btn.tabIndex = -1;
            });

            // Show selected tab panel
            const panel = document.getElementById(tabName);
            if (panel) {
                panel.classList.add('active');

                // Scroll to top of main content to show header
                const mainContent = document.getElementById('main-content');
                if (mainContent) {
                    window.scrollTo({
                        top: mainContent.offsetTop - 100,
                        behavior: 'smooth'
                    });
                }

                // Move focus to panel for screen readers (after scroll completes)
                setTimeout(() => {
                    panel.focus();
                }, 300);
            }

            // Activate selected tab button
            const activeTab = document.getElementById(tabName + '-tab');
            if (activeTab) {
                activeTab.classList.add('active');
                activeTab.setAttribute('aria-selected', 'true');
                activeTab.tabIndex = 0;
            }

            // Announce to screen readers
            announceToScreenReader('Viewing ' + tabName + ' section');

            // Load tab-specific content
            if (tabName === 'ticketnotes') {
                loadTicketNotesTab();
            }
            if (tabName === 'events') {
                setTimeout(() => {
                    loadEventsTab();
                }, 0);
            }
        }

        // Screen Reader Announcements
        function announceToScreenReader(message) {
            const announcer = document.getElementById('status-announcer');
            if (announcer) {
                announcer.textContent = message;
                setTimeout(() => announcer.textContent = '', 1000);
            }
        }

        // Keyboard Navigation for Tabs (Arrow Keys, Home, End)
        function handleTabKeyDown(e) {
            const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
            const currentIndex = tabs.indexOf(e.target);
            let newIndex;

            switch(e.key) {
                case 'ArrowLeft':
                    newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.length - 1;
                    e.preventDefault();
                    break;
                case 'ArrowRight':
                    newIndex = currentIndex < tabs.length - 1 ? currentIndex + 1 : 0;
                    e.preventDefault();
                    break;
                case 'Home':
                    newIndex = 0;
                    e.preventDefault();
                    break;
                case 'End':
                    newIndex = tabs.length - 1;
                    e.preventDefault();
                    break;
                default:
                    return;
            }

            tabs[newIndex].focus();
            tabs[newIndex].click();
        }

        // Global Keyboard Shortcuts - WCAG Level AAA
        let previousFocusedElement = null;

        function showKeyboardHelp() {
            const overlay = document.getElementById('keyboard-help-overlay');
            if (overlay) {
                previousFocusedElement = document.activeElement;
                overlay.classList.add('active');

                // Focus the close button for keyboard accessibility
                const closeButton = overlay.querySelector('.keyboard-help-close');
                if (closeButton) {
                    closeButton.focus();
                }

                // Trap focus within modal
                overlay.addEventListener('keydown', trapFocusInModal);

                announceToScreenReader('Keyboard shortcuts help opened');
            }
        }

        function closeKeyboardHelp() {
            const overlay = document.getElementById('keyboard-help-overlay');
            if (overlay) {
                overlay.classList.remove('active');
                overlay.removeEventListener('keydown', trapFocusInModal);

                // Return focus to previous element
                if (previousFocusedElement) {
                    previousFocusedElement.focus();
                }

                announceToScreenReader('Keyboard shortcuts help closed');
            }
        }

        function trapFocusInModal(e) {
            if (e.key === 'Escape') {
                closeKeyboardHelp();
                return;
            }

            if (e.key === 'Tab') {
                const modal = document.querySelector('.keyboard-help-modal');
                const focusableElements = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
                const firstElement = focusableElements[0];
                const lastElement = focusableElements[focusableElements.length - 1];

                if (e.shiftKey && document.activeElement === firstElement) {
                    e.preventDefault();
                    lastElement.focus();
                } else if (!e.shiftKey && document.activeElement === lastElement) {
                    e.preventDefault();
                    firstElement.focus();
                }
            }
        }

        // J/K Navigation (Vim-style scrolling)
        function scrollToNextSection() {
            const sections = Array.from(document.querySelectorAll('h2[class="card-title"], .card'));
            const scrollPosition = window.scrollY + 100;

            for (let section of sections) {
                const sectionTop = section.getBoundingClientRect().top + window.scrollY;
                if (sectionTop > scrollPosition) {
                    window.scrollTo({
                        top: sectionTop - 80,
                        behavior: 'smooth'
                    });
                    announceToScreenReader('Scrolled to next section');
                    return;
                }
            }
        }

        function scrollToPreviousSection() {
            const sections = Array.from(document.querySelectorAll('h2[class="card-title"], .card')).reverse();
            const scrollPosition = window.scrollY - 100;

            for (let section of sections) {
                const sectionTop = section.getBoundingClientRect().top + window.scrollY;
                if (sectionTop < scrollPosition) {
                    window.scrollTo({
                        top: sectionTop - 80,
                        behavior: 'smooth'
                    });
                    announceToScreenReader('Scrolled to previous section');
                    return;
                }
            }
        }

        // Global keyboard event handler
        document.addEventListener('keydown', function(e) {
            // Don't trigger shortcuts if user is typing in input/textarea
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
                return;
            }

            // Check if keyboard help modal is open
            const helpOpen = document.getElementById('keyboard-help-overlay')?.classList.contains('active');

            if (!helpOpen) {
                // ? or Ctrl+/ - Show keyboard help
                if (e.key === '?' || (e.ctrlKey && e.key === '/')) {
                    e.preventDefault();
                    showKeyboardHelp();
                }
                // J - Scroll to next section
                else if (e.key === 'j' || e.key === 'J') {
                    e.preventDefault();
                    scrollToNextSection();
                }
                // K - Scroll to previous section
                else if (e.key === 'k' || e.key === 'K') {
                    e.preventDefault();
                    scrollToPreviousSection();
                }
            } else {
                // Esc - Close help modal
                if (e.key === 'Escape') {
                    e.preventDefault();
                    closeKeyboardHelp();
                }
            }
        });

        // Removed Quick Status Analysis
        function updateQuickStatus_removed() {
            const data = window.systemData;
            if (!data) return;
            
            let criticalCount = 0;
            let warningCount = 0;
            let overallHealth = 'Good';
            
            // Check Events
            if (data.Events?.Summary) {
                criticalCount += data.Events.Summary.Critical || 0;
                warningCount += data.Events.Summary.Warnings || 0;
                
                // Check for specific critical events
                if (data.Events.Events?.Critical) {
                    const shutdowns = data.Events.Events.Critical.filter(e => e.Id === 41).length;
                    const bsods = data.Events.Events.Critical.filter(e => e.Id === 1001).length;
                    
                    // Adjust critical count - Event ID 41 only critical if 3+
                    if (shutdowns < 3) {
                        criticalCount -= shutdowns;
                        if (shutdowns > 0) warningCount += shutdowns;
                    }
                    
                    if (bsods > 0) overallHealth = 'Critical';
                }
            }
            
            // Check Drivers
            if (data.Drivers?.Summary) {
                if (data.Drivers.Summary.MissingDrivers > 0) criticalCount++;
                if (data.Drivers.Summary.ProblemDrivers > 0) warningCount++;
            }
            
            // Check Disk Space
            if (data.Hardware?.Storage?.SystemDrive) {
                const freePercent = data.Hardware.Storage.SystemDrive.FreeSpacePercent;
                if (freePercent && freePercent < 10) {
                    criticalCount++;
                    overallHealth = 'Critical';
                } else if (freePercent && freePercent < 20) {
                    warningCount++;
                }
            }
            
            // Check Memory
            if (data.Hardware?.Memory?.UsagePercent) {
                if (data.Hardware.Memory.UsagePercent > 90) {
                    criticalCount++;
                } else if (data.Hardware.Memory.UsagePercent > 80) {
                    warningCount++;
                }
            }
            
            // Update display
            const criticalDiv = document.getElementById('quick-critical');
            const warningDiv = document.getElementById('quick-warning');
            const okDiv = document.getElementById('quick-ok');
            
            if (criticalCount > 0) {
                document.getElementById('critical-count').textContent = criticalCount;
                criticalDiv.style.display = 'block';
                overallHealth = 'Critical';
            }
            
            if (warningCount > 0) {
                document.getElementById('warning-count').textContent = warningCount;
                warningDiv.style.display = 'block';
                if (overallHealth !== 'Critical') overallHealth = 'Attention Required';
            }
            
            if (criticalCount === 0 && warningCount === 0) {
                okDiv.style.display = 'block';
                document.getElementById('health-status').textContent = 'Good';
            } else {
                okDiv.style.display = 'block';
                document.getElementById('health-status').textContent = overallHealth;
            }
        }
        
        // Removed Copy Quick Summary function
        function copyQuickSummary_removed() {
            const data = window.systemData;
            if (!data) {
                alert('No data available');
                return;
            }
            
            let summary = `System: ${data.Metadata?.ComputerName || 'Unknown'}\n`;
            summary += `OS: ${data.OS?.SystemInfo?.WindowsVersion || 'Windows'}\n`;
            summary += `CPU: ${data.Hardware?.CPU?.Model || 'Unknown'}\n`;
            summary += `RAM: ${data.Hardware?.Memory?.TotalGB || 'Unknown'}GB`;
            
            const memUsage = data.Hardware?.Memory?.UsagePercent;
            if (memUsage) summary += ` (${memUsage}% used)`;
            
            summary += `\n`;
            
            // Add critical issues if any
            const criticalCount = document.getElementById('critical-count').textContent;
            const warningCount = document.getElementById('warning-count').textContent;
            
            if (criticalCount !== '0') {
                summary += `\n❌ ${criticalCount} Critical Issues`;
            }
            if (warningCount !== '0') {
                summary += `\n⚠️ ${warningCount} Warnings`;
            }
            
            // Add health status
            const healthStatus = document.getElementById('health-status').textContent;
            summary += `\n\nOverall Health: ${healthStatus}`;
            
            navigator.clipboard.writeText(summary).then(() => {
                // Visual feedback
                const btn = event.target;
                const originalText = btn.innerHTML;
                btn.innerHTML = '✅ Copied!';
                btn.style.background = 'var(--success-color)';
                setTimeout(() => {
                    btn.innerHTML = originalText;
                    btn.style.background = 'var(--accent-color)';
                }, 2000);
            }).catch(err => {
                alert('Failed to copy to clipboard');
            });
        }

        // Collapsible Section Toggle
        function toggleCollapsible(button) {
            const isExpanded = button.getAttribute('aria-expanded') === 'true';
            const content = button.nextElementSibling;

            // Toggle aria-expanded
            button.setAttribute('aria-expanded', !isExpanded);

            // Toggle content visibility
            if (isExpanded) {
                content.classList.add('collapsed');
            } else {
                content.classList.remove('collapsed');
            }
        }

        // Toggle Driver Category Details
        function toggleDriverCategory(categoryId) {
            const categorySection = document.getElementById(categoryId);
            if (categorySection) {
                // Hide all other category sections first
                document.querySelectorAll('.collapsible-section').forEach(section => {
                    if (section.id !== categoryId) {
                        section.style.display = 'none';
                    }
                });

                // Toggle this section
                if (categorySection.style.display === 'none') {
                    categorySection.style.display = 'block';
                    // Smooth scroll to the section
                    categorySection.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                } else {
                    categorySection.style.display = 'none';
                }
            }
        }

        // Table Sorting
        function sortTable(tableId, columnIndex) {
            const table = document.getElementById(tableId);
            const tbody = table.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr'));
            
            // Determine sort direction
            const th = table.querySelectorAll('th')[columnIndex];
            const isAscending = th.textContent.includes('↑');
            
            // Update header arrows
            table.querySelectorAll('th').forEach(header => {
                header.textContent = header.textContent.replace(/[↑↓]/, '↕');
            });
            
            th.textContent = th.textContent.replace('↕', isAscending ? '↓' : '↑');
            
            // Sort rows
            rows.sort((a, b) => {
                const aValue = a.cells[columnIndex].textContent.trim();
                const bValue = b.cells[columnIndex].textContent.trim();
                
                // Try to parse as number
                const aNum = parseFloat(aValue);
                const bNum = parseFloat(bValue);
                
                if (!isNaN(aNum) && !isNaN(bNum)) {
                    return isAscending ? bNum - aNum : aNum - bNum;
                }
                
                // Sort as string
                return isAscending 
                    ? bValue.localeCompare(aValue)
                    : aValue.localeCompare(bValue);
            });
            
            // Re-append sorted rows
            rows.forEach(row => tbody.appendChild(row));
        }

        // Utility functions for Reliability Index
        function getReliabilityColor(index) {
            if (index === null || index === undefined || index === "N/A") return 'var(--text-muted)';
            const numIndex = parseFloat(index);
            if (numIndex >= 8) return 'var(--success-color)';    // Green for 8-10
            if (numIndex >= 6) return 'var(--warning-color)';   // Yellow for 6-7.99
            if (numIndex >= 4) return 'var(--danger-color)';    // Red for 4-5.99
            return 'var(--danger-color)';                       // Red for <4
        }
        
        function getReliabilityDescription(index) {
            if (index === null || index === undefined || index === "N/A") return 'No data available';
            const numIndex = parseFloat(index);
            if (numIndex >= 9) return 'Excellent stability';
            if (numIndex >= 8) return 'Very stable';
            if (numIndex >= 7) return 'Good stability';
            if (numIndex >= 6) return 'Fair stability';
            if (numIndex >= 4) return 'Poor stability';
            return 'Very unstable';
        }

        function getDetailedReliabilityAnalysis(index, stabilityData, eventsData) {
            if (index === null || index === undefined || index === "N/A") {
                return {
                    description: 'No data available',
                    context: 'Windows Reliability Monitor data is not accessible.',
                    recommendations: ['Check if Windows Reliability Monitor is enabled', 'Run System File Checker (sfc /scannow)']
                };
            }

            const numIndex = parseFloat(index);
            let description, context, recommendations = [];
            let specificIssues = [];
            let rootCauses = [];

            // Analyze specific issues FIRST to provide targeted recommendations
            if (stabilityData) {
                if (stabilityData.BlueScreenEvents7Days > 0) {
                    specificIssues.push(`${stabilityData.BlueScreenEvents7Days} blue screen crashes`);
                    rootCauses.push('System crashes are directly impacting reliability score');
                    recommendations.unshift('🚨 CRITICAL: Check C:\\Windows\\Minidump\\ for crash dump files');
                    recommendations.push('Run Memory Diagnostic (mdsched.exe)');
                }

                if (stabilityData.RecentCriticalEvents > 0) {
                    specificIssues.push(`${stabilityData.RecentCriticalEvents} recent critical system events`);
                    recommendations.push('Open Event Viewer → Windows Logs → System for details');
                }

                if (stabilityData.UnexpectedShutdowns && stabilityData.UnexpectedShutdowns.length > 0) {
                    specificIssues.push(`${stabilityData.UnexpectedShutdowns.length} unexpected shutdowns`);
                    rootCauses.push('Improper shutdowns reduce reliability score');
                    recommendations.push('Check Event ID 6008 for unexpected shutdown causes');
                }
            }

            // Analyze Event Log data for specific patterns
            let dcomErrorCount = 0;
            let configMgrErrors = 0;
            let serviceErrors = 0;

            if (eventsData && eventsData.CriticalEvents) {
                eventsData.CriticalEvents.forEach(event => {
                    if (event.Id === 10028) {
                        dcomErrorCount++;
                        if (event.Message && event.Message.includes('phont74000usb.homeoffice.wal-mart.com')) {
                            configMgrErrors++;
                        }
                    }
                    if (event.Id === 7034 || event.Id === 7031) {
                        serviceErrors++;
                    }
                });
            }

            // Specific DCOM Configuration Manager issue analysis
            if (configMgrErrors > 5) {
                specificIssues.push(`${configMgrErrors} DCOM errors connecting to Configuration Manager server`);
                rootCauses.push('Microsoft Configuration Manager cannot reach print server "phont74000usb.homeoffice.wal-mart.com"');
                recommendations.unshift('📞 Contact IT: Network connectivity issue with print server phont74000usb.homeoffice.wal-mart.com');
                recommendations.push('Verify VPN/network connection to corporate resources');

                // Adjust description based on this specific issue
                if (numIndex >= 4 && numIndex < 7) {
                    description = 'Moderate stability with network connectivity issues';
                    context = `Network connectivity problems are affecting reliability score. The system cannot connect to corporate Configuration Manager server, generating frequent errors that Windows counts against system stability.`;
                }
            } else if (dcomErrorCount > 5) {
                specificIssues.push(`${dcomErrorCount} DCOM communication errors`);
                rootCauses.push('Distributed COM service communication failures');
                recommendations.push('Check DCOM configuration in Component Services');
            }

            if (serviceErrors > 3) {
                specificIssues.push(`${serviceErrors} service crash/restart events`);
                rootCauses.push('Windows services are failing unexpectedly');
                recommendations.push('Review failing services in Services.msc');
            }

            // Determine description based on actual issues found, not just score
            if (!description) {
                if (numIndex >= 9) {
                    description = 'Excellent stability';
                    context = 'System is very stable with minimal issues affecting user experience.';
                    if (recommendations.length === 0) recommendations = ['Continue current maintenance practices', 'Consider creating a system restore point'];
                } else if (numIndex >= 8) {
                    description = 'Very stable';
                    context = 'System is stable with only occasional minor issues.';
                    if (recommendations.length === 0) recommendations = ['Monitor for any developing patterns', 'Keep current update schedule'];
                } else if (numIndex >= 7) {
                    description = 'Good stability';
                    context = 'System is generally stable but may have some intermittent issues.';
                    if (recommendations.length === 0) recommendations = ['Review recent software installations', 'Check for driver updates'];
                } else if (numIndex >= 6) {
                    description = 'Fair stability with identifiable issues';
                    context = 'System experiences regular issues that may impact user productivity.';
                    if (recommendations.length === 0) recommendations = ['Investigate recurring errors in Event Log', 'Consider recent system changes'];
                } else if (numIndex >= 4) {
                    description = 'Poor stability requiring attention';
                    context = 'System has significant stability issues requiring immediate attention.';
                    if (recommendations.length === 0) recommendations = ['Priority: Investigate critical system errors', 'Review installed software for conflicts'];
                } else {
                    description = 'Very unstable system';
                    context = 'System is experiencing severe stability issues affecting reliability.';
                    if (recommendations.length === 0) recommendations = ['🚨 URGENT: Review system for malware', 'Consider system restore or repair'];
                }
            }

            // Add specific findings to context
            if (specificIssues.length > 0) {
                context += ` Detected issues: ${specificIssues.join(', ')}.`;
            }
            if (rootCauses.length > 0) {
                context += ` Root cause: ${rootCauses.join('; ')}.`;
            }

            // Add score interpretation
            context += ` Current score (${numIndex}/10) indicates ${numIndex >= 7 ? 'acceptable' : numIndex >= 5 ? 'moderate' : 'poor'} system reliability.`;

            return {
                description,
                context,
                recommendations: recommendations.slice(0, 5) // Allow up to 5 specific recommendations
            };
        }
        
        // Sort applications table by column
        function sortApplicationsTable(columnIndex) {
            const table = document.getElementById('allApplicationsTable');
            if (!table) return;
            
            const tbody = table.querySelector('tbody');
            const rows = Array.from(tbody.querySelectorAll('tr')).filter(row => row.style.display !== 'none');
            
            // Toggle sort direction
            const currentDir = table.getAttribute('data-sort-dir') || 'asc';
            const newDir = currentDir === 'asc' ? 'desc' : 'asc';
            table.setAttribute('data-sort-dir', newDir);
            
            rows.sort((a, b) => {
                const aVal = a.cells[columnIndex]?.textContent.trim() || '';
                const bVal = b.cells[columnIndex]?.textContent.trim() || '';
                
                // Handle size column (convert to MB for comparison)
                if (columnIndex === 4) {
                    const getSizeInMB = (sizeStr) => {
                        if (sizeStr.includes('GB')) return parseFloat(sizeStr) * 1024;
                        if (sizeStr.includes('MB')) return parseFloat(sizeStr);
                        return 0;
                    };
                    const aSizeMB = getSizeInMB(aVal);
                    const bSizeMB = getSizeInMB(bVal);
                    return newDir === 'asc' ? aSizeMB - bSizeMB : bSizeMB - aSizeMB;
                }
                
                // Handle date column
                if (columnIndex === 3) {
                    const aDate = aVal === 'Unknown' ? new Date(0) : new Date(aVal);
                    const bDate = bVal === 'Unknown' ? new Date(0) : new Date(bVal);
                    return newDir === 'asc' ? aDate - bDate : bDate - aDate;
                }
                
                // Default string comparison
                return newDir === 'asc' ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
            });
            
            // Re-append sorted rows
            rows.forEach(row => tbody.appendChild(row));
        }

        // HTML Encoding function to prevent XSS attacks
        function escapeHtml(unsafe) {
            if (unsafe === null || unsafe === undefined) return '';
            return String(unsafe)
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;")
                .replace(/'/g, "&#039;");
        }

        // Load System Data
