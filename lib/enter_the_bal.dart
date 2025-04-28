import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _setupRealtimeSubscription();
  }

  Future<void> _loadBalance() async {
    try {
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('credit')
          .eq('user_id', widget.customerId);

      print(
          'Initial transactions fetch for customerId ${widget.customerId}: $transactionsResponse');

      setState(() {
        balance = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
      });

      print('Updated balance (sum of credits) in UpdateCreditScreen: $balance');
    } catch (e) {
      print('Error fetching balance for customerId ${widget.customerId}: $e');
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
            print(
                'Real-time transaction update for customerId ${widget.customerId}: $payload');
            _loadBalance();
          },
        )
        .subscribe();
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
      // Fetch the latest egg price from eggs_rates table
      final eggRateResponse = await _supabase
          .from('egg_rates')
          .select('rate')
          .order('updated_at', ascending: false)
          .limit(1);

      print('Egg rate response: $eggRateResponse');

      double eggPrice;
      if (eggRateResponse.isEmpty) {
        // Fallback to default rate
        eggPrice = 10.0; // Adjust default rate as needed
        print('No egg rate found, using default rate: $eggPrice');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No egg rate found, using default rate')),
        );
      } else {
        eggPrice = eggRateResponse[0]['rate'].toDouble();
        print('Fetched egg price: $eggPrice per egg');
      }

      // Calculate the cost: (egg_price * 30) * trays
      final cost = (eggPrice * 30) * trays;
      final newBalance = balance + cost;

      // Insert a new transaction in the transactions table
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
      print('Error updating balance for customerId ${widget.customerId}: $e');
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
