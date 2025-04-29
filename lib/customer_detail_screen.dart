import 'package:driver_app/enter_the_bal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
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

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _supabase = Supabase.instance.client;
  double balance = 0.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('credit, paid, balance')
          .eq('user_id', widget.customerId);

      double totalCredit = 0.0;
      double totalPaid = 0.0;
      for (var t in transactionsResponse) {
        totalCredit += (t['credit']?.toDouble() ?? 0.0);
        totalPaid += (t['paid']?.toDouble() ?? 0.0);
      }
      setState(() {
        balance = totalCredit - totalPaid;
      });
    } catch (e) {
      setState(() {
        balance = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load balance: $e')),
      );
    }
  }

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

  void _showPaymentDialog() {
    final TextEditingController amountController = TextEditingController();
    String? selectedPaymentMode;
    final List<String> paymentModes = ['Cash', 'UPI', 'Bank Transfer'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Payment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Collected (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPaymentMode,
                decoration: const InputDecoration(
                  labelText: 'Mode of Payment',
                  border: OutlineInputBorder(),
                ),
                items: paymentModes.map((mode) {
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedPaymentMode = value;
                },
                validator: (value) =>
                    value == null ? 'Please select a payment mode' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final amountText = amountController.text.trim();
                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    if (selectedPaymentMode == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select a mode of payment')),
                      );
                      return;
                    }
                    if (amount > balance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Amount cannot exceed current balance')),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      final newBalance = balance - amount;
                      await _supabase.from('transactions').insert({
                        'user_id': widget.customerId,
                        'date': DateTime.now().toIso8601String(),
                        'credit': 0.0,
                        'paid': amount,
                        'balance': newBalance,
                        'mode_of_payment': selectedPaymentMode,
                      });

                      setState(() {
                        balance = newBalance;
                        isLoading = false;
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment recorded successfully')),
                      );
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to record payment: $e')),
                      );
                    }
                  },
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Done'),
          ),
        ],
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
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Bal: ₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () =>
                        _showImageDialog(context, widget.profileImageUrl),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.profileImageUrl.isNotEmpty
                          ? NetworkImage(widget.profileImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: widget.profileImageUrl.isEmpty
                          ? const Icon(Icons.person,
                              size: 40, color: Colors.black54)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _showImageDialog(context, widget.shopImageUrl),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.shopImageUrl.isNotEmpty
                          ? NetworkImage(widget.shopImageUrl)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: widget.shopImageUrl.isEmpty
                          ? const Icon(Icons.shopping_cart,
                              size: 40, color: Colors.black54)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _infoCard(Icons.person_outline, 'Name', widget.name),
              const SizedBox(height: 16),
              _infoCard(Icons.email_outlined, 'Email', widget.email),
              const SizedBox(height: 16),
              _infoCard(Icons.phone_outlined, 'Phone', widget.number),
              const SizedBox(height: 16),
              _infoCard(Icons.location_on_outlined, 'Area', widget.area),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateCreditScreen(
                          customerId: widget.customerId,
                          customerName: widget.name,
                        ),
                      ),
                    ).then((_) => _loadBalance());
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: balance > 0 ? _showPaymentDialog : null,
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
