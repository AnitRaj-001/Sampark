// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sampark/home_page.dart';
import 'package:sampark/screens/auth_screen.dart';
import 'package:sampark/screens/chat_screen.dart';
import 'package:sampark/screens/search_screen.dart';
import 'package:sampark/controller/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      initialBinding: BindingsBuilder(() {
        Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
      }),
      getPages: [
        GetPage(name: '/auth', page: () => const AuthScreen()),
        GetPage(name: '/home', page: () => const HomePage()),
        GetPage(name: '/chat', page: () => const ChatScreen()),
        GetPage(name: '/search', page: () => const SearchScreen()),
      ],
      initialRoute: '/auth',
      home: FutureBuilder(
        future: Firebase.initializeApp(), // Ensure Firebase is ready
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final authController = Get.find<AuthController>();
          return Obx(() {
            if (authController.currentUser.value == null) {
              return const AuthScreen();
            } else {
              return const HomePage();
            }
          });
        },
      ),
    );
  }
}