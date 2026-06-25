import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;

// =============================================================================
// ExcelExportService
//
// Template layout derived from E-Class_Record_Template_original_file.xlsx
// and verified against E-Class_Record_LAVENDER__1_.xlsx (filled sample).
// All row/col constants are 0-based to match the excel package's indexing.
//
// ── Rows 1–6 (all sheets) ────────────────────────────────────────────────────
//   Row 1 (idx 0)  — "Class Record" title, merged A1:Z2
//   Row 3 (idx 2)  — DepEd order note
//   Row 4 (idx 3)  — REGION label B4, value G4 | DIVISION label I4, value L4
//   Row 5 (idx 4)  — SCHOOL NAME label B5, value G5 | SCHOOL ID label Q5,
//                    value S5 | SCHOOL YEAR label V5, value Y5(INPUT)/Z5(TERM)
//
// ── Row 7 — header fields written by the app ─────────────────────────────────
//   INPUT sheet:
//     Grade & Section → J7  (col idx  9, merged J7:M7)
//     Teacher         → Q7  (col idx 16, merged Q7:V7)
//     Subject         → Y7  (col idx 24, merged Y7:Z7)
//   TERM1/2/3 sheets (own independent cells, NOT linked to INPUT):
//     Grade & Section → J7  (col idx  9, merged J7:M7)  ← same col as INPUT
//     Teacher         → Q7  (col idx 16, merged Q7:V7)  ← same col as INPUT
//     Subject         → Z7  (col idx 25, merged Z7:AA7) ← DIFFERENT from INPUT
//
// ── TERM1/2/3 sheet: score area ──────────────────────────────────────────────
//   Row 8  (idx 7)  — category headers
//   Row 9  (idx 8)  — slot numbers / sub-headers
//   Row 10 (idx 9)  — Highest Possible Score (HPS)
//   Row 11 (idx 10) — "MALE" label
//   Row 12 (idx 11) — first male student score row
//   Row 62 (idx 61) — "FEMALE" label
//   Row 63 (idx 62) — first female student score row
//
//   Written/Oral Works (20%)  → slots F–J (idx 5–9), Total=K(10)  [max 5]
//   Product/Performance (50%) → slots N–P (idx 13–15), Total=Q(16) [max 3]
//   Summative Tests (30%)     → ST1=T(19), ST2=U(20), TE=V(21), Total=W(22)
//
// ── INPUT sheet: name area ───────────────────────────────────────────────────
//   Col B (idx 1) — student names
//   Row 12 (idx 11) — first male student name row
//   Row 63 (idx 62) — first female student name row
// =============================================================================

class ExcelExportService {
  // ── Shared header row (same index on all sheets) ──────────────────────────
  static const int _headerRow = 6; // row 7 (0-based)

  // ── Row 7 value cells — INPUT sheet (0-based cols) ───────────────────────
  static const int _inputGradeSectionCol = 9; // col J  (merged J7:M7)
  static const int _inputTeacherCol = 16; // col Q  (merged Q7:V7)
  static const int _inputSubjectCol = 24; // col Y  (merged Y7:Z7)

  // ── Row 7 value cells — TERM1/2/3 sheets (0-based cols) ──────────────────
  static const int _termGradeSectionCol = 9; // col J  (merged J7:M7)
  static const int _termTeacherCol = 16; // col Q  (merged Q7:V7)
  static const int _termSubjectCol = 25; // col Z  (merged Z7:AA7)

  // ── Row 5 school year value cells (0-based) ───────────────────────────────
  static const int _schoolYearRow = 4; // row 5 (0-based)
  static const int _inputSchoolYearCol = 24; // col Y  (INPUT sheet)
  static const int _termSchoolYearCol = 25; // col Z  (TERM sheets — =INPUT!Y5)

  // ── INPUT sheet: student name column and start rows (0-based) ─────────────
  static const int _inputNameCol = 1; // col B
  static const int _inputMaleStartRow = 11; // row 12
  static const int _inputFemaleStartRow = 62; // row 63

  // ── TERM sheets: HPS row and student score start rows (0-based) ───────────
  static const int _hpsRow = 9; // row 10
  static const int _termMaleStartRow = 11; // row 12
  static const int _termFemaleStartRow = 62; // row 63

  // ── TERM sheets: Written/Oral Works block (0-based cols) ─────────────────
  static const int _wwSlot1Col = 5;
  static const int _wwSlot2Col = 6;
  static const int _wwSlot3Col = 7;
  static const int _wwSlot4Col = 8;
  static const int _wwSlot5Col = 9;

  // ── TERM sheets: Product/Performance Tasks block (0-based cols) ───────────
  static const int _ptSlot1Col = 13;
  static const int _ptSlot2Col = 14;
  static const int _ptSlot3Col = 15;

  // ── TERM sheets: Summative Tests block (0-based cols) ─────────────────────
  static const int _stST1Col = 19;
  static const int _stST2Col = 20;
  static const int _stTECol = 21;

  static const List<int> _wwSlotCols = [
    _wwSlot1Col,
    _wwSlot2Col,
    _wwSlot3Col,
    _wwSlot4Col,
    _wwSlot5Col,
  ];
  static const List<int> _ptSlotCols = [_ptSlot1Col, _ptSlot2Col, _ptSlot3Col];
  static const List<int> _stSlotCols = [_stST1Col, _stST2Col, _stTECol];

  // =========================================================================
  // PUBLIC: exportAttendance
  // =========================================================================
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
        sheetObject
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = CellStyle(
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
          String displayValue = status == 'PRESENT'
              ? 'P'
              : status == 'ABSENT'
              ? 'A'
              : status == 'LATE'
              ? 'L'
              : '-';
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

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      final result = await Share.shareXFiles([
        XFile(
          tempFile.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        ),
      ], subject: fileName);

      if (result.status == ShareResultStatus.success) return fileName;
      return null;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }

  // =========================================================================
  // PUBLIC: exportGradeSummary
  // =========================================================================
  static Future<String?> exportGradeSummary({
    required String sectionName,
    required List<Map<String, dynamic>> rows,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Grades'];
      excel.delete('Sheet1');

      final headers = [
        TextCellValue('Student Name'),
        TextCellValue('Percent'),
        TextCellValue('Transmuted Grade'),
      ];
      sheet.appendRow(headers);

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#085041'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
        );
      }

      for (var r in rows) {
        sheet.appendRow([
          TextCellValue(r['full_name'] ?? 'Unknown'),
          TextCellValue((r['percent'] ?? 0.0).toString()),
          TextCellValue(r['transmuted']?.toString() ?? ''),
        ]);
      }

      for (int i = 0; i < 3; i++) {
        sheet.setColumnWidth(i, i == 0 ? 28.0 : 16.0);
      }

      final bytes = excel.encode();
      if (bytes == null) return null;

      final sanitizedSection = sectionName.replaceAll(RegExp(r'[^-]'), '_');
      final fileName =
          'Grades_${sanitizedSection}_${DateTime.now().toIso8601String()}.xlsx';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      final result = await Share.shareXFiles([
        XFile(
          tempFile.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        ),
      ], subject: fileName);

      if (await tempFile.exists()) await tempFile.delete();

      if (result.status == ShareResultStatus.success) return fileName;
      return null;
    } catch (e) {
      print('Excel export error: $e');
      return null;
    }
  }

  // =========================================================================
  // PUBLIC: exportTermGradesWithTemplate
  // =========================================================================
  static Future<String?> exportTermGradesWithTemplate({
    required BuildContext context,
    required String sectionName,
    required String teacherName,
    required String subjectName,
    required String schoolYear,
    required String gradeLevel,
    required List<Map<String, dynamic>> allStudents,
    required List<Map<String, dynamic>> allCategories,
    required List<Map<String, dynamic>> allGradeItems,
    required Map<String, Map<String, double>> studentScores,
  }) async {
    try {
      // ── Load template ─────────────────────────────────────────────────────
      final ByteData data = await rootBundle.load(
        'assets/templates/E-Class_Record_Template.xlsx',
      );
      final Uint8List templateBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // Decode inside its own try/catch to give a clearer error if the asset
      // itself is corrupted or the wrong file was bundled.
      late final Excel excelDoc;
      try {
        excelDoc = Excel.decodeBytes(templateBytes);
      } catch (e) {
        print('[ExcelExport] Failed to decode template: $e');
        return null;
      }

      final Sheet? inputSheet = excelDoc.tables['INPUT'];
      final Sheet? term1Sheet = excelDoc.tables['TERM1'];
      final Sheet? term2Sheet = excelDoc.tables['TERM2'];
      final Sheet? term3Sheet = excelDoc.tables['TERM3'];

      if (inputSheet == null) {
        print(
          '[ExcelExport] Template missing INPUT sheet. Available sheets: ${excelDoc.tables.keys.toList()}',
        );
        return null;
      }
      if (term1Sheet == null) {
        print(
          '[ExcelExport] Template missing TERM1 sheet. Available sheets: ${excelDoc.tables.keys.toList()}',
        );
        return null;
      }

      final allSlotCols = [..._wwSlotCols, ..._ptSlotCols, ..._stSlotCols];
      for (final sheet in [term1Sheet, term2Sheet, term3Sheet]) {
        if (sheet == null) continue; // Skip if the sheet didn't load

        for (final col in allSlotCols) {
          sheet.setColumnWidth(col, 11.0);
        }
      }
      // ── Fix header layout on all sheets (rows 1–6) ───────────────────────
      for (final sheet in [inputSheet, term1Sheet, term2Sheet, term3Sheet]) {
        if (sheet != null) _fixHeaderLayout(sheet);
      }

      final String gradeSectionValue = 'Grade $gradeLevel - $sectionName';

      // ── Write row-7 header fields ─────────────────────────────────────────
      _writeText(
        inputSheet,
        col: _inputGradeSectionCol,
        row: _headerRow,
        value: gradeSectionValue,
      );
      _writeText(
        inputSheet,
        col: _inputTeacherCol,
        row: _headerRow,
        value: teacherName,
      );
      _writeText(
        inputSheet,
        col: _inputSubjectCol,
        row: _headerRow,
        value: subjectName,
      );

      // ── Write school year into INPUT row 5 ────────────────────────────────
      // TERM sheets reference this via =INPUT!Y5, so we only write to INPUT.
      _writeText(
        inputSheet,
        col: _inputSchoolYearCol,
        row: _schoolYearRow,
        value: schoolYear,
      );

      // ── Write TERM1/2/3 header fields ─────────────────────────────────────
      for (final termSheet in [term1Sheet, term2Sheet, term3Sheet]) {
        if (termSheet == null) continue;
        _writeText(
          termSheet,
          col: _termGradeSectionCol,
          row: _headerRow,
          value: gradeSectionValue,
        );
        _writeText(
          termSheet,
          col: _termTeacherCol,
          row: _headerRow,
          value: teacherName,
        );
        _writeText(
          termSheet,
          col: _termSubjectCol,
          row: _headerRow,
          value: subjectName,
        );
      }

      // ── Bucket grade items by category ───────────────────────────────────
      // ── Bucket grade items by category ───────────────────────────────────
      final Set<String> wwCatIds = {};
      final Set<String> ptCatIds = {};
      final Set<String> stCatIds = {};

      for (final cat in allCategories) {
        final name = (cat['name'] as String? ?? '').toLowerCase();
        final id = cat['id']?.toString();
        if (id == null) continue;
        if (name.contains('written') || name.contains('oral')) {
          wwCatIds.add(id);
        } else if (name.contains('performance') || name.contains('product')) {
          ptCatIds.add(id);
        } else if (name.contains('summative') ||
            name.contains('exam') ||
            name.contains('test')) {
          stCatIds.add(id);
        }
      }

      // --- NEW LOGIC: Helper function to check if the task has a term ---
      bool hasValidPeriod(Map<String, dynamic> item) {
        final pid = item['period_id']?.toString().trim();
        return pid != null && pid.isNotEmpty;
      }

      // --- UPDATED LOGIC: Filter by category AND ensure it has a term ---
      final wwTasks = allGradeItems
          .where(
            (i) =>
                wwCatIds.contains(i['category_id']?.toString()) &&
                hasValidPeriod(i),
          )
          .toList();

      final ptTasks = allGradeItems
          .where(
            (i) =>
                ptCatIds.contains(i['category_id']?.toString()) &&
                hasValidPeriod(i),
          )
          .toList();

      final stTasks = allGradeItems
          .where(
            (i) =>
                stCatIds.contains(i['category_id']?.toString()) &&
                hasValidPeriod(i),
          )
          .toList();

      // ── Write HPS row ─────────────────────────────────────────────────────
      _writeHps(term1Sheet, tasks: wwTasks, slotCols: _wwSlotCols);
      _writeHps(term1Sheet, tasks: ptTasks, slotCols: _ptSlotCols);
      _writeHps(term1Sheet, tasks: stTasks, slotCols: _stSlotCols);

      // ── Sort students ─────────────────────────────────────────────────────
      bool isMale(Map<String, dynamic> s) {
        final g = s['gender']?.toString().toLowerCase() ?? '';
        return g == 'male' || g == 'm';
      }

      bool isFemale(Map<String, dynamic> s) {
        final g = s['gender']?.toString().toLowerCase() ?? '';
        return g == 'female' || g == 'f';
      }

      int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
          (a['full_name'] as String? ?? '').compareTo(
            b['full_name'] as String? ?? '',
          );

      final males = allStudents.where(isMale).toList()..sort(byName);
      final females = allStudents.where(isFemale).toList()..sort(byName);

      // ── Inject student names + scores ─────────────────────────────────────
      _writeStudentGroup(
        students: males,
        inputSheet: inputSheet,
        term1Sheet: term1Sheet,
        nameStartRow: _inputMaleStartRow,
        scoreStartRow: _termMaleStartRow,
        wwTasks: wwTasks,
        ptTasks: ptTasks,
        stTasks: stTasks,
        studentScores: studentScores,
      );

      _writeStudentGroup(
        students: females,
        inputSheet: inputSheet,
        term1Sheet: term1Sheet,
        nameStartRow: _inputFemaleStartRow,
        scoreStartRow: _termFemaleStartRow,
        wwTasks: wwTasks,
        ptTasks: ptTasks,
        stTasks: stTasks,
        studentScores: studentScores,
      );

      // ── Encode & save ─────────────────────────────────────────────────────
      final List<int>? exportedBytes = excelDoc.encode();
      if (exportedBytes == null) {
        print(
          '[ExcelExport] encode() returned null — workbook may be corrupt.',
        );
        return null;
      }

      final sanitized = sectionName.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final fileName = 'E-Class_Record_$sanitized.xlsx';

      // Call our shared file picker helper instead of Share.shareXFiles
      return await _saveExcelToDevice(exportedBytes, fileName, context);
    } catch (e, st) {
      print('[ExcelExport] Fatal error: $e');
      print('[ExcelExport] Stack trace: $st');
      return null;
    }
  }

  // ── Shared Save Helper ──────────────────────────────────────────────────
  static Future<String?> _saveExcelToDevice(
    List<int> bytes,
    String fileName,
    BuildContext context,
  ) async {
    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.manageExternalStorage
            .request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Please allow it in Settings.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose where to save the Excel file',
      );

      if (selectedDirectory == null) return null;

      final filePath = '$selectedDirectory/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $filePath'),
            backgroundColor: const Color(0xFF0F6E56), // Your Teal Mid color
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return filePath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // =========================================================================
  // PRIVATE HELPERS
  // =========================================================================

  /// Fixes layout for rows 1–6 on each sheet after template is loaded:
  ///  • "Class Record" (A1) — horizontally and vertically centered
  ///  • Label cells (REGION, DIVISION, SCHOOL NAME, SCHOOL ID, SCHOOL YEAR) — right-justified
  ///  • All cells in rows 1–6 — borders removed
  static void _fixHeaderLayout(Sheet sheet) {
    final noBorder = Border(borderStyle: BorderStyle.None);

    // Strip borders from every cell in rows 1–6 (0-based: rows 0–5)
    for (int r = 0; r < 6; r++) {
      for (final cell in sheet.row(r)) {
        if (cell == null) continue;
        cell.cellStyle = (cell.cellStyle ?? CellStyle()).copyWith(
          leftBorderVal: noBorder,
          rightBorderVal: noBorder,
          topBorderVal: noBorder,
          bottomBorderVal: noBorder,
        );
      }
    }

    // "Class Record" — A1 (row 0, col 0) — center both axes
    final titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bold: true, // Works perfectly in the base constructor
      fontSize: 21,
      fontFamily: 'Arial',
    );

    // A3 DepEd order note (row 2, col 0) — center both axes
    final subtitleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
    );
    subtitleCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontSize: 7,
      italic: true,
    );

    // Label cells — right-justified (0-based row/col):
    // REGION=B4(r3,c1), DIVISION=I4(r3,c8), SCHOOL NAME=B5(r4,c1),
    // SCHOOL ID=Q5(r4,c16), SCHOOL YEAR=V5(r4,c21)
    const labelPositions = [
      (r: 3, c: 1), // REGION
      (r: 3, c: 8), // DIVISION
      (r: 4, c: 1), // SCHOOL NAME
      (r: 4, c: 16), // SCHOOL ID
      (r: 4, c: 21), // SCHOOL YEAR
    ];
    for (final pos in labelPositions) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: pos.c, rowIndex: pos.r),
      );
      cell.cellStyle = (cell.cellStyle ?? CellStyle()).copyWith(
        horizontalAlignVal: HorizontalAlign.Right,
      );
    }
  }

  static void _writeHps(
    Sheet sheet, {
    required List<Map<String, dynamic>> tasks,
    required List<int> slotCols,
  }) {
    for (int i = 0; i < tasks.length && i < slotCols.length; i++) {
      final maxScore =
          (tasks[i]['max_points'] as num?)?.toDouble() ??
          (tasks[i]['max_score'] as num?)?.toDouble() ??
          0.0;
      _writeNumber(sheet, col: slotCols[i], row: _hpsRow, value: maxScore);
    }
  }

  static void _writeStudentGroup({
    required List<Map<String, dynamic>> students,
    required Sheet inputSheet,
    required Sheet term1Sheet,
    required int nameStartRow,
    required int scoreStartRow,
    required List<Map<String, dynamic>> wwTasks,
    required List<Map<String, dynamic>> ptTasks,
    required List<Map<String, dynamic>> stTasks,
    required Map<String, Map<String, double>> studentScores,
  }) {
    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      final studentId = student['id']?.toString();
      if (studentId == null) continue;

      final fullName = student['full_name'] as String? ?? '';
      final scores = studentScores[studentId] ?? {};

      _writeText(
        inputSheet,
        col: _inputNameCol,
        row: nameStartRow + i,
        value: fullName,
      );
      _writeText(
        term1Sheet,
        col: _inputNameCol,
        row: scoreStartRow + i,
        value: fullName,
      );

      _writeScores(
        term1Sheet,
        rowIndex: scoreStartRow + i,
        tasks: wwTasks,
        slotCols: _wwSlotCols,
        scores: scores,
      );
      _writeScores(
        term1Sheet,
        rowIndex: scoreStartRow + i,
        tasks: ptTasks,
        slotCols: _ptSlotCols,
        scores: scores,
      );
      _writeScores(
        term1Sheet,
        rowIndex: scoreStartRow + i,
        tasks: stTasks,
        slotCols: _stSlotCols,
        scores: scores,
      );
    }
  }

  static void _writeScores(
    Sheet sheet, {
    required int rowIndex,
    required List<Map<String, dynamic>> tasks,
    required List<int> slotCols,
    required Map<String, double> scores,
  }) {
    for (int i = 0; i < tasks.length && i < slotCols.length; i++) {
      final taskId = tasks[i]['id']?.toString();
      if (taskId == null) continue;
      final score = scores[taskId];
      if (score != null) {
        _writeNumber(sheet, col: slotCols[i], row: rowIndex, value: score);
      }
    }
  }

  static void _writeText(
    Sheet sheet, {
    required int col,
    required int row,
    required String value,
  }) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(
      value,
    );
  }

  static void _writeNumber(
    Sheet sheet, {
    required int col,
    required int row,
    required double value,
  }) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = DoubleCellValue(
      value,
    );
  }
}
