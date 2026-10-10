class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int pointsCost;
  final int stock;
  final int reservedStock;
  final String
      category; // e.g., 'Shampoo', 'Microfiber', 'Air Freshener', 'Wax'
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.pointsCost,
    required this.stock,
    this.reservedStock = 0,
    required this.category,
    this.imageUrl = '',
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      pointsCost: map['pointsCost'] ?? 0,
      stock: map['stock'] ?? 0,
      reservedStock: map['reservedStock'] ?? 0,
      category: map['category'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  int get availableStock => (stock - reservedStock).clamp(0, stock);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'pointsCost': pointsCost,
      'stock': stock,
      'reservedStock': reservedStock,
      'category': category,
      'imageUrl': imageUrl,
    };
  }
}
