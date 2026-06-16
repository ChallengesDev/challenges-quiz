import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/notifications_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/result_screen.dart';
import 'screens/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase with company backend database
    await Supabase.initialize(
      url: 'https://oxnuoppzgcgxqbkkkibr.supabase.co',
      anonKey: 'sb_publishable_aaOtHDYiI0nMQARVfNvf2g_IiCaCfwi',
    );
  } catch (e) {
    print('Supabase initialization failed, falling back to mock: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: MaterialApp(
        title: 'Challenges Quiz',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xff0b0f19),
          primaryColor: const Color(0xff6c5ce7),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xff6c5ce7),
            secondary: Color(0xff00f5d4),
            background: Color(0xff0b0f19),
            surface: Color(0xff151c2c),
            onPrimary: Colors.white,
            onSecondary: Colors.black,
          ),
          fontFamily: 'Outfit',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff0b0f19),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xff151c2c),
            selectedItemColor: Color(0xff00f5d4),
            unselectedItemColor: Colors.white54,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/quiz': (context) => const QuizScreen(),
          '/result': (context) => const ResultScreen(),
          '/notifications': (context) => const NotificationsScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff00f5d4)),
          ),
        ),
      );
    }

    if (authProvider.isAuthenticated && authProvider.colaborador != null) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
