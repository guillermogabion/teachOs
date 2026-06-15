import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelExportService {
  static Future<String?> exportAttendance({
    required String sectionName,
    required String startDate,
    required String endDate,
    required List<Map<String, dynamic>> rawData,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Attendance Sheet'];
      excel.delete('Sheet1');

      final Set<String> uniqueDates = {};
      final Map<String, Map<String, String>> studentAttendanceMap = {};

      for (var row in rawData) {
        String date = row['date'] ?? '';
        String name = row['full_name'] ?? 'Unknown Student';
        String status = (row['status'] as String? ?? '-').toUpperCase();

        if (date.isNotEmpty) {
          uniqueDates.add(date);
          studentAttendanceMap.putIfAbsent(name, () => {});
          studentAttendanceMap[name]![date] = status;
        }
      }

      final List<String> sortedDates = uniqueDates.toList()..sort();
      final List<String> sortedStudentNames = studentAttendanceMap.keys.toList()
        ..sort();

      List<CellValue> headers = [
        TextCellValue('Student Name'),
        ...sortedDates.map((d) => TextCellValue(d)),
        TextCellValue('Present Count'),
        TextCellValue('Absent Count'),
        TextCellValue('Late Count'),
      ];
      sheetObject.appendRow(headers);

      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#3F51B5'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
        );
      }

      for (String studentName in sortedStudentNames) {
        final attendance = studentAttendanceMap[studentName]!;
        int present = 0, absent = 0, late = 0;
        List<CellValue> rowCells = [TextCellValue(studentName)];

        for (String date in sortedDates) {
          String status = attendance[date] ?? '-';
          if (status == 'PRESENT') present++;
          if (status == 'ABSENT') absent++;
          if (status == 'LATE') late++;

          String displayValue = '-';
          if (status == 'PRESENT') displayValue = 'P';
          if (status == 'ABSENT') displayValue = 'A';
          if (status == 'LATE') displayValue = 'L';
          rowCells.add(TextCellValue(displayValue));
        }

        rowCells.add(IntCellValue(present));
        rowCells.add(IntCellValue(absent));
        rowCells.add(IntCellValue(late));
        sheetObject.appendRow(rowCells);
      }

      for (int i = 0; i < headers.length; i++) {
        sheetObject.setColumnWidth(i, i == 0 ? 28.0 : 16.0);
      }

      final bytes = excel.encode();
      if (bytes == null) return null;

      final sanitizedSection = sectionName.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final fileName =
          'Attendance_${sanitizedSection}_${startDate}_to_${endDate}.xlsx';

      // ✅ Write to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      // ✅ Open native Android share sheet
      final result = await Share.shareXFiles([
        XFile(
          tempFile.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        ),
      ], subject: fileName);

      // ✅ Clean up temp file after sharing
      if (await tempFile.exists()) await tempFile.delete();

      if (result.status == ShareResultStatus.success) {
        return fileName;
      }

      return null;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }
}
