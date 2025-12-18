// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'down_payment_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DownPaymentRequestImpl _$$DownPaymentRequestImplFromJson(
  Map<String, dynamic> json,
) => _$DownPaymentRequestImpl(
  id: json['id'] as String,
  siteVisitId: json['siteVisitId'] as String,
  mmpSiteEntryId: json['mmpSiteEntryId'] as String? ?? '',
  siteName: json['siteName'] as String? ?? '',
  requestedBy: json['requestedBy'] as String,
  requestedAt: DateTime.parse(json['requestedAt'] as String),
  requesterRole: json['requesterRole'] as String,
  hubId: json['hubId'] as String?,
  hubName: json['hubName'] as String?,
  totalTransportationBudget:
      (json['totalTransportationBudget'] as num?)?.toDouble() ?? 0.0,
  requestedAmount: (json['requestedAmount'] as num?)?.toDouble() ?? 0.0,
  paymentType: json['paymentType'] as String? ?? 'full_advance',
  installmentPlan:
      (json['installmentPlan'] as List<dynamic>?)
          ?.map((e) => InstallmentPlan.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  paidInstallments:
      (json['paidInstallments'] as List<dynamic>?)
          ?.map((e) => PaidInstallment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  justification: json['justification'] as String? ?? '',
  supportingDocuments:
      (json['supportingDocuments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  supervisorId: json['supervisorId'] as String?,
  supervisorStatus: json['supervisorStatus'] as String?,
  supervisorApprovedBy: json['supervisorApprovedBy'] as String?,
  supervisorApprovedAt: json['supervisorApprovedAt'] == null
      ? null
      : DateTime.parse(json['supervisorApprovedAt'] as String),
  supervisorNotes: json['supervisorNotes'] as String?,
  supervisorRejectionReason: json['supervisorRejectionReason'] as String?,
  adminStatus: json['adminStatus'] as String?,
  adminProcessedBy: json['adminProcessedBy'] as String?,
  adminProcessedAt: json['adminProcessedAt'] == null
      ? null
      : DateTime.parse(json['adminProcessedAt'] as String),
  adminNotes: json['adminNotes'] as String?,
  adminRejectionReason: json['adminRejectionReason'] as String?,
  status: json['status'] as String? ?? 'pending_supervisor',
  totalPaidAmount: (json['totalPaidAmount'] as num?)?.toDouble() ?? 0.0,
  remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
  walletTransactionIds:
      (json['walletTransactionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  metadata:
      json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{},
);

Map<String, dynamic> _$$DownPaymentRequestImplToJson(
  _$DownPaymentRequestImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'siteVisitId': instance.siteVisitId,
  'mmpSiteEntryId': instance.mmpSiteEntryId,
  'siteName': instance.siteName,
  'requestedBy': instance.requestedBy,
  'requestedAt': instance.requestedAt.toIso8601String(),
  'requesterRole': instance.requesterRole,
  'hubId': instance.hubId,
  'hubName': instance.hubName,
  'totalTransportationBudget': instance.totalTransportationBudget,
  'requestedAmount': instance.requestedAmount,
  'paymentType': instance.paymentType,
  'installmentPlan': instance.installmentPlan,
  'paidInstallments': instance.paidInstallments,
  'justification': instance.justification,
  'supportingDocuments': instance.supportingDocuments,
  'supervisorId': instance.supervisorId,
  'supervisorStatus': instance.supervisorStatus,
  'supervisorApprovedBy': instance.supervisorApprovedBy,
  'supervisorApprovedAt': instance.supervisorApprovedAt?.toIso8601String(),
  'supervisorNotes': instance.supervisorNotes,
  'supervisorRejectionReason': instance.supervisorRejectionReason,
  'adminStatus': instance.adminStatus,
  'adminProcessedBy': instance.adminProcessedBy,
  'adminProcessedAt': instance.adminProcessedAt?.toIso8601String(),
  'adminNotes': instance.adminNotes,
  'adminRejectionReason': instance.adminRejectionReason,
  'status': instance.status,
  'totalPaidAmount': instance.totalPaidAmount,
  'remainingAmount': instance.remainingAmount,
  'walletTransactionIds': instance.walletTransactionIds,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'metadata': instance.metadata,
};

_$InstallmentPlanImpl _$$InstallmentPlanImplFromJson(
  Map<String, dynamic> json,
) => _$InstallmentPlanImpl(
  installmentNumber: (json['installmentNumber'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  dueDate: DateTime.parse(json['dueDate'] as String),
  description: json['description'] as String,
);

Map<String, dynamic> _$$InstallmentPlanImplToJson(
  _$InstallmentPlanImpl instance,
) => <String, dynamic>{
  'installmentNumber': instance.installmentNumber,
  'amount': instance.amount,
  'dueDate': instance.dueDate.toIso8601String(),
  'description': instance.description,
};

_$PaidInstallmentImpl _$$PaidInstallmentImplFromJson(
  Map<String, dynamic> json,
) => _$PaidInstallmentImpl(
  installmentNumber: (json['installmentNumber'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  paidAt: DateTime.parse(json['paidAt'] as String),
  transactionId: json['transactionId'] as String,
);

Map<String, dynamic> _$$PaidInstallmentImplToJson(
  _$PaidInstallmentImpl instance,
) => <String, dynamic>{
  'installmentNumber': instance.installmentNumber,
  'amount': instance.amount,
  'paidAt': instance.paidAt.toIso8601String(),
  'transactionId': instance.transactionId,
};
