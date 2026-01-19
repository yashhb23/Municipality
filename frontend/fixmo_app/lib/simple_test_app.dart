import 'package:flutter/material.dart';

/// Ultra-simple test app to verify Flutter is working
class SimpleTestApp extends StatelessWidget {
  const SimpleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixMo Test',
      debugShowCheckedModeBanner: false,
      home: const SimpleTestScreen(),
    );
  }
}

class SimpleTestScreen extends StatelessWidget {
  const SimpleTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: const Text('FixMo Working!'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 120,
              color: Colors.white,
            ),
            SizedBox(height: 30),
            Text(
              '🎉 SUCCESS! 🎉',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'FixMo Flutter App is Running!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Your Android Virtual Device is working correctly',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Text(
              '🇲🇺 Ready for Mauritius! 🇲🇺',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 