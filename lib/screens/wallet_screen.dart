import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/wallet_models.dart';
import '../models/payment_method_models.dart';
import '../models/down_payment_request.dart';
import '../providers/wallet_provider.dart';
import '../providers/payment_method_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/down_payment_provider.dart';
import '../services/wallet_service.dart';
import '../widgets/down_payment_request_dialog.dart';
import 'cost_submission_history_screen.dart';
import 'cost_submission_form_screen.dart';
import 'withdrawal_request_screen.dart';
import 'payment_methods_screen.dart';
import 'help_screen.dart';
import 'error_messages_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _withdrawalAmountController = TextEditingController();
  final _withdrawalReasonController = TextEditingController();
  PaymentMethod? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _withdrawalAmountController.dispose();
    _withdrawalReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final walletStatsAsync = ref.watch(walletStatsProvider);
    final service = ref.watch(walletServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light background
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2), // Deep blue
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(walletProvider);
              ref.invalidate(walletStatsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF9800), // Orange
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Wallet'),
            Tab(text: 'Transactions'),
            Tab(text: 'Withdrawals'),
            Tab(text: 'Cost Submissions'),
          ],
        ),
      ),
      body: walletAsync.when(
        data: (wallet) {
          if (wallet == null) {
            return const Center(child: Text('Wallet not found'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildWalletTab(wallet, walletStatsAsync, service),
              _buildTransactionsTab(service),
              _buildWithdrawalsTab(wallet, service),
              _buildCostSubmissionsTab(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildWalletTab(Wallet wallet, AsyncValue<WalletStats> statsAsync, WalletService service) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(walletProvider);
        ref.invalidate(walletStatsProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1976D2), // Deep blue
                    Color(0xFF42A5F5), // Light blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.formatCurrency(wallet.currentBalance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Available for withdrawal',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Quick Stats Grid - Always show
            const Text(
              'Quick Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(wallet, statsAsync, service),

            const SizedBox(height: 24),

            // Request Withdrawal Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showWithdrawalDialog(wallet, service),
                icon: const Icon(Icons.money_off),
                label: const Text(
                  'Request Withdrawal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800), // Orange
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Request Down Payment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDownPaymentDialog(),
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text(
                  'Request Down Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50), // Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Methods Section
            _buildPaymentMethodsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PaymentMethodsScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Color(0xFF1976D2),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage how you receive payments',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.help_outline,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            title: const Text(
              'Help & Support',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Get help and find answers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFF44336),
                size: 24,
              ),
            ),
            title: const Text(
              'Common Errors',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Understand error messages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ErrorMessagesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF263238).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Wallet wallet, AsyncValue<WalletStats> statsAsync, WalletService service) {
    // Default stats when no data
    final WalletStats defaultStats = WalletStats(
      totalEarned: 0,
      totalWithdrawn: 0,
      pendingWithdrawals: 0,
      currentBalance: wallet.currentBalance,
      totalTransactions: 0,
      completedSiteVisits: 0,
    );

    WalletStats stats = defaultStats;

    // Extract stats from async value if available
    statsAsync.whenData((data) {
      stats = data;
    });

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Earned',
          service.formatCurrency(stats.totalEarned),
          Icons.trending_up,
          const Color(0xFF4CAF50),
        ),
        _buildStatCard(
          'Total Withdrawn',
          service.formatCurrency(stats.totalWithdrawn),
          Icons.trending_down,
          const Color(0xFFF44336),
        ),
        _buildStatCard(
          'Pending Withdrawals',
            service.formatCurrency(stats.pendingWithdrawals.toDouble()),
          Icons.schedule,
          const Color(0xFFFF9800),
        ),
        _buildStatCard(
          'Completed Sites',
          stats.completedSiteVisits.toString(),
          Icons.check_circle,
          const Color(0xFF2196F3),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab(WalletService service) {
    final transactionsAsync = ref.watch(walletTransactionsProvider(100));
    final profile = ref.watch(currentUserProfileProvider);
    final userId = profile?.id ?? '';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-tabs for Transactions and Down Payments
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1976D2),
              tabs: [
                Tab(text: 'Transactions'),
                Tab(text: 'Down Payments'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Transactions List
                _buildTransactionsList(transactionsAsync, service),
                // Down Payments History
                _buildDownPaymentsHistory(userId, service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(AsyncValue<List<WalletTransaction>> transactionsAsync, WalletService service) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return _buildTransactionItem(transaction, service);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildDownPaymentsHistory(String userId, WalletService service) {
    if (userId.isEmpty) {
      return const Center(child: Text('Please log in to view down payments'));
    }

    final downPaymentsAsync = ref.watch(userDownPaymentStreamProvider(userId));

    return downPaymentsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No down payment requests yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Request a down payment for your\naccepted site visits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showDownPaymentDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Request Down Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Request button at top
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDownPaymentDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Down Payment Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // Requests list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _buildDownPaymentItem(request, service);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(userDownPaymentStreamProvider(userId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownPaymentItem(DownPaymentRequest request, WalletService service) {
    final statusColor = _getDownPaymentStatusColor(request.status);
    final statusLabel = _getDownPaymentStatusLabel(request.status);
    final statusIcon = _getDownPaymentStatusIcon(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with site name and status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.siteName.isNotEmpty ? request.siteName : 'Site Visit',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF263238),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested ${_formatDate(request.requestedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF263238).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Amount details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requested Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF263238).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.formatCurrency(request.requestedAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF263238).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.formatCurrency(request.totalTransportationBudget),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF263238).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Payment type badge
          if (request.paymentType.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  request.paymentType == 'full_advance' 
                      ? Icons.payments 
                      : Icons.schedule,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  request.paymentType == 'full_advance' 
                      ? 'Full Advance' 
                      : 'Installments',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
          // Paid amount if any
          if (request.totalPaidAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Text(
                  'Paid: ${service.formatCurrency(request.totalPaidAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ],
          // Rejection reason if rejected
          if (request.status == 'rejected' && 
              (request.supervisorRejectionReason != null || request.adminRejectionReason != null)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.supervisorRejectionReason ?? request.adminRejectionReason ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  Color _getDownPaymentStatusColor(String status) {
    switch (status) {
      case 'pending_supervisor':
        return const Color(0xFFFF9800); // Orange
      case 'pending_admin':
        return const Color(0xFF2196F3); // Blue
      case 'approved':
        return const Color(0xFF4CAF50); // Green
      case 'rejected':
        return const Color(0xFFF44336); // Red
      case 'partially_paid':
        return const Color(0xFF9C27B0); // Purple
      case 'fully_paid':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getDownPaymentStatusLabel(String status) {
    switch (status) {
      case 'pending_supervisor':
        return 'Pending Approval';
      case 'pending_admin':
        return 'With Finance';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'partially_paid':
        return 'Partially Paid';
      case 'fully_paid':
        return 'Fully Paid';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  IconData _getDownPaymentStatusIcon(String status) {
    switch (status) {
      case 'pending_supervisor':
        return Icons.hourglass_empty;
      case 'pending_admin':
        return Icons.account_balance;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'partially_paid':
        return Icons.pie_chart;
      case 'fully_paid':
        return Icons.verified;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildTransactionItem(WalletTransaction transaction, WalletService service) {
    final isCredit = transaction.isCredit;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCredit 
                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                  : const Color(0xFFF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.description ?? 'No description',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF263238).withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  service.formatDate(transaction.createdAt, includeTime: true),
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF263238).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${service.formatCurrency(transaction.amount.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCredit ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                ),
              ),
              if (transaction.balanceAfter != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Balance: ${service.formatCurrency(transaction.balanceAfter!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF263238).withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalsTab(Wallet wallet, WalletService service) {
    final withdrawalsAsync = ref.watch(withdrawalRequestsProvider);

    return withdrawalsAsync.when(
      data: (withdrawals) {
        if (withdrawals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No withdrawal requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WithdrawalRequestScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Request Withdrawal'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Request Withdrawal Button - always visible
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WithdrawalRequestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Withdrawal Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // Withdrawals list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: withdrawals.length,
                itemBuilder: (context, index) {
                  final withdrawal = withdrawals[index];
                  return _buildWithdrawalItem(withdrawal, service);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildWithdrawalItem(WithdrawalRequest withdrawal, WalletService service) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (withdrawal.status) {
      case 'approved':
        statusColor = const Color(0xFF4CAF50);
        statusLabel = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'supervisor_approved':
        statusColor = const Color(0xFF2196F3);
        statusLabel = 'Pending Finance';
        statusIcon = Icons.schedule;
        break;
      case 'processing':
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'Processing';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'rejected':
        statusColor = const Color(0xFFF44336);
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = 'Cancelled';
        statusIcon = Icons.block;
        break;
      default:
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'Pending Review';
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                service.formatCurrency(withdrawal.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF263238),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: const Color(0xFF263238).withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'Requested: ${service.formatDate(withdrawal.requestedAt)}',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF263238).withOpacity(0.6),
                ),
              ),
            ],
          ),
          // Payment method removed - property not in WithdrawalRequest model
          if (withdrawal.reason != null && withdrawal.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.note,
                  size: 14,
                  color: const Color(0xFF263238).withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    withdrawal.reason!,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF263238).withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showWithdrawalDialog(Wallet wallet, WalletService service) {
    // Reset selected payment method when opening dialog
    _selectedPaymentMethod = null;
    
    // Watch payment methods to show in dropdown
    final paymentMethodsAsync = ref.read(paymentMethodsProvider);
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Withdrawal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance: ${service.formatCurrency(wallet.currentBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _withdrawalAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'SDG ',
                  ),
                ),
                const SizedBox(height: 16),
                // Payment Method dropdown from saved methods
                paymentMethodsAsync.when(
                  data: (methods) {
                    if (methods.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No payment methods saved',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFFF9800)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => const PaymentMethodsScreen(),
                                ));
                              },
                              child: const Text('Add Payment Method'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return DropdownButtonFormField<PaymentMethod>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: methods.map((method) => DropdownMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(method.paymentType.icon, size: 20, color: const Color(0xFF1976D2)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${method.name} (${method.maskedDetails})',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (method.isDefault)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Default', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedPaymentMethod = value;
                        });
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Error loading payment methods: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _withdrawalReasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _submitWithdrawal(wallet, service, dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the down payment request dialog
  void _showDownPaymentDialog() {
    final profile = ref.read(currentUserProfileProvider);
    if (profile == null) {
      _showError('User profile not found. Please log in again.');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => DownPaymentRequestDialog(
        userId: profile.id,
      ),
    );
  }

  Future<void> _submitWithdrawal(Wallet wallet, WalletService service, BuildContext dialogContext) async {
    final amount = double.tryParse(_withdrawalAmountController.text);
    
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    final validation = service.validateWithdrawalAmount(
      amount: amount,
      currentBalance: wallet.currentBalance,
    );

    if (!validation.isValid) {
      _showError(validation.errorMessage!);
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return;
    }

    try {
      final createWithdrawal = ref.read(createWithdrawalRequestProvider);
      await createWithdrawal(
        amount: amount,
        currency: 'SDG',
        reason: _withdrawalReasonController.text,
        paymentMethod: _selectedPaymentMethod!.id, // Use the payment method ID
      );

      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _withdrawalAmountController.clear();
        _withdrawalReasonController.clear();
        _selectedPaymentMethod = null;
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF44336),
      ),
    );
  }

  Widget _buildCostSubmissionsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Submit your site visit costs for reimbursement',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CostSubmissionFormScreen(),
                    ),
                  );
                  if (result == true) {
                    // Refresh list
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: CostSubmissionHistoryScreen(),
        ),
      ],
    );
  }
}
