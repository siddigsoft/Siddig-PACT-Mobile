// Web-specific configuration implementations
// No imports needed since we're using the default configuration

/// Configure app-specific settings for web platform
void configureApp() {
  // Using the default URL strategy (hash-based) which is more compatible
  // and doesn't require special server configuration
  // Not calling setUrlStrategy() at all will use the default hash (#) strategy

  // Log configuration
  print('🌐 Web platform detected: Using default URL strategy');
}
