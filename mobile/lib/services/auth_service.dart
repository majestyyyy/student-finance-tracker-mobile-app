import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../config/azure_config.dart';

class AuthService extends ChangeNotifier {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  String? _accessToken;
  String? _displayName;

  bool get isLoading => _isLoading;
  String? get accessToken => _accessToken;
  String? get displayName => _displayName;

  /// Main entry login sequence handler interacting with Entra ID & Google OAuth
  Future<bool> loginWithMicrosoftOrGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AzureConfig.clientId,
          AzureConfig.redirectUri,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: AzureConfig.authorizationEndpoint,
            tokenEndpoint: AzureConfig.tokenEndpoint,
          ),
          scopes: AzureConfig.scopes,
          promptValues: ['login'],
          additionalParameters: {
            'idp_flow': AzureConfig.userFlow,
          },
        ),
      );

      if (result != null && result.accessToken != null) {
        // Cache session tokens in secure local device hardware storage layers
        await _secureStorage.write(key: 'access_token', value: result.accessToken);
        await _secureStorage.write(key: 'id_token', value: result.idToken);
        await _secureStorage.write(key: 'refresh_token', value: result.refreshToken);
        
        // Extract real profile fields safely by decoding the underlying JWT ID Token
        if (result.idToken != null) {
          try {
            final Map<String, dynamic> decodedToken = JwtDecoder.decode(result.idToken!);
            _displayName = decodedToken['name'] ?? 
                           decodedToken['given_name'] ?? 
                           decodedToken['email'] ?? 
                           'Student';
          } catch (jwtError) {
            debugPrint('JWT token decoding fallback warning: $jwtError');
            _displayName = result.tokenAdditionalParameters?['given_name'] ?? 'Student';
          }
        } else {
          _displayName = result.tokenAdditionalParameters?['given_name'] ?? 'Student';
        }
        
        await _secureStorage.write(key: 'user_name', value: _displayName);
        
        _accessToken = result.accessToken;
        _isLoading = false;
        notifyListeners();
        return true; 
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Authentication core engine failure exception: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Initial app boot checker to resolve auto-login structural state bypasses
  Future<bool> checkAutoLoginState() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null) {
        // Double check token expiration matrix status
        bool isTokenExpired = false;
        try {
          isTokenExpired = JwtDecoder.isExpired(token);
        } catch (_) {
          // If token format is opaque, assume valid or let endpoint reject later
        }

        if (isTokenExpired) {
          // Token is dead, wipe out configuration cleanly to drop onto login
          await logout();
          return false;
        }

        _accessToken = token;
        _displayName = await _secureStorage.read(key: 'user_name') ?? 'Student';
        notifyListeners();
        return true;
      }
    } catch (storageError) {
      debugPrint('Secure keychain access initialization fault: $storageError');
    }
    return false;
  }

  /// Wipe session profiles entirely out of local secure persistence files on logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Keychain flushing fault exception ignored: $e');
    }
    
    _accessToken = null;
    _displayName = null;
    _isLoading = false;
    notifyListeners();
  }
}