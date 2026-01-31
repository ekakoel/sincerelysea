import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const SincerelyseaApp());
}

class SincerelyseaApp extends StatefulWidget {
  const SincerelyseaApp({super.key});

  @override
  State<SincerelyseaApp> createState() => _SincerelyseaAppState();
}

class _SincerelyseaAppState extends State<SincerelyseaApp> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sincerelysea',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Home')),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Signed in as: ${snapshot.data!.email ?? snapshot.data!.displayName}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async => await _auth.signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const LoginPage();
        },
      ),
    );
  }
}
