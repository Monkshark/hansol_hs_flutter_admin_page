
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'timetable_data_api.dart';

class SubjectCategoryDashboard extends StatefulWidget {
  const SubjectCategoryDashboard({super.key});

  @override
  State<SubjectCategoryDashboard> createState() =>
      _SubjectCategoryDashboardState();
}

class _SubjectCategoryDashboardState extends State<SubjectCategoryDashboard> {
  final List<String> categories = ["인문", "자연", "진로", "예체능", "공통"];
  Map<String, String?> categoryMap = {};
  Map<String, bool> isOriginalMap = {};
  List<String> grade2Subjects = [];
  List<String> grade3Subjects = [];
  bool loading = true;
  String? hoveredSubject;

  @override
  void initState() {
    super.initState();
    loadSubjects();
  }

  Future<void> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "cached_subjects";
    final cacheTimeKey = "cached_subjects_time";

    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheTime = prefs.getInt(cacheTimeKey) ?? 0;
    const cacheDuration = 6 * 60 * 60 * 1000;

    List<String> allG2 = [], allG3 = [];

    if (prefs.containsKey(cacheKey) && now - cacheTime < cacheDuration) {
      final cached = jsonDecode(prefs.getString(cacheKey)!);
      allG2 = List<String>.from(cached["grade2"]);
      allG3 = List<String>.from(cached["grade3"]);
    } else {
      allG2 = await TimetableDataApi.getSubjects(grade: 2);
      allG3 = await TimetableDataApi.getSubjects(grade: 3);
      await prefs.setString(cacheKey, jsonEncode({"grade2": allG2, "grade3": allG3}));
      await prefs.setInt(cacheTimeKey, now);
    }

    for (String subject in allG2) {
      final doc = await FirebaseFirestore.instance
          .collection("subjects")
          .doc("2")
          .collection(subject)
          .doc("meta")
          .get();

      final key = "2:$subject";
      if (doc.exists) {
        final data = doc.data()!;
        categoryMap[key] = data["category"];
        isOriginalMap[key] = data["isOriginal"] ?? false;
      }
    }

    for (String subject in allG3) {
      final doc = await FirebaseFirestore.instance
          .collection("subjects")
          .doc("3")
          .collection(subject)
          .doc("meta")
          .get();

      final key = "3:$subject";
      if (doc.exists) {
        final data = doc.data()!;
        categoryMap[key] = data["category"];
        isOriginalMap[key] = data["isOriginal"] ?? false;
      }
    }

    setState(() {
      grade2Subjects = allG2;
      grade3Subjects = allG3;
      loading = false;
    });
  }

  Future<void> clearCacheAndReload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("cached_subjects");
    await prefs.remove("cached_subjects_time");
    setState(() {
      loading = true;
    });
    await loadSubjects();
  }

  Widget buildSubjectItem(String subject, int grade) {
    final key = "$grade:$subject";
    String? category = categoryMap[key];
    bool isOriginal = isOriginalMap[key] ?? false;

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredSubject = key),
      onExit: (_) => setState(() => hoveredSubject = null),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Card(
          color: hoveredSubject == key ? Colors.blue.withOpacity(0.05) : null,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                      child: Text(subject,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 5),
                  Text("($grade학년)",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (category == null)
                    const Icon(Icons.error, color: Colors.red, size: 16),
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: category,
                      hint: const Text("분류 선택"),
                      items: categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (newVal) {
                        setState(() {
                          categoryMap[key] = newVal;
                        });
                        FirebaseFirestore.instance
                            .collection("subjects")
                            .doc(grade.toString())
                            .collection(subject)
                            .doc("meta")
                            .set({
                          "category": newVal,
                          "isOriginal": isOriginal,
                        }, SetOptions(merge: true));
                      },
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("원반수업", style: TextStyle(fontSize: 11)),
                        Switch(
                          value: isOriginal,
                          onChanged: (val) {
                            setState(() {
                              isOriginalMap[key] = val;
                            });
                            FirebaseFirestore.instance
                                .collection("subjects")
                                .doc(grade.toString())
                                .collection(subject)
                                .doc("meta")
                                .set({
                              "category": category,
                              "isOriginal": val,
                            }, SetOptions(merge: true));
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSubjectGrid(List<String> subjects, int grade) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 3.8,
      padding: const EdgeInsets.all(10),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: subjects.map((s) => buildSubjectItem(s, grade)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text("과목 분류 관리자"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '캐시 삭제 및 새로고침',
            onPressed: clearCacheAndReload,
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text("✅ 2학년 과목",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          buildSubjectGrid(grade2Subjects, 2),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text("✅ 3학년 과목",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          buildSubjectGrid(grade3Subjects, 3),
        ],
      ),
    );
  }
}
