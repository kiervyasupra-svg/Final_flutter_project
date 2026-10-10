import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../customer/data/repositories/store_repository.dart';
import 'service_management_screen.dart';
import 'transaction_history_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedTab = 0;
  final Set<String> _processingActions = {};
  final StoreRepository _storeRepository = StoreRepository();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderAlerts;
  Set<String>? _knownPendingOrderIds;

  @override
  void initState() {
    super.initState();
    _orderAlerts = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen(_handleOrderUpdates);
  }

  void _handleOrderUpdates(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final pendingIds = snapshot.docs
        .where((doc) => doc.data()['status'] == 'PENDING_APPROVAL')
        .map((doc) => doc.id)
        .toSet();
    final previousIds = _knownPendingOrderIds;
    _knownPendingOrderIds = pendingIds;
    if (previousIds == null) return;

    final hasNewOrder = pendingIds.difference(previousIds).isNotEmpty;
    if (!hasNewOrder || !mounted) return;

    SystemSound.play(SystemSoundType.alert);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New store order received for admin approval.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _orderAlerts?.cancel();
    super.dispose();
  }

  bool _isProcessing(String key) => _processingActions.contains(key);

  void _setProcessing(String key, bool value) {
    if (!mounted) return;
    setState(() {
      if (value) {
        _processingActions.add(key);
      } else {
        _processingActions.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final sections = [
      ('Reservations', 'Review appointments and manage the service queue.',
        Icons.calendar_month_rounded),
      ('Wallet top-ups', 'Verify payment receipts and approve wallet credits.',
        Icons.account_balance_wallet_rounded),
      ('Store orders', 'Approve purchases and manage customer pick-up.',
        Icons.inventory_2_rounded),
      ('Services', 'Build your menu, pricing, and booking availability.',
        Icons.local_car_wash_rounded),
      ('Transactions', 'Review wallet, booking, and store payment activity.',
        Icons.receipt_long_rounded),
    ];
    final section = sections[_selectedTab];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF244B77),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_car_wash_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WashMate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF172B4D),
                      ),
                ),
                const Text(
                  'ADMIN WORKSPACE',
                  style: TextStyle(
                    color: Color(0xFF74839A),
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF475467),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await authController.logout();
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: _buildSectionBanner(
              title: section.$1,
              subtitle: section.$2,
              icon: section.$3,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: switch (_selectedTab) {
                  0 => _buildReservationsTab(),
                  1 => _buildTopUpsTab(),
                  2 => _buildProductOrdersTab(),
                  3 => const ServiceManagementScreen(),
                  _ => const TransactionHistoryScreen(),
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7F0FC),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Top-ups',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Store orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_car_wash_outlined),
            selectedIcon: Icon(Icons.local_car_wash_rounded),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBanner({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183B63), Color(0xFF315D89)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20183B63),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD6E4F2),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: RESERVATIONS
  // -------------------------------------------------------------
  Widget _buildReservationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final reservationSnapshot = snapshot.data;
        if (reservationSnapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = reservationSnapshot.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No reservations found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final index =
                docs.indexWhere((doc) => doc.id == key.value);
            return index < 0 ? null : index;
          },
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final title = data['serviceTitle'] ?? 'Service';
            final status =
                (data['status'] ?? 'PENDING').toString().toUpperCase();
            final vehicle = data['vehicleType'] ?? 'N/A';
            final timeSlot = data['timeSlot'] ?? '';
            final customerName = data['userName'] ?? 'Customer';
            final amountPaid = (data['amountPaid'] as num?)?.toDouble() ??
                (data['depositPaid'] as num?)?.toDouble() ??
                (data['price'] as num?)?.toDouble() ??
                0;
            final remainingBalance =
                (data['remainingBalance'] as num?)?.toDouble() ??
                    (((data['price'] as num?)?.toDouble() ?? amountPaid) -
                        amountPaid)
                        .clamp(0, double.infinity)
                        .toDouble();
            final timestamp = data['date'];
            final dateText = timestamp is Timestamp
                ? _formatDate(timestamp.toDate())
                : 'Date not set';

            final statusColor = switch (status) {
              'APPROVED' || 'COMPLETED' => Colors.green.shade100,
              'DENIED' => Colors.red.shade100,
              _ => Colors.orange.shade100,
            };
            final statusTextColor = switch (status) {
              'APPROVED' || 'COMPLETED' => Colors.green.shade800,
              'DENIED' => Colors.red.shade800,
              _ => Colors.orange.shade800,
            };

            final isProcessing = _isProcessing('reservation-$docId');
            return Card(
              key: ValueKey<String>(docId),
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE6EBF2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customer: $customerName',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vehicle: $vehicle | Time: $timeSlot',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: $dateText',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid: ₱${amountPaid.toStringAsFixed(2)}'
                      '  •  Balance due: ₱${remainingBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF244B77),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status == 'PENDING')
                      _adminActionRow(
                        secondaryAction: OutlinedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _updateReservationStatus(docId, 'DENIED'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Deny'),
                        ),
                        primaryAction: FilledButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _updateReservationStatus(docId, 'APPROVED'),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Approve booking'),
                        ),
                      )
                    else if (status == 'DENIED')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _updateReservationStatus(docId, 'PENDING'),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reopen for review'),
                        ),
                      )
                    else if (status == 'APPROVED')
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _updateReservationStatus(
                                    docId,
                                    'COMPLETED',
                                  ),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.task_alt_rounded),
                          label: const Text('Mark carwash completed'),
                        ),
                      )
                    else if (status == 'COMPLETED')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF027A48),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Carwash completed · time slot released',
                              style: TextStyle(
                                color: Color(0xFF027A48),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isProcessing) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 2: TOP-UP APPROVALS (With Cloudinary Receipt Preview)
  // -------------------------------------------------------------
  Widget _buildTopUpsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('topups')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final topUpSnapshot = snapshot.data;
        if (topUpSnapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = topUpSnapshot.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No pending top-up requests.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final userId = (data['userId'] ?? '').toString();
            final userName = (data['userName'] ?? 'Customer').toString();
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final receiptUrl = (data['receiptUrl'] ?? '').toString();
            final String status =
                (data['status'] ?? 'PENDING').toString().toUpperCase();
            final isProcessing = _isProcessing('topup-$docId');

            return Card(
              key: ValueKey<String>(docId),
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE6EBF2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF244B77),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF172B4D),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Wallet funding request',
                                style: TextStyle(
                                  color: Color(0xFF74839A),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₱${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF027A48),
                          ),
                        ),
                      ],
                    ),
                    if (receiptUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(
                                  receiptUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('Unable to load receipt image.'),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F8FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE7ECF3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF315D89),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Review payment receipt',
                                style: TextStyle(
                                  color: Color(0xFF315D89),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _statusBadge(status),
                    if (status == 'PENDING') ...[
                      const SizedBox(height: 12),
                      _adminActionRow(
                        secondaryAction: OutlinedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _rejectTopUp(docId),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Deny request'),
                        ),
                        primaryAction: FilledButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _approveTopUp(docId, userId, amount),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Approve top-up'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductOrdersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load store orders.'));
        }
        final orderSnapshot = snapshot.data;
        if (orderSnapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = orderSnapshot.docs.toList()
          ..sort((a, b) {
            final aDate = a.data()['createdAt'];
            final bDate = b.data()['createdAt'];
            if (aDate is! Timestamp || bDate is! Timestamp) return 0;
            return bDate.compareTo(aDate);
          });
        if (orders.isEmpty) {
          return const Center(child: Text('No store orders yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = orderDoc.data();
            final orderId = orderDoc.id;
            final status = (order['status'] ?? 'PENDING_APPROVAL').toString();
            final customer = (order['customerName'] ?? 'Customer').toString();
            final method = (order['paymentMethod'] ?? 'wallet').toString();
            final amount = (order['totalPaid'] as num?)?.toDouble() ?? 0;
            final items = (order['items'] as List? ?? const [])
                .map((item) => '${item['name']} × ${item['quantity']}')
                .join('\n');
            final actionKey = 'order-$orderId';
            final processing = _isProcessing(actionKey);
            final displayAmount = method == 'points'
                ? '${amount.toInt()} pts'
                : '₱${amount.toStringAsFixed(2)}';

            return Card(
              key: ValueKey<String>(orderId),
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE6EBF2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFF244B77),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF172B4D),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                style: const TextStyle(
                                  color: Color(0xFF74839A),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        items.isEmpty ? 'No order items' : items,
                        style: const TextStyle(
                          color: Color(0xFF344054),
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _orderInfoPill(
                          Icons.payments_outlined,
                          displayAmount,
                        ),
                        _orderInfoPill(
                          Icons.account_balance_wallet_outlined,
                          method.toUpperCase(),
                        ),
                      ],
                    ),
                    if (status == 'PENDING_APPROVAL' ||
                        status == 'READY_FOR_PICKUP')
                      const SizedBox(height: 14),
                    if (status == 'PENDING_APPROVAL')
                      _adminActionRow(
                        secondaryAction: OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () => _reviewProductOrder(
                                    orderId,
                                    approve: false,
                                  ),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Deny & refund'),
                        ),
                        primaryAction: FilledButton.icon(
                          onPressed: processing
                              ? null
                              : () => _reviewProductOrder(
                                    orderId,
                                    approve: true,
                                  ),
                          icon: processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Confirm & approve'),
                        ),
                      )
                    else if (status == 'READY_FOR_PICKUP')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ready for pick-up',
                            style: TextStyle(
                              color: Color(0xFF027A48),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: processing
                                  ? null
                                  : () => _markProductOrderHandedOver(orderId),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Scan / hand over'),
                            ),
                          ),
                        ],
                      ),
                    if (processing && status != 'PENDING_APPROVAL')
                      const LinearProgressIndicator(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _adminActionRow({
    required Widget secondaryAction,
    required Widget primaryAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(height: 48, child: secondaryAction),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(height: 48, child: primaryAction),
        ),
      ],
    );
  }

  Widget _orderInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF667085)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'READY_FOR_PICKUP' || 'HANDED_OVER' => const Color(0xFF027A48),
      'REJECTED' => const Color(0xFFB42318),
      _ => const Color(0xFFB54708),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _reviewProductOrder(
    String orderId, {
    required bool approve,
  }) async {
    final actionKey = 'order-$orderId';
    if (_isProcessing(actionKey)) return;
    _setProcessing(actionKey, true);
    try {
      if (approve) {
        await _storeRepository.approveOrder(orderId);
      } else {
        await _storeRepository.rejectOrder(orderId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve
              ? 'Order approved and inventory updated.'
              : 'Order denied; payment refunded and stock released.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update order: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setProcessing(actionKey, false);
    }
  }

  Future<void> _markProductOrderHandedOver(String orderId) async {
    var scanHandled = false;
    final scannedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scan pickup receipt'),
        content: SizedBox(
          width: 320,
          height: 360,
          child: MobileScanner(
            onDetect: (capture) {
              if (scanHandled) return;
              final code = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code != null) {
                scanHandled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted &&
                      Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(code);
                  }
                });
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (scannedId == null) return;
    if (scannedId != orderId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That receipt does not match this order.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final actionKey = 'order-$orderId';
    if (_isProcessing(actionKey)) return;
    _setProcessing(actionKey, true);
    try {
      await _storeRepository.markOrderHandedOver(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as handed over.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete handover: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setProcessing(actionKey, false);
    }
  }

  // Action: Approve TopUp and add balance to User
  Future<void> _approveTopUp(
      String topupId, String userId, double amount) async {
    final firestore = FirebaseFirestore.instance;
    final actionKey = 'topup-$topupId';
    if (_isProcessing(actionKey)) return;
    _setProcessing(actionKey, true);

    try {
      if (userId.isEmpty || !amount.isFinite || amount <= 0) {
        throw Exception('This top-up request has invalid payment details.');
      }

      await firestore.runTransaction((transaction) async {
        final userRef = firestore.collection('users').doc(userId);
        final topupRef = firestore.collection('topups').doc(topupId);

        final topupSnap = await transaction.get(topupRef);
        if (!topupSnap.exists) {
          throw Exception('Top-up request no longer exists.');
        }
        final topupData = topupSnap.data();
        if (topupData == null) {
          throw Exception('Top-up request data is missing.');
        }
        final status =
            (topupData['status'] ?? 'PENDING').toString().toUpperCase();
        if (status != 'PENDING') {
          throw Exception('This top-up request has already been reviewed.');
        }

        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('User profile not found');
        }

        final double currentBalance =
            (userSnap.data()?['walletBalance'] ?? 0.0).toDouble();
        final transactionAmount =
            (topupData['amount'] as num?)?.toDouble() ?? 0.0;
        if (transactionAmount != amount) {
          throw Exception('Top-up amount changed. Refresh and try again.');
        }

        transaction.update(userRef, {
          'walletBalance': currentBalance + amount,
        });

        transaction.update(topupRef, {
          'status': 'APPROVED',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top-Up Approved & Balance Added!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve top-up: ${e.toString()}')),
      );
    } finally {
      _setProcessing(actionKey, false);
    }
  }

  Future<void> _rejectTopUp(String topupId) async {
    final actionKey = 'topup-$topupId';
    if (_isProcessing(actionKey)) return;
    _setProcessing(actionKey, true);

    try {
      final firestore = FirebaseFirestore.instance;
      final topupRef = firestore.collection('topups').doc(topupId);
      await firestore.runTransaction((transaction) async {
        final topupSnap = await transaction.get(topupRef);
        if (!topupSnap.exists) {
          throw Exception('Top-up request no longer exists.');
        }
        final status =
            (topupSnap.data()?['status'] ?? 'PENDING').toString().toUpperCase();
        if (status != 'PENDING') {
          throw Exception('This top-up request has already been reviewed.');
        }
        transaction.update(topupRef, {
          'status': 'REJECTED',
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top-up request denied.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deny top-up: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setProcessing(actionKey, false);
    }
  }

  Future<void> _updateReservationStatus(String docId, String status) async {
    final actionKey = 'reservation-$docId';
    if (_isProcessing(actionKey)) return;
    _setProcessing(actionKey, true);

    try {
      final firestore = FirebaseFirestore.instance;
      final reservationRef = firestore.collection('reservations').doc(docId);
      await firestore.runTransaction((transaction) async {
        final reservationSnapshot = await transaction.get(reservationRef);
        if (!reservationSnapshot.exists) {
          throw Exception('Reservation no longer exists.');
        }

        final reservation = reservationSnapshot.data()!;
        final currentStatus =
            (reservation['status'] ?? 'PENDING').toString().toUpperCase();

        if (status == 'COMPLETED') {
          if (currentStatus == 'COMPLETED') return;
          if (currentStatus != 'APPROVED') {
            throw Exception('Only approved carwashes can be completed.');
          }
          transaction.update(reservationRef, {
            'status': 'COMPLETED',
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        if (status == 'APPROVED') {
          if (currentStatus == 'APPROVED') return;
          if (currentStatus != 'PENDING') {
            throw Exception('Only pending reservations can be approved.');
          }

          final pointsAwarded = reservation['pointsAwarded'] == true;
          final configuredReward =
              (reservation['loyaltyPointsReward'] as num?)?.toInt();
          final rewardPoints = configuredReward ??
              (((reservation['depositPaid'] as num?)?.toDouble() ?? 0) / 10)
                  .floor();
          final userId = (reservation['userId'] ?? '').toString();

          if (!pointsAwarded && rewardPoints > 0) {
            if (userId.isEmpty) {
              throw Exception('Reservation has no linked customer account.');
            }
            final userRef = firestore.collection('users').doc(userId);
            final userSnapshot = await transaction.get(userRef);
            if (!userSnapshot.exists) {
              throw Exception('Customer account was not found.');
            }
            transaction.update(userRef, {
              'rewardPoints': FieldValue.increment(rewardPoints),
            });
          }

          transaction.update(reservationRef, {
            'status': 'APPROVED',
            'pointsAwarded': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        if (status == 'DENIED' && currentStatus != 'PENDING') {
          throw Exception('Only pending reservations can be denied.');
        }
        if (status == 'PENDING' && currentStatus != 'DENIED') {
          throw Exception('Only denied reservations can be reopened.');
        }
        transaction.update(reservationRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'APPROVED'
                ? 'Reservation approved.'
                : status == 'DENIED'
                    ? 'Reservation denied.'
                    : 'Reservation reopened for review.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update reservation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setProcessing(actionKey, false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
