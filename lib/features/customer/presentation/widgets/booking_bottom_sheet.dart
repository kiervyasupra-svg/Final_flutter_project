import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/service_schedule.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/service_model.dart';
import '../controllers/booking_controller.dart';

class BookingBottomSheet extends StatefulWidget {
  final ServiceModel service;

  const BookingBottomSheet({super.key, required this.service});

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  String _selectedVehicleType = '';
  String _selectedPaymentMethod = 'wallet';
  final String _selectedLocation = 'In-Shop';
  BookingController? _bookingController;
  Timer? _clockTimer;

  static const List<String> _vehicleTypes = [
    'Sedan',
    'SUV',
    'Truck',
    'Van',
    'Pickup / Van',
    'Motorcycle',
  ];

  @override
  void initState() {
    super.initState();
    final vehicleTypes = _availableVehicleTypes;
    _selectedVehicleType = vehicleTypes.isEmpty ? '' : vehicleTypes.first;
    _loadBookedSlots();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final selectedTimeSlot = _selectedTimeSlot;
      setState(() {
        if (selectedTimeSlot != null && _isSlotInPast(selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookingController = Provider.of<BookingController>(
      context,
      listen: false,
    );
    if (_bookingController == bookingController) return;
    _bookingController?.removeListener(_handleBookingAvailabilityChanged);
    _bookingController = bookingController
      ..addListener(_handleBookingAvailabilityChanged);
  }

  void _handleBookingAvailabilityChanged() {
    final selectedTimeSlot = _selectedTimeSlot;
    if (!mounted ||
        selectedTimeSlot == null ||
        !_bookingController!.bookedSlots.contains(selectedTimeSlot)) {
      return;
    }
    setState(() => _selectedTimeSlot = null);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bookingController?.removeListener(_handleBookingAvailabilityChanged);
    super.dispose();
  }

  List<String> get _availableVehicleTypes => _vehicleTypes
      .where(widget.service.vehicleTypes.contains)
      .toList(growable: false);

  void _loadBookedSlots() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BookingController>(context, listen: false).fetchBookedSlots(
        _selectedDate,
        requestedDurationMinutes: widget.service.durationMinutes,
      );
    });
  }

  bool get _isPastDate {
    final now = DateTime.now();
    return _selectedDate.isBefore(
      DateTime(now.year, now.month, now.day),
    );
  }

  bool _isSlotInPast(String slot) =>
      ServiceSchedule.isTimeSlotInPast(_selectedDate, slot);

  double get _serviceTotal =>
      widget.service.priceForVehicle(_selectedVehicleType);

  String get _formattedDate =>
      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

  Future<void> _handlePaymentAndReservation() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final bookingController =
        Provider.of<BookingController>(context, listen: false);
    final user = authController.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue.')),
      );
      return;
    }

    if (_isPastDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date.')),
      );
      return;
    }

    final selectedTimeSlot = _selectedTimeSlot;
    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot first.')),
      );
      return;
    }

    if (_isSlotInPast(selectedTimeSlot)) {
      setState(() => _selectedTimeSlot = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That time slot has already passed. Please choose another time.'),
        ),
      );
      return;
    }

    if (_selectedPaymentMethod != 'wallet') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Card and GCash payments are not available yet. Please use your wallet balance.',
          ),
        ),
      );
      return;
    }

    final double amountDue = _serviceTotal;
    final double userBalance = user.walletBalance;

    if (userBalance < amountDue) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insufficient Wallet Balance'),
          content: Text(
            'Your wallet balance is ₱${userBalance.toStringAsFixed(2)}. Full payment of ₱${amountDue.toStringAsFixed(2)} is required to book this service.\n\nPlease top up your wallet and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Top up now'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await bookingController.createPaidReservation(
        userId: user.uid,
        service: widget.service,
        selectedDate: _selectedDate,
        selectedTimeSlot: selectedTimeSlot,
        vehicleType: _selectedVehicleType,
        location: _selectedLocation,
        amountPaid: amountDue,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Full payment received. Reservation submitted for approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingController = Provider.of<BookingController>(context);
    final availableSlots = ServiceSchedule.timeSlots
        .where(
          (slot) =>
              !bookingController.bookedSlots.contains(slot) &&
              !_isSlotInPast(slot),
        )
        .length;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.service.durationMinutes} min • ${widget.service.vehicleTypes.join(', ')}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₱${_serviceTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF244B77),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _stepPill('1', 'Details', true),
                const SizedBox(width: 10),
                _stepPill('2', 'Schedule', true),
                const SizedBox(width: 10),
                _stepPill('3', 'Pay', false),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Vehicle type',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_availableVehicleTypes.isEmpty)
              const Text(
                'This service currently has no eligible vehicle types.',
                style: TextStyle(color: Color(0xFFB42318)),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleType,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: _availableVehicleTypes.map((type) {
                  final price = widget.service.priceForVehicle(type);
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      '$type · ₱${price.toStringAsFixed(2)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedVehicleType = val);
                  }
                },
              ),
            const SizedBox(height: 16),
            const Text('Service location',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCE1FF)),
              ),
              child: Text(
                'In-Shop',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF244B77),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select date',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (!bookingController.isLoading)
                  Text(
                    '$availableSlots slots open',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_formattedDate),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _selectedTimeSlot = null;
                      });
                      _loadBookedSlots();
                    }
                  },
                  child: const Text('Change date'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Available time slots',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (bookingController.bookedSlotsErrorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bookingController.bookedSlotsErrorMessage!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              )
            else if (availableSlots == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No available time slots left for this date. Please choose another day.',
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ServiceSchedule.timeSlots.map((slot) {
                  final isBooked = bookingController.bookedSlots.contains(slot) ||
                      _isSlotInPast(slot);
                  final isSelected = _selectedTimeSlot == slot;

                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: const Color(0xFF244B77),
                    disabledColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: isBooked
                        ? null
                        : (selected) {
                            setState(() {
                              _selectedTimeSlot = selected ? slot : null;
                            });
                          },
                  );
                }).toList(),
              ),
            const SizedBox(height: 18),
            const Text(
              'Payment method',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _paymentMethodOption(
              value: 'wallet',
              title: 'Available balance',
              subtitle:
                  'Wallet balance: ₱${(Provider.of<AuthController>(context).currentUser?.walletBalance ?? 0).toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 8),
            _paymentMethodOption(
              value: 'card',
              title: 'Card',
              subtitle: 'Card checkout will be available soon.',
              icon: Icons.credit_card_outlined,
            ),
            const SizedBox(height: 8),
            _paymentMethodOption(
              value: 'gcash',
              title: 'GCash',
              subtitle: 'GCash checkout will be available soon.',
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _summaryRow(
                      'Service total', '₱${_serviceTotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _summaryRow(
                    'Full payment due now',
                    '₱${_serviceTotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('Balance after payment', '₱0.00'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: bookingController.isLoading ||
                        availableSlots == 0 ||
                        _selectedVehicleType.isEmpty
                    ? null
                    : _handlePaymentAndReservation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF244B77),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: bookingController.isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Processing...'),
                        ],
                      )
                    : Text(
                        _selectedPaymentMethod == 'wallet'
                            ? 'Pay with wallet • ₱${_serviceTotal.toStringAsFixed(2)}'
                            : '${_selectedPaymentMethod == 'gcash' ? 'GCash' : 'Card'} payments coming soon',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedPaymentMethod == value
              ? const Color(0xFF244B77)
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethod,
        onChanged: (method) {
          if (method != null) {
            setState(() => _selectedPaymentMethod = method);
          }
        },
        secondary: Icon(icon, color: const Color(0xFF244B77)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        activeColor: const Color(0xFF244B77),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _stepPill(String number, String label, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF244B77) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey.shade500,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFF244B77) : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
