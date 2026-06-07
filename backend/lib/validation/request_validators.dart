/// Shared request-body validation helpers for API routes.
class RequestValidators {
  RequestValidators._();

  static const _emailPattern = r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
  static const _azureUserIdMaxLength = 255;
  static const _accountNameMaxLength = 200;

  static const validAccountTypeCodes = <String>{
    'cash',
    'traditional_bank',
    'digital_bank',
    'credit_card',
    'bnpl',
    'savings',
  };

  static String? validateAzureUserId(dynamic value) {
    if (value == null) {
      return 'azure_user_id is required';
    }
    if (value is! String) {
      return 'azure_user_id must be a string';
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'azure_user_id cannot be empty';
    }
    if (trimmed.length > _azureUserIdMaxLength) {
      return 'azure_user_id exceeds maximum length of $_azureUserIdMaxLength';
    }
    return null;
  }

  static String? validateEmail(dynamic value) {
    if (value == null) {
      return 'email is required';
    }
    if (value is! String) {
      return 'email must be a string';
    }
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'email cannot be empty';
    }
    if (!RegExp(_emailPattern).hasMatch(trimmed)) {
      return 'email format is invalid';
    }
    return null;
  }

  static String? validateAccountTypeCode(dynamic value) {
    if (value == null) {
      return 'account_type is required';
    }
    if (value is! String) {
      return 'account_type must be a string';
    }
    final normalized = value.trim().toLowerCase();
    if (!validAccountTypeCodes.contains(normalized)) {
      return 'account_type must be one of: ${validAccountTypeCodes.join(', ')}';
    }
    return null;
  }

  static String? validateAccountName(dynamic value) {
    if (value == null) {
      return 'name is required';
    }
    if (value is! String) {
      return 'name must be a string';
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'name cannot be empty';
    }
    if (trimmed.length > _accountNameMaxLength) {
      return 'name exceeds maximum length of $_accountNameMaxLength';
    }
    return null;
  }

  static String? validateBalance(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! num) {
      return 'balance must be a number';
    }
    final balance = value.toDouble();
    if (balance < -999999999999.99 || balance > 999999999999.99) {
      return 'balance is out of allowed range';
    }
    return null;
  }

  static String? validateCurrencyCode(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      return 'currency_code must be a string';
    }
    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(trimmed)) {
      return 'currency_code must be a 3-letter ISO code';
    }
    return null;
  }
}
