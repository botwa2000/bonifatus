// .../lib/providers/language_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/api_service.dart';
import '../models/language_model.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languagePreferenceKey = 'selected_language';
  final ApiService _apiService = ApiService();
  bool _initialized = false;
  bool get initialized => _initialized;

  String _selectedLanguage = 'en';
  Map<String, String> _translations = {};
  List<Language> _availableLanguages = [];
  bool _isLoading = false;

  String get selectedLanguage => _selectedLanguage;
  List<Language> get availableLanguages => _availableLanguages;
  bool get isLoading => _isLoading;

  Future<void> loadTranslations() async {
    try {
      final response = await _apiService.getTranslations(_selectedLanguage);

      if (response['success'] == true && response['data'] != null) {
        // Load translations
        final translationsData = response['data']['translations'];
        if (translationsData is Map) {
          _translations = Map<String, String>.from(
              translationsData.map((key, value) => MapEntry(key.toString(), value.toString()))
          );
        }

        // Load available languages
        if (response['data']['languages'] != null) {
          final languagesList = response['data']['languages'] as List;
          _availableLanguages = languagesList
              .map((lang) => Language.fromJson(lang as Map<String, dynamic>))
              .where((lang) => lang.isActive)
              .toList()
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        }
      } else {
        print('Translation loading failed: ${response['message']}');
        _translations = {
          'error_message': response['message'] ?? ApiService.MAINTENANCE_MESSAGE
        };
        _availableLanguages = [
          Language(
            id: 'en',
            name: 'English',
            countryCode: 'GB',
            displayOrder: 1,
          )
        ];
      }
    } catch (e) {
      print('Error loading translations: $e');
      _translations = {
        'error_message': ApiService.MAINTENANCE_MESSAGE
      };
      _availableLanguages = [
        Language(
          id: 'en',
          name: 'English',
          countryCode: 'GB',
          displayOrder: 1,
        )
      ];
    }
    notifyListeners();
  }

  String translate(String key) {
    if (_translations.isEmpty) return key;
    return _translations[key] ?? key;
  }

  Future<void> setLanguage(String languageId) async {
    if (_selectedLanguage != languageId) {
      try {
        _isLoading = true;
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languagePreferenceKey, languageId);
        _selectedLanguage = languageId;
        await loadTranslations();
      } catch (e) {
        print('Error setting language: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedLanguage = prefs.getString(_languagePreferenceKey) ?? 'en';
      await loadTranslations();
      _initialized = true;
    } catch (e) {
      print('Error during initialization: $e');
      _translations = {};
      _availableLanguages = [
        Language(
          id: 'en',
          name: 'English',
          countryCode: 'GB',
          displayOrder: 1,
        )
      ];
    }
    _isLoading = false;
    notifyListeners();
  }
}