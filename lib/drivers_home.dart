import 'package:driver_app/customer_detail_screen.dart';
import 'package:driver_app/login.dart';
import 'package:flutter/material.dart';
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
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAssignedCustomers();
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
          .order('full_name', ascending: true);

      setState(() {
        customers = List<Map<String, dynamic>>.from(response);
        filteredCustomers = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
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

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }

  Widget buildCustomerItem(Map<String, dynamic> customer) {
    final imageUrl = customer['profile_image'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey.shade300,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer['full_name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
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
      backgroundColor: const Color.fromARGB(255, 181, 182, 183),
      body: SafeArea(
        child: Column(
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
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome ${widget.driverName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
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
                child: TextField(
                  controller: searchController,
                  onChanged: filterCustomers,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search by name or address',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await fetchAssignedCustomers();
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              return buildCustomerItem(
                                  filteredCustomers[index]);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
