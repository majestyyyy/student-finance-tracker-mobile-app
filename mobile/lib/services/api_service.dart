import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class ApiSyncResult {
  final bool success;
  final int? userId;
  final bool? created;
  final String? errorMessage;

  const ApiSyncResult({
    required this.success,
    this.userId,
    this.created,
    this.errorMessage,
  });
}

/// Communicates directly with the Dart Frog backend server API instance.
class ApiService {
  Future<ApiSyncResult> syncUser({
    required String azureUserId,
    required String email,
    String? displayName,
    String? accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(Environment.usersSyncEndpoint),
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'azure_user_id': azureUserId,
          'email': email,
          'display_name': displayName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userMap = data['user'] as Map<String, dynamic>?;
        return ApiSyncResult(
          success: true,
          userId: userMap?['id'] as int?,
          created: data['status'] == 'created',
        );
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        return ApiSyncResult(
          success: false,
          errorMessage: errorData?['error'] ?? 'Server responded with status: ${response.statusCode}',
          );
      }
    } catch (e) {
      debugPrint('ApiService syncUser Critical Failure Encountered: $e');
      return ApiSyncResult(
        success: false,
        errorMessage: 'Network exception occurred: ${e.toString()}',
      );
    }
  }
}