import 'package:driver_app/enter_the_bal.dart';
import 'package:driver_app/qrpayment.dart';
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
  int crateQuantity = 0;
  bool isLoading = false;
  bool isCustomer = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCustomerRole();
  }

  Future<void> _checkCustomerRole() async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', widget.customerId)
          .single();

      if (response['role'] == 'customer') {
        setState(() {
          isCustomer = true;
        });
        _loadBalance();
        _loadCrateQuantity();
        _setupRealtimeSubscription();
        _setupRealtimeCrateSubscription();
      } else {
        setState(() {
          errorMessage = 'This user is not a customer.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error verifying customer role: $e';
      });
    }
  }

  Future<void> _loadBalance() async {
    try {
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('credit, paid')
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

  Future<void> _loadCrateQuantity() async {
    try {
      final response = await _supabase
          .from('crates')
          .select('quantity')
          .eq('user_id', widget.customerId)
          .maybeSingle();

      setState(() {
        crateQuantity = response?['quantity']?.toInt() ?? 0;
      });
    } catch (e) {
      setState(() {
        crateQuantity = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching crate quantity: $e')),
      );
    }
  }

  void _setupRealtimeSubscription() {
    _supabase
        .channel('transactions_${widget.customerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.customerId,
          ),
          callback: (payload) {
            _loadBalance();
          },
        )
        .subscribe();
  }

  void _setupRealtimeCrateSubscription() {
    _supabase
        .channel('crates_${widget.customerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'crates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.customerId,
          ),
          callback: (payload) {
            _loadCrateQuantity();
          },
        )
        .subscribe();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Payment Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Collected (₹)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPaymentMode,
                decoration: InputDecoration(
                  labelText: 'Mode of Payment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Done',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  void _showUpdateCrateDialog() {
    final TextEditingController crateController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Update Crate Quantity',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Crates: $crateQuantity',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: crateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Crate Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final crateText = crateController.text.trim();
                    final cratesToUpdate = int.tryParse(crateText);
                    if (cratesToUpdate == null || cratesToUpdate < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please enter a valid non-negative number of crates')),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      await _supabase.from('crates').upsert({
                        'user_id': widget.customerId,
                        'quantity': cratesToUpdate,
                        'updated_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'user_id');

                      setState(() {
                        crateQuantity = cratesToUpdate;
                        isLoading = false;
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Crate quantity updated successfully')),
                      );
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Failed to update crate quantity: $e')),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Update',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (isCustomer) {
      _supabase.channel('transactions_${widget.customerId}').unsubscribe();
      _supabase.channel('crates_${widget.customerId}').unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isCustomer) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.04,
                vertical: constraints.maxHeight * 0.02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1976D2),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: constraints.maxHeight * 0.02,
                      horizontal: constraints.maxWidth * 0.04,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Customer Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Bal: ₹${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.03),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _showImageDialog(context, widget.profileImageUrl),
                        child: CircleAvatar(
                          radius: constraints.maxWidth * 0.1,
                          backgroundImage: widget.profileImageUrl.isNotEmpty
                              ? NetworkImage(widget.profileImageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: widget.profileImageUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.black54)
                              : null,
                        ),
                      ),
                      SizedBox(width: constraints.maxWidth * 0.05),
                      GestureDetector(
                        onTap: () =>
                            _showImageDialog(context, widget.shopImageUrl),
                        child: CircleAvatar(
                          radius: constraints.maxWidth * 0.1,
                          backgroundImage: widget.shopImageUrl.isNotEmpty
                              ? NetworkImage(widget.shopImageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: widget.shopImageUrl.isEmpty
                              ? const Icon(Icons.store,
                                  size: 40, color: Colors.black54)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: constraints.maxHeight * 0.04),
                  _infoCard(
                      Icons.person_outline, 'Name', widget.name, constraints),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  _infoCard(
                      Icons.email_outlined, 'Email', widget.email, constraints),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  _infoCard(Icons.phone_outlined, 'Phone', widget.number,
                      constraints),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  _infoCard(Icons.location_on_outlined, 'Area', widget.area,
                      constraints),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  _infoCard(Icons.inventory_2_outlined, 'Crates',
                      crateQuantity.toString(), constraints),
                  SizedBox(height: constraints.maxHeight * 0.04),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showUpdateCrateDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Update Crates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
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
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Update Credit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  const Center(
                    child: Text(
                      'Check all the details before clicking on payment',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: balance > 0 ? _showPaymentDialog : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'QR Payments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard(
      IconData icon, String label, String value, BoxConstraints constraints) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 24),
          SizedBox(width: constraints.maxWidth * 0.03),
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
