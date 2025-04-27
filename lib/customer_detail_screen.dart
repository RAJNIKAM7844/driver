import 'package:driver_app/enter_the_bal.dart';
import 'package:flutter/material.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId; // For navigating to UpdateCreditScreen
  final String name;
  final String number;
  final String area;
  final String profileImageUrl;
  final String shopImageUrl;
  final String email;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.name,
    required this.number,
    required this.area,
    required this.profileImageUrl,
    required this.shopImageUrl,
    required this.email,
  });

  void _showImageDialog(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 211, 211, 211),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF1976D2),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Customer Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Profile and Shop Images
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showImageDialog(context, profileImageUrl),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: profileImageUrl.isEmpty
                          ? const Icon(Icons.person,
                              size: 40, color: Colors.black54)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _showImageDialog(context, shopImageUrl),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: shopImageUrl.isNotEmpty
                          ? NetworkImage(shopImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: shopImageUrl.isEmpty
                          ? const Icon(Icons.shopping_cart,
                              size: 40, color: Colors.black54)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Customer Info Cards
              _infoCard(Icons.person_outline, 'Name', name),
              const SizedBox(height: 16),
              _infoCard(Icons.email_outlined, 'Email', email),
              const SizedBox(height: 16),
              _infoCard(Icons.phone_outlined, 'Phone',
                  number), // Added phone number display
              const SizedBox(height: 16),
              _infoCard(Icons.location_on_outlined, 'Area', area),
              const SizedBox(height: 40),

              // Update Credit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateCreditScreen(
                          customerId: customerId,
                          customerName: name,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E5A),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Update Credit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Warning Text
              const Text(
                'Check all the details before clicking on payment',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Payment Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement payment logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E5A),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 24),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
