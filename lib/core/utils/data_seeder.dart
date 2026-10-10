import 'package:cloud_firestore/cloud_firestore.dart';

class DataSeeder {
  static Future<void> seedInitialData() async {
    final firestore = FirebaseFirestore.instance;

    final existingServices = await firestore.collection('services').get();
    if (existingServices.docs.isNotEmpty) {
      return;
    }

    final services = [
      {
        'title': 'Express Body Wash',
        'description': 'Exterior body wash, tire dress, and window cleaning.',
        'price': 150.0,
        'durationMinutes': 25,
        'vehicleTypes': ['Sedan', 'SUV', 'Pickup / Van', 'Motorcycle'],
        'imageUrl': '',
        'isActive': true,
      },
      {
        'title': 'Complete Interior & Exterior Detailing',
        'description':
            'Full vacuum, carpet shampoo, engine bay cleaning, and body wax.',
        'price': 500.0,
        'durationMinutes': 60,
        'vehicleTypes': ['Sedan', 'SUV', 'Pickup / Van'],
        'imageUrl': '',
        'isActive': true,
      },
      {
        'title': 'Ceramic Coating Protection',
        'description': 'Paint protection coating with hydrophobic finish.',
        'price': 1200.0,
        'durationMinutes': 120,
        'vehicleTypes': ['Sedan', 'SUV', 'Pickup / Van'],
        'imageUrl': '',
        'isActive': true,
      },
    ];

    for (var service in services) {
      await firestore.collection('services').add(service);
    }

    final products = [
      {
        'name': 'Premium Car Shampoo 1L',
        'description': 'High-foam pH neutral car wash soap.',
        'price': 250.0,
        'pointsCost': 50,
        'stock': 15,
        'category': 'Shampoo',
        'imageUrl': '',
      },
      {
        'name': 'Microfiber Towel Set (3pcs)',
        'description': 'Ultra-soft 800GSM drying towels.',
        'price': 180.0,
        'pointsCost': 35,
        'stock': 20,
        'category': 'Microfiber',
        'imageUrl': '',
      },
      {
        'name': 'Organic Citrus Air Freshener',
        'description': 'Long-lasting car scent canister.',
        'price': 120.0,
        'pointsCost': 25,
        'stock': 30,
        'category': 'Air Freshener',
        'imageUrl': '',
      },
      {
        'name': 'Liquid Carnauba Body Wax',
        'description': 'Deep shine & paint protection wax.',
        'price': 350.0,
        'pointsCost': 70,
        'stock': 10,
        'category': 'Wax',
        'imageUrl': '',
      },
    ];

    for (var product in products) {
      await firestore.collection('products').add(product);
    }
  }
}
