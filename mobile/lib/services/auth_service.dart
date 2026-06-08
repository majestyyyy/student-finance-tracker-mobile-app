import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../config/azure_config.dart';
import '../config/environment.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;

  bool _isLoading = false;
  bool _isUserSynced = false;
  String? _accessToken;
  String? _displayName;
  String? _azureUserId;
  String? _email;
  String? _lastSyncError;

  bool get isLoading => _isLoading;
  bool get isUserSynced => _isUserSynced;
  String? get accessToken => _accessToken;
  String? get displayName => _displayName;
  String? get azureUserId => _azureUserId;
  String? get email => _email;
  String? get lastSyncError => _lastSyncError;

  /// Full sign-in: OIDC auth, then mandatory backend user sync before success.
  Future<bool> loginWithMicrosoftOrGoogle() async {
    _isLoading = true;
    _lastSyncError = null;
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

      if (result.accessToken == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _secureStorage.write(
        key: 'access_token',
        value: result.accessToken,
      );
      await _secureStorage.write(key: 'id_token', value: result.idToken);
      await _secureStorage.write(
        key: 'refresh_token',
        value: result.refreshToken,
      );

      final claims = _extractClaims(result.idToken ?? result.accessToken);
      _azureUserId = claims['sub'] as String?;
      _email = _resolveEmail(claims);
      _displayName = claims['name'] as String? ??
          claims['given_name'] as String? ??
          _email ??
          'Student';

      if (_azureUserId == null || _azureUserId!.isEmpty) {
        throw StateError('Azure token is missing the sub claim');
      }

      _email ??= '$_azureUserId@studenttracker.local';

      await _secureStorage.write(key: 'azure_user_id', value: _azureUserId);
      await _secureStorage.write(key: 'user_name', value: _displayName);
      await _secureStorage.write(key: 'user_email', value: _email);

      _accessToken = result.accessToken;

      final synced = await ensureUserSynced();
      if (!synced) {
        await _clearSessionState();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Authentication failure: $error');
      await _clearSessionState();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restores a persisted session and blocks until backend user sync succeeds.
  Future<bool> checkAutoLoginState() async {
    try {
      final token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        return false;
      }

      var isTokenExpired = false;
      try {
        isTokenExpired = JwtDecoder.isExpired(token);
      } catch (_) {}

      if (isTokenExpired) {
        await logout();
        return false;
      }

      _accessToken = token;
      _displayName = await _secureStorage.read(key: 'user_name') ?? 'Student';
      _azureUserId = await _secureStorage.read(key: 'azure_user_id');
      _email = await _secureStorage.read(key: 'user_email');

      if (_azureUserId == null || _azureUserId!.isEmpty) {
        final idToken = await _secureStorage.read(key: 'id_token');
        final claims = _extractClaims(idToken ?? token);
        _azureUserId = claims['sub'] as String?;
        _email ??= _resolveEmail(claims);
        if (_azureUserId != null) {
          await _secureStorage.write(key: 'azure_user_id', value: _azureUserId);
        }
        if (_email != null) {
          await _secureStorage.write(key: 'user_email', value: _email);
        }
      }

      _email ??= _azureUserId != null
          ? '$_azureUserId@studenttracker.local'
          : null;

      final synced = await ensureUserSynced();
      notifyListeners();
      return synced;
    } catch (storageError) {
      debugPrint('Secure storage read error: $storageError');
      return false;
    }
  }

  /// POST /v1/users/sync — must succeed before any finance API calls.
  Future<bool> ensureUserSynced() async {
    _lastSyncError = null;

    if (_azureUserId == null || _azureUserId!.isEmpty) {
      _lastSyncError = 'Missing Azure user id (sub claim)';
      _isUserSynced = false;
      return false;
    }

    if (_email == null || _email!.isEmpty) {
      _lastSyncError = 'Missing user email for sync';
      _isUserSynced = false;
      return false;
    }

    try {
      final response = await _httpClient.post(
        Uri.parse(Environment.usersSyncEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_accessToken != null && _accessToken!.isNotEmpty)
            'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'azure_user_id': _azureUserId,
          'email': _email,
          if (_displayName != null) 'display_name': _displayName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _isUserSynced = true;
        _lastSyncError = null;
        notifyListeners();
        return true;
      }

      _lastSyncError =
          'User sync failed (${response.statusCode}): ${response.body}';
      debugPrint(_lastSyncError);
      _isUserSynced = false;
      notifyListeners();
      return false;
    } catch (error) {
      _lastSyncError = 'User sync network error: $error';
      debugPrint(_lastSyncError);
      _isUserSynced = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _secureStorage.deleteAll();
    } catch (error) {
      debugPrint('Secure storage clear error: $error');
    }

    await _clearSessionState();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _clearSessionState() async {
    _accessToken = null;
    _displayName = null;
    _azureUserId = null;
    _email = null;
    _isUserSynced = false;
  }

  Map<String, dynamic> _extractClaims(String? jwt) {
    if (jwt == null || jwt.isEmpty) {
      return {};
    }

    try {
      return JwtDecoder.decode(jwt);
    } catch (_) {
      return {};
    }
  }

  String? _resolveEmail(Map<String, dynamic> claims) {
    final directEmail = claims['email'];
    if (directEmail is String && directEmail.isNotEmpty) {
      return directEmail.toLowerCase();
    }

    final emails = claims['emails'];
    if (emails is List && emails.isNotEmpty) {
      final first = emails.first;
      if (first is String && first.isNotEmpty) {
        return first.toLowerCase();
      }
    }

    final preferredUsername = claims['preferred_username'];
    if (preferredUsername is String && preferredUsername.contains('@')) {
      return preferredUsername.toLowerCase();
    }

    return null;
  }
}
