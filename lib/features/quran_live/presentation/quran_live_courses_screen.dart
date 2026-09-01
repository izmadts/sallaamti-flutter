import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/info_pill.dart';
import '../data/quran_live_repository.dart';

const _categoryColors = {
  'Nazrah': Color(0xFF0D6B6B),
  'Tajweed': Color(0xFFB8962E),
  'Translation': Color(0xFF1A5276),
  'Arabic Grammar': Color(0xFF922B21),
  'Seerah': Color(0xFF16A34A),
  'Hadith': Color(0xFF7D3C98),
};

class QuranLiveCoursesScreen extends ConsumerStatefulWidget {
  const QuranLiveCoursesScreen({super.key});

  @override
  ConsumerState<QuranLiveCoursesScreen> createState() => _QuranLiveCoursesScreenState();
}

class _QuranLiveCoursesScreenState extends ConsumerState<QuranLiveCoursesScreen> {
  late Future<List<QuranLiveCourseInfo>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = ref.read(quranLiveRepositoryProvider).courses();
  }

  void _reload() => setState(() => _coursesFuture = ref.read(quranLiveRepositoryProvider).courses());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Quran Classes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.school_outlined),
              tooltip: 'My Class',
              onPressed: () => context.push('/quran-live/my-class'),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<QuranLiveCourseInfo>>(
            future: _coursesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : 'Something went wrong.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final courses = snapshot.data ?? [];

              if (courses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎥', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('No Live Classes Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('Check back soon — new batches open regularly.', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _CourseCard(course: courses[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final QuranLiveCourseInfo course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[course.category] ?? const Color(0xFF0D6B6B);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/quran-live/${course.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoPill(text: course.category ?? 'Live Class', color: color, filled: true),
                  if (course.minAge != null || course.maxAge != null)
                    InfoPill(text: '🎂 ${course.minAge ?? 0}${course.maxAge != null ? '–${course.maxAge}' : '+'}', color: color),
                  // 'both' is "no restriction" — a badge for it would imply
                  // one exists where it doesn't.
                  if (course.genderPreference == 'male') InfoPill(text: '♂ Boys only', color: color),
                  if (course.genderPreference == 'female') InfoPill(text: '♀ Girls only', color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(course.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
              if ((course.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(course.description!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Text('👤 Teacher: ${course.teacher?.name ?? 'TBA'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              if (course.classDays.isNotEmpty || course.classTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('🗓️ ${course.classDays.join(', ')} ${course.classTime ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Color(0xFFB8962E), fontSize: 15, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'Rs. ${_formatFee(course.monthlyFee)}'),
                        TextSpan(text: '/month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const Text('View Details →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D6B6B))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFee(String fee) {
    final value = double.tryParse(fee) ?? 0;
    return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}
