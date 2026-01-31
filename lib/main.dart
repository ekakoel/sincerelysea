import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// Pastikan baris ini tidak error setelah menjalankan 'flutterfire configure'
// import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Jika sudah ada firebase_options.dart, ubah menjadi:
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Pastikan google-services.json ada di android/app/ sebelum mengaktifkan ini
    await Firebase.initializeApp(); 
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const SincerelyseaApp());
}

class SincerelyseaApp extends StatelessWidget {
  const SincerelyseaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sincerelysea',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Sincerelysea',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
