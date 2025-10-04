//components/mmp_files_sheet.dart
import 'package:flutter/material.dart';
import '../../models/mmp_file.dart';
import '../../services/mmp_file_service.dart';

class MMPFilesSheet extends StatefulWidget {
  const MMPFilesSheet({super.key});

  @override
  State<MMPFilesSheet> createState() => _MMPFilesSheetState();
}

class _MMPFilesSheetState extends State<MMPFilesSheet> {
  final MMPFileService _mmpService = MMPFileService();
  List<MMPFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final fileData = await _mmpService.getMMPFiles();
      setState(() {
        _files = fileData.map((data) => MMPFile.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading MMP files: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MMP Files',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadFiles,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return ListTile(
                            title: Text(file.name ?? 'Unnamed File'),
                            subtitle: Text(
                              'Status: ${file.status ?? 'Unknown'}\n'
                              'Created: ${file.createdAt.toString().split('.')[0]}',
                            ),
                            trailing: file.fileUrl != null
                                ? IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: () {
                                      // TODO: Implement file download
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
