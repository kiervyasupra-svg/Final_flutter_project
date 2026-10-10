import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  // CLOUDINARY CONFIGURATION
  final String _cloudName = 'o5axyuxi';
  final String _uploadPreset = 'carwash_presets';

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<String> _uploadToCloudinary(File imageFile) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Receipt upload failed (${response.statusCode}). Please try again.',
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final receiptUrl = responseData['secure_url'];
    if (receiptUrl is! String || receiptUrl.isEmpty) {
      throw Exception('Receipt upload did not return a valid image URL.');
    }
    return receiptUrl;
  }

  Future<void> _submitTopUpRequest() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;

    if (user == null) return;

    final String amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid top-up amount.')),
      );
      return;
    }

    final selectedImage = _selectedImage;
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please upload a screenshot of your payment receipt.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. Upload receipt image
      final String downloadUrl = await _uploadToCloudinary(selectedImage);

      // 2. Add Top-Up request record to Firestore
      await FirebaseFirestore.instance.collection('topups').add({
        'userId': user.uid,
        'userName': user.name,
        'amount': amount,
        'receiptUrl': downloadUrl,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _selectedImage = null;
        _amountController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Top-Up Request submitted successfully! Pending admin approval.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit top-up: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final user = authController.currentUser;
    final double balance = user == null ? 0.0 : user.walletBalance;
    final int points = user == null ? 0 : user.rewardPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Wallet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Card Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF4A6572),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Wallet Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$points Reward Points',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Top-Up Request Form Section
            const Text(
              'Top-Up Request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send GCash/Bank payment, enter the amount below, and upload payment receipt screenshot for verification.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.payments_outlined),
                labelText: 'Amount (₱)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Selection Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickReceiptImage,
                icon: Icon(
                  _selectedImage != null
                      ? Icons.check_circle
                      : Icons.upload_file,
                  color: _selectedImage != null ? Colors.green : null,
                ),
                label: Text(
                  _selectedImage != null
                      ? 'Receipt Selected ✓'
                      : 'Select Receipt Image',
                  style: TextStyle(
                    color: _selectedImage != null ? Colors.green : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitTopUpRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Top-Up Request',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
