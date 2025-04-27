import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' show File;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncfusion;
import 'models/note_model.dart';
import 'db/db_helper.dart';

class ViewListScreen extends StatefulWidget {
  const ViewListScreen({super.key});

  @override
  _ViewListScreenState createState() => _ViewListScreenState();
}

class _ViewListScreenState extends State<ViewListScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await DBHelper().getNotes();
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _deleteNote(int? id) async {
    if (id == null) return;
    await DBHelper().deleteNote(id);
    _loadNotes();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  Widget _buildImageFromBase64(String base64Str) {
    try {
      final Uint8List bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return const Icon(CupertinoIcons.photo);
    }
  }

  Future<void> _exportSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes selected for export')),
      );
      return;
    }

    final selectedNotes = _notes.where((n) => n.id != null && _selectedIds.contains(n.id)).toList();
    final workbook = syncfusion.Workbook();
    final sheet = workbook.worksheets[0];

    sheet.getRangeByName('A1').setText('Text');
    sheet.getRangeByName('B1').setText('DateTime');
    sheet.getRangeByName('C1').setText('Latitude');
    sheet.getRangeByName('D1').setText('Longitude');

    int maxImages = selectedNotes.fold<int>(0, (prev, note) => note.imageBase64List.length > prev ? note.imageBase64List.length : prev);

    for (int i = 0; i < maxImages; i++) {
      final columnLetter = String.fromCharCode(69 + i); // E, F, G, etc.
      sheet.getRangeByName('${columnLetter}1').setText('Image ${i + 1}');
    }

    int row = 2;
    for (var note in selectedNotes) {
      sheet.getRangeByName('A$row').setText(note.text);
      sheet.getRangeByName('B$row').dateTime = note.dateTime;
      if (note.latitude != null) sheet.getRangeByName('C$row').setNumber(note.latitude!);
      if (note.longitude != null) sheet.getRangeByName('D$row').setNumber(note.longitude!);

      int imageCol = 5;
      for (var base64Image in note.imageBase64List) {
        final Uint8List imageBytes = base64Decode(base64Image);
        final syncfusion.Picture picture = sheet.pictures.addStream(row, imageCol, imageBytes);
        picture.height = 80;
        picture.width = 80;
        imageCol++;
      }

      row++;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'field_notes.xlsx')
        ..click();

      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported notes with images downloaded!')),
      );
    } else {
      try {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/field_notes.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        final xFile = XFile(
          filePath,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        await Share.shareXFiles(
          [xFile],
          text: 'Please find attached the exported field notes.',
          subject: 'Field Notes Export',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field notes export shared!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export notes: $e')),
        );
      }
    }
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Notes'),
        actions: [
          IconButton(
            icon: Icon(_selectionMode ? CupertinoIcons.xmark : CupertinoIcons.check_mark_circled),
            onPressed: _toggleSelectionMode,
          ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(CupertinoIcons.share),
              onPressed: _exportSelected,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _notes.isEmpty
          ? const Center(child: Text('No notes yet'))
          : SingleChildScrollView(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final note = _notes[index];
            final selected = note.id != null && _selectedIds.contains(note.id);
            return _selectionMode
                ? CheckboxListTile(
              value: selected,
              title: Text(note.text.length > 30 ? '${note.text.substring(0, 30)}…' : note.text),
              subtitle: Text(formatDateTime(note.dateTime)),
              onChanged: (val) => setState(() {
                if (val == true && note.id != null) {
                  _selectedIds.add(note.id!);
                } else if (note.id != null) {
                  _selectedIds.remove(note.id);
                }
              }),
            )
                : Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: note.imageBase64List.isNotEmpty
                    ? _buildImageFromBase64(note.imageBase64List.first)
                    : const Icon(CupertinoIcons.doc_text),
                title: Text(note.text.length > 30 ? '${note.text.substring(0, 30)}…' : note.text),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(note.dateTime),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Lat: ${note.latitude?.toStringAsFixed(4)}  Lng: ${note.longitude?.toStringAsFixed(4)}',
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(CupertinoIcons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteNote(note.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
