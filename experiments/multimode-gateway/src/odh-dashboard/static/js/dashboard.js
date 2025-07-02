// ODH Dashboard JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Initialize dashboard
    initializeDashboard();
});

function initializeDashboard() {
    // Update timestamps
    updateTimestamp();
    
    // Setup service status monitoring
    setupServiceMonitoring();
    
    // Add keyboard shortcuts
    setupKeyboardShortcuts();
    
    console.log('ODH Dashboard initialized');
}

// Update current time display
function updateTimestamp() {
    const timeElement = document.getElementById('current-time');
    if (timeElement) {
        const now = new Date();
        timeElement.textContent = now.toLocaleString();
    }
}

// Setup periodic service status checking
function setupServiceMonitoring() {
    // Check service status every 30 seconds
    setInterval(checkServiceHealth, 30000);
}

// Check health of services via API
async function checkServiceHealth() {
    try {
        const response = await fetch('/api/services');
        if (response.ok) {
            const data = await response.json();
            updateServiceStatus(data.services);
        }
    } catch (error) {
        console.warn('Failed to check service health:', error);
    }
}

// Update service status indicators
function updateServiceStatus(services) {
    services.forEach(service => {
        const statusElements = document.querySelectorAll(`[data-service="${service.name}"]`);
        statusElements.forEach(element => {
            element.className = `badge bg-${getStatusColor(service.status)}-subtle text-${getStatusColor(service.status)}-emphasis`;
            element.innerHTML = `<i class="bi bi-circle-fill me-1" style="font-size: 0.5em;"></i>${service.status.charAt(0).toUpperCase() + service.status.slice(1)}`;
        });
    });
}

// Get Bootstrap color class for service status
function getStatusColor(status) {
    switch (status.toLowerCase()) {
        case 'healthy': return 'success';
        case 'warning': return 'warning';
        case 'error': return 'danger';
        default: return 'secondary';
    }
}

// Setup keyboard shortcuts
function setupKeyboardShortcuts() {
    document.addEventListener('keydown', function(event) {
        // Alt + H = Home/Dashboard
        if (event.altKey && event.key === 'h') {
            event.preventDefault();
            window.location.href = '/';
        }
        
        // Alt + A = About page
        if (event.altKey && event.key === 'a') {
            event.preventDefault();
            window.location.href = '/about';
        }
        
        // Alt + R = Refresh page
        if (event.altKey && event.key === 'r') {
            event.preventDefault();
            window.location.reload();
        }
    });
}

// Utility function to show loading state
function showLoading(element) {
    if (element) {
        element.classList.add('loading');
    }
}

// Utility function to hide loading state
function hideLoading(element) {
    if (element) {
        element.classList.remove('loading');
    }
}

// Copy text to clipboard
function copyToClipboard(text) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(text).then(() => {
            showToast('Copied to clipboard!', 'success');
        }).catch(err => {
            console.error('Failed to copy: ', err);
            showToast('Failed to copy to clipboard', 'error');
        });
    } else {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        try {
            document.execCommand('copy');
            showToast('Copied to clipboard!', 'success');
        } catch (err) {
            console.error('Failed to copy: ', err);
            showToast('Failed to copy to clipboard', 'error');
        }
        document.body.removeChild(textArea);
    }
}

// Show toast notification
function showToast(message, type = 'info') {
    // Create toast element
    const toast = document.createElement('div');
    toast.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    toast.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    toast.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.appendChild(toast);
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    }, 3000);
}

// Handle service card clicks
document.addEventListener('click', function(event) {
    if (event.target.matches('.service-card a, .service-card a *')) {
        const link = event.target.closest('a');
        if (link) {
            // Add loading state to clicked service
            const card = link.closest('.service-card');
            if (card) {
                showLoading(card);
                // Remove loading state after navigation (or timeout)
                setTimeout(() => hideLoading(card), 1000);
            }
        }
    }
});

// Handle route path copy functionality
document.addEventListener('click', function(event) {
    if (event.target.matches('code')) {
        const text = event.target.textContent;
        copyToClipboard(text);
    }
});

// Add smooth scrolling for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Analytics/tracking (placeholder for future implementation)
function trackEvent(category, action, label) {
    // This could be implemented with your analytics provider
    console.log('Event tracked:', { category, action, label });
}

// Export functions for use in templates
window.ODHDashboard = {
    copyToClipboard,
    showToast,
    trackEvent,
    checkServiceHealth,
    updateTimestamp
}; 