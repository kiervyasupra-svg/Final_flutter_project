import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/product_model.dart';
import '../controllers/store_controller.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreController>();
    final user = context.watch<AuthController>().currentUser;
    const categories = ['All', 'Shampoo', 'Microfiber', 'Air Freshener', 'Wax'];
    final products = _selectedCategory == 'All'
        ? store.products
        : store.products
            .where((product) => product.category == _selectedCategory)
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Car care essentials',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'My orders',
                onPressed:
                    user == null ? null : () => _showOrders(context, user.uid),
                icon: const Icon(Icons.receipt_long_rounded),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Shopping cart',
                    onPressed: () => _showCheckout(
                      context,
                      Map<ProductModel, int>.from(store.cart),
                      clearCartOnSuccess: true,
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  if (store.cartCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF476F),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text(
                          '${store.cartCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: categories.map((category) {
              final selected = category == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                child: Material(
                  color: selected
                      ? const Color(0xFF244B77)
                      : const Color(0xFFDCEBFA),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 42,
                        minWidth: 64,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF244B77)
                              : const Color(0xFF7EA9D2),
                          width: selected ? 1 : 1.3,
                        ),
                      ),
                      child: Text(
                        category,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF123F65),
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedCategory == 'All'
                      ? 'All products'
                      : _selectedCategory,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${products.length} ${products.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: store.isLoading
              ? const Center(child: CircularProgressIndicator())
              : store.products.isEmpty
                  ? const Center(
                      child: Text('No products are available right now.'))
                  : products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 40,
                                  color: Color(0xFF74839A),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No $_selectedCategory products yet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF344054),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _selectedCategory = 'All'),
                                  icon: const Icon(Icons.grid_view_rounded),
                                  label: const Text('Show all products'),
                                ),
                              ],
                            ),
                          ),
                        )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 600
                                ? 3
                                : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: 300,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) => _ProductCard(
                            product: products[index],
                            onTap: () => _showCheckout(
                              context,
                              {products[index]: 1},
                            ),
                            onAdd: () => context
                                .read<StoreController>()
                                .addToCart(products[index]),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showCheckout(
    BuildContext context,
    Map<ProductModel, int> initialItems, {
    bool clearCartOnSuccess = false,
  }) {
    if (initialItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _CheckoutSheet(
        initialItems: initialItems,
        clearCartOnSuccess: clearCartOnSuccess,
        onOrderPlaced: (orderId, items, paymentMethod, customerName) {
          Navigator.pop(sheetContext);
          _showReceipt(
            context,
            orderId,
            items: items,
            paymentMethod: paymentMethod,
            customerName: customerName,
          );
        },
      ),
    );
  }

  void _showReceipt(
    BuildContext context,
    String orderId, {
    Map<ProductModel, int>? items,
    String paymentMethod = 'wallet',
    String customerName = '',
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .snapshots(),
          builder: (context, snapshot) {
            final order = snapshot.data?.data();
            final status = (order?['status'] ?? 'PENDING_APPROVAL').toString();
            final receiptItems = (order?['items'] as List?)
                    ?.map((item) => '${item['name']} × ${item['quantity']}')
                    .join('\n') ??
                items?.entries
                    .map((entry) => '${entry.key.name} × ${entry.value}')
                    .join('\n') ??
                '';
            final paidAmount = (order?['totalPaid'] as num?)?.toDouble();
            final currentPaymentMethod =
                (order?['paymentMethod'] ?? paymentMethod).toString();
            final currentCustomer =
                (order?['customerName'] ?? customerName).toString();
            final stage = switch (status) {
              'READY_FOR_PICKUP' => 1,
              'HANDED_OVER' => 2,
              'REJECTED' => -1,
              _ => 0,
            };

            return Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: stage == -1
                          ? const Color(0xFFFEE4E2)
                          : const Color(0xFFE8F5EE),
                      child: Icon(
                        stage == -1
                            ? Icons.error_outline_rounded
                            : Icons.check_rounded,
                        color: stage == -1
                            ? const Color(0xFFB42318)
                            : const Color(0xFF198754),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Store order receipt',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      status.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: Color(0xFF244B77),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OrderProgress(stage: stage),
                    if (currentCustomer.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Customer: $currentCustomer'),
                    ],
                    if (receiptItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(receiptItems, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      currentPaymentMethod == 'points'
                          ? 'Paid: ${paidAmount?.toInt() ?? _pointsForItems(items)} pts'
                          : 'Paid: ₱${(paidAmount ?? _cashForItems(items)).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: orderId,
                      size: 156,
                      backgroundColor: Colors.white,
                    ),
                    const Text('Scan this code at pick-up'),
                    const SizedBox(height: 8),
                    SelectableText(
                      orderId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _cashForItems(Map<ProductModel, int>? items) =>
      items?.entries.fold<double>(
        0,
        (total, entry) => total + entry.key.price * entry.value,
      ) ??
      0;

  int _pointsForItems(Map<ProductModel, int>? items) =>
      items?.entries.fold<int>(
        0,
        (total, entry) => total + entry.key.pointsCost * entry.value,
      ) ??
      0;

  void _showOrders(BuildContext context, String userId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('My store orders',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Unable to load orders.'));
                  }
                  final orderSnapshot = snapshot.data;
                  if (orderSnapshot == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = orderSnapshot.docs.toList()
                    ..sort((a, b) {
                      final aDate = a.data()['createdAt'];
                      final bDate = b.data()['createdAt'];
                      if (aDate is! Timestamp || bDate is! Timestamp) return 0;
                      return bDate.compareTo(aDate);
                    });
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('You have no store orders yet.'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final status = (data['status'] ?? 'PENDING_APPROVAL')
                          .toString()
                          .replaceAll('_', ' ');
                      final items = (data['items'] as List? ?? const []);
                      final itemsText = items
                          .map((item) => '${item['name']} x${item['quantity']}')
                          .join(', ');
                      return ListTile(
                        leading: const Icon(Icons.local_mall_outlined),
                        title: Text(itemsText,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('Order ${doc.id}\n$status'),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Show pickup code',
                          icon: const Icon(Icons.qr_code_2_rounded),
                          onPressed: () => _showReceipt(
                            context,
                            doc.id,
                            customerName:
                                (data['customerName'] ?? '').toString(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final available = product.availableStock;
    final stockColor = available == 0
        ? const Color(0xFFB42318)
        : available < 5
            ? const Color(0xFFB54708)
            : const Color(0xFF027A48);
    final stockLabel = available == 0
        ? 'Out of stock'
        : available < 5
            ? 'Low stock · $available'
            : 'In stock · $available';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: available > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE6EAF0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 104,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _productPlaceholder(),
                          )
                        : _productPlaceholder(),
                  ),
              ),
              const SizedBox(height: 8),
              Text(
                stockLabel,
                style: TextStyle(
                  color: stockColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, height: 1.15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _PricePill(
                      label: '₱${product.price.toStringAsFixed(0)}',
                      background: const Color(0xFFFFF1F0),
                      foreground: const Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PricePill(
                      label: '${product.pointsCost} pts',
                      background: const Color(0xFFFFF7E5),
                      foreground: const Color(0xFF9A6700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: FilledButton.icon(
                  onPressed: available > 0 ? onAdd : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: Text(available > 0 ? 'Add to cart' : 'Out of stock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productPlaceholder() => Container(
        width: double.infinity,
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.shopping_basket_rounded,
              size: 42, color: Color(0xFF244B77)),
        ),
      );
}

class _PricePill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _PricePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _OrderProgress extends StatelessWidget {
  final int stage;

  const _OrderProgress({required this.stage});

  @override
  Widget build(BuildContext context) {
    if (stage < 0) {
      return const Text(
        'Order denied · payment refunded',
        style: TextStyle(color: Color(0xFFB42318)),
      );
    }
    const labels = ['Pending', 'Ready', 'Picked up'];
    return Row(
      children: List.generate(labels.length, (index) {
        final complete = index <= stage;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index <= stage
                            ? const Color(0xFF198754)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: complete
                        ? const Color(0xFF198754)
                        : const Color(0xFFE5E7EB),
                    child: Icon(
                      complete ? Icons.check : Icons.circle,
                      size: complete ? 14 : 7,
                      color: complete ? Colors.white : Colors.grey,
                    ),
                  ),
                  if (index < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index < stage
                            ? const Color(0xFF198754)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 10,
                  color: complete ? const Color(0xFF198754) : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final Map<ProductModel, int> initialItems;
  final bool clearCartOnSuccess;
  final void Function(
    String orderId,
    Map<ProductModel, int> items,
    String paymentMethod,
    String customerName,
  ) onOrderPlaced;

  const _CheckoutSheet({
    required this.initialItems,
    required this.clearCartOnSuccess,
    required this.onOrderPlaced,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late final Map<ProductModel, int> _items = Map.from(widget.initialItems);
  String _paymentMethod = 'wallet';
  bool _isSubmitting = false;

  double get _cashTotal => _items.entries.fold(
        0,
        (total, entry) => total + entry.key.price * entry.value,
      );

  int get _pointsTotal => _items.entries.fold(
        0,
        (total, entry) => total + entry.key.pointsCost * entry.value,
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final store = context.watch<StoreController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Review your order',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ..._items.entries.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.name),
                  subtitle: Text(
                    '₱${entry.key.price.toStringAsFixed(2)} each · ${entry.key.pointsCost} pts',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                  if (entry.value <= 1) {
                                    _items.remove(entry.key);
                                  } else {
                                    _items[entry.key] = entry.value - 1;
                                  }
                                }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${entry.value}'),
                      IconButton(
                        onPressed: _isSubmitting ||
                                entry.value >= entry.key.availableStock
                            ? null
                            : () => setState(() {
                                  _items[entry.key] = entry.value + 1;
                                }),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                )),
            const Divider(),
            Text('Payment method',
                style: Theme.of(context).textTheme.titleMedium),
            _PaymentMethodOption(
              title: 'Wallet · ₱${_cashTotal.toStringAsFixed(2)}',
              subtitle:
                  'Available: ₱${(user?.walletBalance ?? 0).toStringAsFixed(2)}',
              selected: _paymentMethod == 'wallet',
              enabled: !_isSubmitting,
              onTap: () => setState(() => _paymentMethod = 'wallet'),
            ),
            const SizedBox(height: 8),
            _PaymentMethodOption(
              title: 'Reward points · $_pointsTotal pts',
              subtitle: 'Available: ${user?.rewardPoints ?? 0} pts',
              selected: _paymentMethod == 'points',
              enabled: !_isSubmitting,
              onTap: () => setState(() => _paymentMethod = 'points'),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || user == null || _items.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isSubmitting = true);
                        final orderId = await store.placeOrder(
                          userId: user.uid,
                          customerName: user.name,
                          customerEmail: user.email,
                          items: Map.from(_items),
                          paymentMethod: _paymentMethod,
                        );
                        if (!mounted) return;
                        setState(() => _isSubmitting = false);
                        if (orderId != null) {
                          if (widget.clearCartOnSuccess) {
                            store.clearCart();
                          }
                          widget.onOrderPlaced(
                            orderId,
                            Map.from(_items),
                            _paymentMethod,
                            user.name,
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                store.errorMessage ?? 'Could not place order.',
                              ),
                            ),
                          );
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Proceed to payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF244B77) : Colors.grey.shade400;
    return Material(
      color: selected ? const Color(0xFFEAF3FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
