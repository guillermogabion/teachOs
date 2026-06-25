import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../attendance/repository/attendance_repository.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealLight = Color(0xFF5DCAA5);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);

  static const blueSurf = Color(0xFFE6F1FB);
  static const blueText = Color(0xFF185FA5);

  static const purpleSurf = Color(0xFFEEEDFE);
  static const purpleText = Color(0xFF534AB7);

  static const pinkSurf = Color(0xFFFBEAF0);
  static const pinkText = Color(0xFF993556);

  static const greenSurf = Color(0xFFEAF3DE);
  static const greenText = Color(0xFF3B6D11);

  static const amberSurf = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF854F0B);

  static const graySurf = Color(0xFFF1EFE8);
  static const grayText = Color(0xFF444441);

  static const redSurf = Color(0xFFFCEBEB);
  static const redText = Color(0xFFA32D2D);
  static const redBorder = Color(0xFFF09595);
}

// ─── Reusable Rounded Input Field Style ───────────────────────────
InputDecoration _buildInputDecoration({
  required String labelText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen>
    with RestorationMixin<AttendanceRecordsScreen> {
  final RestorableString _attendanceScreen = RestorableString('');
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
  String? get restorationId => 'attendance_records_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_attendanceScreen, 'attendance_records_screen');
  }

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
                backgroundColor: _Brand.redText,
              ),
            );
          }
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose where to save the Excel file',
      );

      if (selectedDirectory == null) return;

      final filePath = '$selectedDirectory/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $filePath'),
            backgroundColor: _Brand.tealMid,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: _Brand.redText,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showExportMonthPicker() async {
    final Set<String> availableMonths = {};
    for (final dateStr in _allDatesForSection) {
      final trimmed = dateStr.length > 7 ? dateStr.substring(0, 7) : dateStr;
      availableMonths.add(trimmed);
    }
    final sortedMonths = availableMonths.toList()..sort();

    if (sortedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance data available to export.'),
          backgroundColor: _Brand.grayText,
        ),
      );
      return;
    }

    String? pickedMonth = sortedMonths.last;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Export by Month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _Brand.tealDark,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a month to export:',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pickedMonth,
                    decoration: _buildInputDecoration(
                      labelText: 'Month Selection',
                    ),
                    items: sortedMonths.map((m) {
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Brand.tealMid,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
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
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthLabel = '${_monthName(month)} $year';

    final monthDates = _allDatesForSection.where((dateStr) {
      final trimmed = dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
      return trimmed.startsWith(yearMonth);
    }).toList()..sort();

    if (monthDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data found for $monthLabel.'),
          backgroundColor: _Brand.grayText,
        ),
      );
      return;
    }

    final studentIds = _filteredStudentIds
        .where((id) => !id.startsWith('HEADER_'))
        .toList();

    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students found.'),
          backgroundColor: _Brand.grayText,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Attendance'];
      excel.delete('Sheet1');

      final totalCols = 1 + monthDates.length + 2;
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
        backgroundColorHex: ExcelColor.fromHexString(
          '#0F6E56',
        ), // Brand Teal Mid
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      List<CellValue> headers = [
        TextCellValue('Student Name'),
        ...monthDates.map((d) {
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
          backgroundColorHex: ExcelColor.fromHexString('#EAF8F3'), // Teal Surf
          fontColorHex: ExcelColor.fromHexString('#085041'), // Teal Dark
          horizontalAlign: i == 0
              ? HorizontalAlign.Left
              : HorizontalAlign.Center,
        );
      }

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

        final rowBg = isAlternate ? '#F9FBFB' : '#FFFFFF';
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
                  ? '#EAF8F3'
                  : isAbsent
                  ? '#FCEBEB'
                  : rowBg,
            ),
            fontColorHex: ExcelColor.fromHexString(
              isPresent
                  ? '#0F6E56'
                  : isAbsent
                  ? '#A32D2D'
                  : '#333333',
            ),
            horizontalAlign: i == 0
                ? HorizontalAlign.Left
                : HorizontalAlign.Center,
          );
        }

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: monthDates.length + 1,
                rowIndex: rowIndex,
              ),
            )
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString('#0F6E56'),
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
          fontColorHex: ExcelColor.fromHexString('#A32D2D'),
          backgroundColorHex: ExcelColor.fromHexString(rowBg),
          horizontalAlign: HorizontalAlign.Center,
        );

        isAlternate = !isAlternate;
        rowIndex++;
      }

      sheet.setColumnWidth(0, 30.0);
      for (int i = 1; i <= monthDates.length; i++) {
        sheet.setColumnWidth(i, 6.0);
      }
      sheet.setColumnWidth(monthDates.length + 1, 10.0);
      sheet.setColumnWidth(monthDates.length + 2, 10.0);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: _Brand.redText,
          ),
        );
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
        recordDate = DateTime.parse(
          dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr,
        );
      } catch (_) {
        return true;
      }

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
      if (to != null && record.isAfter(to)) return false;
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

  Future<void> _showDateFilterModal() async {
    DateTime? tempFrom = _fromDate;
    DateTime? tempTo = _toDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Filter by Date Range',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _Brand.tealDark,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: const Text(
                      'From Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      tempFrom != null
                          ? tempFrom!.toIso8601String().split('T')[0]
                          : 'Not set',
                    ),
                    trailing: const Icon(
                      Icons.edit_calendar_rounded,
                      color: _Brand.teal,
                    ),
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
                  const Divider(height: 1),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: const Text(
                      'To Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      tempTo != null
                          ? tempTo!.toIso8601String().split('T')[0]
                          : 'Not set',
                    ),
                    trailing: const Icon(
                      Icons.edit_calendar_rounded,
                      color: _Brand.teal,
                    ),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Brand.tealMid,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
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
  }

  @override
  Widget build(BuildContext context) {
    final activeDates = _filteredDates;
    final activeStudentIds = _filteredStudentIds;

    return Scaffold(
      backgroundColor: Colors.white,
      // ─── FIX: Prevents the keyboard from shrinking the view and causing a 60px overflow ───
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Attendance Logs Matrix',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: Colors.grey.shade200,
          ),
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: _Brand.teal,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                icon: const Icon(
                  Icons.file_download_outlined,
                  color: _Brand.tealMid,
                ),
                tooltip: 'Export Matrix Data',
                onPressed: _showExportMonthPicker,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Inside build method, replace your Filter Container with this:
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ), // Tightened vertical padding
            color: Colors.white,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: _buildInputDecoration(
                    labelText: 'Select Class/Section',
                  ),
                  value: _selectedSectionId,
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
                const SizedBox(height: 8), // Reduced gap
                TextField(
                  decoration: _buildInputDecoration(
                    labelText: 'Search Student Name...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.black38,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8), // Reduced gap
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGenderFilter,
                        decoration: _buildInputDecoration(
                          labelText: 'Gender View',
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
                    const SizedBox(width: 8), // Reduced gap
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: _buildInputDecoration(
                          labelText: 'Grouping',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'gender',
                            child: Text('Grouped'),
                          ),
                          DropdownMenuItem(value: 'name', child: Text('Plain')),
                        ],
                        onChanged: (val) => setState(() => _sortBy = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Reduced gap
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                        ),
                        label: Text(
                          _fromDate == null && _toDate == null
                              ? 'Date Range'
                              : '${_fromDate != null ? _fromDate!.toIso8601String().split('T')[0] : 'Start'} → ${_toDate != null ? _toDate!.toIso8601String().split('T')[0] : 'End'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                          size: 18,
                          color: _Brand.redText,
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
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _Brand.teal),
                  )
                : activeStudentIds.isEmpty
                ? const Center(
                    child: Text(
                      'No records found.',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
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
    const double rowHeight = 46.0;
    const double headingHeight = 48.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STICKY SIDE: Student names and dynamic group headers
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_Brand.tealSurf),
              headingRowHeight: headingHeight,
              dataRowHeight: rowHeight,
              horizontalMargin: 16,
              columnSpacing: 0,
              border: TableBorder.all(color: Colors.grey.shade100, width: 0.5),
              columns: const [
                DataColumn(
                  label: Text(
                    'Student Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _Brand.tealDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              rows: activeStudentIds.map((studentId) {
                if (studentId.startsWith('HEADER_')) {
                  String label = studentId == 'HEADER_BOYS'
                      ? 'Boys'
                      : (studentId == 'HEADER_GIRLS' ? 'Girls' : 'Unassigned');
                  Color bgSurface = studentId == 'HEADER_BOYS'
                      ? _Brand.blueSurf
                      : _Brand.pinkSurf;
                  Color textColor = studentId == 'HEADER_BOYS'
                      ? _Brand.blueText
                      : _Brand.pinkText;

                  return DataRow(
                    color: WidgetStateProperty.all(bgSurface),
                    cells: [
                      DataCell(
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        studentIdToName[studentId] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
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
                headingRowColor: WidgetStateProperty.all(_Brand.tealSurf),
                headingRowHeight: headingHeight,
                dataRowHeight: rowHeight,
                horizontalMargin: 12,
                columnSpacing: 20,
                border: TableBorder.all(
                  color: Colors.grey.shade100,
                  width: 0.5,
                ),
                columns: [
                  ...activeDates.map(
                    (date) => DataColumn(
                      label: Center(
                        child: Text(
                          date.length >= 10
                              ? date.substring(5, 10)
                              : date, // Condensed MM-DD view
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _Brand.tealDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Center(
                      child: Text(
                        'Pres.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _Brand.tealMid,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Center(
                      child: Text(
                        'Abs.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _Brand.redText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: activeStudentIds.map((studentId) {
                  if (studentId.startsWith('HEADER_')) {
                    Color bgSurface = studentId == 'HEADER_BOYS'
                        ? _Brand.blueSurf
                        : _Brand.pinkSurf;
                    return DataRow(
                      color: WidgetStateProperty.all(bgSurface),
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
                    Color txtColor = Colors.black38;
                    Color bgColor = Colors.transparent;

                    if (status == 'PRESENT') {
                      presentSum++;
                      txtColor = _Brand.tealDark;
                      bgColor = _Brand.tealSurf;
                    } else if (status == 'ABSENT') {
                      absentSum++;
                      txtColor = _Brand.redText;
                      bgColor = _Brand.redSurf;
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
                            fontWeight: FontWeight.w700,
                            color: txtColor,
                            fontSize: 12,
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
                              fontWeight: FontWeight.w700,
                              color: _Brand.tealDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Text(
                            '$absentSum',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _Brand.redText,
                              fontSize: 13,
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
