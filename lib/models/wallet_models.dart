import 'package:json_annotation/json_annotation.dart';

part 'wallet_models.g.dart';

@JsonSerializable()
class Wallet {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final Map<String, dynamic> balances;
  @JsonKey(name: 'total_earned')
  final double totalEarned;
  @JsonKey(name: 'total_withdrawn')
  final double totalWithdrawn;
  final String currency;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Wallet({
    required this.id,
    required this.userId,
    required this.balances,
    required this.totalEarned,
    required this.totalWithdrawn,
    this.currency = 'SDG',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
  Map<String, dynamic> toJson() => _$WalletToJson(this);

  double get currentBalance {
    final sdgBalance = balances['SDG'];
    if (sdgBalance is num) {
      return sdgBalance.toDouble();
    }
    return 0.0;
  }

  Wallet copyWith({
    String? id,
    String? userId,
    Map<String, dynamic>? balances,
    double? totalEarned,
    double? totalWithdrawn,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balances: balances ?? this.balances,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@JsonSerializable()
class WalletTransaction {
  final String id;
  @JsonKey(name: 'wallet_id')
  final String walletId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String type;
  final double amount;
  @JsonKey(name: 'amount_cents')
  final int? amountCents;
  final String currency;
  @JsonKey(name: 'site_visit_id')
  final String? siteVisitId;
  @JsonKey(name: 'withdrawal_request_id')
  final String? withdrawalRequestId;
  final String? description;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'balance_before')
  final double? balanceBefore;
  @JsonKey(name: 'balance_after')
  final double? balanceAfter;
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.type,
    required this.amount,
    this.amountCents,
    this.currency = 'SDG',
    this.siteVisitId,
    this.withdrawalRequestId,
    this.description,
    this.metadata,
    this.balanceBefore,
    this.balanceAfter,
    this.createdBy,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$WalletTransactionToJson(this);

  String get typeLabel {
    switch (type) {
      case 'earning':
        return 'Earning';
      case 'site_visit_fee':
        return 'Site Visit Fee';
      case 'withdrawal':
        return 'Withdrawal';
      case 'adjustment':
        return 'Adjustment';
      case 'bonus':
        return 'Bonus';
      case 'penalty':
        return 'Penalty';
      default:
        return type;
    }
  }

  bool get isCredit => ['earning', 'site_visit_fee', 'bonus', 'adjustment'].contains(type) && amount > 0;
}

@JsonSerializable()
class WithdrawalRequest {
  final String id;
  @JsonKey(name: 'wallet_id')
  final String walletId;
  @JsonKey(name: 'user_id')
  final String userId;
  final double amount;
  final String currency;
  final String status; // pending, supervisor_approved, processing, approved, rejected, cancelled
  @JsonKey(name: 'requested_at')
  final DateTime requestedAt;
  @JsonKey(name: 'processed_at')
  final DateTime? processedAt;
  final String? reason;
  
  // Supervisor approval (first step)
  @JsonKey(name: 'supervisor_id')
  final String? supervisorId;
  @JsonKey(name: 'supervisor_notes')
  final String? supervisorNotes;
  @JsonKey(name: 'supervisor_approved_at')
  final DateTime? supervisorApprovedAt;
  
  // Admin processing (second step)
  @JsonKey(name: 'admin_processed_by')
  final String? adminProcessedBy;
  @JsonKey(name: 'admin_processed_at')
  final DateTime? adminProcessedAt;
  @JsonKey(name: 'admin_notes')
  final String? adminNotes;
  
  // Offline deduplication
  @JsonKey(name: 'reference_id')
  final String? referenceId;

  WithdrawalRequest({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.amount,
    this.currency = 'SDG',
    this.status = 'pending',
    required this.requestedAt,
    this.processedAt,
    this.reason,
    this.supervisorId,
    this.supervisorNotes,
    this.supervisorApprovedAt,
    this.adminProcessedBy,
    this.adminProcessedAt,
    this.adminNotes,
    this.referenceId,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      _$WithdrawalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WithdrawalRequestToJson(this);
  
  // Helper getters
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending Supervisor';
      case 'supervisor_approved':
        return 'Awaiting Admin';
      case 'processing':
        return 'Processing';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  bool get canCancel => status == 'pending';
  bool get needsSupervisorApproval => status == 'pending';
  bool get needsAdminProcessing => status == 'supervisor_approved';
  bool get isSettled => ['approved', 'rejected', 'cancelled'].contains(status);
}

@JsonSerializable()
class SiteVisitCost {
  final String id;
  @JsonKey(name: 'site_visit_id')
  final String siteVisitId;
  final double cost;
  final String currency;
  final String type;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  SiteVisitCost({
    required this.id,
    required this.siteVisitId,
    required this.cost,
    this.currency = 'SDG',
    this.type = 'field_operation',
    required this.createdAt,
  });

  factory SiteVisitCost.fromJson(Map<String, dynamic> json) =>
      _$SiteVisitCostFromJson(json);
  Map<String, dynamic> toJson() => _$SiteVisitCostToJson(this);
}

@JsonSerializable()
class WalletStats {
  final double totalEarned;
  final double totalWithdrawn;
  final int pendingWithdrawals;
  final double currentBalance;
  final int totalTransactions;
  final int completedSiteVisits;

  WalletStats({
    required this.totalEarned,
    required this.totalWithdrawn,
    this.pendingWithdrawals = 0,
    required this.currentBalance,
    this.totalTransactions = 0,
    this.completedSiteVisits = 0,
  });

  factory WalletStats.fromJson(Map<String, dynamic> json) =>
      _$WalletStatsFromJson(json);
  Map<String, dynamic> toJson() => _$WalletStatsToJson(this);

  double get approvalRate {
    if (totalTransactions == 0) return 0;
    return (totalEarned / (totalEarned + totalWithdrawn)) * 100;
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});

  factory ValidationResult.valid() => ValidationResult(isValid: true);
  factory ValidationResult.invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}
