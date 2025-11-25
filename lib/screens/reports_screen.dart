import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_visit.dart';
import '../services/site_visit_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SiteVisitService _siteVisitService = SiteVisitService();
  List<SiteVisit> _allVisits = [];
  List<SiteVisit> _filteredVisits = [];
  bool _isLoading = true;
  String? _userId;
  Map<String, Map<String, dynamic>> _siteLocations = {}; // site_id -> location data

  // Filter state
  String _filterType = 'Date'; // Date, Month, Year
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _userId = Supabase.instance.client.auth.currentUser?.id;
      if (_userId != null) {
        _allVisits = await _siteVisitService.getCompletedSiteVisits(_userId!);
        await _loadSiteLocations();
        _applyFilter();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading visits: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSiteLocations() async {
    try {
      final siteIds = _allVisits.map((v) => v.id).toList();
      if (siteIds.isEmpty) return;

      final response = await Supabase.instance.client
          .from('site_locations')
          .select('site_id, latitude, longitude, accuracy, recorded_at')
          .inFilter('site_id', siteIds)
          .order('recorded_at', ascending: false);

      _siteLocations.clear();
      for (var location in response) {
        final siteId = location['site_id'];
        if (!_siteLocations.containsKey(siteId)) {
          _siteLocations[siteId] = location;
        }
      }
    } catch (e) {
      print('Error loading site locations: $e');
      // Don't show error to user, just continue without location data
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredVisits = _allVisits.where((visit) {
        final date = visit.completedAt;
        if (date == null) return false;

        switch (_filterType) {
          case 'Date':
            return date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;
          case 'Month':
            return date.year == _selectedDate.year &&
                date.month == _selectedDate.month;
          case 'Year':
            return date.year == _selectedDate.year;
          default:
            return true;
        }
      }).toList();
    });
  }

  Map<String, int> _getSummaryCounts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    int daily = 0;
    int weekly = 0;
    int monthly = 0;

    for (var visit in _allVisits) {
      final date = visit.completedAt;
      if (date == null) continue;

      if (date.isAfter(today) || date.isAtSameMomentAs(today)) {
        daily++;
      }
      if (date.isAfter(startOfWeekDate) || date.isAtSameMomentAs(startOfWeekDate)) {
        weekly++;
      }
      if (date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth)) {
        monthly++;
      }
    }

    return {'daily': daily, 'weekly': weekly, 'monthly': monthly};
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _applyFilter();
      });
    }
  }

  // Improved PDF Generation
  Future<String> _generateAndSavePDF() async {
    final pdf = pw.Document();
    
    // Load fonts with fallback
    pw.Font? font;
    pw.Font? boldFont;
    
    try {
      font = await PdfGoogleFonts.nunitoRegular();
      boldFont = await PdfGoogleFonts.nunitoBold();
    } catch (e) {
      // Fallback to built-in fonts if Google Fonts fail
      font = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Site Visit Report', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                  pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font, fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Filter: $_filterType - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: pw.TextStyle(font: font, fontSize: 14)),
            pw.Text('Total Visits: ${_filteredVisits.length}', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
              },
              headers: ['Site Name', 'Site Code', 'Completed At', 'Coordinates', 'Accuracy', 'Notes'],
              data: _filteredVisits.map((visit) {
                final location = _siteLocations[visit.id];
                final coordinates = location != null 
                  ? '${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}'
                  : 'Not recorded';
                final accuracy = location != null 
                  ? '${location['accuracy']?.toStringAsFixed(1) ?? 'N/A'}m'
                  : 'N/A';
                
                return [
                  visit.siteName ?? 'N/A',
                  visit.siteCode ?? 'N/A',
                  visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                  coordinates,
                  accuracy,
                  visit.notes ?? 'No notes',
                ];
              }).toList(),
            ),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              title: pw.Text('Generated by PACT Mobile', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    // Handle file saving based on platform
    if (kIsWeb) {
      // For web, use printing package to handle PDF
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'site_visit_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      return ''; // Return empty string for web since we don't save to file
    } else {
      // For mobile/desktop, save to temporary directory
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/site_visit_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    }
  }

  Future<void> _printPDF() async {
    try {
      if (kIsWeb) {
        // For web, generate PDF directly and print
        final pdf = pw.Document();
        
        // Load fonts with fallback
        pw.Font? font;
        pw.Font? boldFont;
        
        try {
          font = await PdfGoogleFonts.nunitoRegular();
          boldFont = await PdfGoogleFonts.nunitoBold();
        } catch (e) {
          font = pw.Font.helvetica();
          boldFont = pw.Font.helveticaBold();
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Site Visit Report', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                      pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font, fontSize: 12)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Filter: $_filterType - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: pw.TextStyle(font: font, fontSize: 14)),
                pw.Text('Total Visits: ${_filteredVisits.length}', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                  },
                  headers: ['Site Name', 'Site Code', 'Completed At', 'Coordinates', 'Accuracy', 'Notes'],
                  data: _filteredVisits.map((visit) {
                    final location = _siteLocations[visit.id];
                    final coordinates = location != null 
                      ? '${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}'
                      : 'Not recorded';
                    final accuracy = location != null 
                      ? '${location['accuracy']?.toStringAsFixed(1) ?? 'N/A'}m'
                      : 'N/A';
                    
                    return [
                      visit.siteName ?? 'N/A',
                      visit.siteCode ?? 'N/A',
                      visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                      coordinates,
                      accuracy,
                      visit.notes ?? 'No notes',
                    ];
                  }).toList(),
                ),
                pw.Footer(
                  margin: const pw.EdgeInsets.only(top: 20),
                  title: pw.Text('Generated by PACT Mobile', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
                ),
              ];
            },
          ),
        );

        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
          return pdf.save();
        });
      } else {
        // For mobile/desktop
        final pdfPath = await _generateAndSavePDF();
        if (pdfPath.isNotEmpty) {
          await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
            final file = File(pdfPath);
            return file.readAsBytesSync();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing: $e')));
    }
  }

  Future<void> _sendEmail() async {
    try {
      if (kIsWeb) {
        // For web, show a message that email with attachment is not supported
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email with PDF attachment is not supported on web. Please use the PDF download feature instead.')),
        );
        return;
      }

      final pdfPath = await _generateAndSavePDF();
      if (pdfPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate PDF')),
        );
        return;
      }

      final email = await showDialog<String>(
        context: context,
        builder: (context) => EmailDialog(),
      );

      if (email != null && email.isNotEmpty) {
        final Email emailToSend = Email(
          body: 'Please find attached the site visit report.',
          subject: 'Site Visit Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
          recipients: [email],
          attachmentPaths: [pdfPath],
          isHTML: false,
        );

        await FlutterEmailSender.send(emailToSend);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email sent successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _getSummaryCounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1976D2), // Deep blue
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: kIsWeb ? 'Download PDF' : 'Generate PDF',
            onPressed: () async {
              try {
                if (kIsWeb) {
                  // For web, generate and share PDF directly
                  final pdf = pw.Document();
                  
                  // Load fonts with fallback
                  pw.Font? font;
                  pw.Font? boldFont;
                  
                  try {
                    font = await PdfGoogleFonts.nunitoRegular();
                    boldFont = await PdfGoogleFonts.nunitoBold();
                  } catch (e) {
                    font = pw.Font.helvetica();
                    boldFont = pw.Font.helveticaBold();
                  }

                  pdf.addPage(
                    pw.MultiPage(
                      pageFormat: PdfPageFormat.a4,
                      build: (pw.Context context) {
                        return [
                          pw.Header(
                            level: 0,
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Site Visit Report', style: pw.TextStyle(font: boldFont, fontSize: 24)),
                                pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(font: font, fontSize: 12)),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 20),
                          pw.Text('Filter: $_filterType - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}', style: pw.TextStyle(font: font, fontSize: 14)),
                          pw.Text('Total Visits: ${_filteredVisits.length}', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                          pw.SizedBox(height: 20),
                          pw.Table.fromTextArray(
                            border: pw.TableBorder.all(color: PdfColors.grey),
                            headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),
                            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                            cellStyle: pw.TextStyle(font: font, fontSize: 10),
                            cellAlignments: {
                              0: pw.Alignment.centerLeft,
                              1: pw.Alignment.centerLeft,
                              2: pw.Alignment.centerLeft,
                              3: pw.Alignment.centerLeft,
                              4: pw.Alignment.centerLeft,
                              5: pw.Alignment.centerLeft,
                            },
                            headers: ['Site Name', 'Site Code', 'Completed At', 'Coordinates', 'Accuracy', 'Notes'],
                            data: _filteredVisits.map((visit) {
                              final location = _siteLocations[visit.id];
                              final coordinates = location != null 
                                ? '${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}'
                                : 'Not recorded';
                              final accuracy = location != null 
                                ? '${location['accuracy']?.toStringAsFixed(1) ?? 'N/A'}m'
                                : 'N/A';
                              
                              return [
                                visit.siteName ?? 'N/A',
                                visit.siteCode ?? 'N/A',
                                visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                                coordinates,
                                accuracy,
                                visit.notes ?? 'No notes',
                              ];
                            }).toList(),
                          ),
                          pw.Footer(
                            margin: const pw.EdgeInsets.only(top: 20),
                            title: pw.Text('Generated by PACT Mobile', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
                          ),
                        ];
                      },
                    ),
                  );

                  await Printing.sharePdf(
                    bytes: await pdf.save(), 
                    filename: 'site_visit_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf'
                  );
                } else {
                  // For mobile/desktop, generate and show success message
                  final pdfPath = await _generateAndSavePDF();
                  if (pdfPath.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF saved to: $pdfPath')),
                    );
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error generating PDF: $e')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Print',
            onPressed: _printPDF,
          ),
          IconButton(
            icon: const Icon(Icons.email, color: Colors.white),
            tooltip: 'Email',
            onPressed: _sendEmail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFE3F2FD), // Light blue
                        Color(0xFFF3E5F5), // Light purple tint
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard('Today', counts['daily']!, const Color(0xFF1976D2)), // Deep blue
                      _buildSummaryCard('This Week', counts['weekly']!, const Color(0xFFFF9800)), // Orange
                      _buildSummaryCard('This Month', counts['monthly']!, const Color(0xFF4CAF50)), // Green
                    ],
                  ),
                ),
                
                const Divider(height: 1),

                // Filter Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: DropdownButton<String>(
                                value: _filterType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                icon: Icon(Icons.arrow_drop_down, color: const Color(0xFF1976D2)),
                                style: TextStyle(
                                  color: const Color(0xFF263238),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                items: ['Date', 'Month', 'Year'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _filterType = newValue;
                                      _applyFilter();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE0E0E0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                                      style: TextStyle(
                                        color: const Color(0xFF263238),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(Icons.calendar_today, color: const Color(0xFFFF9800), size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Results Header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF9800).withOpacity(0.1), // Light orange
                        const Color(0xFF1976D2).withOpacity(0.1), // Light blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: const Color(0xFF1976D2),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Results (${_filteredVisits.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF263238),
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _filteredVisits.isEmpty
                      ? const Center(child: Text('No visits found for this period'))
                      : ListView.builder(
                          itemCount: _filteredVisits.length,
                          itemBuilder: (context, index) {
                            final visit = _filteredVisits[index];
                            final location = _siteLocations[visit.id];
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFFFF9800).withOpacity(0.1), // Light orange border
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Leading icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF1976D2).withOpacity(0.8), // Blue gradient
                                            const Color(0xFF42A5F5),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          visit.siteCode.length >= 2 
                                            ? visit.siteCode.substring(0, 2).toUpperCase()
                                            : visit.siteCode.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                            visit.siteName ?? 'Unknown Site',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF263238),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          const SizedBox(height: 8),
                                          // Site code
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 16, color: const Color(0xFFFF9800)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Code: ${visit.siteCode}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Date
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, size: 16, color: const Color(0xFF1976D2)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  visit.completedAt != null
                                                      ? DateFormat('MMM dd, yyyy HH:mm').format(visit.completedAt!)
                                                      : 'No Date',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Location (if available)
                                          if (location != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.gps_fixed, size: 16, color: const Color(0xFF4CAF50)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '${location['latitude']?.toStringAsFixed(4) ?? 'N/A'}, ${location['longitude']?.toStringAsFixed(4) ?? 'N/A'} (±${location['accuracy']?.toStringAsFixed(0) ?? 'N/A'}m)',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 12,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Trailing status
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper for min function
int min(int a, int b) => a < b ? a : b;

class EmailDialog extends StatefulWidget {
  @override
  _EmailDialogState createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Report via Email'),
      content: TextField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'Email Address',
          hintText: 'Enter email address',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_emailController.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}