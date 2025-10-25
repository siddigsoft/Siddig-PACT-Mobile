import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/safety_checklist.dart';
import '../services/safety_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class SafetyChecklistScreen extends StatefulWidget {
  const SafetyChecklistScreen({super.key});

  @override
  State<SafetyChecklistScreen> createState() => _SafetyChecklistScreenState();
}

class _SafetyChecklistScreenState extends State<SafetyChecklistScreen> {
  late SafetyService _safetyService;
  List<SafetyChecklist> _checklists = [];
  bool _isLoading = true;

  // Checklist type configuration
  final List<String> _checklistTypes = ['pre_visit', 'during_visit', 'post_visit', 'emergency'];
  String _selectedChecklistType = 'pre_visit';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _safetyService = SafetyService(prefs);
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    setState(() => _isLoading = true);
    final checklists = await _safetyService.getChecklists();
    setState(() {
      _checklists = checklists;
      _isLoading = false;
    });
  }

  // Helper method to get current user ID from Supabase auth
  String? _getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id;
  }

  Future<void> _showNewChecklistForm() async {
    final locationController = TextEditingController();
    bool areaSafe = true;
    bool threatsEncountered = false;
    bool cleanWaterAvailable = true;
    bool foodAvailable = true;
    final safetyNotesController = TextEditingController();
    final threatDetailsController = TextEditingController();
    final hindrancesController = TextEditingController();
    final additionalNotesController = TextEditingController();

    // Reset selected type to default
    _selectedChecklistType = 'pre_visit';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.safetyChecklist,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checklist type dropdown
              DropdownButtonFormField<String>(
                value: _selectedChecklistType,
                decoration: const InputDecoration(
                  labelText: 'Checklist Type',
                  hintText: 'Select checklist type',
                ),
                items: _checklistTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.replaceAll('_', ' ').toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedChecklistType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Enter current location',
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Area is Safe'),
                      value: areaSafe,
                      onChanged: (value) => setState(() => areaSafe = value),
                    ),
                    if (!areaSafe) ...[
                      TextField(
                        controller: safetyNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Safety Concerns',
                          hintText: 'Describe safety issues',
                        ),
                        maxLines: 2,
                      ),
                    ],
                    SwitchListTile(
                      title: const Text('Threats Encountered'),
                      value: threatsEncountered,
                      onChanged: (value) =>
                          setState(() => threatsEncountered = value),
                    ),
                    if (threatsEncountered) ...[
                      TextField(
                        controller: threatDetailsController,
                        decoration: const InputDecoration(
                          labelText: 'Threat Details',
                          hintText: 'Describe encountered threats',
                        ),
                        maxLines: 2,
                      ),
                    ],
                    SwitchListTile(
                      title: const Text('Clean Water Available'),
                      value: cleanWaterAvailable,
                      onChanged: (value) =>
                          setState(() => cleanWaterAvailable = value),
                    ),
                    SwitchListTile(
                      title: const Text('Food Available'),
                      value: foodAvailable,
                      onChanged: (value) =>
                          setState(() => foodAvailable = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hindrancesController,
                decoration: const InputDecoration(
                  labelText: 'Hindrances',
                  hintText: 'List any hindrances (comma-separated)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: additionalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  hintText: 'Any other observations',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = _getCurrentUserId();
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User not authenticated')),
                );
                return;
              }

              if (locationController.text.isNotEmpty) {
                final checklist = SafetyChecklist(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: userId, // Now gets actual user ID from auth
                  checklistType: _selectedChecklistType, // Now configurable
                  items: [
                    {
                      'question': 'Is the area safe?',
                      'answer': areaSafe,
                      'notes': !areaSafe ? safetyNotesController.text : null,
                    },
                    {
                      'question': 'Threats encountered?',
                      'answer': threatsEncountered,
                      'details': threatsEncountered ? threatDetailsController.text : null,
                    },
                    {
                      'question': 'Clean water available?',
                      'answer': cleanWaterAvailable,
                    },
                    {
                      'question': 'Food available?',
                      'answer': foodAvailable,
                    },
                    {
                      'question': 'Hindrances',
                      'answer': hindrancesController.text.isNotEmpty,
                      'details': hindrancesController.text,
                    },
                  ],
                  completedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await _safetyService.addChecklist(checklist);
                _loadChecklists();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white, // Ensure text is white for visibility
            ),
            child: Text(AppLocalizations.of(context)!.submit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: Text(
          'Safety Checklists',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textDark,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _checklists.length,
              itemBuilder: (context, index) {
                final checklist = _checklists[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(
                      'Safety Checklist - ${checklist.checklistType.replaceAll('_', ' ').toUpperCase()}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Completed: ${checklist.completedAt?.toString().split('.')[0] ?? checklist.createdAt.toString().split('.')[0]}',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: Icon(
                      checklist.items.any((item) => item['question'] == 'Is the area safe?' && item['answer'] == true)
                          ? Icons.check_circle
                          : Icons.warning,
                      color: checklist.items.any((item) => item['question'] == 'Is the area safe?' && item['answer'] == true)
                          ? AppColors.accentGreen
                          : AppColors.accentRed,
                    ),
                    onTap: () {
                      // Show detailed view
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Safety Checklist - ${checklist.checklistType.replaceAll('_', ' ').toUpperCase()}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDetailItem(
                                  'Completed',
                                  checklist.completedAt?.toString().split('.')[0] ?? 'Not completed',
                                ),
                                ...checklist.items.map((item) => _buildDetailItem(
                                  item['question'] ?? 'Unknown',
                                  item['answer']?.toString() ?? 'N/A',
                                )),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(duration: 300.ms);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showNewChecklistForm();
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
