/// Microsoft Entra External ID (CIAM) OIDC configuration tailored specifically
/// for the 'Student Finance Mobile' application deployment architecture.
class AzureConfig {
  AzureConfig._();

  static const String tenantName = String.fromEnvironment(
    'AZURE_TENANT_NAME',
    defaultValue: 'studentmoneytracker',
  );

  static const String tenantId = String.fromEnvironment(
    'AZURE_TENANT_ID',
    defaultValue: 'c256232d-23c6-4130-9360-00b771ed9863',
  );

  static const String clientId = String.fromEnvironment(
    'AZURE_CLIENT_ID',
    defaultValue: 'c3624609-6201-447c-b816-690d42b94774',
  );

  static const String userFlow = String.fromEnvironment(
    'AZURE_USER_FLOW',
    defaultValue: 'student_auth', // Matches your freshly created user flow!
  );

  static const String redirectUri = String.fromEnvironment(
    'AZURE_REDIRECT_URI',
    defaultValue: 'com.studenttracker.app://oauthredirect/', // 👈 Added the missing trailing slash here
  );

  static const String discoveryUrlOverride = String.fromEnvironment(
    'AZURE_DISCOVERY_URL',
    defaultValue: '',
  );

  /// Resolves to: studentmoneytracker.ciamlogin.com
  static String get tenantDomain {
    if (tenantName.contains('ciamlogin.com')) {
      return tenantName;
    }
    return '$tenantName.ciamlogin.com';
  }

  /// OpenID Connect discovery document URL endpoint string.
  static String get oidcDiscoveryUrl {
    if (discoveryUrlOverride.isNotEmpty) {
      return discoveryUrlOverride;
    }
    return 'https://$tenantDomain/$tenantId/v2.0/.well-known/openid-configuration';
  }

  /// Base Clean Authorization Endpoint
  static String get authorizationEndpoint => 
      'https://$tenantDomain/$tenantId/oauth2/v2.0/authorize';

  /// Base Clean Token Exchange Endpoint
  static String get tokenEndpoint => 
      'https://$tenantDomain/$tenantId/oauth2/v2.0/token';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];
}