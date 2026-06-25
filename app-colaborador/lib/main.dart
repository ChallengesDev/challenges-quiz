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
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xffFAF9F6),
          primaryColor: const Color(0xff6B5FD3),
          cardColor: const Color(0xffFFFFFF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xff6B5FD3),
            secondary: Color(0xff3B7DD8),
            background: Color(0xffFAF9F6),
            surface: Color(0xffFFFFFF),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xff2D2D3A),
            onBackground: Color(0xff2D2D3A),
          ),
          fontFamily: 'Outfit',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Color(0xff2D2D3A)),
            bodyMedium: TextStyle(color: Color(0xff6B6B76)),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xffFAF9F6),
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xff2D2D3A)),
            titleTextStyle: TextStyle(
              color: Color(0xff2D2D3A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xffFFFFFF),
            selectedItemColor: Color(0xff6B5FD3),
            unselectedItemColor: Color(0xff6B6B76),
            elevation: 8,
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
