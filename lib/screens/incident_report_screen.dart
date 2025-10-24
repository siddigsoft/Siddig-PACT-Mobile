import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/safety_report.dart';
import '../services/local_storage_service.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  late LocalStorageService _localStorage;
  List<SafetyReport> _reports = [];
  bool _isLoading = true;
  final _imagePicker = ImagePicker();
  List<String> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    _localStorage = LocalStorageService();
    _loadReports();

    // Trigger sync when screen loads if online
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    if (syncProvider.isOnline) {
      syncProvider.syncSafetyReports();
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = _localStorage.getAllSafetyReports();
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );
    if (image != null) {
      setState(() {
        _selectedImages.add(image.path);
      });
    }
  }

  Future<void> _showNewReportForm() async {
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final witnessesController = TextEditingController();
    final actionController = TextEditingController();
    String selectedType = 'other';
    bool requiresImmediate = false;
    _selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.reportIncident,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ['harassment', 'theft', 'accident', 'medicalEmergency', 'naturalDisaster', 'other']
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) selectedType = value;
                },
                decoration: const InputDecoration(labelText: 'Incident Type'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Enter incident location',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what happened',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: witnessesController,
                decoration: const InputDecoration(
                  labelText: 'Witnesses',
                  hintText: 'List witnesses (comma-separated)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actionController,
                decoration: const InputDecoration(
                  labelText: 'Action Taken',
                  hintText: 'Describe any immediate action taken',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Requires Immediate Attention'),
                      value: requiresImmediate,
                      onChanged: (value) =>
                          setState(() => requiresImmediate = value),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _pickImage();
                        setState(() {});
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Add Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white, // Ensure text is visible
                      ),
                    ),
                    if (_selectedImages.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedImages
                            .map(
                              (path) => Stack(
                                children: [
                                  Image.file(
                                    File(path),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle),
                                      color: Colors.red,
                                      onPressed: () {
                                        setState(() {
                                          _selectedImages.remove(path);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (locationController.text.isNotEmpty &&
                  descriptionController.text.isNotEmpty) {
                final report = SafetyReport(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'Incident Report - ${selectedType}',
                  description: descriptionController.text,
                  status: 'submitted',
                  createdAt: DateTime.now(),
                  submittedAt: DateTime.now(),
                  location: locationController.text,
                  hazards: [selectedType], // Using incident type as hazard
                  recommendations: actionController.text.isNotEmpty ? [actionController.text] : [],
                  incidentType: selectedType,
                  incidentDate: DateTime.now(),
                  witnesses: witnessesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  requiresImmediate: requiresImmediate,
                  actionTaken: actionController.text.isNotEmpty ? actionController.text : null,
                  mediaUrls: _selectedImages,
                  reportedBy: 'Current User', // Replace with actual user
                );

                await _localStorage.saveSafetyReport(report);
                _loadReports();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white, // Ensure text is visible
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
        title: Row(
          children: [
            Text(
              'Incident Reports',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
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
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final report = _reports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(
                      report.incidentType ?? 'Incident Report',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location: ${report.location}',
                          style: GoogleFonts.poppins(),
                        ),
                        Text(
                          'Date: ${report.incidentDate?.toString().split('.')[0] ?? report.createdAt.toString().split('.')[0]}',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                    trailing: report.requiresImmediate == true
                        ? Icon(Icons.warning, color: AppColors.accentRed)
                        : null,
                    onTap: () {
                      // Show detailed view
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            report.incidentType ?? 'Incident Report',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDetailItem('Location', report.location),
                                _buildDetailItem(
                                  'Date',
                                  report.incidentDate?.toString().split('.')[0] ?? report.createdAt.toString().split('.')[0],
                                ),
                                _buildDetailItem(
                                  'Description',
                                  report.description,
                                ),
                                if (report.witnesses != null &&
                                    report.witnesses!.isNotEmpty)
                                  _buildDetailItem(
                                    'Witnesses',
                                    report.witnesses!.join(', '),
                                  ),
                                if (report.actionTaken != null)
                                  _buildDetailItem(
                                    'Action Taken',
                                    report.actionTaken!,
                                  ),
                                _buildDetailItem(
                                  'Immediate Attention',
                                  report.requiresImmediate == true ? 'Yes' : 'No',
                                ),
                                if (report.mediaUrls != null &&
                                    report.mediaUrls!.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: report.mediaUrls!
                                        .map(
                                          (path) => Image.file(
                                            File(path),
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        .toList(),
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
          _showNewReportForm();
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
