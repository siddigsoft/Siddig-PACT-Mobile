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
              },
              headers: ['Site Name', 'Site Code', 'Completed At', 'Notes'],
              data: _filteredVisits.map((visit) => [
                visit.siteName ?? 'N/A',
                visit.siteCode ?? 'N/A',
                visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                visit.notes ?? 'No notes',
              ]).toList(),
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
                  },
                  headers: ['Site Name', 'Site Code', 'Completed At', 'Notes'],
                  data: _filteredVisits.map((visit) => [
                    visit.siteName ?? 'N/A',
                    visit.siteCode ?? 'N/A',
                    visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                    visit.notes ?? 'No notes',
                  ]).toList(),
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
        title: const Text('Reports & Statistics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
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
                            },
                            headers: ['Site Name', 'Site Code', 'Completed At', 'Notes'],
                            data: _filteredVisits.map((visit) => [
                              visit.siteName ?? 'N/A',
                              visit.siteCode ?? 'N/A',
                              visit.completedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(visit.completedAt!) : 'N/A',
                              visit.notes ?? 'No notes',
                            ]).toList(),
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
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _printPDF,
          ),
          IconButton(
            icon: const Icon(Icons.email),
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
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard('Today', counts['daily']!, Colors.blue),
                      _buildSummaryCard('This Week', counts['weekly']!, Colors.orange),
                      _buildSummaryCard('This Month', counts['monthly']!, Colors.green),
                    ],
                  ),
                ),
                
                const Divider(height: 1),

                // Filter Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: _filterType,
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              labelText: 'Select Date',
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Results (${_filteredVisits.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(visit.siteCode.substring(0, min(2, visit.siteCode.length))),
                                ),
                                title: Text(visit.siteName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Code: ${visit.siteCode}'),
                                    Text(
                                      visit.completedAt != null
                                          ? DateFormat('MMM dd, yyyy HH:mm').format(visit.completedAt!)
                                          : 'No Date',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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