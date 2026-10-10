import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../customer/data/models/service_model.dart';
import '../../data/repositories/admin_service_repository.dart';

class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  State<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  final AdminServiceRepository _repository = AdminServiceRepository();
  final Set<String> _processing = {};
  late final Stream<List<ServiceModel>> _servicesStream;

  @override
  void initState() {
    super.initState();
    _servicesStream = _repository.watchServices();
  }

  Future<void> _runAction(
    String serviceId,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (!_processing.add(serviceId)) return;
    setState(() {});
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update service: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    } finally {
      _processing.remove(serviceId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editService([ServiceModel? service]) async {
    final edited = await showDialog<ServiceModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceFormDialog(service: service),
    );
    if (edited == null || !mounted) return;
    await _runAction(
      service?.id ?? 'new-service',
      () => service == null
          ? _repository.createService(edited)
          : _repository.updateService(edited),
      service == null ? 'Service added.' : 'Service updated.',
    );
  }

  Future<void> _confirmArchive(ServiceModel service) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.archive_outlined,
          color: Color(0xFFB54708),
        ),
        title: Text(
          service.isArchived ? 'Restore service?' : 'Archive service?',
        ),
        content: Text(
          service.isArchived
              ? 'Restore ${service.title} to the service list? It will remain inactive until you turn it on.'
              : 'Archive ${service.title}? It will no longer appear in customer bookings. Existing reservations will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(service.isArchived ? 'Restore' : 'Archive service'),
          ),
        ],
      ),
    );
    if (shouldArchive != true) return;
    await _runAction(
      service.id,
      () => service.isArchived
          ? _repository.restoreService(service.id)
          : _repository.archiveService(service.id),
      service.isArchived ? 'Service restored.' : 'Service archived.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceModel>>(
      stream: _servicesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFB42318),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Services could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = snapshot.data!;
        final activeCount = services
            .where((service) => service.isActive && !service.isArchived)
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${services.length} services',
                          style: const TextStyle(
                            color: Color(0xFF172B4D),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$activeCount available to customers',
                          style: const TextStyle(
                            color: Color(0xFF74839A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _editService(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add service'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: services.isEmpty
                  ? _emptyServices()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: services.length,
                      itemBuilder: (context, index) =>
                          _serviceCard(services[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyServices() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.local_car_wash_rounded,
                color: Color(0xFF244B77),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Build your service menu',
              style: TextStyle(
                color: Color(0xFF172B4D),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add your first carwash service to make it bookable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF74839A)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _editService(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a service'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(ServiceModel service) {
    final isProcessing = _processing.contains(service.id);
    final availability = service.isArchived
        ? 'ARCHIVED'
        : service.isActive
            ? 'ACTIVE'
            : 'INACTIVE';
    final badgeColor = service.isArchived
        ? const Color(0xFF667085)
        : service.isActive
            ? const Color(0xFF027A48)
            : const Color(0xFFB54708);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE6EBF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _serviceArtwork(service),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        service.description.isEmpty
                            ? 'No service description'
                            : service.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _serviceStatusBadge(availability, badgeColor),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _serviceInfoPill(
                  Icons.payments_outlined,
                  '₱${service.price.toStringAsFixed(2)}',
                ),
                _serviceInfoPill(
                  Icons.schedule_rounded,
                  '${service.durationMinutes} min',
                ),
                _serviceInfoPill(
                  Icons.stars_rounded,
                  '${service.loyaltyPoints} pts',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: service.vehicleTypes.isEmpty
                  ? const [
                      _VehiclePill(label: 'No vehicle types'),
                    ]
                  : service.vehicleTypes.map((type) {
                      final multiplier = service.vehiclePriceMultipliers[type];
                      final label = multiplier == null
                          ? type
                          : '$type · ${multiplier.toStringAsFixed(2)}×';
                      return _VehiclePill(label: label);
                    }).toList(),
            ),
            const SizedBox(height: 14),
            if (service.isArchived)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _confirmArchive(service),
                  icon: const Icon(Icons.unarchive_rounded),
                  label: const Text('Restore service'),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.isActive
                          ? 'Visible in customer booking'
                          : 'Hidden from customer booking',
                      style: TextStyle(
                        color: service.isActive
                            ? const Color(0xFF027A48)
                            : const Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: service.isActive,
                    onChanged: isProcessing
                        ? null
                        : (active) => _runAction(
                              service.id,
                              () => _repository.setActive(service.id, active),
                              active
                                  ? 'Service is now active.'
                                  : 'Service is now inactive.',
                            ),
                    activeTrackColor: const Color(0xFF244B77),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _serviceActionRow(
                secondaryAction: OutlinedButton.icon(
                  onPressed: isProcessing ? null : () => _editService(service),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit service'),
                ),
                primaryAction: OutlinedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _confirmArchive(service),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB54708),
                  ),
                ),
              ),
            ],
            if (isProcessing) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serviceArtwork(ServiceModel service) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 54,
        height: 54,
        child: service.imageUrl.isEmpty
            ? const ColoredBox(
                color: Color(0xFFEAF3FF),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: Color(0xFF244B77),
                  size: 25,
                ),
              )
            : Image.network(
                service.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFEAF3FF),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF667085),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _serviceActionRow({
    required Widget secondaryAction,
    required Widget primaryAction,
  }) {
    return Row(
      children: [
        Expanded(child: SizedBox(height: 48, child: secondaryAction)),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 48, child: primaryAction)),
      ],
    );
  }

  Widget _serviceStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _serviceInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475467)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePill extends StatelessWidget {
  const _VehiclePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF315D89),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({this.service});

  final ServiceModel? service;

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  static const _vehicleOptions = [
    'Sedan',
    'SUV',
    'Truck',
    'Van',
    'Pickup / Van',
    'Motorcycle',
  ];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late final TextEditingController _pointsController;
  late final Map<String, TextEditingController> _multiplierControllers;
  late Set<String> _selectedVehicles;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _titleController = TextEditingController(text: service?.title ?? '');
    _descriptionController =
        TextEditingController(text: service?.description ?? '');
    _priceController =
        TextEditingController(text: service?.price.toString() ?? '');
    _durationController = TextEditingController(
      text: service?.durationMinutes.toString() ?? '30',
    );
    _pointsController = TextEditingController(
      text: service?.loyaltyPoints.toString() ?? '0',
    );
    _selectedVehicles = {...?service?.vehicleTypes};
    _multiplierControllers = {
      for (final vehicle in _vehicleOptions)
        vehicle: TextEditingController(
          text: (service?.vehiclePriceMultipliers[vehicle] ?? 1).toString(),
        ),
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    for (final controller in _multiplierControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one vehicle type.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final multipliers = <String, double>{};
      for (final vehicle in _selectedVehicles) {
        final multiplier =
            double.tryParse(_multiplierControllers[vehicle]!.text.trim());
        if (multiplier == null || !multiplier.isFinite || multiplier <= 0) {
          throw Exception('Enter a valid price multiplier for $vehicle.');
        }
        multipliers[vehicle] = multiplier;
      }

      final service = ServiceModel(
        id: widget.service?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        durationMinutes: int.parse(_durationController.text.trim()),
        vehicleTypes: _vehicleOptions
            .where(_selectedVehicles.contains)
            .toList(growable: false),
        imageUrl: widget.service?.imageUrl ?? '',
        isActive: widget.service?.isActive ?? true,
        isArchived: false,
        loyaltyPoints: int.parse(_pointsController.text.trim()),
        vehiclePriceMultipliers: multipliers,
      );
      if (mounted) Navigator.pop(context, service);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save service: $error'),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _positivePrice(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null || !price.isFinite || price <= 0) {
      return 'Enter a price greater than zero.';
    }
    return null;
  }

  String? _positiveInteger(String? value, String label,
      {bool allowZero = false}) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || (allowZero ? number < 0 : number <= 0)) {
      return allowZero
          ? 'Enter zero or a positive $label.'
          : 'Enter a positive $label.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.service == null ? 'Add service' : 'Edit service'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Service name',
                    hintText: 'Full Body Detailing',
                    prefixIcon: Icon(Icons.local_car_wash_rounded),
                  ),
                  validator: (value) => _requiredText(value, 'Service name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) => _requiredText(value, 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Base price (₱)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: _positivePrice,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        validator: (value) =>
                            _positiveInteger(value, 'duration'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Loyalty points earned',
                    prefixIcon: Icon(Icons.stars_rounded),
                  ),
                  validator: (value) =>
                      _positiveInteger(value, 'points', allowZero: true),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available vehicle types',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap a vehicle to include or remove it.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    return Column(
                      children: [
                        for (final vehicle in _vehicleOptions) ...[
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _VehicleTypeSelector(
                              label: vehicle,
                              selected: _selectedVehicles.contains(vehicle),
                              onTap: _isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        if (_selectedVehicles
                                            .contains(vehicle)) {
                                          _selectedVehicles.remove(vehicle);
                                        } else {
                                          _selectedVehicles.add(vehicle);
                                        }
                                      });
                                    },
                            ),
                          ),
                          if (vehicle != _vehicleOptions.last)
                            const SizedBox(height: gap),
                        ],
                      ],
                    );
                  },
                ),
                if (_selectedVehicles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Vehicle price multipliers',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1.00 keeps base price; 1.20 adds 20%.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._vehicleOptions.where(_selectedVehicles.contains).map(
                        (vehicle) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: _multiplierControllers[vehicle],
                            enabled: !_isSaving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,3}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: '$vehicle multiplier',
                              prefixIcon:
                                  const Icon(Icons.tune_rounded, size: 19),
                            ),
                            validator: (value) {
                              final multiplier =
                                  double.tryParse(value?.trim() ?? '');
                              if (multiplier == null ||
                                  !multiplier.isFinite ||
                                  multiplier <= 0) {
                                return 'Enter a multiplier greater than zero.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Saving' : 'Save service'),
        ),
      ],
    );
  }
}

class _VehicleTypeSelector extends StatelessWidget {
  const _VehicleTypeSelector({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F2FC) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? const Color(0xFF3974A8) : const Color(0xFF98AFC4),
          width: selected ? 1.6 : 1.2,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: onTap == null ? null : (_) => onTap!(),
        activeColor: const Color(0xFF244B77),
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.standard,
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF172B4D),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
