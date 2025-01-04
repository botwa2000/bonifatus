import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

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
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _TutorialStep(
                    icon: Icons.stars,
                    title: languageProvider.translate('tutorial_grades_title'),
                    description: languageProvider.translate('tutorial_grades_desc'),
                  ),
                  _TutorialStep(
                    icon: Icons.calculate,
                    title: languageProvider.translate('tutorial_entry_title'),
                    description: languageProvider.translate('tutorial_entry_desc'),
                  ),
                  _TutorialStep(
                    icon: Icons.trending_up,
                    title: languageProvider.translate('tutorial_progress_title'),
                    description: languageProvider.translate('tutorial_progress_desc'),
                  ),
                  _TutorialStep(
                    icon: Icons.emoji_events,
                    title: languageProvider.translate('tutorial_rewards_title'),
                    description: languageProvider.translate('tutorial_rewards_desc'),
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
                    child: Text(
                      languageProvider.translate('skip'),
                      style: const TextStyle(color: Colors.white),
                    ),
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
                      _currentPage < 2
                          ? languageProvider.translate('next')
                          : languageProvider.translate('done'),
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