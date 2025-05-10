import 'package:driver_app/customer_detail_screen.dart';
import 'package:driver_app/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverAssignedCustomersScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String areaName;

  const DriverAssignedCustomersScreen({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.areaName,
  });

  @override
  State<DriverAssignedCustomersScreen> createState() =>
      _DriverAssignedCustomersScreenState();
}

class _DriverAssignedCustomersScreenState
    extends State<DriverAssignedCustomersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  bool isLoading = false;
  int trayQuantity = 0;
  int totalCrates = 0;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAssignedCustomers();
    fetchTrayQuantity();
    setupRealtimeTraySubscription();
  }

  Future<void> fetchAssignedCustomers() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await supabase
          .from('users')
          .select(
              'id, full_name, location, phone, profile_image, shop_image, email')
          .eq('location', widget.areaName)
          .eq('role', 'customer')
          .order('full_name', ascending: true);

      setState(() {
        customers = List<Map<String, dynamic>>.from(response);
        filteredCustomers = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
      await fetchTotalCrates();
      if (customers.isNotEmpty) {
        setupRealtimeCrateSubscription();
      }
    } catch (e) {
      setState(() {
        customers = [];
        filteredCustomers = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching customers: $e')),
      );
    }
  }

  Future<void> fetchTrayQuantity() async {
    try {
      final response = await supabase
          .from('tray_quantities')
          .select('quantity')
          .eq('driver_id', int.parse(widget.driverId))
          .maybeSingle();

      setState(() {
        trayQuantity = response?['quantity']?.toInt() ?? 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching tray quantity: $e')),
      );
    }
  }

  Future<void> fetchTotalCrates() async {
    if (customers.isEmpty) {
      setState(() {
        totalCrates = 0;
      });
      return;
    }

    try {
      final response = await supabase
          .from('crates')
          .select('quantity')
          .inFilter('user_id', customers.map((c) => c['id']).toList());

      int total = 0;
      for (var item in response) {
        total += ((item['quantity'] as num?)?.toInt() ?? 0);
      }
      setState(() {
        totalCrates = total;
      });
    } catch (e) {
      setState(() {
        totalCrates = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching crate quantity: $e')),
      );
    }
  }

  void setupRealtimeTraySubscription() {
    supabase
        .channel('tray_quantities_${widget.driverId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tray_quantities',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: widget.driverId,
          ),
          callback: (payload) {
            fetchTrayQuantity();
          },
        )
        .subscribe();
  }

  void setupRealtimeCrateSubscription() {
    supabase
        .channel('crates_${widget.areaName}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'crates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'user_id',
            value: customers.map((c) => c['id']).toList(),
          ),
          callback: (payload) {
            fetchTotalCrates();
          },
        )
        .subscribe();
  }

  void filterCustomers(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredCustomers = customers.where((customer) {
        final name = customer['full_name']?.toLowerCase() ?? '';
        final area = customer['location']?.toLowerCase() ?? '';
        return name.contains(lowerQuery) || area.contains(lowerQuery);
      }).toList();
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driverId');
    await prefs.remove('driverName');
    await prefs.remove('areaName');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }

  Widget buildCustomerItem(
      Map<String, dynamic> customer, BoxConstraints constraints) {
    final imageUrl = customer['profile_image'] ?? '';
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: constraints.maxHeight * 0.01,
        horizontal: constraints.maxWidth * 0.04,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(
                  customerId: customer['id'],
                  name: customer['full_name'] ?? 'Unknown',
                  number: customer['phone'] ?? 'N/A',
                  area: customer['location'] ?? '-',
                  profileImageUrl: customer['profile_image'] ?? '',
                  shopImageUrl: customer['shop_image'] ?? '',
                  email: customer['email'] ?? 'N/A',
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: constraints.maxHeight * 0.02,
              horizontal: constraints.maxWidth * 0.04,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: constraints.maxWidth * 0.06,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          color: Colors.black54,
                          size: 24,
                        )
                      : null,
                ),
                SizedBox(width: constraints.maxWidth * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: constraints.maxHeight * 0.005),
                      Text(
                        customer['location'] ?? '-',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.black54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
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
                    vertical: constraints.maxHeight * 0.04,
                    horizontal: constraints.maxWidth * 0.06,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome ${widget.driverName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.01),
                          Text(
                            'Trays: $trayQuantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.005),
                          Text(
                            'Total Crates: $totalCrates',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout,
                            color: Colors.white, size: 28),
                        onPressed: _logout,
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.04,
                    vertical: constraints.maxHeight * 0.01,
                  ),
                  child: Container(
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
                      controller: searchController,
                      onChanged: filterCustomers,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search by name or address',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await fetchAssignedCustomers();
                      await fetchTrayQuantity();
                      await fetchTotalCrates();
                    },
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredCustomers.isEmpty
                            ? const Center(
                                child: Text(
                                  'No customers assigned to this driver.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                    vertical: constraints.maxHeight * 0.01),
                                itemCount: filteredCustomers.length,
                                itemBuilder: (context, index) {
                                  return buildCustomerItem(
                                      filteredCustomers[index], constraints);
                                },
                              ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    supabase.channel('tray_quantities_${widget.driverId}').unsubscribe();
    supabase.channel('crates_${widget.areaName}').unsubscribe();
    super.dispose();
  }
}
