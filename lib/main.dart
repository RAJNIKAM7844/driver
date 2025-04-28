import 'package:driver_app/drivers_home.dart';
import 'package:driver_app/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://kwoxhpztkxzqetwanlxx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3b3hocHp0a3h6cWV0d2FubHh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxMjQyMTAsImV4cCI6MjA2MDcwMDIxMH0.jEIMSnX6-uEA07gjnQKdEXO20Zlpw4XPybfeLQr7W-M',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  String? driverId;
  String? driverName;
  String? areaName;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDriverId = prefs.getString('driverId');
    final storedDriverName = prefs.getString('driverName');
    final storedAreaName = prefs.getString('areaName');

    if (storedDriverId != null &&
        storedDriverName != null &&
        storedAreaName != null) {
      setState(() {
        isLoggedIn = true;
        driverId = storedDriverId;
        driverName = storedDriverName;
        areaName = storedAreaName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn
          ? DriverAssignedCustomersScreen(
              driverId: driverId!,
              driverName: driverName!,
              areaName: areaName!,
            )
          : const DriverLoginScreen(),
    );
  }
}
