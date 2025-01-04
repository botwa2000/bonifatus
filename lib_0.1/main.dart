import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screens/Calculator/bonus_calculator.dart';
import 'Screens/Profile/user_profile_screen.dart';
import 'Screens/Settings/settings_screen.dart';
import 'Services/auth_service.dart';
import 'Providers/language_provider.dart';
import 'Providers/theme_provider.dart';
import 'Screens/Auth/login_page.dart';
import 'Screens/Auth/registration_screen.dart';
import 'Screens/Auth/reset_password_page.dart';

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
          return MaterialApp(
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
          home: languageProvider.initialized
              ? const MainAppScreen()
              : const Center(child: CircularProgressIndicator()),
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
        title: const Text('Bonifatus'),
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
              const Center(child: Text('Progress Screen - To be implemented')),
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

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  _OnboardingOverlayState createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  _TutorialStep(
                    icon: Icons.stars,
                    title: 'Turn Grades into Rewards',
                    description: 'Bonifatus helps you earn rewards for your academic achievements. Every good grade counts towards your bonus points which can be converted into real rewards!',
                  ),
                  _TutorialStep(
                    icon: Icons.calculate,
                    title: 'Enter Your Grades',
                    description: 'Add your subjects and grades to calculate your bonus points automatically.',
                  ),
                  _TutorialStep(
                    icon: Icons.trending_up,
                    title: 'Track Progress',
                    description: 'Monitor your academic performance and earned rewards over time.',
                  ),
                  _TutorialStep(
                    icon: Icons.emoji_events,
                    title: 'Earn Rewards',
                    description: 'Convert your bonus points into rewards set by your parents.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Skip', style: TextStyle(color: Colors.white)),
                  ),
                  Row(
                    children: List.generate(
                      3,
                          (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        widget.onComplete();
                      }
                    },
                    child: Text(
                      _currentPage < 2 ? 'Next' : 'Done',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}