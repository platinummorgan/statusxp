// Flutter Web Debug Configuration
// This file ensures source maps and debugging features are enabled

// Enhanced error reporting for production debugging
window.addEventListener('error', function(e) {
  const errorInfo = {
    message: e.message,
    source: e.filename,
    line: e.lineno,
    column: e.colno,
    stack: e.error ? e.error.stack : 'No stack available',
    timestamp: new Date().toISOString(),
    userAgent: navigator.userAgent,
    url: window.location.href
  };
  
  console.group('🔍 JavaScript Error Details');
  console.error('Full error object:', e.error);
  console.table(errorInfo);
  
  // Special handling for null check operator errors
  if (e.message && (e.message.includes('null') || e.message.includes('undefined'))) {
    console.group('🚨 NULL/UNDEFINED ERROR ANALYSIS');
    console.log('This appears to be a null/undefined access error');
    console.log('Location: ' + e.filename + ':' + e.lineno + ':' + e.colno);
    
    // Try to extract surrounding code context if possible
    if (e.error && e.error.stack) {
      const stackLines = e.error.stack.split('\n');
      console.log('Stack analysis:');
      stackLines.slice(0, 10).forEach((line, index) => {
        console.log(`  ${index}: ${line.trim()}`);
      });
    }
    console.groupEnd();
  }
  
  console.groupEnd();
  
  // Send error to console for debugging
  window.lastJSError = errorInfo;
});

// Enable unhandled promise rejection debugging
window.addEventListener('unhandledrejection', function(e) {
  console.group('🔍 Unhandled Promise Rejection');
  console.error('Promise rejection:', e.reason);
  if (e.reason && e.reason.stack) {
    console.log('Stack trace:', e.reason.stack);
  }
  console.groupEnd();
  
  window.lastPromiseError = {
    reason: e.reason,
    promise: e.promise,
    timestamp: new Date().toISOString()
  };
});

// Flutter configuration for debug mode
window.flutterConfiguration = window.flutterConfiguration || {};
Object.assign(window.flutterConfiguration, {
  canvasKitBaseUrl: "https://www.gstatic.com/flutter-canvaskit/",
  debugMode: true,
  enableSourceMaps: true,
  enableDebugging: true,
  serviceWorkerSettings: {
    allUrls: true,
    verbose: true
  }
});

// Add debug helper functions
window.debugStatusXP = {
  getLastError: () => window.lastJSError,
  getLastPromiseError: () => window.lastPromiseError,
  clearErrors: () => {
    window.lastJSError = null;
    window.lastPromiseError = null;
  }
};

console.log('🛠️ StatusXP debug configuration loaded - Enhanced error tracking enabled');