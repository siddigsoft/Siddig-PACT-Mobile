// lib/widgets/visit_report_dialog.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../services/location_service.dart';

class VisitReportData {
  final List<String> activities;
  final String? notes;
  final int durationMinutes;
  final Position? coordinates;
  final List<File> photos;

  VisitReportData({
    required this.activities,
    this.notes,
    required this.durationMinutes,
    this.coordinates,
    required this.photos,
  });
}

class VisitReportDialog extends StatefulWidget {
  final Map<String, dynamic> site;
  final Function(VisitReportData) onSubmit;
  final bool isSubmitting;

  const VisitReportDialog({
    super.key,
    required this.site,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  @override
  State<VisitReportDialog> createState() => _VisitReportDialogState();
}

class _VisitReportDialogState extends State<VisitReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final List<String> _selectedActivities = [];
  final List<File> _photos = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _availableActivities = [
    'Site Inspection',
    'Data Collection',
    'Photo Documentation',
    'GPS Recording',
    'Interview with CP',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _photos.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
      setState(() {
        _photos.addAll(images.map((img) => File(img.path)));
      });
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<Position?> _getCurrentLocation() async {
    return await LocationService.getCurrentLocation();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one activity')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 60;
    
    // Get location
    _getCurrentLocation().then((position) {
      final reportData = VisitReportData(
        activities: _selectedActivities,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        durationMinutes: duration,
        coordinates: position,
        photos: _photos,
      );
      widget.onSubmit(reportData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Visit Report',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activities
                      Text(
                        'Activities Performed *',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _availableActivities.map((activity) {
                          final isSelected = _selectedActivities.contains(activity);
                          return FilterChip(
                            label: Text(activity),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedActivities.add(activity);
                                } else {
                                  _selectedActivities.remove(activity);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Visit Duration (minutes) *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter duration';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          border: OutlineInputBorder(),
                          hintText: 'Optional notes about the visit...',
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Photos
                      Text(
                        'Photos',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('From Gallery'),
                          ),
                        ],
                      ),
                      if (_photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(_photos[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      color: Colors.red,
                                      onPressed: () {
                                        setState(() {
                                          _photos.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.backgroundGray),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: widget.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Report'),
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

