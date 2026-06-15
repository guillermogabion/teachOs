import 'package:flutter/material.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';
import 'class_roster_screen.dart';

// Assuming this matches your central color palette setup
class _Brand {
  static const Color teal = Colors.teal;
  static final Color tealSurf = Colors.teal.shade50;
  static final Color greySurf = Colors.grey.shade50;
  static final Color greyBorder = Colors.grey.shade200;
}

class ArchivedClassesScreen extends StatelessWidget {
  const ArchivedClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sectionRepo = SectionRepository();

    return Scaffold(
      backgroundColor: _Brand.greySurf,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: _Brand.greyBorder),
        ),
        title: const Text(
          'Archived History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: FutureBuilder<List<Section>>(
        future: sectionRepo.getArchivedSections(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _Brand.teal),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Archive is empty.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Past school years will automatically appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final archivedSections = snapshot.data!;
          return ListView.builder(
            itemCount: archivedSections.length,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemBuilder: (context, index) {
              final section = archivedSections[index];

              return Container(
                margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Brand.greyBorder, width: 0.8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClassRosterScreen(section: section),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          // Grade Level Accent Badge
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _Brand.greySurf,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _Brand.greyBorder,
                                width: 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'G${section.gradeLevel}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Class Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Adviser: ${section.adviserName ?? "None Specified"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Historical Year Timeline Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _Brand.tealSurf,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              section.schoolYearId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _Brand.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
