import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../attendance/repository/attendance_repository.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  final _attendanceRepo = AttendanceRepository();

  bool _isLoading = true;
  bool _isExporting = false;
  String? _selectedSectionId;

  // --- FILTER & SORT STATES ---
  String _searchQuery = '';
  String _selectedGenderFilter = 'All'; // Options: 'All', 'Male', 'Female'
  String _sortBy = 'gender'; // Defaulted to gender grouping

  DateTime? _fromDate;
  DateTime? _toDate;

  List<Map<String, dynamic>> _sections = [];
  List<String> _allDatesForSection = [];

  final Map<String, String> _studentIdToName = {};
  final Map<String, String> _studentIdToGender = {};
  Map<String, Map<String, String>> _matrixData = {};

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    try {
      final sectionsData = await _attendanceRepo.getAvailableSections();
      if (sectionsData.isNotEmpty) {
        _sections = sectionsData;
        _selectedSectionId = sectionsData.first['id'] as String;
        await _loadHistoricalMatrix();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error initializing data: $e");
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED SAVE HELPER — asks user to pick a folder, writes file there
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveExcelToDevice(List<int> bytes, String fileName) async {
    try {
      if (Platform.isAndroid) {
        // Request storage permission (Android 10 and below needs WRITE,
        // Android 11+ needs MANAGE_EXTERNAL_STORAGE for arbitrary paths)
        PermissionStatus status = await Permission.manageExternalStorage
            .request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Please allow it in Settings.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Let the user pick a destination folder
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose where to save the Excel file',
      );

      // User cancelled the picker
      if (selectedDirectory == null) return;

      final filePath = '$selectedDirectory/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showExportMonthPicker() async {
    // Build list of available months from all dates
    final Set<String> availableMonths = {};
    for (final dateStr in _allDatesForSection) {
      final trimmed = dateStr.length > 7 ? dateStr.substring(0, 7) : dateStr;
      availableMonths.add(trimmed); // 'YYYY-MM'
    }
    final sortedMonths = availableMonths.toList()..sort();

    if (sortedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance data available to export.'),
        ),
      );
      return;
    }

    String? pickedMonth = sortedMonths.last; // default to latest month

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Export by Month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a month to export:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pickedMonth,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: sortedMonths.map((m) {
                      // Format 'YYYY-MM' → 'January 2025'
                      final parts = m.split('-');
                      final dt = DateTime(
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                      );
                      final label = '${_monthName(dt.month)} ${dt.year}';
                      return DropdownMenuItem(value: m, child: Text(label));
                    }).toList(),
                    onChanged: (val) => setModalState(() => pickedMonth = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (pickedMonth != null) {
                      _exportToExcelByMonth(pickedMonth!);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month];
  }

  Future<void> _exportToExcelByMonth(String yearMonth) async {
    // yearMonth format: 'YYYY-MM'
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthLabel = '${_monthName(month)} $year';

    // Filter dates to selected month only
    final monthDates = _allDatesForSection.where((dateStr) {
      final trimmed = dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
      return trimmed.startsWith(yearMonth);
    }).toList()..sort();

    if (monthDates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No data found for $monthLabel.')));
      return;
    }

    // Get student IDs (no HEADER_ entries)
    final studentIds = _filteredStudentIds
        .where((id) => !id.startsWith('HEADER_'))
        .toList();

    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No students found.')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Attendance'];
      excel.delete('Sheet1');

      // ── Row 0: Big title "Month of January 2025" merged across all columns
      final totalCols =
          1 + monthDates.length + 2; // name + dates + present + absent
      sheet.appendRow([
        TextCellValue('Month of $monthLabel'),
        ...List.filled(totalCols - 1, TextCellValue('')),
      ]);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#FF8F00'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      // ── Row 1: Column headers — Name | 01 | 02 | 03 ... | Present | Absent
      List<CellValue> headers = [
        TextCellValue('Student Name'),
        ...monthDates.map((d) {
          // Extract just the day number: '2025-01-03' → '03'
          final day = d.length >= 10 ? d.substring(8, 10) : d;
          return TextCellValue(day);
        }),
        TextCellValue('Present'),
        TextCellValue('Absent'),
      ];
      sheet.appendRow(headers);

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
            .cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
          fontColorHex: ExcelColor.fromHexString('#E65100'),
          horizontalAlign: i == 0
              ? HorizontalAlign.Left
              : HorizontalAlign.Center,
        );
      }

      // ── Data rows
      int rowIndex = 2;
      bool isAlternate = false;

      for (String studentId in studentIds) {
        final name = _studentIdToName[studentId] ?? 'Unknown';
        int presentCount = 0;
        int absentCount = 0;

        List<CellValue> row = [TextCellValue(name)];

        for (String date in monthDates) {
          final status = _matrixData[studentId]?[date] ?? '-';
          if (status == 'PRESENT') presentCount++;
          if (status == 'ABSENT') absentCount++;

          final display = status == 'PRESENT'
              ? 'P'
              : status == 'ABSENT'
              ? 'A'
              : '-';
          row.add(TextCellValue(display));
        }

        row.add(IntCellValue(presentCount));
        row.add(IntCellValue(absentCount));
        sheet.appendRow(row);

        // Alternating row background
        final rowBg = isAlternate ? '#FFF8E1' : '#FFFFFF';
        for (int i = 0; i < row.length; i++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex),
          );
          final isPresent =
              i > 0 &&
              i <= monthDates.length &&
              _matrixData[studentId]?[monthDates[i - 1]] == 'PRESENT';
          final isAbsent =
              i > 0 &&
              i <= monthDates.length &&
              _matrixData[studentId]?[monthDates[i - 1]] == 'ABSENT';

          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(
              isPresent
                  ? '#E8F5E9'
                  : isAbsent
                  ? '#FFEBEE'
                  : rowBg,
            ),
            fontColorHex: ExcelColor.fromHexString(
              isPresent
                  ? '#2E7D32'
                  : isAbsent
                  ? '#C62828'
                  : '#212121',
            ),
            horizontalAlign: i == 0
                ? HorizontalAlign.Left
                : HorizontalAlign.Center,
          );
        }

        // Bold + color the totals columns
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: monthDates.length + 1,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString('#1B5E20'),
          backgroundColorHex: ExcelColor.fromHexString(rowBg),
          horizontalAlign: HorizontalAlign.Center,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: monthDates.length + 2,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString('#B71C1C'),
          backgroundColorHex: ExcelColor.fromHexString(rowBg),
          horizontalAlign: HorizontalAlign.Center,
        );

        isAlternate = !isAlternate;
        rowIndex++;
      }

      // ── Column widths
      sheet.setColumnWidth(0, 30.0); // Name column
      for (int i = 1; i <= monthDates.length; i++) {
        sheet.setColumnWidth(i, 6.0); // Day columns narrow
      }
      sheet.setColumnWidth(monthDates.length + 1, 10.0); // Present
      sheet.setColumnWidth(monthDates.length + 2, 10.0); // Absent

      // ── Encode & save via folder picker
      final bytes = excel.encode();

      if (bytes != null) {
        String sectionName = _sections.firstWhere(
          (s) => s['id'] == _selectedSectionId,
          orElse: () => {'name': 'Class'},
        )['name'];
        String safeName = sectionName.replaceAll(RegExp(r'[^\w\s]+'), '_');
        String fileName =
            'Attendance_${safeName}_${yearMonth.replaceAll('-', '_')}.xlsx';

        await _saveExcelToDevice(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _loadHistoricalMatrix() async {
    if (_selectedSectionId == null) return;
    setState(() => _isLoading = true);

    final rawLogs = await _attendanceRepo.getHistoricalSectionAttendance(
      _selectedSectionId!,
    );

    final Map<String, String> idToNameMap = {};
    final Map<String, String> idToGenderMap = {};
    final Map<String, Map<String, String>> structuralMatrix = {};
    final Set<String> uniqueDates = {};

    for (var row in rawLogs) {
      final studentId = row['student_id'].toString();
      final fullName = row['full_name'] as String;
      final gender = row['gender'] as String? ?? 'N/A';
      final dateStr = row['date'] as String?;
      final status = row['status'] as String?;

      idToNameMap[studentId] = fullName;
      idToGenderMap[studentId] = gender;

      if (!structuralMatrix.containsKey(studentId)) {
        structuralMatrix[studentId] = {};
      }

      if (dateStr != null && status != null) {
        structuralMatrix[studentId]![dateStr] = status;
        uniqueDates.add(dateStr);
      }
    }

    setState(() {
      _studentIdToName.clear();
      _studentIdToName.addAll(idToNameMap);

      _studentIdToGender.clear();
      _studentIdToGender.addAll(idToGenderMap);

      _matrixData = structuralMatrix;
      _allDatesForSection = uniqueDates.toList()..sort();
      _isLoading = false;
    });
  }

  List<String> get _filteredDates {
    return _allDatesForSection.where((dateStr) {
      DateTime? recordDate;
      try {
        // Handle both 'YYYY-MM-DD' and 'YYYY-MM-DD HH:MM:SS' formats
        recordDate = DateTime.parse(
          dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr,
        );
      } catch (_) {
        return true; // Don't filter out unparseable dates
      }

      // Normalize to date-only (strip time)
      final from = _fromDate != null
          ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
          : null;
      final to = _toDate != null
          ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day)
          : null;
      final record = DateTime(
        recordDate.year,
        recordDate.month,
        recordDate.day,
      );

      if (from != null && record.isBefore(from)) return false;
      if (to != null && record.isAfter(to)) return false; // inclusive
      return true;
    }).toList();
  }

  List<String> get _filteredStudentIds {
    final list = _matrixData.keys.where((id) {
      final studentName = _studentIdToName[id] ?? '';
      final studentGender = (_studentIdToGender[id] ?? 'N/A').toLowerCase();

      final matchesName = studentName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      bool matchesGender = false;
      if (_selectedGenderFilter == 'All') {
        matchesGender = true;
      } else if (_selectedGenderFilter == 'Male') {
        matchesGender = studentGender == 'male' || studentGender == 'm';
      } else if (_selectedGenderFilter == 'Female') {
        matchesGender = studentGender == 'female' || studentGender == 'f';
      }

      return matchesName && matchesGender;
    }).toList();

    if (_sortBy == 'name') {
      list.sort(
        (a, b) =>
            (_studentIdToName[a] ?? '').compareTo(_studentIdToName[b] ?? ''),
      );
      return list;
    } else if (_sortBy == 'gender') {
      final boysList =
          list.where((id) {
            final g = (_studentIdToGender[id] ?? '').toLowerCase();
            return g == 'male' || g == 'm';
          }).toList()..sort(
            (a, b) => (_studentIdToName[a] ?? '').compareTo(
              _studentIdToName[b] ?? '',
            ),
          );

      final girlsList =
          list.where((id) {
            final g = (_studentIdToGender[id] ?? '').toLowerCase();
            return g == 'female' || g == 'f';
          }).toList()..sort(
            (a, b) => (_studentIdToName[a] ?? '').compareTo(
              _studentIdToName[b] ?? '',
            ),
          );

      final unassignedList =
          list.where((id) {
            final g = (_studentIdToGender[id] ?? '').toLowerCase();
            return g != 'male' && g != 'm' && g != 'female' && g != 'f';
          }).toList()..sort(
            (a, b) => (_studentIdToName[a] ?? '').compareTo(
              _studentIdToName[b] ?? '',
            ),
          );

      final combinedResult = <String>[];
      if (boysList.isNotEmpty) {
        combinedResult.add('HEADER_BOYS');
        combinedResult.addAll(boysList);
      }
      if (girlsList.isNotEmpty) {
        combinedResult.add('HEADER_GIRLS');
        combinedResult.addAll(girlsList);
      }
      if (unassignedList.isNotEmpty) {
        combinedResult.add('HEADER_UNASSIGNED');
        combinedResult.addAll(unassignedList);
      }
      return combinedResult;
    }
    return list;
  }

  Future<void> _exportToExcel() async {
    if (_filteredDates.isEmpty || _filteredStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Attendance Export'];
      excel.delete('Sheet1');

      List<CellValue> headers = [
        TextCellValue('Student Name'),
        ..._filteredDates.map((d) => TextCellValue(d)),
        TextCellValue('Total Present'),
        TextCellValue('Total Absent'),
      ];
      sheet.appendRow(headers);

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FF8F00'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      int currentRowIndex = 1;
      for (String studentId in _filteredStudentIds) {
        if (studentId.startsWith('HEADER_')) {
          String headerLabel = studentId == 'HEADER_BOYS'
              ? 'Boys:'
              : (studentId == 'HEADER_GIRLS' ? 'Girls:' : 'Unassigned:');

          List<CellValue> separatorRow = [TextCellValue(headerLabel)];
          for (int d = 0; d < _filteredDates.length + 2; d++) {
            separatorRow.add(TextCellValue(''));
          }
          sheet.appendRow(separatorRow);

          for (int i = 0; i < headers.length; i++) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: currentRowIndex,
                  ),
                )
                .cellStyle = CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
            );
          }
          currentRowIndex++;
          continue;
        }

        String name = _studentIdToName[studentId] ?? 'Unknown';
        int presentCount = 0;
        int absentCount = 0;

        List<CellValue> row = [TextCellValue(name)];

        for (String date in _filteredDates) {
          String status = _matrixData[studentId]?[date] ?? '-';
          if (status == 'PRESENT') presentCount++;
          if (status == 'ABSENT') absentCount++;
          String shortStatus = status == 'PRESENT'
              ? 'P'
              : (status == 'ABSENT' ? 'A' : '-');
          row.add(TextCellValue(shortStatus));
        }

        row.add(IntCellValue(presentCount));
        row.add(IntCellValue(absentCount));
        sheet.appendRow(row);
        currentRowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, i == 0 ? 30.0 : 14.0);
      }

      final bytes = excel.encode();

      if (bytes != null) {
        String sectionName = _sections.firstWhere(
          (s) => s['id'] == _selectedSectionId,
          orElse: () => {'name': 'Class'},
        )['name'];
        String safeName = sectionName.replaceAll(RegExp(r'[^\w\s]+'), '_');
        String fileName =
            'Attendance_${safeName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        await _saveExcelToDevice(bytes, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showDateFilterModal() async {
    DateTime? tempFrom = _fromDate;
    DateTime? tempTo = _toDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Filter by Date Range',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('From Date'),
                    subtitle: Text(
                      tempFrom != null
                          ? tempFrom!.toIso8601String().split('T')[0]
                          : 'Not set',
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setModalState(() => tempFrom = picked);
                    },
                  ),
                  ListTile(
                    title: const Text('To Date'),
                    subtitle: Text(
                      tempTo != null
                          ? tempTo!.toIso8601String().split('T')[0]
                          : 'Not set',
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempTo ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setModalState(() => tempTo = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _fromDate = tempFrom;
                      _toDate = tempTo;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeDates = _filteredDates;
    final activeStudentIds = _filteredStudentIds;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Attendance Logs Matrix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _showExportMonthPicker,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Class/Section',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedSectionId,
                  items: _sections.map((sec) {
                    return DropdownMenuItem(
                      value: sec['id'] as String,
                      child: Text(
                        '${sec['name']} (Grade ${sec['grade_level']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _selectedSectionId = val;
                      _loadHistoricalMatrix();
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Student Name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGenderFilter,
                        decoration: const InputDecoration(
                          labelText: 'Gender View',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('Show All'),
                          ),
                          DropdownMenuItem(
                            value: 'Male',
                            child: Text('Boys Only'),
                          ),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Girls Only'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedGenderFilter = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Grouping Style',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'gender',
                            child: Text('Grouped (Boys / Girls)'),
                          ),
                          DropdownMenuItem(
                            value: 'name',
                            child: Text('Plain Alphabetical'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _sortBy = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _fromDate == null && _toDate == null
                              ? 'Filter by Date Range'
                              : '${_fromDate != null ? _fromDate!.toIso8601String().split('T')[0] : 'Start'}'
                                    ' → '
                                    '${_toDate != null ? _toDate!.toIso8601String().split('T')[0] : 'End'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ).copyWith(left: 12),
                          alignment: Alignment.centerLeft,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: _showDateFilterModal,
                      ),
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.redAccent,
                        ),
                        tooltip: 'Clear Date Range',
                        style: IconButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.all(14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : activeStudentIds.isEmpty
                ? const Center(child: Text('No records found.'))
                : InteractiveScrollGrid(
                    activeDates: activeDates,
                    activeStudentIds: activeStudentIds,
                    studentIdToName: _studentIdToName,
                    matrixData: _matrixData,
                  ),
          ),
        ],
      ),
    );
  }
}

class InteractiveScrollGrid extends StatelessWidget {
  final List<String> activeDates;
  final List<String> activeStudentIds;
  final Map<String, String> studentIdToName;
  final Map<String, Map<String, String>> matrixData;

  const InteractiveScrollGrid({
    super.key,
    required this.activeDates,
    required this.activeStudentIds,
    required this.studentIdToName,
    required this.matrixData,
  });

  @override
  Widget build(BuildContext context) {
    const double rowHeight = 44.0;
    const double headingHeight = 50.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STICKY SIDE: Student names and dynamic group headers
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              headingRowHeight: headingHeight,
              dataRowHeight: rowHeight,
              horizontalMargin: 16,
              columnSpacing: 0,
              border: TableBorder.all(color: Colors.grey.shade200),
              columns: const [
                DataColumn(
                  label: Text(
                    'Student Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: activeStudentIds.map((studentId) {
                if (studentId.startsWith('HEADER_')) {
                  String label = studentId == 'HEADER_BOYS'
                      ? 'Boys:'
                      : (studentId == 'HEADER_GIRLS'
                            ? 'Girls:'
                            : 'Unassigned:');
                  Color labelColor = studentId == 'HEADER_BOYS'
                      ? Colors.blue.shade800
                      : Colors.pink.shade800;

                  return DataRow(
                    color: WidgetStateProperty.all(Colors.grey.shade100),
                    cells: [
                      DataCell(
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: labelColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return DataRow(
                  cells: [
                    DataCell(Text(studentIdToName[studentId] ?? 'Unknown')),
                  ],
                );
              }).toList(),
            ),
          ),

          // SCROLLABLE SIDE: Dates and total scores matrices
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                headingRowHeight: headingHeight,
                dataRowHeight: rowHeight,
                horizontalMargin: 12,
                columnSpacing: 24,
                border: TableBorder.all(color: Colors.grey.shade200),
                columns: [
                  ...activeDates.map(
                    (date) => DataColumn(
                      label: Text(
                        date,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Present',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Absent',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
                rows: activeStudentIds.map((studentId) {
                  if (studentId.startsWith('HEADER_')) {
                    return DataRow(
                      color: WidgetStateProperty.all(Colors.grey.shade100),
                      cells: [
                        ...activeDates.map(
                          (_) => const DataCell(SizedBox.shrink()),
                        ),
                        const DataCell(SizedBox.shrink()),
                        const DataCell(SizedBox.shrink()),
                      ],
                    );
                  }

                  int presentSum = 0;
                  int absentSum = 0;

                  final dateCells = activeDates.map((date) {
                    final status = matrixData[studentId]?[date] ?? '-';
                    Color txtColor = Colors.grey;
                    Color bgColor = Colors.transparent;

                    if (status == 'PRESENT') {
                      presentSum++;
                      txtColor = Colors.green.shade800;
                      bgColor = Colors.green.shade50;
                    } else if (status == 'ABSENT') {
                      absentSum++;
                      txtColor = Colors.red.shade800;
                      bgColor = Colors.red.shade50;
                    }

                    return DataCell(
                      Container(
                        alignment: Alignment.center,
                        color: bgColor,
                        child: Text(
                          status == 'PRESENT'
                              ? 'P'
                              : status == 'ABSENT'
                              ? 'A'
                              : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: txtColor,
                          ),
                        ),
                      ),
                    );
                  }).toList();

                  return DataRow(
                    cells: [
                      ...dateCells,
                      DataCell(
                        Center(
                          child: Text(
                            '$presentSum',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Text(
                            '$absentSum',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
