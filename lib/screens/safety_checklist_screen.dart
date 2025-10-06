import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/safety_checklist.dart';
import '../services/safety_service.dart';
import '../theme/app_colors.dart';

class SafetyChecklistScreen extends StatefulWidget {
  const SafetyChecklistScreen({super.key});

  @override
  State<SafetyChecklistScreen> createState() => _SafetyChecklistScreenState();
}

class _SafetyChecklistScreenState extends State<SafetyChecklistScreen> {
  late SafetyService _safetyService;
  List<SafetyChecklist> _checklists = [];
  bool _isLoading = true;

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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Safety Checklist',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (locationController.text.isNotEmpty) {
                final checklist = SafetyChecklist(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  date: DateTime.now(),
                  areaSafe: areaSafe,
                  safetyNotes: !areaSafe ? safetyNotesController.text : null,
                  threatsEncountered: threatsEncountered,
                  threatDetails: threatsEncountered
                      ? threatDetailsController.text
                      : null,
                  cleanWaterAvailable: cleanWaterAvailable,
                  foodAvailable: foodAvailable,
                  hindrances: hindrancesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  additionalNotes: additionalNotesController.text.isNotEmpty
                      ? additionalNotesController.text
                      : null,
                  location: locationController.text,
                );

                await _safetyService.addChecklist(checklist);
                _loadChecklists();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Submit'),
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
                      checklist.location,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Date: ${checklist.date.toString().split('.')[0]}',
                      style: GoogleFonts.poppins(),
                    ),
                    trailing: Icon(
                      checklist.areaSafe ? Icons.check_circle : Icons.warning,
                      color: checklist.areaSafe
                          ? AppColors.accentGreen
                          : AppColors.accentRed,
                    ),
                    onTap: () {
                      // Show detailed view
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            checklist.location,
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
                                  'Date',
                                  checklist.date.toString().split('.')[0],
                                ),
                                _buildDetailItem(
                                  'Area Safety',
                                  checklist.areaSafe ? 'Safe' : 'Unsafe',
                                ),
                                if (!checklist.areaSafe)
                                  _buildDetailItem(
                                    'Safety Notes',
                                    checklist.safetyNotes ?? 'No notes',
                                  ),
                                _buildDetailItem(
                                  'Threats',
                                  checklist.threatsEncountered ? 'Yes' : 'No',
                                ),
                                if (checklist.threatsEncountered)
                                  _buildDetailItem(
                                    'Threat Details',
                                    checklist.threatDetails ?? 'No details',
                                  ),
                                _buildDetailItem(
                                  'Clean Water',
                                  checklist.cleanWaterAvailable ? 'Yes' : 'No',
                                ),
                                _buildDetailItem(
                                  'Food',
                                  checklist.foodAvailable ? 'Yes' : 'No',
                                ),
                                if (checklist.hindrances.isNotEmpty)
                                  _buildDetailItem(
                                    'Hindrances',
                                    checklist.hindrances.join(', '),
                                  ),
                                if (checklist.additionalNotes != null)
                                  _buildDetailItem(
                                    'Additional Notes',
                                    checklist.additionalNotes!,
                                  ),
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
