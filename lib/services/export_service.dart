import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class ExportService {
  static Future<void> exportToCSV(List<Task> tasks) async {
    if (tasks.isEmpty) throw Exception("No tasks to export");

    List<List<dynamic>> csvData = [
      ['Title', 'Description', 'Due Date', 'Time', 'Repeat', 'Completed', 'Progress', 'Subtasks']
    ];

    for (var task in tasks) {
      String subtasksStr = task.subTasks
          .map((s) => "${s.title} (${s.isCompleted ? 'Done' : 'Pending'})")
          .join('; ');
      csvData.add([
        task.title,
        task.description,
        DateFormat('yyyy-MM-dd').format(task.dueDate),
        task.time,
        task.repeat,
        task.isCompleted ? 'Yes' : 'No',
        "${(task.progress * 100).toStringAsFixed(0)}%",
        subtasksStr,
      ]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    await Share.shareXFiles([XFile(file.path)], text: 'My Tasks - CSV Export');
  }

  static Future<void> exportToPDF(List<Task> tasks) async {
    if (tasks.isEmpty) throw Exception("No tasks to export");

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Task Manager Export',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['Title', 'Due Date', 'Status', 'Progress', 'Subtasks'],
            data: tasks.map((task) {
              String subtasksStr = task.subTasks.isNotEmpty
                  ? task.subTasks.map((s) => s.title).join(', ')
                  : 'None';
              return [
                task.title,
                DateFormat('yyyy-MM-dd HH:mm').format(task.dueDate),
                task.isCompleted ? 'Completed' : 'Pending',
                "${(task.progress * 100).toStringAsFixed(0)}%",
                subtasksStr,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My Tasks - PDF Export');
  }

  // Improved Email Export - Now uses Share Sheet (much more reliable)
  static Future<void> exportAndEmail(List<Task> tasks) async {
    if (tasks.isEmpty) throw Exception("No tasks to export");

    List<List<dynamic>> csvData = [
      ['Title', 'Description', 'Due Date', 'Time', 'Repeat', 'Completed', 'Progress']
    ];

    for (var task in tasks) {
      csvData.add([
        task.title,
        task.description.replaceAll('\n', ' '),
        DateFormat('yyyy-MM-dd').format(task.dueDate),
        task.time,
        task.repeat,
        task.isCompleted ? 'Yes' : 'No',
        "${(task.progress * 100).toStringAsFixed(0)}%",
      ]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/tasks_for_email_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Task Manager Export\nExported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n\nPlease attach this file in your email.',
      subject: 'My Tasks Export',
    );
  }
}