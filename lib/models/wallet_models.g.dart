// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Wallet _$WalletFromJson(Map<String, dynamic> json) => Wallet(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  balances: json['balances'] as Map<String, dynamic>,
  totalEarned: (json['total_earned'] as num).toDouble(),
  totalWithdrawn: (json['total_withdrawn'] as num).toDouble(),
  currency: json['currency'] as String? ?? 'SDG',
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$WalletToJson(Wallet instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'balances': instance.balances,
  'total_earned': instance.totalEarned,
  'total_withdrawn': instance.totalWithdrawn,
  'currency': instance.currency,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) =>
    WalletTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      amountCents: (json['amount_cents'] as num?)?.toInt(),
      currency: json['currency'] as String? ?? 'SDG',
      siteVisitId: json['site_visit_id'] as String?,
      withdrawalRequestId: json['withdrawal_request_id'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      balanceBefore: (json['balance_before'] as num?)?.toDouble(),
      balanceAfter: (json['balance_after'] as num?)?.toDouble(),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$WalletTransactionToJson(WalletTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wallet_id': instance.walletId,
      'user_id': instance.userId,
      'type': instance.type,
      'amount': instance.amount,
      'amount_cents': instance.amountCents,
      'currency': instance.currency,
      'site_visit_id': instance.siteVisitId,
      'withdrawal_request_id': instance.withdrawalRequestId,
      'description': instance.description,
      'metadata': instance.metadata,
      'balance_before': instance.balanceBefore,
      'balance_after': instance.balanceAfter,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
    };

WithdrawalRequest _$WithdrawalRequestFromJson(Map<String, dynamic> json) =>
    WithdrawalRequest(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SDG',
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at'] as String),
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$WithdrawalRequestToJson(WithdrawalRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wallet_id': instance.walletId,
      'user_id': instance.userId,
      'amount': instance.amount,
      'currency': instance.currency,
      'status': instance.status,
      'requested_at': instance.requestedAt.toIso8601String(),
      'processed_at': instance.processedAt?.toIso8601String(),
      'reason': instance.reason,
    };

SiteVisitCost _$SiteVisitCostFromJson(Map<String, dynamic> json) =>
    SiteVisitCost(
      id: json['id'] as String,
      siteVisitId: json['site_visit_id'] as String,
      cost: (json['cost'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SDG',
      type: json['type'] as String? ?? 'field_operation',
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SiteVisitCostToJson(SiteVisitCost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'site_visit_id': instance.siteVisitId,
      'cost': instance.cost,
      'currency': instance.currency,
      'type': instance.type,
      'created_at': instance.createdAt.toIso8601String(),
    };

WalletStats _$WalletStatsFromJson(Map<String, dynamic> json) => WalletStats(
  totalEarned: (json['totalEarned'] as num).toDouble(),
  totalWithdrawn: (json['totalWithdrawn'] as num).toDouble(),
  pendingWithdrawals: (json['pendingWithdrawals'] as num?)?.toInt() ?? 0,
  currentBalance: (json['currentBalance'] as num).toDouble(),
  totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
  completedSiteVisits: (json['completedSiteVisits'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WalletStatsToJson(WalletStats instance) =>
    <String, dynamic>{
      'totalEarned': instance.totalEarned,
      'totalWithdrawn': instance.totalWithdrawn,
      'pendingWithdrawals': instance.pendingWithdrawals,
      'currentBalance': instance.currentBalance,
      'totalTransactions': instance.totalTransactions,
      'completedSiteVisits': instance.completedSiteVisits,
    };
