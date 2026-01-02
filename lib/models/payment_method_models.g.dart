// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePaymentMethodRequest _$CreatePaymentMethodRequestFromJson(
        Map<String, dynamic> json) =>
    CreatePaymentMethodRequest(
      type: $enumDecode(_$PaymentTypeEnumMap, json['type']),
      name: json['name'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      phoneNumber: json['phone_number'] as String?,
      cardNumber: json['card_number'] as String?,
    );

Map<String, dynamic> _$CreatePaymentMethodRequestToJson(
        CreatePaymentMethodRequest instance) =>
    <String, dynamic>{
      'type': _$PaymentTypeEnumMap[instance.type]!,
      'name': instance.name,
      'bank_name': instance.bankName,
      'account_number': instance.accountNumber,
      'phone_number': instance.phoneNumber,
      'card_number': instance.cardNumber,
    };

const _$PaymentTypeEnumMap = {
  PaymentType.bank: 'bank',
  PaymentType.mobileMoney: 'mobile_money',
  PaymentType.card: 'card',
};
