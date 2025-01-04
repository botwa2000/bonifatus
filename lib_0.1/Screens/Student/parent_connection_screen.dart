// lib/screens/student/parent_connection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Services/auth_service.dart';
import '../../Services/api_service.dart';
import '../../Services/relationship_service.dart';
import '../../Providers/language_provider.dart';

class ParentConnectionScreen extends StatefulWidget {
  const ParentConnectionScreen({super.key});

  @override
  _ParentConnectionScreenState createState() => _ParentConnectionScreenState();
}

class _ParentConnectionScreenState extends State<ParentConnectionScreen> {
  final RelationshipService _relationshipService = RelationshipService(ApiService());
  bool _isLoading = false;
  Map<String, dynamic>? _parentInfo;
  String? _errorMessage;
  late LanguageProvider _languageProvider;

  @override
  void initState() {
    super.initState();
    _loadParentInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageProvider = Provider.of<LanguageProvider>(context);
  }

  Future<void> _loadParentInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await AuthService().getCurrentUserId();
      if (userId != null) {
        final response = await _relationshipService.getParent(userId);

        if (mounted) {
          setState(() {
            if (response['success'] && response['data'] != null) {
              _parentInfo = response['data'];
              _errorMessage = null;
            } else {
              _parentInfo = null;
              _errorMessage = response['message'] ?? _languageProvider.translate('error_loading_data');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parentInfo = null;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageProvider.translate('parent_connection')),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadParentInfo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.family_restroom,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _languageProvider.translate('connected_parent'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadParentInfo,
                                icon: const Icon(Icons.refresh),
                                label: Text(_languageProvider.translate('retry')),
                              ),
                            ],
                          ),
                        )
                      else if (_parentInfo != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                  child: Text(
                                    _parentInfo!['first_name']?[0].toUpperCase() ?? '',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${_parentInfo!['first_name']} ${_parentInfo!['last_name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(_parentInfo!['email'] ?? ''),
                                    if (_parentInfo!['relationship_since'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Connected since: ${_formatDate(_parentInfo!['relationship_since'])}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.family_restroom_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _languageProvider.translate('no_parent_connected'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}