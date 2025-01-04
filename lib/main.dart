import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screens/Calculator/bonus_calculator.dart';
import 'Screens/Profile/user_profile_screen.dart';
import 'Screens/Progress/progress_screen.dart';
import 'Screens/Settings/settings_screen.dart';
import 'Services/auth_service.dart';
import 'Providers/language_provider.dart';
import 'Providers/theme_provider.dart';
import 'Screens/Auth/login_page.dart';
import 'Screens/Auth/registration_screen.dart';
import 'Screens/Auth/reset_password_page.dart';
import 'widgets/onboarding_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        if (languageProvider.isLoading) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'Bonifatus',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            brightness: Brightness.dark,
          ),
          themeMode: themeProvider.themeMode,
          home: const MainAppScreen(), // No ChangeNotifierProvider here
          routes: {
            '/home': (context) => const MainAppScreen(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegistrationPage(),
            '/reset-password': (context) => const ResetPasswordPage(),
          },
        );
      },
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;
  bool _showTutorial = false;
  final AuthService _authService = AuthService();
  bool isLoggedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No _languageProvider initialization here
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      bool loggedIn = await _authService.isLoggedIn();
      if (mounted) {
        setState(() {
          isLoggedIn = loggedIn;
        });
      }
    } catch (e) {
      print('Error checking login status: $e');
    }
  }

  void _showOnboardingTutorial() {
    setState(() => _showTutorial = true);
  }

  Widget _buildProfileSection() {
    return const UserProfileScreen();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.translate('bonifatus')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: languageProvider.translate('how_it_works'),
            onPressed: _showOnboardingTutorial,
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              const BonusCalculator(),
              Consumer<LanguageProvider>(
                builder: (context, provider, _) => const ProgressScreen(),
              ),
              const SettingsScreen(),
              _buildProfileSection(),
            ],
          ),
          if (_showTutorial)
            OnboardingOverlay(
              onComplete: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.calculate),
            label: languageProvider.translate('bonus_calculator'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.trending_up),
            label: languageProvider.translate('progress'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: languageProvider.translate('settings'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: languageProvider.translate('profile'),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}