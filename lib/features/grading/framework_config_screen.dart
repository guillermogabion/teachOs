// import 'package:flutter/material.dart';
// import 'package:uuid/uuid.dart';
// import '../../features/grading/repository/framework_repository.dart';

// // ─── Brand palette ────────────────────────────────────────────────────────────
// class _Brand {
//   static const tealDark = Color(0xFF085041);
//   static const tealMid = Color(0xFF0F6E56);
//   static const teal = Color(0xFF1D9E75);
//   static const tealSurf = Color(0xFFEAF8F3);
//   static const tealBorder = Color(0xFF9FE1CB);
//   static const error = Color(0xFFD32F2F);
// }

// class FrameworkConfigScreen extends StatefulWidget {
//   final String frameworkId;
//   final String frameworkName;

//   const FrameworkConfigScreen({
//     super.key,
//     required this.frameworkId,
//     required this.frameworkName,
//   });

//   @override
//   State<FrameworkConfigScreen> createState() => _FrameworkConfigScreenState();
// }

// class _FrameworkConfigScreenState extends State<FrameworkConfigScreen> {
//   final _repo = FrameworkRepository();
//   final _uuid = const Uuid();

//   List<GradeCategory> _categories = [];
//   List<AcademicPeriod> _periods = [];
//   Map<String, List<GradeSubcategory>> _subcategoriesByCategory = {};
//   final Set<String> _expandedCategoryIds = {};
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     final categories = await _repo.getCategories(widget.frameworkId);
//     final periods = await _repo.getPeriods(widget.frameworkId);

//     final subsByCategory = <String, List<GradeSubcategory>>{};
//     for (final cat in categories) {
//       subsByCategory[cat.id] = await _repo.getSubcategories(cat.id);
//     }

//     if (mounted) {
//       setState(() {
//         _categories = categories;
//         _periods = periods;
//         _subcategoriesByCategory = subsByCategory;
//         _isLoading = false;
//       });
//     }
//   }

//   double get _totalWeight {
//     return _categories.fold(0.0, (sum, item) => sum + item.weightPercentage);
//   }

//   bool get _isValidWeight => _totalWeight == 100.0;

//   void _showAddCategoryDialog([GradeCategory? existingCategory]) {
//     final nameController = TextEditingController(
//       text: existingCategory?.name ?? '',
//     );
//     final weightController = TextEditingController(
//       text: existingCategory != null
//           ? existingCategory.weightPercentage.toString()
//           : '',
//     );
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Text(
//           existingCategory == null ? 'Add Grade Category' : 'Edit Category',
//           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//         ),
//         content: SingleChildScrollView(
//           child: SizedBox(
//             width: 400,
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: nameController,
//                     decoration: InputDecoration(
//                       labelText: 'Category Name (e.g., Written Works)',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     validator: (v) => v!.isEmpty ? 'Required' : null,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: weightController,
//                     keyboardType: const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                     decoration: InputDecoration(
//                       labelText: 'Weight Percentage (%)',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       suffixText: '%',
//                     ),
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return 'Required';
//                       if (double.tryParse(v) == null) return 'Must be a number';
//                       return null;
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancel',
//               style: TextStyle(color: Colors.grey.shade700),
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _Brand.teal,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 final category = GradeCategory(
//                   id: existingCategory?.id ?? _uuid.v4(),
//                   frameworkId: widget.frameworkId,
//                   name: nameController.text.trim(),
//                   weightPercentage: double.parse(weightController.text.trim()),
//                   orderIndex:
//                       existingCategory?.orderIndex ?? _categories.length,
//                 );

//                 await _repo.saveCategory(category);
//                 if (context.mounted) {
//                   Navigator.pop(context);
//                   _loadData();
//                 }
//               }
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Modal for Subcategories ───────────────────────────────────────────────
//   void _showAddSubcategoryDialog(
//     GradeCategory parentCategory, [
//     GradeSubcategory? existingSubcategory,
//   ]) {
//     final nameController = TextEditingController(
//       text: existingSubcategory?.name ?? '',
//     );
//     final weightController = TextEditingController(
//       text: existingSubcategory?.weightPercentage?.toString() ?? '',
//     );
//     // If the subcategory already has a weight, or if other siblings already
//     // have weights, default the toggle on so the teacher sees the field.
//     final siblingsAreWeighted =
//         (_subcategoriesByCategory[parentCategory.id] ?? []).any(
//           (s) => s.id != existingSubcategory?.id && s.weightPercentage != null,
//         );
//     bool isWeighted =
//         existingSubcategory?.weightPercentage != null || siblingsAreWeighted;

//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setDialogState) => AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: Text(
//             existingSubcategory == null
//                 ? 'Add Subcategory'
//                 : 'Edit Subcategory',
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//           ),
//           content: SingleChildScrollView(
//             child: SizedBox(
//               width: 400,
//               child: Form(
//                 key: formKey,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     TextFormField(
//                       controller: nameController,
//                       decoration: InputDecoration(
//                         labelText: 'Subcategory Name (e.g., Quizzes)',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       validator: (v) =>
//                           (v == null || v.trim().isEmpty) ? 'Required' : null,
//                     ),
//                     const SizedBox(height: 20),
//                     // ── Mode toggle ────────────────────────────────────────
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: isWeighted
//                             ? _Brand.tealSurf
//                             : Colors.grey.shade50,
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: isWeighted
//                               ? _Brand.tealBorder
//                               : Colors.grey.shade200,
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   isWeighted
//                                       ? 'Weighted subcategory'
//                                       : 'Organizational only',
//                                   style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w600,
//                                     color: isWeighted
//                                         ? _Brand.tealDark
//                                         : Colors.black54,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 2),
//                                 Text(
//                                   isWeighted
//                                       ? 'Carries its own % share of "${parentCategory.name}".'
//                                       : 'Groups items only — no separate weight.',
//                                   style: TextStyle(
//                                     fontSize: 11,
//                                     color: isWeighted
//                                         ? _Brand.tealMid
//                                         : Colors.black38,
//                                     height: 1.3,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           Switch(
//                             value: isWeighted,
//                             activeColor: _Brand.teal,
//                             onChanged: (v) {
//                               setDialogState(() {
//                                 isWeighted = v;
//                                 if (!v) weightController.clear();
//                               });
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (isWeighted) ...[
//                       const SizedBox(height: 16),
//                       TextFormField(
//                         controller: weightController,
//                         keyboardType: const TextInputType.numberWithOptions(
//                           decimal: true,
//                         ),
//                         decoration: InputDecoration(
//                           labelText: 'Weight % inside "${parentCategory.name}"',
//                           helperText:
//                               'All weighted subcategories here must add up to 100%.',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           suffixText: '%',
//                         ),
//                         validator: (v) {
//                           if (!isWeighted) return null;
//                           if (v == null || v.trim().isEmpty) {
//                             return 'Enter a percentage';
//                           }
//                           if (double.tryParse(v.trim()) == null) {
//                             return 'Must be a number';
//                           }
//                           return null;
//                         },
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: Text(
//                 'Cancel',
//                 style: TextStyle(color: Colors.grey.shade700),
//               ),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _Brand.teal,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               onPressed: () async {
//                 if (formKey.currentState!.validate()) {
//                   final weightText = weightController.text.trim();
//                   final existingSubs =
//                       _subcategoriesByCategory[parentCategory.id] ?? [];
//                   final subcategory = GradeSubcategory(
//                     id: existingSubcategory?.id ?? _uuid.v4(),
//                     categoryId: parentCategory.id,
//                     name: nameController.text.trim(),
//                     weightPercentage: (!isWeighted || weightText.isEmpty)
//                         ? null
//                         : double.parse(weightText),
//                     orderIndex:
//                         existingSubcategory?.orderIndex ?? existingSubs.length,
//                   );

//                   await _repo.saveSubcategory(subcategory);
//                   if (ctx.mounted) {
//                     Navigator.pop(ctx);
//                     _loadData();
//                   }
//                 }
//               },
//               child: const Text('Save'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ─── Modal for Academic Periods ───────────────────────────────────────────
//   void _showAddPeriodDialog([AcademicPeriod? existingPeriod]) {
//     final nameController = TextEditingController(
//       text: existingPeriod?.name ?? '',
//     );
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Text(
//           existingPeriod == null ? 'Add Academic Period' : 'Edit Term',
//           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//         ),
//         content: SingleChildScrollView(
//           child: SizedBox(
//             width: 400,
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: nameController,
//                     decoration: InputDecoration(
//                       labelText: 'Term Name (e.g., 1st Quarter, Midterms)',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     validator: (v) => v!.isEmpty ? 'Required' : null,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancel',
//               style: TextStyle(color: Colors.grey.shade700),
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _Brand.teal,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 final period = AcademicPeriod(
//                   id: existingPeriod?.id ?? _uuid.v4(),
//                   frameworkId: widget.frameworkId,
//                   name: nameController.text.trim(),
//                   orderIndex: existingPeriod?.orderIndex ?? _periods.length,
//                 );

//                 await _repo.savePeriod(period);
//                 if (context.mounted) {
//                   Navigator.pop(context);
//                   _loadData();
//                 }
//               }
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Subcategory section (nested inside each category card) ──────────────
//   Widget _buildSubcategorySection(GradeCategory category) {
//     final subs = _subcategoriesByCategory[category.id] ?? [];
//     final weightedSubs = subs.where((s) => s.weightPercentage != null).toList();
//     final orgSubs = subs.where((s) => s.weightPercentage == null).toList();
//     final hasWeighted = weightedSubs.isNotEmpty;
//     final hasOrg = orgSubs.isNotEmpty;
//     final subWeightTotal = weightedSubs.fold<double>(
//       0,
//       (sum, s) => sum + (s.weightPercentage ?? 0),
//     );
//     final weightedBalanced = hasWeighted && (subWeightTotal - 100).abs() < 0.01;

//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Divider(height: 20),

//           // ── Weighted subcategories ─────────────────────────────────────
//           if (hasWeighted) ...[
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 3,
//                   ),
//                   decoration: BoxDecoration(
//                     color: weightedBalanced
//                         ? _Brand.tealSurf
//                         : Colors.orange.shade50,
//                     borderRadius: BorderRadius.circular(99),
//                     border: Border.all(
//                       color: weightedBalanced
//                           ? _Brand.tealBorder
//                           : Colors.orange.shade300,
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         weightedBalanced
//                             ? Icons.check_circle_outline_rounded
//                             : Icons.warning_amber_rounded,
//                         size: 12,
//                         color: weightedBalanced
//                             ? _Brand.tealMid
//                             : Colors.orange.shade700,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Weighted — ${subWeightTotal.toStringAsFixed(0)}% / 100%',
//                         style: TextStyle(
//                           fontSize: 10.5,
//                           fontWeight: FontWeight.w600,
//                           color: weightedBalanced
//                               ? _Brand.tealDark
//                               : Colors.orange.shade800,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             ...weightedSubs.map((sub) => _buildSubcategoryRow(category, sub)),
//             if (!weightedBalanced)
//               Padding(
//                 padding: const EdgeInsets.only(top: 2, bottom: 6),
//                 child: Text(
//                   'Weighted subcategories must add up to exactly 100%.',
//                   style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
//                 ),
//               ),
//             if (hasOrg) const SizedBox(height: 12),
//           ],

//           // ── Organizational subcategories ───────────────────────────────
//           if (hasOrg) ...[
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 3,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: BorderRadius.circular(99),
//                     border: Border.all(color: Colors.grey.shade300),
//                   ),
//                   child: Text(
//                     'Organizational',
//                     style: TextStyle(
//                       fontSize: 10.5,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             ...orgSubs.map((sub) => _buildSubcategoryRow(category, sub)),
//           ],

//           if (subs.isEmpty)
//             Text(
//               'No subcategories — items added here pool together as one group.',
//               style: TextStyle(
//                 fontSize: 11.5,
//                 color: Colors.grey.shade500,
//                 height: 1.4,
//               ),
//             ),

//           const SizedBox(height: 8),
//           Align(
//             alignment: Alignment.centerLeft,
//             child: TextButton.icon(
//               onPressed: () => _showAddSubcategoryDialog(category),
//               icon: const Icon(Icons.add, size: 16, color: _Brand.teal),
//               label: const Text(
//                 'Add Subcategory',
//                 style: TextStyle(color: _Brand.teal, fontSize: 12),
//               ),
//               style: TextButton.styleFrom(
//                 padding: EdgeInsets.zero,
//                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubcategoryRow(GradeCategory category, GradeSubcategory sub) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6),
//       child: Row(
//         children: [
//           const Icon(
//             Icons.subdirectory_arrow_right_rounded,
//             size: 14,
//             color: Colors.black26,
//           ),
//           const SizedBox(width: 6),
//           Expanded(
//             child: Text(
//               sub.name,
//               style: const TextStyle(fontSize: 13, color: Colors.black87),
//             ),
//           ),
//           if (sub.weightPercentage != null)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//               margin: const EdgeInsets.only(right: 4),
//               decoration: BoxDecoration(
//                 color: _Brand.tealSurf,
//                 borderRadius: BorderRadius.circular(99),
//               ),
//               child: Text(
//                 '${sub.weightPercentage!.toStringAsFixed(0)}%',
//                 style: const TextStyle(
//                   fontSize: 10.5,
//                   color: _Brand.tealDark,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//           IconButton(
//             icon: const Icon(
//               Icons.edit_outlined,
//               size: 16,
//               color: Colors.black45,
//             ),
//             onPressed: () => _showAddSubcategoryDialog(category, sub),
//             padding: EdgeInsets.zero,
//             constraints: const BoxConstraints(),
//             visualDensity: VisualDensity.compact,
//           ),
//           const SizedBox(width: 10),
//           IconButton(
//             icon: const Icon(
//               Icons.delete_outline,
//               size: 16,
//               color: _Brand.error,
//             ),
//             onPressed: () async {
//               await _repo.deleteSubcategory(sub.id);
//               _loadData();
//             },
//             padding: EdgeInsets.zero,
//             constraints: const BoxConstraints(),
//             visualDensity: VisualDensity.compact,
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator(color: _Brand.teal)),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: const BackButton(color: Colors.black87),
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Curriculum Configuration',
//               style: TextStyle(
//                 color: Colors.black87,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             Text(
//               widget.frameworkName,
//               style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//             ),
//           ],
//         ),
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Divider(height: 1, color: Colors.grey.shade200),
//         ),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(20),
//         children: [
//           // --- Shared-framework notice ---
//           FutureBuilder<int>(
//             future: _repo.countSectionsUsingFramework(widget.frameworkId),
//             builder: (context, snap) {
//               if (!snap.hasData) return const SizedBox.shrink();
//               final count = snap.data!;
//               return Padding(
//                 padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.blueGrey.shade50,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(
//                         Icons.info_outline_rounded,
//                         size: 16,
//                         color: Colors.blueGrey.shade400,
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           count == 0
//                               ? 'Not currently assigned to any class.'
//                               : 'Used by $count ${count == 1 ? 'class' : 'classes'} — changes here apply to ${count == 1 ? 'that class' : 'all of them'}.',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.blueGrey.shade700,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),

//           // --- Weight Validation Tracker ---
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: _isValidWeight ? _Brand.tealSurf : Colors.red.shade50,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(
//                 color: _isValidWeight ? _Brand.tealBorder : Colors.red.shade200,
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Total Component Weight',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: _isValidWeight ? _Brand.tealDark : _Brand.error,
//                       ),
//                     ),
//                     Text(
//                       '${_totalWeight.toStringAsFixed(1)}%',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: _isValidWeight ? _Brand.tealDark : _Brand.error,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(4),
//                   child: LinearProgressIndicator(
//                     value: _totalWeight / 100.0,
//                     minHeight: 8,
//                     backgroundColor: Colors.white,
//                     valueColor: AlwaysStoppedAnimation<Color>(
//                       _isValidWeight
//                           ? _Brand.teal
//                           : (_totalWeight > 100 ? _Brand.error : Colors.orange),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 if (!_isValidWeight)
//                   Text(
//                     _totalWeight > 100
//                         ? 'Weight exceeds 100%. Please adjust categories.'
//                         : 'Weight is below 100%. Grades cannot be finalized.',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: _Brand.error,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   )
//                 else
//                   const Text(
//                     'Perfect! Curriculum weights are balanced.',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: _Brand.tealMid,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 32),

//           // ==================================================================
//           // CATEGORIES SECTION
//           // ==================================================================
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Grading Categories',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//               TextButton.icon(
//                 onPressed: () => _showAddCategoryDialog(),
//                 icon: const Icon(Icons.add, size: 18, color: _Brand.teal),
//                 label: const Text(
//                   'Add Component',
//                   style: TextStyle(color: _Brand.teal),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),

//           if (_categories.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(32),
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 border: Border.all(
//                   color: Colors.grey.shade300,
//                   style: BorderStyle.solid,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 'No grading components configured.\nAdd components like "Written Works" or "Exams".',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey.shade500),
//               ),
//             )
//           else
//             ReorderableListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _categories.length,
//               onReorder: (oldIndex, newIndex) {
//                 setState(() {
//                   if (oldIndex < newIndex) newIndex -= 1;
//                   final item = _categories.removeAt(oldIndex);
//                   _categories.insert(newIndex, item);
//                 });
//                 _repo.saveCategoryOrder(_categories);
//               },
//               itemBuilder: (context, index) {
//                 final cat = _categories[index];
//                 final isExpanded = _expandedCategoryIds.contains(cat.id);
//                 final subCount = _subcategoriesByCategory[cat.id]?.length ?? 0;
//                 return Card(
//                   key: ValueKey(cat.id),
//                   elevation: 0,
//                   margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
//                   shape: RoundedRectangleBorder(
//                     side: BorderSide(color: Colors.grey.shade200),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Column(
//                     children: [
//                       ListTile(
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 4,
//                         ),
//                         leading: CircleAvatar(
//                           backgroundColor: _Brand.tealSurf,
//                           child: Text(
//                             '${cat.weightPercentage.toStringAsFixed(0)}%',
//                             style: const TextStyle(
//                               color: _Brand.tealDark,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         title: Text(
//                           cat.name,
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                         subtitle: subCount > 0
//                             ? Text(
//                                 '$subCount subcategor${subCount == 1 ? 'y' : 'ies'}',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey.shade500,
//                                 ),
//                               )
//                             : null,
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             IconButton(
//                               icon: Icon(
//                                 isExpanded
//                                     ? Icons.expand_less_rounded
//                                     : Icons.expand_more_rounded,
//                                 color: Colors.black54,
//                               ),
//                               tooltip: 'Subcategories',
//                               onPressed: () => setState(() {
//                                 if (isExpanded) {
//                                   _expandedCategoryIds.remove(cat.id);
//                                 } else {
//                                   _expandedCategoryIds.add(cat.id);
//                                 }
//                               }),
//                             ),
//                             IconButton(
//                               icon: const Icon(
//                                 Icons.edit_outlined,
//                                 color: Colors.black54,
//                                 size: 20,
//                               ),
//                               onPressed: () => _showAddCategoryDialog(cat),
//                             ),
//                             IconButton(
//                               icon: const Icon(
//                                 Icons.delete_outline,
//                                 color: _Brand.error,
//                                 size: 20,
//                               ),
//                               onPressed: () async {
//                                 await _repo.deleteCategory(cat.id);
//                                 _loadData();
//                               },
//                             ),
//                             const Icon(
//                               Icons.drag_handle_rounded,
//                               color: Colors.black26,
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (isExpanded) _buildSubcategorySection(cat),
//                     ],
//                   ),
//                 );
//               },
//             ),

//           const SizedBox(height: 32),
//           const Divider(),
//           const SizedBox(height: 16),

//           // ==================================================================
//           // ACADEMIC PERIODS SECTION
//           // ==================================================================
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Academic Periods',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//               TextButton.icon(
//                 onPressed: () => _showAddPeriodDialog(),
//                 icon: const Icon(Icons.add, size: 18, color: _Brand.teal),
//                 label: const Text(
//                   'Add Term',
//                   style: TextStyle(color: _Brand.teal),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),

//           if (_periods.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(32),
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 border: Border.all(
//                   color: Colors.grey.shade300,
//                   style: BorderStyle.solid,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 'No academic periods configured.\nAdd terms like "First Quarter" or "Semester 1".',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey.shade500),
//               ),
//             )
//           else
//             ReorderableListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _periods.length,
//               onReorder: (oldIndex, newIndex) {
//                 setState(() {
//                   if (oldIndex < newIndex) newIndex -= 1;
//                   final item = _periods.removeAt(oldIndex);
//                   _periods.insert(newIndex, item);
//                 });
//                 _repo.savePeriodOrder(_periods);
//               },
//               itemBuilder: (context, index) {
//                 final period = _periods[index];
//                 return Card(
//                   key: ValueKey(period.id),
//                   elevation: 0,
//                   margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
//                   shape: RoundedRectangleBorder(
//                     side: BorderSide(color: Colors.grey.shade200),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: ListTile(
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 16,
//                       vertical: 4,
//                     ),
//                     leading: CircleAvatar(
//                       backgroundColor: Colors.blueGrey.shade50,
//                       child: Text(
//                         '${index + 1}',
//                         style: TextStyle(
//                           color: Colors.blueGrey.shade700,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     title: Text(
//                       period.name,
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: const Icon(
//                             Icons.edit_outlined,
//                             color: Colors.black54,
//                             size: 20,
//                           ),
//                           onPressed: () => _showAddPeriodDialog(period),
//                         ),
//                         IconButton(
//                           icon: const Icon(
//                             Icons.delete_outline,
//                             color: _Brand.error,
//                             size: 20,
//                           ),
//                           onPressed: () async {
//                             await _repo.deletePeriod(period.id);
//                             _loadData();
//                           },
//                         ),
//                         const Icon(
//                           Icons.drag_handle_rounded,
//                           color: Colors.black26,
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../features/grading/repository/framework_repository.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
class _Brand {
  static const tealDark = Color(0xFF085041);
  static const tealMid = Color(0xFF0F6E56);
  static const teal = Color(0xFF1D9E75);
  static const tealSurf = Color(0xFFEAF8F3);
  static const tealBorder = Color(0xFF9FE1CB);
  static const error = Color(0xFFD32F2F);
}

class FrameworkConfigScreen extends StatefulWidget {
  final String frameworkId;
  final String frameworkName;

  const FrameworkConfigScreen({
    super.key,
    required this.frameworkId,
    required this.frameworkName,
  });

  @override
  State<FrameworkConfigScreen> createState() => _FrameworkConfigScreenState();
}

class _FrameworkConfigScreenState extends State<FrameworkConfigScreen> {
  final _repo = FrameworkRepository();
  final _uuid = const Uuid();

  List<GradeCategory> _categories = [];
  List<AcademicPeriod> _periods = [];
  Map<String, List<GradeSubcategory>> _subcategoriesByCategory = {};
  final Set<String> _expandedCategoryIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _repo.getCategories(widget.frameworkId);
    final periods = await _repo.getPeriods(widget.frameworkId);

    final subsByCategory = <String, List<GradeSubcategory>>{};
    for (final cat in categories) {
      subsByCategory[cat.id] = await _repo.getSubcategories(cat.id);
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _periods = periods;
        _subcategoriesByCategory = subsByCategory;
        _isLoading = false;
      });
    }
  }

  double get _totalWeight {
    return _categories.fold(0.0, (sum, item) => sum + item.weightPercentage);
  }

  bool get _isValidWeight => _totalWeight == 100.0 && _allSubWeightsBalanced;

  /// True if every category that has weighted subcategories has them sum to 100%.
  bool get _allSubWeightsBalanced {
    for (final cat in _categories) {
      final subs = _subcategoriesByCategory[cat.id] ?? [];
      final weightedSubs = subs
          .where((s) => s.weightPercentage != null)
          .toList();
      if (weightedSubs.isEmpty) continue;
      final total = weightedSubs.fold<double>(
        0,
        (s, e) => s + (e.weightPercentage ?? 0),
      );
      if ((total - 100).abs() >= 0.01) return false;
    }
    return true;
  }

  /// Returns categories whose weighted subcategories don't sum to 100%.
  List<({GradeCategory category, double subTotal})>
  get _unbalancedSubcategoryCategories {
    final result = <({GradeCategory category, double subTotal})>[];
    for (final cat in _categories) {
      final subs = _subcategoriesByCategory[cat.id] ?? [];
      final weightedSubs = subs
          .where((s) => s.weightPercentage != null)
          .toList();
      if (weightedSubs.isEmpty) continue;
      final total = weightedSubs.fold<double>(
        0,
        (s, e) => s + (e.weightPercentage ?? 0),
      );
      if ((total - 100).abs() >= 0.01) {
        result.add((category: cat, subTotal: total));
      }
    }
    return result;
  }

  void _showAddCategoryDialog([GradeCategory? existingCategory]) {
    final nameController = TextEditingController(
      text: existingCategory?.name ?? '',
    );
    final weightController = TextEditingController(
      text: existingCategory != null
          ? existingCategory.weightPercentage.toString()
          : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existingCategory == null ? 'Add Grade Category' : 'Edit Category',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Category Name (e.g., Written Works)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Weight Percentage (%)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: '%',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final category = GradeCategory(
                  id: existingCategory?.id ?? _uuid.v4(),
                  frameworkId: widget.frameworkId,
                  name: nameController.text.trim(),
                  weightPercentage: double.parse(weightController.text.trim()),
                  orderIndex:
                      existingCategory?.orderIndex ?? _categories.length,
                );

                await _repo.saveCategory(category);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Modal for Subcategories ───────────────────────────────────────────────
  void _showAddSubcategoryDialog(
    GradeCategory parentCategory, [
    GradeSubcategory? existingSubcategory,
  ]) {
    final nameController = TextEditingController(
      text: existingSubcategory?.name ?? '',
    );
    final weightController = TextEditingController(
      text: existingSubcategory?.weightPercentage?.toString() ?? '',
    );
    // If the subcategory already has a weight, or if other siblings already
    // have weights, default the toggle on so the teacher sees the field.
    final siblingsAreWeighted =
        (_subcategoriesByCategory[parentCategory.id] ?? []).any(
          (s) => s.id != existingSubcategory?.id && s.weightPercentage != null,
        );
    bool isWeighted =
        existingSubcategory?.weightPercentage != null || siblingsAreWeighted;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            existingSubcategory == null
                ? 'Add Subcategory'
                : 'Edit Subcategory',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Subcategory Name (e.g., Quizzes)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    // ── Mode toggle ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isWeighted
                            ? _Brand.tealSurf
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isWeighted
                              ? _Brand.tealBorder
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWeighted
                                      ? 'Weighted subcategory'
                                      : 'Organizational only',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isWeighted
                                        ? _Brand.tealDark
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isWeighted
                                      ? 'Carries its own % share of "${parentCategory.name}".'
                                      : 'Groups items only — no separate weight.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isWeighted
                                        ? _Brand.tealMid
                                        : Colors.black38,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isWeighted,
                            activeColor: _Brand.teal,
                            onChanged: (v) {
                              setDialogState(() {
                                isWeighted = v;
                                if (!v) weightController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isWeighted) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Weight % inside "${parentCategory.name}"',
                          helperText:
                              'All weighted subcategories here must add up to 100%.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixText: '%',
                        ),
                        validator: (v) {
                          if (!isWeighted) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter a percentage';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Must be a number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final weightText = weightController.text.trim();
                  final existingSubs =
                      _subcategoriesByCategory[parentCategory.id] ?? [];
                  final subcategory = GradeSubcategory(
                    id: existingSubcategory?.id ?? _uuid.v4(),
                    categoryId: parentCategory.id,
                    name: nameController.text.trim(),
                    weightPercentage: (!isWeighted || weightText.isEmpty)
                        ? null
                        : double.parse(weightText),
                    orderIndex:
                        existingSubcategory?.orderIndex ?? existingSubs.length,
                  );

                  await _repo.saveSubcategory(subcategory);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modal for Academic Periods ───────────────────────────────────────────
  void _showAddPeriodDialog([AcademicPeriod? existingPeriod]) {
    final nameController = TextEditingController(
      text: existingPeriod?.name ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existingPeriod == null ? 'Add Academic Period' : 'Edit Term',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Term Name (e.g., 1st Quarter, Midterms)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final period = AcademicPeriod(
                  id: existingPeriod?.id ?? _uuid.v4(),
                  frameworkId: widget.frameworkId,
                  name: nameController.text.trim(),
                  orderIndex: existingPeriod?.orderIndex ?? _periods.length,
                );

                await _repo.savePeriod(period);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Subcategory section (nested inside each category card) ──────────────
  Widget _buildSubcategorySection(GradeCategory category) {
    final subs = _subcategoriesByCategory[category.id] ?? [];
    final weightedSubs = subs.where((s) => s.weightPercentage != null).toList();
    final orgSubs = subs.where((s) => s.weightPercentage == null).toList();
    final hasWeighted = weightedSubs.isNotEmpty;
    final hasOrg = orgSubs.isNotEmpty;
    final subWeightTotal = weightedSubs.fold<double>(
      0,
      (sum, s) => sum + (s.weightPercentage ?? 0),
    );
    final weightedBalanced = hasWeighted && (subWeightTotal - 100).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 20),

          // ── Weighted subcategories ─────────────────────────────────────
          if (hasWeighted) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: weightedBalanced
                        ? _Brand.tealSurf
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: weightedBalanced
                          ? _Brand.tealBorder
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        weightedBalanced
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 12,
                        color: weightedBalanced
                            ? _Brand.tealMid
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Weighted — ${subWeightTotal.toStringAsFixed(0)}% / 100%',
                        style: TextStyle(
                          fontSize: 10.5,
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
            const SizedBox(height: 8),
            ...weightedSubs.map((sub) => _buildSubcategoryRow(category, sub)),
            if (!weightedBalanced)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(
                  'Weighted subcategories must add up to exactly 100%.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ),
            if (hasOrg) const SizedBox(height: 12),
          ],

          // ── Organizational subcategories ───────────────────────────────
          if (hasOrg) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Organizational',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...orgSubs.map((sub) => _buildSubcategoryRow(category, sub)),
          ],

          if (subs.isEmpty)
            Text(
              'No subcategories — items added here pool together as one group.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAddSubcategoryDialog(category),
              icon: const Icon(Icons.add, size: 16, color: _Brand.teal),
              label: const Text(
                'Add Subcategory',
                style: TextStyle(color: _Brand.teal, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryRow(GradeCategory category, GradeSubcategory sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 14,
            color: Colors.black26,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              sub.name,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          if (sub.weightPercentage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _Brand.tealSurf,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${sub.weightPercentage!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _Brand.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: Colors.black45,
            ),
            onPressed: () => _showAddSubcategoryDialog(category, sub),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 16,
              color: _Brand.error,
            ),
            onPressed: () async {
              await _repo.deleteSubcategory(sub.id);
              _loadData();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _Brand.teal)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Curriculum Configuration',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.frameworkName,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Shared-framework notice ---
          FutureBuilder<int>(
            future: _repo.countSectionsUsingFramework(widget.frameworkId),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final count = snap.data!;
              return Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.blueGrey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          count == 0
                              ? 'Not currently assigned to any class.'
                              : 'Used by $count ${count == 1 ? 'class' : 'classes'} — changes here apply to ${count == 1 ? 'that class' : 'all of them'}.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // --- Weight Validation Tracker ---
          Builder(
            builder: (context) {
              final unbalanced = _unbalancedSubcategoryCategories;
              final catOk = _totalWeight == 100.0;
              final subOk = unbalanced.isEmpty;
              final allOk = catOk && subOk;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: allOk ? _Brand.tealSurf : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: allOk ? _Brand.tealBorder : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Component Weight',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: allOk ? _Brand.tealDark : _Brand.error,
                          ),
                        ),
                        Text(
                          '${_totalWeight.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: catOk ? _Brand.tealDark : _Brand.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_totalWeight / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          catOk
                              ? _Brand.teal
                              : (_totalWeight > 100
                                    ? _Brand.error
                                    : Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!catOk)
                      Text(
                        _totalWeight > 100
                            ? 'Category weights exceed 100%. Please adjust.'
                            : 'Category weights don\'t reach 100%. Grades cannot be finalized.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _Brand.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (!subOk) ...[
                      if (!catOk) const SizedBox(height: 6),
                      Text(
                        'Subcategory weights incomplete:',
                        style: TextStyle(
                          fontSize: 12,
                          color: _Brand.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...unbalanced.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 13,
                                color: _Brand.error,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${e.category.name}: ${e.subTotal.toStringAsFixed(0)}% / 100%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _Brand.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (allOk)
                      const Text(
                        'Perfect! Curriculum weights are balanced.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _Brand.tealMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // ==================================================================
          // CATEGORIES SECTION
          // ==================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grading Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add, size: 18, color: _Brand.teal),
                label: const Text(
                  'Add Component',
                  style: TextStyle(color: _Brand.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_categories.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No grading components configured.\nAdd components like "Written Works" or "Exams".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _categories.removeAt(oldIndex);
                  _categories.insert(newIndex, item);
                });
                _repo.saveCategoryOrder(_categories);
              },
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isExpanded = _expandedCategoryIds.contains(cat.id);
                final subCount = _subcategoriesByCategory[cat.id]?.length ?? 0;
                return Card(
                  key: ValueKey(cat.id),
                  elevation: 0,
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _Brand.tealSurf,
                          child: Text(
                            '${cat.weightPercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: _Brand.tealDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subCount > 0
                            ? Text(
                                '$subCount subcategor${subCount == 1 ? 'y' : 'ies'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: Colors.black54,
                              ),
                              tooltip: 'Subcategories',
                              onPressed: () => setState(() {
                                if (isExpanded) {
                                  _expandedCategoryIds.remove(cat.id);
                                } else {
                                  _expandedCategoryIds.add(cat.id);
                                }
                              }),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.black54,
                                size: 20,
                              ),
                              onPressed: () => _showAddCategoryDialog(cat),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: _Brand.error,
                                size: 20,
                              ),
                              onPressed: () async {
                                await _repo.deleteCategory(cat.id);
                                _loadData();
                              },
                            ),
                            const Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) _buildSubcategorySection(cat),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // ==================================================================
          // ACADEMIC PERIODS SECTION
          // ==================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Academic Periods',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddPeriodDialog(),
                icon: const Icon(Icons.add, size: 18, color: _Brand.teal),
                label: const Text(
                  'Add Term',
                  style: TextStyle(color: _Brand.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_periods.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No academic periods configured.\nAdd terms like "First Quarter" or "Semester 1".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _periods.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _periods.removeAt(oldIndex);
                  _periods.insert(newIndex, item);
                });
                _repo.savePeriodOrder(_periods);
              },
              itemBuilder: (context, index) {
                final period = _periods[index];
                return Card(
                  key: ValueKey(period.id),
                  elevation: 0,
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey.shade50,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      period.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.black54,
                            size: 20,
                          ),
                          onPressed: () => _showAddPeriodDialog(period),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: _Brand.error,
                            size: 20,
                          ),
                          onPressed: () async {
                            await _repo.deletePeriod(period.id);
                            _loadData();
                          },
                        ),
                        const Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
