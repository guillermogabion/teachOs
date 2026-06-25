import 'package:flutter/material.dart';
import '../../features/grading/framework_config_screen.dart';
import '../../features/grading/repository/framework_repository.dart';
import '../../features/grading/repository/framework_repository.dart' as fr;
import 'package:uuid/uuid.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);
  static const error = Color(0xFFD32F2F);
  static const errorSurf = Color(0xFFFDECEC);
}

// ============================================================================
// 1. CURRICULUM SETTINGS SCREEN
// ============================================================================
class CurriculumSettingsScreen extends StatefulWidget {
  const CurriculumSettingsScreen({super.key});

  @override
  State<CurriculumSettingsScreen> createState() =>
      _CurriculumSettingsScreenState();
}

class _CurriculumSettingsScreenState extends State<CurriculumSettingsScreen> {
  final _repo = FrameworkRepository();

  List<GradingFramework> _frameworks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFrameworks();
  }

  Future<void> _loadFrameworks() async {
    final frameworks = await _repo.getFrameworks();
    if (mounted) {
      setState(() {
        _frameworks = frameworks;
        _isLoading = false;
      });
    }
  }

  Future<void> _createFramework() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Curriculum Framework',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // --- FIX: Wrapped content in SingleChildScrollView and SizedBox ---
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400, // Constrains the width for tablets
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min, // Essential for dialogs
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Framework Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    maxLines: 3, // Allows for better description input
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ------------------------------------------------------------------
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ... rest of your existing logic remains exactly the same
    final name = nameController.text.trim();
    final frameworkId = await _repo.createFramework(
      name: name,
      description: descController.text.trim().isEmpty
          ? null
          : descController.text.trim(),
    );

    await _loadFrameworks();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FrameworkConfigScreen(
            frameworkId: frameworkId,
            frameworkName: name,
          ),
        ),
      ).then((_) => _loadFrameworks());
    }
  }

  // ─── Delete Framework ──────────────────────────────────────────────────────
  Future<void> _confirmDeleteFramework(
    BuildContext context,
    GradingFramework framework,
  ) async {
    final sectionsUsing = await _repo.countSectionsUsingFramework(framework.id);
    final gradeEntries = await _repo.countGradeEntriesForFramework(
      framework.id,
    );

    if (!context.mounted) return;

    // A framework still assigned to classes can't be deleted at the DB
    // level (FK RESTRICT) — catch that here with a clearer message instead
    // of letting the delete call fail.
    if (sectionsUsing > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Framework still in use',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Text(
            '$sectionsUsing ${sectionsUsing == 1 ? 'class is' : 'classes are'} '
            'still assigned to "${framework.name}". Reassign '
            '${sectionsUsing == 1 ? 'it' : 'them'} to a different framework '
            'first, then come back to delete this one.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete "${framework.name}"?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes its categories, subcategories, '
              'terms, and transmutation table.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            if (gradeEntries > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _Brand.errorSurf,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: _Brand.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This also wipes $gradeEntries recorded '
                        '${gradeEntries == 1 ? 'score' : 'scores'} from '
                        'classes that used these categories — including any '
                        'since reassigned to a different framework. This '
                        'cannot be undone.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _Brand.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Framework'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.deleteFramework(framework.id);
    await _loadFrameworks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${framework.name}" deleted.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showTransmutationEditor(
    BuildContext context,
    GradingFramework framework,
  ) async {
    final repo = _repo;
    final uuid = const Uuid();

    // Load existing rules
    final existing = await repo.getTransmutations(framework.id);
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final List<fr.TransmutationRule> rules = existing
        .cast<fr.TransmutationRule>()
        .toList();
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    double previewPercent = 0.0;
    double? previewResult;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void addRule() {
            final min = int.tryParse(minCtrl.text);
            final max = int.tryParse(maxCtrl.text);
            final val = double.tryParse(valCtrl.text);
            final desc = descCtrl.text.trim().isEmpty
                ? null
                : descCtrl.text.trim();
            if (min == null || max == null || val == null) return;
            if (min < 0 || max > 100 || min > max) return;
            final newRule = fr.TransmutationRule(
              id: uuid.v4(),
              frameworkId: framework.id,
              minGrade: min.toDouble(),
              maxGrade: max.toDouble(),
              transmutedValue: val,
              descriptor: desc,
            );
            setState(() {
              rules.add(newRule);
              minCtrl.clear();
              maxCtrl.clear();
              valCtrl.clear();
              descCtrl.clear();
            });
          }

          Future<void> saveAll() async {
            // Validation: integer contiguous coverage 0..100, no overlaps
            if (rules.isEmpty) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Add at least one rule')),
              );
              return;
            }

            // Work with integer boundaries
            final sorted = [...rules]
              ..sort((a, b) => a.minGrade.compareTo(b.minGrade));
            // Each should be integer-valued
            for (var r in sorted) {
              if (r.minGrade % 1 != 0 || r.maxGrade % 1 != 0) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Min/Max must be integer percent values'),
                  ),
                );
                return;
              }
            }

            // Check start at 0 and end at 100 and contiguous with no overlaps/gaps
            int expected = 0;
            for (var r in sorted) {
              final min = r.minGrade.toInt();
              final max = r.maxGrade.toInt();
              if (min != expected) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ranges must cover 0..100 without gaps. Expected start: $expected',
                    ),
                  ),
                );
                return;
              }
              if (max < min) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Max must be >= Min')),
                );
                return;
              }
              expected = max + 1;
            }
            if (expected != 101) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Ranges must cover exactly 0..100'),
                ),
              );
              return;
            }

            // Persist: replace all
            await repo.deleteTransmutationsForFramework(framework.id);
            for (var r in sorted) {
              await repo.saveTransmutation(r);
            }

            if (mounted) {
              navigator.pop();
              _loadFrameworks();
            }
          }

          try {
            final match = rules.firstWhere(
              (r) =>
                  previewPercent >= r.minGrade && previewPercent <= r.maxGrade,
            );
            previewResult = match.transmutedValue;
          } catch (_) {
            previewResult = null;
          }

          return AlertDialog(
            title: Text('Transmutation — ${framework.name}'),
            // 1. FIX: Replaced fixed width 520 with double.maxFinite
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 2. FIX: Group Min and Max in the first row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min %',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max %',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 3. FIX: Group Value and Descriptor in the second row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: valCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Transmuted Value',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Label (optional)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4. FIX: Make the Add button span the full width
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _Brand.tealMid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: addRule,
                        child: const Text('Add Rule'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Existing rules list
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: rules.length,
                        itemBuilder: (context, i) {
                          final r = rules[i];
                          return ListTile(
                            contentPadding:
                                EdgeInsets.zero, // Optimizes mobile padding
                            title: Text(
                              '${r.minGrade.toInt()} - ${r.maxGrade.toInt()} → ${r.transmutedValue}${r.descriptor != null ? ' (${r.descriptor})' : ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setState(() => rules.removeAt(i));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preview slider
                    Row(
                      children: [
                        const Text('Preview:'),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 100,
                            divisions: 100,
                            value: previewPercent,
                            onChanged: (v) =>
                                setState(() => previewPercent = v),
                          ),
                        ),
                        SizedBox(
                          width:
                              40, // Fixed width prevents layout jitter as numbers change
                          child: Text(
                            previewResult != null
                                ? previewResult.toString()
                                : '--',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Brand.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: saveAll,
                child: const Text('Save Rules'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Grading Frameworks',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : RefreshIndicator(
              onRefresh: _loadFrameworks,
              color: _Brand.teal,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Each class picks one of these. Editing a framework updates every class currently assigned to it — different classes can use entirely different ones.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final framework in _frameworks) ...[
                    _buildFrameworkCard(context, framework),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: _createFramework,
                    icon: const Icon(
                      Icons.add_chart_rounded,
                      color: _Brand.teal,
                    ),
                    label: const Text(
                      'Create Custom Curriculum Framework',
                      style: TextStyle(color: _Brand.teal),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: _Brand.tealBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFrameworkCard(BuildContext context, GradingFramework framework) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: framework.isDefault ? _Brand.teal : Colors.grey.shade300,
          width: framework.isDefault ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: framework.isDefault
            ? _Brand.tealSurf.withValues(alpha: 0.3)
            : Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  framework.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (framework.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _Brand.teal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            framework.description ?? 'No description yet.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: _repo.countSectionsUsingFramework(framework.id),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Text(
                'Used by $count ${count == 1 ? 'class' : 'classes'}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FrameworkConfigScreen(
                        frameworkId: framework.id,
                        frameworkName: framework.name,
                      ),
                    ),
                  ).then((_) => _loadFrameworks());
                },
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: _Brand.tealMid,
                ),
                label: const Text(
                  'Edit Weights & Periods',
                  style: TextStyle(color: _Brand.tealMid),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              // (Removed placeholder)

              // Transmutation editor
              TextButton.icon(
                onPressed: () => _showTransmutationEditor(context, framework),
                icon: const Icon(
                  Icons.auto_fix_high_rounded,
                  size: 16,
                  color: _Brand.tealMid,
                ),
                label: const Text(
                  'Edit Transmutation',
                  style: TextStyle(color: _Brand.tealMid),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Delete framework — the built-in default can't be removed,
              // since the rest of the app falls back to it.
              if (framework.isDefault)
                Tooltip(
                  message:
                      "The default framework can't be deleted — it's the "
                      'fallback every class uses until you set something else.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Default — can't delete",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _confirmDeleteFramework(context, framework),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: _Brand.error,
                  ),
                  label: const Text(
                    'Delete Framework',
                    style: TextStyle(color: _Brand.error),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. SPREADSHEET MATRIX ENGINE (Synchronized Grid Layout) — unchanged
// ============================================================================
class SpreadsheetGradebook extends StatefulWidget {
  final List<String> assessments;
  final List<Map<String, dynamic>> studentRecords;

  const SpreadsheetGradebook({
    super.key,
    required this.assessments,
    required this.studentRecords,
  });

  @override
  State<SpreadsheetGradebook> createState() => _SpreadsheetGradebookState();
}

class _SpreadsheetGradebookState extends State<SpreadsheetGradebook> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  static const double _cellWidth = 85.0;
  static const double _frozenColumnWidth =
      140.0; // Balanced layout spacing for mobile views
  static const double _rowHeight = 50.0;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Export .xlsx'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Brand.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Data Grid Matrix
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE: Frozen Row Element Columns
                  SizedBox(
                    width: _frozenColumnWidth,
                    child: Column(
                      children: [
                        _buildHeaderCell(
                          'Student Name',
                          _frozenColumnWidth,
                          isFrozen: true,
                        ),
                        ...widget.studentRecords.map((record) {
                          return _buildDataCell(
                            record['name'] ?? '',
                            _frozenColumnWidth,
                            isFrozen: true,
                          );
                        }),
                      ],
                    ),
                  ),

                  // RIGHT SIDE: Fully Scrollable Assessment & Matrix Grid Cells
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: widget.assessments.length * _cellWidth,
                        child: Column(
                          children: [
                            // Synchronized Assessment Header Rows
                            Row(
                              children: widget.assessments
                                  .map((a) => _buildHeaderCell(a, _cellWidth))
                                  .toList(),
                            ),
                            // Data Record Rows
                            ...widget.studentRecords.map((record) {
                              final scores =
                                  record['scores'] as List<dynamic>? ?? [];
                              return Row(
                                children: scores
                                    .map(
                                      (score) => _buildDataCell(
                                        score.toString(),
                                        _cellWidth,
                                      ),
                                    )
                                    .toList(),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, double width, {bool isFrozen = false}) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: isFrozen ? Alignment.centerLeft : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _Brand.tealSurf,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _Brand.tealDark,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isFrozen = false}) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: isFrozen ? Alignment.centerLeft : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Text(
        text,
        style: isFrozen
            ? const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)
            : TextStyle(color: Colors.grey.shade800, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
