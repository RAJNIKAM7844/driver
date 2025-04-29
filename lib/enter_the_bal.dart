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
  bool isLoading = false;
  final _supabase = Supabase.instance.client;
  String? driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
    _loadBalance();
    _setupRealtimeSubscription();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      driverId = prefs.getString('driverId');
    });
  }

  Future<void> _loadBalance() async {
    try {
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('credit')
          .eq('user_id', widget.customerId);

      setState(() {
        balance = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
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

  void _setupRealtimeSubscription() {
    _supabase
        .channel('transactions')
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
    _supabase.channel('transactions').unsubscribe();
    traysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Container(
                  height: 150,
                  color: const Color(0xFF1976D2),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
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
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter the No of trays purchased',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: traysController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement admin logic
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E5A),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : updateBalance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E5A),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
