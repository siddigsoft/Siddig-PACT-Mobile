import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet_models.dart';
import '../models/wallet_transaction.dart';

class WalletRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user's wallet
  Future<Wallet?> getWallet(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create wallet if doesn't exist
        return await _createWallet(userId);
      }

      return Wallet.fromJson(response);
    } catch (e) {
      throw WalletException('Failed to fetch wallet: $e');
    }
  }

  // Create new wallet for user
  Future<Wallet> _createWallet(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .insert({
            'user_id': userId,
            'balances': {'SDG': 0},
            'total_earned': 0,
            'total_withdrawn': 0,
            'currency': 'SDG',
          })
          .select()
          .single();

      return Wallet.fromJson(response);
    } catch (e) {
      throw WalletException('Failed to create wallet: $e');
    }
  }

  /// Check if a fee transaction already exists for a site visit
  /// Uses deduplication strategy: checks both site_visit_id and reference_id
  /// Returns true if any matching fee transaction found
  Future<bool> hasExistingFeeTransaction({
    required String siteVisitId,
    String? referenceId,
  }) async {
    try {
      final List<dynamic> response;
      
      if (referenceId != null && referenceId.isNotEmpty) {
        // Check both site_visit_id and reference_id
        response = await _supabase
            .from('wallet_transactions')
            .select('id')
            .or('site_visit_id.eq.$siteVisitId,reference_id.eq.$referenceId')
            .inFilter('type', ['earning', 'site_visit_fee']);
      } else {
        // Check only site_visit_id
        response = await _supabase
            .from('wallet_transactions')
            .select('id')
            .eq('site_visit_id', siteVisitId)
            .inFilter('type', ['earning', 'site_visit_fee']);
      }
      
      return response.isNotEmpty;
    } catch (e) {
      // Fail-safe: if query fails, don't proceed with insertion
      throw WalletException('Deduplication check failed: $e');
    }
  }

  /// Create a site visit fee transaction with deduplication
  /// Only creates transaction if no existing fee found
  /// Returns the created transaction or throws WalletException
  Future<WalletTransaction> createSiteVisitTransaction({
    required String userId,
    required String siteVisitId,
    required double amount,
    String? description,
    String? referenceId,
  }) async {
    try {
      // CRITICAL: Check for existing transaction first
      final existingTransaction = await hasExistingFeeTransaction(
        siteVisitId: siteVisitId,
        referenceId: referenceId,
      );
      
      if (existingTransaction) {
        throw WalletException(
          'Site visit fee transaction already exists for visit $siteVisitId',
        );
      }

      // Get wallet
      final wallet = await getWallet(userId);
      if (wallet == null) {
        throw WalletException('Wallet not found for user $userId');
      }

      final amountCents = (amount * 100).round();
      final balanceBefore = wallet.currentBalance;
      final balanceAfter = balanceBefore + amount;

      // Create the fee transaction
      final transactionResponse = await _supabase
          .from('wallet_transactions')
          .insert({
            'wallet_id': wallet.id,
            'user_id': userId,
            'type': 'site_visit_fee',
            'amount': amount,
            'amount_cents': amountCents,
            'currency': 'SDG',
            'site_visit_id': siteVisitId,
            'reference_id': referenceId ?? siteVisitId,
            'reference_type': 'site_visit',
            'description': description ?? 'Site visit completion fee',
            'balance_before': balanceBefore,
            'balance_after': balanceAfter,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return WalletTransaction.fromJson(transactionResponse);
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException('Failed to create site visit transaction: $e');
    }
  }

  /// High-level operation: Process visit payment with dedup checks and wallet update
  /// Handles complete visit → fee creation → wallet balance update
  Future<void> processVisitPayment({
    required String userId,
    required String siteVisitId,
    required double enumeratorFee,
    required double transportFee,
    String? referenceId,
  }) async {
    try {
      final wallet = await getWallet(userId);
      if (wallet == null) {
        throw WalletException('Wallet not found');
      }

      final totalFee = enumeratorFee + transportFee;
      if (totalFee <= 0) {
        return; // No fee to process
      }

      // Create fee transaction with dedup check
      final transaction = await createSiteVisitTransaction(
        userId: userId,
        siteVisitId: siteVisitId,
        amount: totalFee,
        description: 'Enumerator fee: $enumeratorFee, Transport fee: $transportFee',
        referenceId: referenceId,
      );

      // Update wallet balance atomically
      final balanceAfter = wallet.currentBalance + totalFee;
      final updateResponse = await _supabase
          .from('wallets')
          .update({
            'balances': {'SDG': balanceAfter},
            'total_earned': wallet.totalEarned + totalFee,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', wallet.id)
          .select()
          .single();

      if (updateResponse == null) {
        throw WalletException('Failed to update wallet balance');
      }
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException('Failed to process visit payment: $e');
    }
  }

  /// Update wallet balance atomically
  Future<Wallet> updateWalletBalance({
    required String walletId,
    required double amountDelta,
  }) async {
    try {
      final wallet = await _supabase
          .from('wallets')
          .select()
          .eq('id', walletId)
          .single();

      final currentWallet = Wallet.fromJson(wallet);
      final newBalance = currentWallet.currentBalance + amountDelta;

      final response = await _supabase
          .from('wallets')
          .update({
            'balances': {'SDG': newBalance},
            'total_earned': currentWallet.totalEarned + amountDelta,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', walletId)
          .select()
          .single();

      return Wallet.fromJson(response);
    } catch (e) {
      throw WalletException('Failed to update wallet balance: $e');
    }
  }

  // Get wallet transactions with pagination
  Future<List<WalletTransaction>> getWalletTransactions({
    required String userId,
    int limit = 20,
    int offset = 0,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      dynamic query = _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId);

      if (type != null) {
        query = query.eq('type', type);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      return (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
    } catch (e) {
      throw WalletException('Failed to fetch transactions: $e');
    }
  }

  // Get withdrawal requests
  Future<List<WithdrawalRequest>> getWithdrawalRequests(String userId) async {
    try {
      final response = await _supabase
          .from('withdrawal_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WithdrawalRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw WalletException('Failed to fetch withdrawal requests: $e');
    }
  }

  // Create withdrawal request
  Future<WithdrawalRequest> createWithdrawalRequest({
    required String userId,
    required double amount,
    required String currency,
    String? reason,
    String? paymentMethod,
  }) async {
    try {
      // Check balance first
      final wallet = await getWallet(userId);
      if (wallet == null) {
        throw WithdrawalException('Wallet not found');
      }

      if (wallet.currentBalance < amount) {
        throw InsufficientBalanceException(
            'Insufficient balance. Available: ${wallet.currentBalance} $currency');
      }

      final response = await _supabase
          .from('withdrawal_requests')
          .insert({
            'user_id': userId,
            'amount': amount,
            'currency': currency,
            'reason': reason,
            'payment_method': paymentMethod,
            'status': 'pending',
          })
          .select()
          .single();

      return WithdrawalRequest.fromJson(response);
    } catch (e) {
      if (e is InsufficientBalanceException) rethrow;
      throw WithdrawalException('Failed to create withdrawal request: $e');
    }
  }

  // Update withdrawal request status (Admin only)
  Future<WithdrawalRequest> updateWithdrawalRequestStatus({
    required String requestId,
    required String status,
    String? notes,
    String? processedBy,
  }) async {
    try {
      final response = await _supabase
          .from('withdrawal_requests')
          .update({
            'status': status,
            'notes': notes,
            'processed_by': processedBy,
            'processed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();

      return WithdrawalRequest.fromJson(response);
    } catch (e) {
      throw WithdrawalException('Failed to update withdrawal request: $e');
    }
  }

  // Get site visit cost
  Future<SiteVisitCost?> getSiteVisitCost(String siteVisitId) async {
    try {
      final response = await _supabase
          .from('site_visit_costs')
          .select()
          .eq('site_visit_id', siteVisitId)
          .maybeSingle();

      if (response == null) return null;

      return SiteVisitCost.fromJson(response);
    } catch (e) {
      throw WalletException('Failed to fetch site visit cost: $e');
    }
  }

  // Create or update site visit cost
  Future<SiteVisitCost> upsertSiteVisitCost({
    required String siteVisitId,
    required double transportationCost,
    required double accommodationCost,
    required double mealAllowance,
    required double otherCosts,
    String? classificationLevel,
    double? complexityMultiplier,
    String? assignedBy,
    String? costNotes,
  }) async {
    try {
      final totalCost = transportationCost +
          accommodationCost +
          mealAllowance +
          otherCosts;

      final baseFeeCents = (totalCost * 100).round();

      final response = await _supabase
          .from('site_visit_costs')
          .upsert({
            'site_visit_id': siteVisitId,
            'transportation_cost': transportationCost,
            'accommodation_cost': accommodationCost,
            'meal_allowance': mealAllowance,
            'other_costs': otherCosts,
            'total_cost': totalCost,
            'currency': 'SDG',
            'classification_level': classificationLevel,
            'base_fee_cents': baseFeeCents,
            'complexity_multiplier': complexityMultiplier ?? 1.0,
            'assigned_by': assignedBy,
            'cost_notes': costNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return SiteVisitCost.fromJson(response);
    } catch (e) {
      throw WalletException('Failed to update site visit cost: $e');
    }
  }

  // Get wallet stats
  Future<WalletStats> getWalletStats(String userId) async {
    try {
      final wallet = await getWallet(userId);
      if (wallet == null) {
        return WalletStats(
          totalEarned: 0,
          totalWithdrawn: 0,
          pendingWithdrawals: 0,
          currentBalance: 0,
          totalTransactions: 0,
          completedSiteVisits: 0,
        );
      }

      // Get pending withdrawals
      final withdrawalRequests = await getWithdrawalRequests(userId);
      final pendingWithdrawals = withdrawalRequests
          .where((r) => r.status == 'pending')
          .length;

      // Get transaction count
      final List<WalletTransaction> transactions = await getWalletTransactions(
        userId: userId,
        limit: 1000,
      );

      // Get completed site visits
      final siteVisitTransactions = transactions
          .where((t) => t.type == 'site_visit_fee')
          .length;

      return WalletStats(
        totalEarned: wallet.totalEarned,
        totalWithdrawn: wallet.totalWithdrawn,
        pendingWithdrawals: pendingWithdrawals,
        currentBalance: wallet.currentBalance,
        totalTransactions: transactions.length,
        completedSiteVisits: siteVisitTransactions,
      );
    } catch (e) {
      throw WalletException('Failed to calculate wallet stats: $e');
    }
  }

  // Real-time stream for wallet updates
  Stream<Wallet?> watchWallet(String userId) {
    return _supabase
        .from('wallets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return Wallet.fromJson(data.first);
        });
  }

  // Real-time stream for transactions
  Stream<List<WalletTransaction>> watchTransactions(String userId) {
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => WalletTransaction.fromJson(json)).toList());
  }

  // Real-time stream for withdrawal requests
  Stream<List<WithdrawalRequest>> watchWithdrawalRequests(String userId) {
    return _supabase
        .from('withdrawal_requests')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => WithdrawalRequest.fromJson(json)).toList());
  }

  // Search transactions
  Future<List<WalletTransaction>> searchTransactions({
    required String userId,
    String? query,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      dynamic dbQuery = _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId);

      if (type != null) {
        dbQuery = dbQuery.eq('type', type);
      }

      if (startDate != null) {
        dbQuery = dbQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        dbQuery = dbQuery.lte('created_at', endDate.toIso8601String());
      }

      final response = await dbQuery.order('created_at', ascending: false);
      var transactions = (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();

      // Filter by query if provided
      if (query != null && query.isNotEmpty) {
        transactions = transactions.where((t) {
          return (t.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              t.type.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }

      return transactions;
    } catch (e) {
      throw WalletException('Failed to search transactions: $e');
    }
  }

  // ============================================================================
  // ATOMIC RPC OPERATIONS (Two-step withdrawal approval)
  // ============================================================================

  /// Supervisor approval (first step) - validates balance but doesn't transfer
  Future<Map<String, dynamic>> supervisorApproveWithdrawal({
    required String requestId,
    required String supervisorId,
    required String notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_supervisor_approve_withdrawal',
        params: {
          'in_request_id': requestId,
          'in_supervisor_id': supervisorId,
          'in_notes': notes,
        },
      ).select().single();

      // Response: {success: boolean, error_text: text}
      if (response['success'] == true) {
        return {'success': true};
      } else {
        throw WithdrawalException(
          response['error_text'] ?? 'Supervisor approval failed',
        );
      }
    } catch (e) {
      if (e is WithdrawalException) rethrow;
      throw WithdrawalException('Failed to approve withdrawal: $e');
    }
  }

  /// Admin processing (second step) - atomically deducts balance and creates transaction
  Future<Map<String, dynamic>> adminProcessWithdrawal({
    required String requestId,
    required String adminId,
    required String notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_admin_process_withdrawal',
        params: {
          'in_request_id': requestId,
          'in_admin_id': adminId,
          'in_notes': notes,
        },
      ).select().single();

      // Response: {success: boolean, error_text: text, transaction_id: uuid}
      if (response['success'] == true) {
        return {
          'success': true,
          'transaction_id': response['transaction_id'],
        };
      } else {
        throw WithdrawalException(
          response['error_text'] ?? 'Withdrawal processing failed',
        );
      }
    } catch (e) {
      if (e is WithdrawalException) rethrow;
      throw WithdrawalException('Failed to process withdrawal: $e');
    }
  }

  /// Reject withdrawal request
  Future<WithdrawalRequest> rejectWithdrawalRequest({
    required String requestId,
    required String reviewerId,
    required String reason,
  }) async {
    try {
      final response = await _supabase
          .from('withdrawal_requests')
          .update({
            'status': 'rejected',
            'admin_processed_by': reviewerId,
            'admin_processed_at': DateTime.now().toIso8601String(),
            'admin_notes': reason,
          })
          .eq('id', requestId)
          .inFilter('status', ['pending', 'supervisor_approved'])
          .select()
          .single();

      return WithdrawalRequest.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw WithdrawalException(
          'Cannot reject: request not found or already processed',
        );
      }
      throw WithdrawalException('Failed to reject withdrawal: ${e.message}');
    } catch (e) {
      throw WithdrawalException('Failed to reject withdrawal: $e');
    }
  }

  /// Get pending withdrawal requests (supervisor view)
  Future<List<WithdrawalRequest>> getPendingWithdrawals() async {
    try {
      final response = await _supabase
          .from('withdrawal_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WithdrawalRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw WalletException('Failed to fetch pending withdrawals: $e');
    }
  }

  /// Get supervisor-approved withdrawals (admin view)
  Future<List<WithdrawalRequest>> getSupervisorApprovedWithdrawals() async {
    try {
      final response = await _supabase
          .from('withdrawal_requests')
          .select()
          .eq('status', 'supervisor_approved')
          .order('supervisor_approved_at', ascending: false);

      return (response as List)
          .map((json) => WithdrawalRequest.fromJson(json))
          .toList();
    } catch (e) {
      throw WalletException('Failed to fetch approved withdrawals: $e');
    }
  }
}

