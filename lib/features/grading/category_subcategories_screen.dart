import 'package:flutter/material.dart';
import '../grading/repository/framework_repository.dart';
import './grade_category_screen.dart';

// ─── Brand palette (shared with ClassGradebookScreen) ─────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);
}
// ─────────────────────────────────────────────────────────────────────────────

/// Lists the subcategories configured under one grading category (e.g. the
/// Quizzes / Unit Tests / Seatworks under "Written Works") so a teacher can
/// drop into the right scoring matrix. The Class Gradebook grid only routes
/// here when a category actually has subcategories — categories with none
/// skip straight to GradeCategoryScreen.
class CategorySubcategoriesScreen extends StatelessWidget {
  final String sectionId;
  final CategoryWithSubcategories categoryEntry;

  const CategorySubcategoriesScreen({
    super.key,
    required this.sectionId,
    required this.categoryEntry,
  });

  @override
  Widget build(BuildContext context) {
    final category = categoryEntry.category;
    final subcategories = categoryEntry.subcategories;
    final weightedSubs = subcategories
        .where((s) => s.weightPercentage != null)
        .toList();
    final orgSubs = subcategories
        .where((s) => s.weightPercentage == null)
        .toList();
    final subWeightTotal = weightedSubs.fold<double>(
      0,
      (s, e) => s + (e.weightPercentage ?? 0),
    );
    final weightedBalanced =
        weightedSubs.isNotEmpty && (subWeightTotal - 100).abs() < 0.01;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 17,
              color: Colors.black54,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 17,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── "All" combined matrix tile ─────────────────────────────────
          _buildTile(
            context,
            icon: Icons.grid_view_rounded,
            title: 'All ${category.name}',
            subtitle: 'Combined matrix — every item in this category',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GradeCategoryScreen(
                  sectionId: sectionId,
                  categoryId: category.id,
                  categoryName: category.name,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),

          // ── Weighted subcategories ─────────────────────────────────────
          if (weightedSubs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: weightedBalanced
                          ? _Brand.tealSurf
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: weightedBalanced
                            ? _Brand.tealBorder
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          weightedBalanced
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 13,
                          color: weightedBalanced
                              ? _Brand.tealMid
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          weightedBalanced
                              ? 'Weighted · ${subWeightTotal.toStringAsFixed(0)}% balanced'
                              : 'Weighted · ${subWeightTotal.toStringAsFixed(0)}% / 100% — adjust weights',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: weightedBalanced
                                ? _Brand.tealDark
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...weightedSubs.map(
              (sub) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTile(
                  context,
                  icon: Icons.bar_chart_rounded,
                  title: sub.name,
                  subtitle:
                      '${sub.weightPercentage!.toStringAsFixed(0)}% of ${category.name} (${category.weightPercentage.toStringAsFixed(0)}%)',
                  badge: '${sub.weightPercentage!.toStringAsFixed(0)}%',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GradeCategoryScreen(
                        sectionId: sectionId,
                        categoryId: category.id,
                        categoryName: category.name,
                        subcategoryId: sub.id,
                        subcategoryName: sub.name,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (orgSubs.isNotEmpty) const SizedBox(height: 8),
          ],

          // ── Organizational subcategories ───────────────────────────────
          if (orgSubs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Organizational — items pool together',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...orgSubs.map(
              (sub) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTile(
                  context,
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: sub.name,
                  subtitle:
                      'Grouped under ${category.name} · ${category.weightPercentage.toStringAsFixed(0)}%',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GradeCategoryScreen(
                        sectionId: sectionId,
                        categoryId: category.id,
                        categoryName: category.name,
                        subcategoryId: sub.id,
                        subcategoryName: sub.name,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _Brand.tealDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Brand.tealSurf,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _Brand.tealBorder),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _Brand.tealDark,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
