// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    PaymentMethod(
      id: json['id'] as String,
      type: $enumDecode(_$PaymentTypeEnumMap, json['type']),
      name: json['name'] as String,
      details: json['details'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      providerName: json['provider_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      cardholderName: json['cardholder_name'] as String?,
      cardNumber: json['card_number'] as String?,
      cardLastFour: json['card_last_four'] as String?,
    );

Map<String, dynamic> _$PaymentMethodToJson(PaymentMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$PaymentTypeEnumMap[instance.type]!,
      'name': instance.name,
      'details': instance.details,
      'is_default': instance.isDefault,
      'user_id': instance.userId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'bank_name': instance.bankName,
      'account_number': instance.accountNumber,
      'provider_name': instance.providerName,
      'phone_number': instance.phoneNumber,
      'cardholder_name': instance.cardholderName,
      'card_number': instance.cardNumber,
      'card_last_four': instance.cardLastFour,
    };

const _$PaymentTypeEnumMap = {
  PaymentType.bank: 'bank',
  PaymentType.mobileMoney: 'mobile_money',
  PaymentType.card: 'card',
};

CreatePaymentMethodRequest _$CreatePaymentMethodRequestFromJson(
  Map<String, dynamic> json,
) => CreatePaymentMethodRequest(
  type: $enumDecode(_$PaymentTypeEnumMap, json['type']),
  bankName: json['bank_name'] as String?,
  accountNumber: json['account_number'] as String?,
  providerName: json['provider_name'] as String?,
  phoneNumber: json['phone_number'] as String?,
  cardholderName: json['cardholder_name'] as String?,
  cardNumber: json['card_number'] as String?,
);

Map<String, dynamic> _$CreatePaymentMethodRequestToJson(
  CreatePaymentMethodRequest instance,
) => <String, dynamic>{
  'type': _$PaymentTypeEnumMap[instance.type]!,
  'bank_name': instance.bankName,
  'account_number': instance.accountNumber,
  'provider_name': instance.providerName,
  'phone_number': instance.phoneNumber,
  'cardholder_name': instance.cardholderName,
  'card_number': instance.cardNumber,
};
