import 'package:freezed_annotation/freezed_annotation.dart';

part 'down_payment_request.freezed.dart';
part 'down_payment_request.g.dart';

@freezed
class DownPaymentRequest with _$DownPaymentRequest {
  const factory DownPaymentRequest({
    required String id,
    required String siteVisitId,
    @Default('') String mmpSiteEntryId,
    @Default('') String siteName,
    required String requestedBy,
    required DateTime requestedAt,
    required String requesterRole,
    String? hubId,
    String? hubName,
    @Default(0.0) double totalTransportationBudget,
    @Default(0.0) double requestedAmount,
    @Default('full_advance') String paymentType,
    @Default([]) List<InstallmentPlan> installmentPlan,
    @Default([]) List<PaidInstallment> paidInstallments,
    @Default('') String justification,
    @Default([]) List<String> supportingDocuments,
    String? supervisorId,
    String? supervisorStatus,
    String? supervisorApprovedBy,
    DateTime? supervisorApprovedAt,
    String? supervisorNotes,
    String? supervisorRejectionReason,
    String? adminStatus,
    String? adminProcessedBy,
    DateTime? adminProcessedAt,
    String? adminNotes,
    String? adminRejectionReason,
    @Default('pending_supervisor') String status,
    @Default(0.0) double totalPaidAmount,
    double? remainingAmount,
    @Default(const <String>[]) List<String> walletTransactionIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(const <String, dynamic>{}) Map<String, dynamic> metadata,
  }) = _DownPaymentRequest;

  factory DownPaymentRequest.fromJson(Map<String, dynamic> json) =>
      _$DownPaymentRequestFromJson(json);
}

@freezed
class InstallmentPlan with _$InstallmentPlan {
  const factory InstallmentPlan({
    required int installmentNumber,
    required double amount,
    required DateTime dueDate,
    required String description,
  }) = _InstallmentPlan;

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) =>
      _$InstallmentPlanFromJson(json);
}

@freezed
class PaidInstallment with _$PaidInstallment {
  const factory PaidInstallment({
    required int installmentNumber,
    required double amount,
    required DateTime paidAt,
    required String transactionId,
  }) = _PaidInstallment;

  factory PaidInstallment.fromJson(Map<String, dynamic> json) =>
      _$PaidInstallmentFromJson(json);
}

enum DownPaymentStatus {
  pendingSupervisor('pending_supervisor'),
  pendingAdmin('pending_admin'),
  approved('approved'),
  rejected('rejected'),
  partiallyPaid('partially_paid'),
  fullyPaid('fully_paid'),
  cancelled('cancelled');

  const DownPaymentStatus(this.value);
  final String value;

  static DownPaymentStatus fromString(String value) {
    return DownPaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DownPaymentStatus.pendingSupervisor,
    );
  }
}

enum SupervisorStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  changesRequested('changes_requested');

  const SupervisorStatus(this.value);
  final String value;

  static SupervisorStatus fromString(String value) {
    return SupervisorStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SupervisorStatus.pending,
    );
  }
}

enum AdminStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const AdminStatus(this.value);
  final String value;

  static AdminStatus fromString(String value) {
    return AdminStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AdminStatus.pending,
    );
  }
}