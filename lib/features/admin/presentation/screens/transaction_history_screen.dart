import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _selectedFilter = 'All';

  static const _filters = ['All', 'Bookings', 'Top-ups', 'Store'];

  List<_HistoryEntry> _entriesFromSnapshots(
    List<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final entries = <_HistoryEntry>[];

    for (final doc in snapshots[0].docs) {
      final data = doc.data();
      final status = _displayStatus(data['status']);
      final date = _dateFrom(data['createdAt']) ?? _dateFrom(data['date']);
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      entries.add(
        _HistoryEntry(
          id: doc.id,
          type: 'Top-ups',
          title: 'Wallet top-up',
          customer: _customerName(data),
          amount: amount,
          amountLabel: '+ ₱${amount.toStringAsFixed(2)}',
          paymentLabel: 'Wallet credit request',
          status: status,
          date: date,
          icon: Icons.account_balance_wallet_rounded,
          positive: true,
          receiptUrl: (data['receiptUrl'] ?? '').toString(),
        ),
      );
    }

    for (final doc in snapshots[1].docs) {
      final data = doc.data();
      final rawType = (data['type'] ?? 'transaction').toString().toLowerCase();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final isRefund = rawType == 'refund';
      final isDebit = rawType == 'payment' || rawType == 'purchase';
      final label = rawType == 'topup'
          ? 'Wallet top-up'
          : rawType == 'payment'
              ? 'Wallet payment'
              : rawType == 'refund'
                  ? 'Wallet refund'
                  : 'Wallet transaction';
      final amountLabel = isDebit
          ? '- ₱${amount.toStringAsFixed(2)}'
          : '+ ₱${amount.toStringAsFixed(2)}';
      entries.add(
        _HistoryEntry(
          id: doc.id,
          type: 'Top-ups',
          title: label,
          customer: _customerName(data),
          amount: amount,
          amountLabel: amountLabel,
          paymentLabel: 'Wallet',
          status: _displayStatus(data['status']),
          date: _dateFrom(data['createdAt']),
          icon: isRefund
              ? Icons.currency_exchange_rounded
              : Icons.account_balance_wallet_rounded,
          positive: !isDebit,
          receiptUrl: (data['proofOfPaymentUrl'] ?? '').toString(),
        ),
      );
    }

    for (final doc in snapshots[2].docs) {
      final data = doc.data();
      final amount = (data['amountPaid'] as num?)?.toDouble() ??
          (data['depositPaid'] as num?)?.toDouble() ??
          (data['reservationFee'] as num?)?.toDouble() ??
          0;
      final isFullyPaid =
          (data['paymentStatus'] ?? '').toString().toUpperCase() == 'PAID';
      entries.add(
        _HistoryEntry(
          id: doc.id,
          type: 'Bookings',
          title: (data['serviceTitle'] ?? 'Carwash booking').toString(),
          customer: _customerName(data),
          amount: amount,
          amountLabel: '- ₱${amount.toStringAsFixed(2)}',
          paymentLabel:
              isFullyPaid ? 'Full booking payment' : 'Booking deposit',
          status: _displayStatus(data['status']),
          date: _dateFrom(data['createdAt']) ?? _dateFrom(data['date']),
          icon: Icons.local_car_wash_rounded,
          positive: false,
          detail: [
            (data['vehicleType'] ?? '').toString(),
            (data['timeSlot'] ?? '').toString(),
          ].where((value) => value.isNotEmpty).join(' · '),
        ),
      );
    }

    for (final doc in snapshots[3].docs) {
      final data = doc.data();
      final paymentMethod = (data['paymentMethod'] ?? 'wallet').toString();
      final amount = (data['totalPaid'] as num?)?.toDouble() ?? 0;
      final isPoints = paymentMethod.toLowerCase() == 'points';
      final refunded =
          (data['status'] ?? '').toString().toUpperCase() == 'REJECTED';
      final itemNames = (data['items'] as List? ?? const [])
          .map((item) {
            if (item is! Map) return '';
            final name = (item['name'] ?? 'Item').toString();
            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            return '$name × $quantity';
          })
          .where((name) => name.isNotEmpty)
          .join(', ');
      entries.add(
        _HistoryEntry(
          id: doc.id,
          type: 'Store',
          title: 'Store order',
          customer: _customerName(data),
          amount: amount,
          amountLabel: isPoints
              ? '${refunded ? '+' : '-'} ${amount.toInt()} pts'
              : '${refunded ? '+' : '-'} ₱${amount.toStringAsFixed(2)}',
          paymentLabel: isPoints ? 'Loyalty points' : 'Wallet',
          status: _displayStatus(data['status']),
          date: _dateFrom(data['createdAt']),
          icon: Icons.shopping_bag_rounded,
          positive: refunded,
          detail: itemNames,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.date == null) return b.date == null ? 0 : 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return entries;
  }

  String _customerName(Map<String, dynamic> data) {
    final name =
        (data['customerName'] ?? data['userName'] ?? '').toString().trim();
    return name.isEmpty ? 'Customer' : name;
  }

  DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _displayStatus(Object? value) {
    final status = (value ?? 'PENDING').toString().trim();
    if (status.isEmpty) return 'PENDING';
    return status.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final sources = [
      FirebaseFirestore.instance.collection('topups').snapshots(),
      FirebaseFirestore.instance.collection('wallet_transactions').snapshots(),
      FirebaseFirestore.instance.collection('reservations').snapshots(),
      FirebaseFirestore.instance.collection('orders').snapshots(),
    ];

    Widget buildSource(
      int index,
      List<QuerySnapshot<Map<String, dynamic>>> snapshots,
    ) {
      if (index == sources.length) {
        return _buildHistory(_entriesFromSnapshots(snapshots));
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: sources[index],
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _historyError(snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return buildSource(index + 1, [...snapshots, snapshot.data!]);
        },
      );
    }

    return buildSource(0, const []);
  }

  Widget _buildHistory(List<_HistoryEntry> entries) {
    final visibleEntries = _selectedFilter == 'All'
        ? entries
        : entries.where((entry) => entry.type == _selectedFilter).toList();
    final totalEvents = entries.length;
    final pendingEvents = entries
        .where((entry) =>
            entry.status == 'PENDING' || entry.status == 'PENDING APPROVAL')
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryMetric(
                      label: 'Recorded activity',
                      value: '$totalEvents',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF244B77),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryMetric(
                      label: 'Awaiting review',
                      value: '$pendingEvents',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFB54708),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _filters.map((filter) {
                    final selected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: selected
                            ? const Color(0xFF244B77)
                            : const Color(0xFFDCEBFA),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => setState(() => _selectedFilter = filter),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 76),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF244B77)
                                    : const Color(0xFF8CB5DD),
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF174A75),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Latest activity',
                      style: TextStyle(
                        color: Color(0xFF172B4D),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${visibleEntries.length} '
                    '${visibleEntries.length == 1 ? 'record' : 'records'}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleEntries.isEmpty
              ? _emptyHistory()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                  itemCount: visibleEntries.length,
                  itemBuilder: (context, index) =>
                      _entryCard(visibleEntries[index]),
                ),
        ),
      ],
    );
  }

  Widget _summaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF172B4D),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(_HistoryEntry entry) {
    final stateColor = switch (entry.status) {
      'APPROVED' ||
      'COMPLETED' ||
      'READY FOR PICKUP' ||
      'HANDED OVER' =>
        const Color(0xFF027A48),
      'REJECTED' || 'DENIED' => const Color(0xFFB42318),
      'PENDING' || 'PENDING APPROVAL' => const Color(0xFFB54708),
      _ => const Color(0xFF475467),
    };
    final amountColor =
        entry.positive ? const Color(0xFF027A48) : const Color(0xFFB42318);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6EBF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    entry.icon,
                    color: const Color(0xFF244B77),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.amountLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _historyStatus(entry.status, stateColor),
                  ],
                ),
              ],
            ),
            if (entry.detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  entry.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _historyMetadata(
                    Icons.payments_outlined,
                    entry.paymentLabel,
                  ),
                ),
                const SizedBox(width: 8),
                _historyMetadata(
                  Icons.schedule_rounded,
                  entry.date == null
                      ? 'Time unavailable'
                      : _formatDate(entry.date!),
                ),
              ],
            ),
            if (entry.receiptUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _showReceipt(entry.receiptUrl),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('View payment receipt'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyMetadata(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF667085)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _historyStatus(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyHistory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF8B9AAF),
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'No activity in this category',
              style: TextStyle(
                color: Color(0xFF344054),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'New payments, bookings, and store orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _selectedFilter = 'All'),
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text('Show all activity'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318)),
            const SizedBox(height: 10),
            const Text(
              'Unable to load transaction history.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'AM' : 'PM';
    return '${local.month}/${local.day}/${local.year} · $hour:$minute $suffix';
  }

  void _showReceipt(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to load payment receipt.'),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.customer,
    required this.amount,
    required this.amountLabel,
    required this.paymentLabel,
    required this.status,
    required this.date,
    required this.icon,
    required this.positive,
    this.detail = '',
    this.receiptUrl = '',
  });

  final String id;
  final String type;
  final String title;
  final String customer;
  final double amount;
  final String amountLabel;
  final String paymentLabel;
  final String status;
  final DateTime? date;
  final IconData icon;
  final bool positive;
  final String detail;
  final String receiptUrl;
}
