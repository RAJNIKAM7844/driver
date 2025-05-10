import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateCreditScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const UpdateCreditScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<UpdateCreditScreen> createState() => _UpdateCreditScreenState();
}

class _UpdateCreditScreenState extends State<UpdateCreditScreen> {
  final TextEditingController traysController = TextEditingController();
  double balance = 0.0;
  int crateQuantity = 0;
  bool isLoading = false;
  bool isCustomer = false;
  String? errorMessage;
  final _supabase = Supabase.instance.client;
  String? driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
    _checkCustomerRole();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverId = prefs.getString('driverId');
    });
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

  Future<bool> _checkAndUpdateTrayQuantity(int trays) async {
    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver not identified')),
      );
      return false;
    }

    try {
      final response = await _supabase
          .from('tray_quantities')
          .select('quantity')
          .eq('driver_id', int.parse(driverId!))
          .maybeSingle();

      final currentQuantity = response?['quantity']?.toInt() ?? 0;

      if (currentQuantity < trays) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough trays available')),
        );
        return false;
      }

      await _supabase.from('tray_quantities').update({
        'quantity': currentQuantity - trays,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('driver_id', int.parse(driverId!));

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating tray quantity: $e')),
      );
      return false;
    }
  }

  void updateBalance() async {
    final traysText = traysController.text.trim();
    if (traysText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the number of trays')),
      );
      return;
    }

    final trays = int.tryParse(traysText);
    if (trays == null || trays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of trays')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final traysUpdated = await _checkAndUpdateTrayQuantity(trays);
      if (!traysUpdated) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final eggRateResponse = await _supabase
          .from('egg_rates')
          .select('rate')
          .order('updated_at', ascending: false)
          .limit(1);

      double eggPrice;
      if (eggRateResponse.isEmpty) {
        eggPrice = 10.0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No egg rate found, using default rate')),
        );
      } else {
        eggPrice = eggRateResponse[0]['rate'].toDouble();
      }

      final cost = (eggPrice * 30) * trays;
      final newBalance = balance + cost;

      await _supabase.from('transactions').insert({
        'user_id': widget.customerId,
        'date': DateTime.now().toIso8601String(),
        'credit': cost,
        'paid': 0.0,
        'balance': newBalance,
        'mode_of_payment': 'Pending',
      });

      setState(() {
        balance = newBalance;
        traysController.clear();
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update balance: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (isCustomer) {
      _supabase.channel('transactions_${widget.customerId}').unsubscribe();
      _supabase.channel('crates_${widget.customerId}').unsubscribe();
    }
    traysController.dispose();
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
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
                        vertical: constraints.maxHeight * 0.03,
                        horizontal: constraints.maxWidth * 0.04,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
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
                    CircleAvatar(
                      radius: constraints.maxWidth * 0.12,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.04),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customerName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.01),
                          Text(
                            'Crates: $crateQuantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.01),
                          const Text(
                            'Enter the No of trays purchased',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.015),
                          Container(
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
                            child: TextField(
                              controller: traysController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Number of trays',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.05),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.05),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : updateBalance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.03),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
