import 'dart:convert';

/// Standard JSON error envelope returned by API routes.
class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  Map<String, dynamic> toJson() => {
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
      };

  String toJsonString() => jsonEncode(toJson());
}
