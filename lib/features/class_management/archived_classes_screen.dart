import 'package:flutter/material.dart';
import 'models/section_model.dart';
import 'repositories/section_repository.dart';
import 'class_roster_screen.dart';

class ArchivedClassesScreen extends StatelessWidget {
  const ArchivedClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sectionRepo = SectionRepository();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Archived History'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Section>>(
        future: sectionRepo
            .getArchivedSections(), // Pulls everything outside the active year
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Archive is empty.\nPast school years will automatically appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final archivedSections = snapshot.data!;
          return ListView.builder(
            itemCount: archivedSections.length,
            itemBuilder: (context, index) {
              final section = archivedSections[index];

              return Card(
                elevation: 0,
                color: Colors.grey.shade100,
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'G${section.gradeLevel}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    section.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  subtitle: Text('Adviser: ${section.adviserName ?? "None"}'),

                  // Clean display chip showing which historical year this record belonged to
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      section.schoolYearId,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Allows tracking or viewing historical student lists
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClassRosterScreen(section: section),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
