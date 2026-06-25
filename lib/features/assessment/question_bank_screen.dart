import 'dart:convert';
import 'package:flutter/material.dart';
import './repository/question_bank_repository.dart';
import '../../services/question_pdf_service.dart';

// ─── Brand Palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const charcoal = Color(0xFF1F2937);
  static const mutedText = Color(0xFF6B7280);
  static const bgSurface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

class _QType {
  static const all = [
    'Multiple Choice',
    'True/False',
    'Identification',
    'Enumeration',
    'Essay',
    'Matching Type',
  ];
  static bool hasChoices(String t) =>
      t == 'Multiple Choice' || t == 'True/False';
}

class _Difficulty {
  static const all = ['Easy', 'Medium', 'Hard'];
}

class _Bloom {
  static const all = [
    'Remembering',
    'Understanding',
    'Applying',
    'Analyzing',
    'Evaluating',
    'Creating',
  ];
}

InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(
    fontSize: 13,
    color: Colors.black54,
    fontWeight: FontWeight.w500,
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  filled: true,
  fillColor: Colors.white,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _Brand.border, width: 1.2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _Brand.teal, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.red.shade300, width: 1.2),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
  ),
);

// ═════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 1: TOPIC DASHBOARD (CARDS) ───────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final _repo = QuestionBankRepository();
  List<QuestionTopic> _topics = [];
  bool _loadingTopics = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _loadingTopics = true);
    final topics = await _repo.getTopics();
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _loadingTopics = false;
    });
  }

  // ─── Quick PDF Export from Card ───
  Future<void> _exportTopicPdf(QuestionTopic topic) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Preparing PDF...'),
        backgroundColor: _Brand.tealMid,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final questions = await _repo.getQuestions(topicId: topic.id);

      if (questions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No questions to export in this topic.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return;
      }

      final qMaps = questions
          .map(
            (item) => {
              'question_text': item.questionText,
              'type': item.type,
              'choices': item.choices,
              'metadata_tags': item.metadataTags,
            },
          )
          .toList();

      if (!mounted) return;
      await QuestionPdfService.printQuestionnaire(
        context: context,
        topicTitle: topic.title,
        questions: qMaps,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _openTopicDialog({QuestionTopic? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<QuestionTopic?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'New Topic' : 'Edit Topic',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _Brand.charcoal,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: titleCtrl,
            autofocus: true,
            decoration: _inputDeco(
              'Topic Name',
              hint: 'e.g. Fraction Operations, Newton\'s Laws',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.tealDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (existing == null) {
                final t = await _repo.insertTopic(title: titleCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx, t);
              } else {
                await _repo.updateTopic(
                  existing.copyWith(title: titleCtrl.text),
                );
                if (ctx.mounted) Navigator.pop(ctx, existing);
              }
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _loadTopics();
    }
  }

  Future<void> _deleteTopic(QuestionTopic topic) async {
    final count = await _repo.getQuestionCount(topic.id);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Topic?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _Brand.charcoal,
          ),
        ),
        content: Text(
          '"${topic.title}" contains $count question${count != 1 ? 's' : ''}. '
          'All questions inside will also be deleted.',
          style: const TextStyle(fontSize: 13, color: _Brand.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteTopic(topic.id);
      await _loadTopics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Topic deleted.'),
            backgroundColor: _Brand.tealDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: AppBar(
        title: const Text(
          'Question Bank',
          style: TextStyle(color: _Brand.charcoal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _Brand.border, height: 1),
        ),
      ),
      body: _loadingTopics
          ? const Center(child: CircularProgressIndicator(color: _Brand.teal))
          : _topics.isEmpty
          ? _buildEmptyState()
          : _buildTopicGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTopicDialog(),
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Topic',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _Brand.tealSurf,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 40,
                color: _Brand.tealMid,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Topics Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _Brand.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + to create your first topic.\nTopics persist across all school years.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _Brand.mutedText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicGrid() {
    final width = MediaQuery.of(context).size.width;
    int columns = 2;
    if (width > 600) columns = 3;
    if (width > 900) columns = 4;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        final topic = _topics[index];
        return _TopicCard(
          topic: topic,
          repo: _repo,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TopicQuestionsScreen(topic: topic),
              ),
            );
            _loadTopics();
          },
          onExport: () => _exportTopicPdf(topic),
          onEdit: () => _openTopicDialog(existing: topic),
          onDelete: () => _deleteTopic(topic),
        );
      },
    );
  }
}

// ─── Individual Topic Card Widget ───
class _TopicCard extends StatelessWidget {
  final QuestionTopic topic;
  final QuestionBankRepository repo;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TopicCard({
    required this.topic,
    required this.repo,
    required this.onTap,
    required this.onExport,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Brand.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _Brand.charcoal.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _Brand.tealSurf,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.library_books_rounded,
                        color: _Brand.tealMid,
                        size: 24,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: _Brand.mutedText,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'export') onExport();
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: _Brand.tealMid,
                              ),
                              SizedBox(width: 8),
                              Text('Export PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: _Brand.mutedText,
                              ),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red.shade400,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red.shade400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  topic.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _Brand.charcoal,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                FutureBuilder<int>(
                  future: repo.getQuestionCount(topic.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Text(
                      '$count Question${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _Brand.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── SCREEN 2: TOPIC QUESTIONS LIST ──────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class TopicQuestionsScreen extends StatefulWidget {
  final QuestionTopic topic;
  const TopicQuestionsScreen({super.key, required this.topic});

  @override
  State<TopicQuestionsScreen> createState() => _TopicQuestionsScreenState();
}

class _TopicQuestionsScreenState extends State<TopicQuestionsScreen> {
  final _repo = QuestionBankRepository();
  List<QuestionBankItem> _allItems = [];
  List<QuestionBankItem> _filtered = [];
  bool _loadingQs = false;

  String _typeFilter = 'All';
  String _searchQuery = '';
  bool _isExporting = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loadingQs = true);
    final items = await _repo.getQuestions(topicId: widget.topic.id);
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _loadingQs = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _allItems.where((item) {
        final typeOk = _typeFilter == 'All' || item.type == _typeFilter;
        final searchOk =
            q.isEmpty ||
            item.questionText.toLowerCase().contains(q) ||
            (item.metadataTags?.toLowerCase().contains(q) ?? false);
        return typeOk && searchOk;
      }).toList();
    });
  }

  Future<void> _openQuestionDialog({QuestionBankItem? existing}) async {
    final formKey = GlobalKey<FormState>();
    final textCtrl = TextEditingController(text: existing?.questionText ?? '');

    final existingTags =
        existing?.metadataTags
            ?.split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet() ??
        {};
    final initDifficulty = existingTags
        .where((t) => _Difficulty.all.contains(t))
        .toSet();
    final initBloom = existingTags.where((t) => _Bloom.all.contains(t)).toSet();
    final initType = existing?.type ?? _QType.all.first;
    final initChoices = existing?.choices ?? [];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionFormSheet(
        formKey: formKey,
        textCtrl: textCtrl,
        initialType: initType,
        initialChoices: initChoices,
        initialDifficulty: initDifficulty,
        initialBloom: initBloom,
        isEditing: existing != null,
        onSave: (type, choices, difficulty, bloom) async {
          if (!formKey.currentState!.validate()) return;
          final tags = [...difficulty, ...bloom].join(',');
          final choicesJson = (choices.isNotEmpty && _QType.hasChoices(type))
              ? jsonEncode(choices)
              : null;
          if (existing == null) {
            await _repo.insertQuestion(
              topicId: widget.topic.id,
              type: type,
              questionText: textCtrl.text,
              metadataTags: tags.isEmpty ? null : tags,
              choices: choices.isNotEmpty && _QType.hasChoices(type)
                  ? choices
                  : null,
            );
          } else {
            await _repo.updateQuestion(
              existing.copyWith(
                type: type,
                questionText: textCtrl.text,
                metadataTags: tags.isEmpty ? null : tags,
                choicesJson: choicesJson,
              ),
            );
          }
          if (mounted) Navigator.of(context).pop(true);
        },
      ),
    );

    if (saved == true) {
      await _loadQuestions();
      _showSnack(existing == null ? 'Question added.' : 'Question updated.');
    }
  }

  Future<void> _deleteQuestion(QuestionBankItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Question?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _Brand.charcoal,
          ),
        ),
        content: Text(
          item.questionText.length > 80
              ? '${item.questionText.substring(0, 80)}…'
              : item.questionText,
          style: const TextStyle(fontSize: 13, color: _Brand.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteQuestion(item.id);
      await _loadQuestions();
      _showSnack('Question deleted.');
    }
  }

  Future<void> _exportToPdf() async {
    if (_filtered.isEmpty) {
      _showSnack('No questions to export.', isError: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final qMaps = _filtered
          .map(
            (item) => {
              'question_text': item.questionText,
              'type': item.type,
              'choices': item.choices,
              'metadata_tags': item.metadataTags,
            },
          )
          .toList();

      await QuestionPdfService.printQuestionnaire(
        context: context,
        topicTitle: widget.topic.title,
        questions: qMaps,
      );
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : _Brand.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.bgSurface,
      appBar: AppBar(
        title: Text(
          widget.topic.title,
          style: const TextStyle(color: _Brand.charcoal, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _Brand.charcoal),
        actions: [
          _isExporting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _Brand.teal,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: _Brand.tealDark,
                  ),
                  tooltip: 'Export PDF',
                  onPressed: _exportToPdf,
                ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _Brand.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuestionDialog,
        backgroundColor: _Brand.tealDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Question',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: _inputDeco('Search questions…').copyWith(
              isDense: true,
              fillColor: _Brand.bgSurface,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _Brand.mutedText,
                size: 20,
              ),
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ['All', ..._QType.all].map(_filterChip).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final active = _typeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) {
          setState(() => _typeFilter = label);
          _applyFilters();
        },
        selectedColor: _Brand.tealDark,
        backgroundColor: _Brand.bgSurface,
        side: BorderSide(color: active ? _Brand.tealDark : _Brand.border),
        labelStyle: TextStyle(
          color: active ? Colors.white : _Brand.charcoal,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingQs) {
      return const Center(child: CircularProgressIndicator(color: _Brand.teal));
    }
    if (_allItems.isEmpty) {
      return _emptyState(
        icon: Icons.quiz_outlined,
        title: 'No Questions Yet',
        subtitle:
            'Tap + Add Question to start composing\nquestions for this topic.',
      );
    }
    if (_filtered.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_rounded,
        title: 'No Results',
        subtitle: 'Try adjusting the filter or search.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildQuestionCard(_filtered[i], i + 1),
    );
  }

  Widget _buildQuestionCard(QuestionBankItem item, int index) {
    final tags =
        item.metadataTags
            ?.split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Brand.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _Brand.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_Brand.tealSurf, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Brand.teal.withOpacity(0.2)),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _Brand.tealDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _Brand.bgSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _Brand.mutedText,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _iconBtn(
                            icon: Icons.edit_rounded,
                            tooltip: 'Edit',
                            color: _Brand.tealMid,
                            onTap: () => _openQuestionDialog(existing: item),
                          ),
                          _iconBtn(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete',
                            color: Colors.red.shade400,
                            onTap: () => _deleteQuestion(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.questionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _Brand.charcoal,
                      height: 1.4,
                    ),
                  ),
                  if (item.choices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...item.choices.asMap().entries.map((c) {
                      const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
                      final l = c.key < letters.length ? letters[c.key] : '?';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$l. ${c.value}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _Brand.mutedText,
                          ),
                        ),
                      );
                    }),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((t) => _tagPill(t)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagPill(String label) {
    Color bg, fg;
    if (label == 'Easy') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (label == 'Medium') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFF854D0E);
    } else if (label == 'Hard') {
      bg = const Color(0xFFFFE4E6);
      fg = const Color(0xFF9F1239);
    } else {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _Brand.tealSurf,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: _Brand.tealMid),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _Brand.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _Brand.mutedText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── BOTTOM SHEET: QUESTION FORM ─────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _QuestionFormSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController textCtrl;
  final String initialType;
  final List<String> initialChoices;
  final Set<String> initialDifficulty;
  final Set<String> initialBloom;
  final bool isEditing;
  final Future<void> Function(
    String type,
    List<String> choices,
    Set<String> difficulty,
    Set<String> bloom,
  )
  onSave;

  const _QuestionFormSheet({
    required this.formKey,
    required this.textCtrl,
    required this.initialType,
    required this.initialChoices,
    required this.initialDifficulty,
    required this.initialBloom,
    required this.isEditing,
    required this.onSave,
  });

  @override
  State<_QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends State<_QuestionFormSheet> {
  late String _type;
  late Set<String> _difficulty;
  late Set<String> _bloom;
  late List<TextEditingController> _choiceCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _difficulty = Set.from(widget.initialDifficulty);
    _bloom = Set.from(widget.initialBloom);
    _choiceCtrl = _initChoiceControllers(
      widget.initialType,
      widget.initialChoices,
    );
  }

  List<TextEditingController> _initChoiceControllers(
    String type,
    List<String> existing,
  ) {
    if (!_QType.hasChoices(type)) return [];
    if (type == 'True/False') {
      return [
        TextEditingController(text: existing.isNotEmpty ? existing[0] : 'True'),
        TextEditingController(
          text: existing.length > 1 ? existing[1] : 'False',
        ),
      ];
    }
    final base = existing.isNotEmpty ? existing : ['', ''];
    return base.map((s) => TextEditingController(text: s)).toList();
  }

  void _onTypeChanged(String newType) {
    for (final c in _choiceCtrl) {
      c.dispose();
    }
    setState(() {
      _type = newType;
      _choiceCtrl = _initChoiceControllers(newType, []);
    });
  }

  void _addChoice() {
    if (_choiceCtrl.length >= 6) return;
    setState(() => _choiceCtrl.add(TextEditingController()));
  }

  void _removeChoice(int index) {
    if (_choiceCtrl.length <= 2) return;
    final c = _choiceCtrl.removeAt(index);
    c.dispose();
    setState(() {});
  }

  List<String> get _choices {
    if (_type == 'True/False') return ['True', 'False'];
    return _choiceCtrl
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    for (final c in _choiceCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_type, _choices, _difficulty, _bloom);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (sheetCtx, scrollCtrl) => Builder(
        builder: (innerCtx) {
          final mq = MediaQuery.of(innerCtx);
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isEditing ? 'Edit Question' : 'New Question',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _Brand.charcoal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Form(
                      key: widget.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: _inputDeco('Question Type'),
                            dropdownColor: Colors.white,
                            value: _type,
                            items: _QType.all
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _onTypeChanged(v);
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: widget.textCtrl,
                            decoration: _inputDeco(
                              'Question Text',
                              hint:
                                  'e.g. What is the capital of the Philippines?',
                            ),
                            maxLines: 3,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter the question text.'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          if (_QType.hasChoices(_type)) ...[
                            _sectionLabel(
                              _type == 'True/False'
                                  ? 'Choices (fixed)'
                                  : 'Answer Choices',
                            ),
                            const SizedBox(height: 8),
                            ..._choiceCtrl.asMap().entries.map((entry) {
                              const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
                              final letter = entry.key < letters.length
                                  ? letters[entry.key]
                                  : '?';
                              final isTF = _type == 'True/False';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _Brand.tealSurf,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _Brand.tealDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: entry.value,
                                        readOnly: isTF,
                                        decoration: _inputDeco(
                                          'Choice $letter',
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                        validator: (v) {
                                          if (isTF) return null;
                                          if (entry.key < 2 &&
                                              (v == null || v.trim().isEmpty)) {
                                            return 'Choice $letter is required.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (!isTF && _choiceCtrl.length > 2) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(
                                          Icons.remove_circle_outline_rounded,
                                          color: Colors.red.shade300,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _removeChoice(entry.key),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                            if (_type == 'Multiple Choice' &&
                                _choiceCtrl.length < 6)
                              TextButton.icon(
                                onPressed: _addChoice,
                                icon: const Icon(
                                  Icons.add_rounded,
                                  color: _Brand.teal,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Add Choice',
                                  style: TextStyle(
                                    color: _Brand.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                          _sectionLabel('Difficulty Level'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _Difficulty.all.map((d) {
                              final on = _difficulty.contains(d);
                              return FilterChip(
                                label: Text(d),
                                selected: on,
                                onSelected: (v) {
                                  setState(() {
                                    _difficulty.clear();
                                    if (v) _difficulty.add(d);
                                  });
                                },
                                selectedColor: _Brand.tealDark,
                                backgroundColor: _Brand.bgSurface,
                                side: BorderSide(
                                  color: on ? _Brand.tealDark : _Brand.border,
                                ),
                                labelStyle: TextStyle(
                                  color: on ? Colors.white : _Brand.charcoal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                checkmarkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel("Bloom's Taxonomy Level"),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _Bloom.all.map((b) {
                              final on = _bloom.contains(b);
                              return FilterChip(
                                label: Text(b),
                                selected: on,
                                onSelected: (v) {
                                  setState(() {
                                    _bloom.clear();
                                    if (v) _bloom.add(b);
                                  });
                                },
                                selectedColor: const Color(0xFF1D4ED8),
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: BorderSide(
                                  color: on
                                      ? const Color(0xFF1D4ED8)
                                      : _Brand.border,
                                ),
                                labelStyle: TextStyle(
                                  color: on
                                      ? Colors.white
                                      : const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                checkmarkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _Brand.tealDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.isEditing
                                          ? 'Update Question'
                                          : 'Add to Bank',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
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
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _Brand.mutedText,
      letterSpacing: 0.4,
    ),
  );
}
