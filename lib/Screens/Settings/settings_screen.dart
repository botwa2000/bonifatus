import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/language_provider.dart';
import '../../Providers/theme_provider.dart';
import '../../models/language_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguageSelector(BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            // ... your existing header ...
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: languageProvider.availableLanguages.length,
                itemBuilder: (context, index) {
                  final language = languageProvider.availableLanguages[index];
                  final isSelected = language.id == languageProvider.selectedLanguage;

                  return ListTile(
                    leading: Text(
                      language.countryCode,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(language.name),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    selected: isSelected,
                    onTap: () async {
                      // Change language
                      await languageProvider.setLanguage(language.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(languageProvider.translate('language_changed')),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeModeSelector(BuildContext context, ThemeProvider themeProvider, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                languageProvider.translate('choose_theme'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(languageProvider.translate('theme_system')),
              trailing: themeProvider.themeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text(languageProvider.translate('theme_light')),
              trailing: themeProvider.themeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(languageProvider.translate('theme_dark')),
              trailing: themeProvider.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Early return if no languages are available yet
    if (languageProvider.availableLanguages.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Find current language safely
    final currentLang = languageProvider.availableLanguages
        .firstWhere(
          (l) => l.id == languageProvider.selectedLanguage,
      orElse: () => Language(
        id: 'en',
        name: 'English',
        countryCode: 'GB',
        displayOrder: 1,
      ),
    );

    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Language Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(languageProvider.translate('language')),
                  subtitle: Row(
                    children: [
                      Text(
                        currentLang.countryCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(currentLang.name),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLanguageSelector(context, languageProvider),
                ),
              ],
            ),
          ),
          // Theme Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text(languageProvider.translate('theme')),
                  subtitle: Text(
                    themeProvider.themeMode == ThemeMode.system
                        ? languageProvider.translate('theme_system')
                        : themeProvider.themeMode == ThemeMode.light
                        ? languageProvider.translate('theme_light')
                        : languageProvider.translate('theme_dark'),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showThemeModeSelector(context, themeProvider, languageProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}