import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class QuestionTopic {
  final String id;
  final String title;
  final String createdAt;

  const QuestionTopic({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory QuestionTopic.fromMap(Map<String, dynamic> m) => QuestionTopic(
    id: m['id'] as String,
    title: m['title'] as String,
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'created_at': createdAt,
  };

  QuestionTopic copyWith({String? title}) =>
      QuestionTopic(id: id, title: title ?? this.title, createdAt: createdAt);
}

class QuestionBankItem {
  final String id;
  final String topicId;
  final String type;
  final String questionText;

  /// Comma-separated difficulty/taxonomy tags, e.g. "Easy,Remembering"
  final String? metadataTags;

  /// JSON-encoded list of choice strings for Multiple Choice / True-False.
  /// Stored in the `choices` column. Null for all other question types.
  final String? choicesJson;

  const QuestionBankItem({
    required this.id,
    required this.topicId,
    required this.type,
    required this.questionText,
    this.metadataTags,
    this.choicesJson,
  });

  /// Decoded list of choices. Empty list if not a choice-based question.
  List<String> get choices {
    if (choicesJson == null || choicesJson!.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(choicesJson!) as List);
    } catch (_) {
      return [];
    }
  }

  factory QuestionBankItem.fromMap(Map<String, dynamic> m) => QuestionBankItem(
    id: m['id'] as String,
    topicId: m['topic_id'] as String,
    type: m['type'] as String,
    questionText: m['question_text'] as String,
    metadataTags: m['metadata_tags'] as String?,
    choicesJson: m['choices'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'topic_id': topicId,
    'type': type,
    'question_text': questionText,
    'metadata_tags': metadataTags,
    'choices': choicesJson,
  };

  QuestionBankItem copyWith({
    String? type,
    String? questionText,
    String? metadataTags,
    String? choicesJson,
  }) => QuestionBankItem(
    id: id,
    topicId: topicId,
    type: type ?? this.type,
    questionText: questionText ?? this.questionText,
    metadataTags: metadataTags ?? this.metadataTags,
    choicesJson: choicesJson ?? this.choicesJson,
  );
}

// ─── Repository ───────────────────────────────────────────────────────────────

class QuestionBankRepository {
  final _db = DatabaseService.instance;
  final _uuid = const Uuid();

  // ── Topics ────────────────────────────────────────────────────────────────

  Future<List<QuestionTopic>> getTopics() async {
    final db = await _db.database;
    final rows = await db.query('question_topics', orderBy: 'title ASC');
    return rows.map(QuestionTopic.fromMap).toList();
  }

  Future<QuestionTopic> insertTopic({required String title}) async {
    final db = await _db.database;
    final topic = QuestionTopic(
      id: _uuid.v4(),
      title: title.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.insert('question_topics', topic.toMap());
    return topic;
  }

  Future<void> updateTopic(QuestionTopic topic) async {
    final db = await _db.database;
    await db.update(
      'question_topics',
      topic.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
  }

  Future<void> deleteTopic(String topicId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'question_bank_v2',
        where: 'topic_id = ?',
        whereArgs: [topicId],
      );
      await txn.delete(
        'question_topics',
        where: 'id = ?',
        whereArgs: [topicId],
      );
    });
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  Future<List<QuestionBankItem>> getQuestions({
    required String topicId,
    String? typeFilter,
  }) async {
    final db = await _db.database;
    final hasType = typeFilter != null && typeFilter.isNotEmpty;
    final rows = await db.query(
      'question_bank_v2',
      where: hasType ? 'topic_id = ? AND type = ?' : 'topic_id = ?',
      whereArgs: hasType ? [topicId, typeFilter] : [topicId],
    );
    return rows.map(QuestionBankItem.fromMap).toList();
  }

  Future<int> getQuestionCount(String topicId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM question_bank_v2 WHERE topic_id = ?',
      [topicId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<QuestionBankItem> insertQuestion({
    required String topicId,
    required String type,
    required String questionText,
    String? metadataTags,
    List<String>? choices,
  }) async {
    final db = await _db.database;
    final item = QuestionBankItem(
      id: _uuid.v4(),
      topicId: topicId,
      type: type,
      questionText: questionText.trim(),
      metadataTags: metadataTags,
      choicesJson: (choices != null && choices.isNotEmpty)
          ? jsonEncode(choices)
          : null,
    );
    await db.insert('question_bank_v2', item.toMap());
    return item;
  }

  Future<void> updateQuestion(QuestionBankItem item) async {
    final db = await _db.database;
    await db.update(
      'question_bank_v2',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteQuestion(String id) async {
    final db = await _db.database;
    await db.delete('question_bank_v2', where: 'id = ?', whereArgs: [id]);
  }
}
