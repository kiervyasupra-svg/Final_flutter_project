class ServiceModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final int durationMinutes;
  final List<String> vehicleTypes;
  final String imageUrl;
  final bool isActive;
  final bool isArchived;
  final int loyaltyPoints;
  final Map<String, double> vehiclePriceMultipliers;

  ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.vehicleTypes,
    this.imageUrl = '',
    this.isActive = true,
    this.isArchived = false,
    this.loyaltyPoints = 0,
    this.vehiclePriceMultipliers = const {},
  });

  factory ServiceModel.fromMap(String id, Map<String, dynamic> map) {
    final rawMultipliers = map['vehiclePriceMultipliers'];
    final multipliers = <String, double>{};
    if (rawMultipliers is Map) {
      for (final entry in rawMultipliers.entries) {
        if (entry.value is num) {
          multipliers[entry.key.toString()] = (entry.value as num).toDouble();
        }
      }
    }
    final rawVehicleTypes = map['vehicleTypes'];
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    return ServiceModel(
      id: id,
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      price: price,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      vehicleTypes: rawVehicleTypes is List
          ? rawVehicleTypes.map((value) => value.toString()).toList()
          : const [],
      imageUrl: (map['imageUrl'] ?? '').toString(),
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      isArchived: map['isArchived'] is bool ? map['isArchived'] as bool : false,
      loyaltyPoints:
          (map['loyaltyPoints'] as num?)?.toInt() ?? (price / 20).floor(),
      vehiclePriceMultipliers: multipliers,
    );
  }

  double priceForVehicle(String vehicleType) =>
      price * (vehiclePriceMultipliers[vehicleType] ?? 1);

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
      'vehicleTypes': vehicleTypes,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'isArchived': isArchived,
      'loyaltyPoints': loyaltyPoints,
      'vehiclePriceMultipliers': vehiclePriceMultipliers,
    };
  }
}
