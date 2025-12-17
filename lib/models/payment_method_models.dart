import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_method_models.g.dart';

/// Enum for payment types
enum PaymentType {
  bank,
  @JsonValue('mobile_money')
  mobileMoney,
  card;

  String get displayName {
    switch (this) {
      case PaymentType.bank:
        return 'Bank Transfer';
      case PaymentType.mobileMoney:
        return 'Mobile Money';
      case PaymentType.card:
        return 'Debit/Credit Card';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentType.bank:
        return Icons.account_balance;
      case PaymentType.mobileMoney:
        return Icons.phone_android;
      case PaymentType.card:
        return Icons.credit_card;
    }
  }
}

/// Payment method model
@JsonSerializable()
class PaymentMethod {
  final String id;
  final PaymentType type;
  final String name; // Bank name, provider name, or cardholder name
  final String details; // e.g., "Account: ***4532"
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Bank-specific fields
  @JsonKey(name: 'bank_name')
  final String? bankName;
  @JsonKey(name: 'account_number')
  final String? accountNumber;

  // Mobile money specific fields
  @JsonKey(name: 'provider_name')
  final String? providerName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;

  // Card specific fields
  @JsonKey(name: 'cardholder_name')
  final String? cardholderName;
  @JsonKey(name: 'card_number')
  final String? cardNumber;
  @JsonKey(name: 'card_last_four')
  final String? cardLastFour;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.details,
    this.isDefault = false,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    this.bankName,
    this.accountNumber,
    this.providerName,
    this.phoneNumber,
    this.cardholderName,
    this.cardNumber,
    this.cardLastFour,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentMethodToJson(this);

  /// Get masked details string
  String get maskedDetails {
    switch (type) {
      case PaymentType.bank:
        return 'Account: ***${accountNumber?.substring(accountNumber!.length - 4)}';
      case PaymentType.mobileMoney:
        return 'Phone: ***${phoneNumber?.substring(phoneNumber!.length - 4)}';
      case PaymentType.card:
        return 'Card: ****${cardLastFour ?? cardNumber?.substring(cardNumber!.length - 4)}';
    }
  }

  PaymentMethod copyWith({
    String? id,
    PaymentType? type,
    String? name,
    String? details,
    bool? isDefault,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bankName,
    String? accountNumber,
    String? providerName,
    String? phoneNumber,
    String? cardholderName,
    String? cardNumber,
    String? cardLastFour,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      details: details ?? this.details,
      isDefault: isDefault ?? this.isDefault,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      providerName: providerName ?? this.providerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cardholderName: cardholderName ?? this.cardholderName,
      cardNumber: cardNumber ?? this.cardNumber,
      cardLastFour: cardLastFour ?? this.cardLastFour,
    );
  }
}

/// Request model for creating a payment method
@JsonSerializable()
class CreatePaymentMethodRequest {
  final PaymentType type;
  @JsonKey(name: 'bank_name')
  final String? bankName;
  @JsonKey(name: 'account_number')
  final String? accountNumber;
  @JsonKey(name: 'provider_name')
  final String? providerName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'cardholder_name')
  final String? cardholderName;
  @JsonKey(name: 'card_number')
  final String? cardNumber;

  CreatePaymentMethodRequest({
    required this.type,
    this.bankName,
    this.accountNumber,
    this.providerName,
    this.phoneNumber,
    this.cardholderName,
    this.cardNumber,
  });

  factory CreatePaymentMethodRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePaymentMethodRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePaymentMethodRequestToJson(this);
}

/// Validation result for payment method
class PaymentMethodValidationResult {
  final bool isValid;
  final String? error;
  final List<String> warnings;

  PaymentMethodValidationResult({
    required this.isValid,
    this.error,
    this.warnings = const [],
  });
}

/// Exception for payment method operations
class PaymentMethodException implements Exception {
  final String message;
  final String? code;

  PaymentMethodException(this.message, {this.code});

  @override
  String toString() => 'PaymentMethodException: $message';
}
