import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

// ─── PDF colour constants ──────────────────────────────────────────────────────
final _tealDark = PdfColor.fromHex('085041');
final _tealMid = PdfColor.fromHex('0F6E56');
final _tealLight = PdfColor.fromHex('EAF8F3');
final _grey = PdfColor.fromHex('6B7280');
final _border = PdfColor.fromHex('E5E7EB');

class QuestionPdfService {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Shows the system print dialog.
  static Future<void> printQuestionnaire({
    required BuildContext context,
    required String topicTitle,
    required List<Map<String, dynamic>> questions,
    String instructions =
        'Read each question carefully and write or encircle the correct answer.',
  }) async {
    final bytes = await _buildPdf(
      topicTitle: topicTitle,
      questions: questions,
      instructions: instructions,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: '$topicTitle – Questionnaire',
    );
  }

  /// Saves PDF to documents folder and opens the share sheet.
  static Future<String?> exportQuestionnaire({
    required BuildContext context,
    required String assessmentTitle,
    required List<Map<String, dynamic>> questions,
    String instructions =
        'Read each question carefully and write or encircle the correct answer.',
  }) async {
    try {
      final safeTitle = assessmentTitle.trim().isEmpty
          ? 'Assessment'
          : assessmentTitle.trim();
      final bytes = await _buildPdf(
        topicTitle: safeTitle,
        questions: questions,
        instructions: instructions,
      );

      final dir = await getApplicationDocumentsDirectory();
      final name =
          '${safeTitle.replaceAll(RegExp(r'[^\w\s]+'), '_')}_Questionnaire.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);

      final result = await Share.shareXFiles([
        XFile(file.path, name: name),
      ], subject: 'Questionnaire: $safeTitle');
      return result.status == ShareResultStatus.success ? file.path : null;
    } catch (e) {
      debugPrint('ExportQuestionnaire error: $e');
      return null;
    }
  }

  // ── PDF builder ────────────────────────────────────────────────────────────

  static Future<List<int>> _buildPdf({
    required String topicTitle,
    required List<Map<String, dynamic>> questions,
    required String instructions,
  }) async {
    final doc = pw.Document();
    final bold = await PdfGoogleFonts.notoSansBold();
    final reg = await PdfGoogleFonts.notoSansRegular();
    final ital = await PdfGoogleFonts.notoSansItalic();

    final styleBase = pw.TextStyle(font: reg, fontSize: 11);
    final styleBold = pw.TextStyle(
      font: bold,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final styleSmall = pw.TextStyle(font: reg, fontSize: 9, color: _grey);
    final styleItal = pw.TextStyle(
      font: ital,
      fontSize: 10,
      fontStyle: pw.FontStyle.italic,
      color: _grey,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        // ── Header ────────────────────────────────────────────────────────────
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // School name placeholder + topic title row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      topicTitle.toUpperCase(),
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _tealDark,
                      ),
                    ),
                    pw.Text('Questionnaire', style: styleSmall),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _tealDark,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'TeachOS',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── Answer Sheet Header ──────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColor.fromHex('F9FAFB'),
              ),
              child: pw.Column(
                children: [
                  // Row 1: Name + Score
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: _labeledLine(
                          label: 'Name:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        flex: 1,
                        child: _labeledLine(
                          label: 'Score:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Row 2: Section + Date + Quarter
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _labeledLine(
                          label: 'Section:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: _labeledLine(
                          label: 'Date:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: _labeledLine(
                          label: 'Quarter:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Row 3: Subject + Teacher
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _labeledLine(
                          label: 'Subject:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: _labeledLine(
                          label: 'Teacher:',
                          reg: reg,
                          bold: bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Instructions
            pw.Text('Instructions: $instructions', style: styleItal),
            pw.SizedBox(height: 6),
            pw.Divider(color: _border, thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        // ── Footer ────────────────────────────────────────────────────────────
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: _border, thickness: 0.8),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TeachOS – Xientech', style: styleSmall),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: styleSmall,
                ),
              ],
            ),
          ],
        ),
        // ── Content ───────────────────────────────────────────────────────────
        build: (ctx) => List.generate(questions.length, (i) {
          final q = questions[i];
          final questionText = (q['question_text'] as String?) ?? '';
          final qType = (q['type'] as String?) ?? '';
          // choices comes from the decoded list (already a List<String> at call site)
          final choices = _parseChoices(q['choices']);

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Question text
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      decoration: pw.BoxDecoration(
                        color: _tealLight,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${i + 1}',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            color: _tealDark,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pw.Text(questionText, style: styleBase)),
                  ],
                ),

                // Choices (MC or T/F)
                if ((qType == 'Multiple Choice' || qType == 'True/False') &&
                    choices.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 30, top: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: _buildChoiceRows(choices, styleBold, styleBase),
                    ),
                  ),

                // Answer blank for non-choice types
                if (qType != 'Multiple Choice' && qType != 'True/False') ...[
                  pw.SizedBox(height: 5),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 30),
                    child: pw.Text(
                      'Answer: ___________________________________',
                      style: styleSmall,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );

    return doc.save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Labeled blank line like:  Name: ___________
  static pw.Widget _labeledLine({
    required String label,
    required pw.Font reg,
    required pw.Font bold,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: bold,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 1),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _grey, width: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Parses choices regardless of whether the caller passed a List<String>,
  /// a JSON string, or null.
  static List<String> _parseChoices(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = (json.decode(raw) as List);
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static List<pw.Widget> _buildChoiceRows(
    List<String> choices,
    pw.TextStyle boldStyle,
    pw.TextStyle baseStyle,
  ) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return choices.asMap().entries.map((entry) {
      final letter = entry.key < letters.length ? letters[entry.key] : '?';
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '(   )  $letter.  ',
              style: boldStyle.copyWith(fontSize: 10),
            ),
            pw.Expanded(
              child: pw.Text(
                entry.value,
                style: baseStyle.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
