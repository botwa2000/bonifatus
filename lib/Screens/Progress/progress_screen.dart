// lib/screens/progress/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../models/term_results_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../Providers/language_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _showLifetimeResults = false;
  Map<String, List<TermResult>> _groupedResults = {};
  double _lifetimeAverage = 0;
  double _lifetimeBonus = 0;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        final response = await _apiService.makeRequest(
          'get_term_results',
          {'student_id': userId},
        );

        if (response['success'] && response['data'] != null) {
          final results = (response['data'] as List)
              .map((result) => TermResult.fromJson(result))
              .toList();

          // Group results by school year
          _groupedResults = groupBy(results, (result) => result.schoolYear);

          // Calculate lifetime stats
          if (results.isNotEmpty) {
            _lifetimeAverage = results.map((r) => r.averageScore).reduce((a, b) => a + b) / results.length;
            _lifetimeBonus = results.map((r) => r.totalBonus).reduce((a, b) => a + b);
          }

          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading results: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.translate('progress')),
        actions: [
          Switch(
            value: _showLifetimeResults,
            onChanged: (value) => setState(() => _showLifetimeResults = value),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showLifetimeResults
          ? _buildLifetimeResults()
          : _buildTermResults(),
    );
  }

  Widget _buildLifetimeResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Lifetime Statistics',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Average Grade: ${_lifetimeAverage.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Total Bonus: €${_lifetimeBonus.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Add charts or graphs here
        ],
      ),
    );
  }

  Widget _buildTermResults() {
    return ListView.builder(
      itemCount: _groupedResults.length,
      itemBuilder: (context, index) {
        final year = _groupedResults.keys.elementAt(index);
        final yearResults = _groupedResults[year]!;

        return ExpansionTile(
          title: Text('School Year $year'),
          children: yearResults.map((result) => TermResultCard(
            result: result,
            onTap: () => _showTermDetails(result),
          )).toList(),
        );
      },
    );
  }

  void _showTermDetails(TermResult result) {
    showModalBottomSheet(
      context: context,
      builder: (context) => TermDetailsSheet(result: result),
    );
  }
}

class TermResultCard extends StatelessWidget {
  final TermResult result;
  final VoidCallback onTap;

  const TermResultCard({super.key, 
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(result.isFullTerm ? 'Full Term' : 'Mid Term'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Average: ${result.averageScore.toStringAsFixed(2)}'),
            Text('Bonus: €${result.totalBonus.toStringAsFixed(2)}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class TermDetailsSheet extends StatelessWidget {
  final TermResult result;

  const TermDetailsSheet({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Grade Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: result.grades.length,
              itemBuilder: (context, index) {
                final grade = result.grades[index];
                return ListTile(
                  title: Text(grade['subject_name']),
                  subtitle: Text('Grade: ${grade['grade_name']}'),
                  trailing: Text('${grade['percentage_equivalent']}%'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}