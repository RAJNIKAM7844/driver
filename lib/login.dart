import 'package:driver_app/drivers_home.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both username and password';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await supabase
          .from('drivers')
          .select(
              'id, driver_name, username, password, delivery_areas!area_id(area_name)')
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        setState(() {
          errorMessage = 'Username not found';
        });
      } else {
        if (response['password'] == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('driverId', response['id'].toString());
          await prefs.setString('driverName', response['driver_name']);
          await prefs.setString(
              'areaName', response['delivery_areas']['area_name']);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverAssignedCustomersScreen(
                driverId: response['id'].toString(),
                driverName: response['driver_name'],
                areaName: response['delivery_areas']['area_name'],
              ),
            ),
          );
        } else {
          setState(() {
            errorMessage = 'Incorrect password';
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred. Please try again.';
      });
      print('Login error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.06,
                vertical: constraints.maxHeight * 0.04,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Driver Login',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF1976D2),
                        ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.06),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.03),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  SizedBox(height: constraints.maxHeight * 0.03),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login'),
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
}
