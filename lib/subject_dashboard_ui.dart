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
  final List<String> categories = ["인문", "자연", "예체능", "공통"];
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

    List<String> g2Subjects = [], g3Subjects = [];
    Map<String, Map<String, dynamic>> firestoreData = {};

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection("subjects").get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final grade = data["grade"];
        final name = doc.id;
        firestoreData[name] = data;

        if (grade == 2) g2Subjects.add(name);
        if (grade == 3) g3Subjects.add(name);

        categoryMap[name] = data["category"];
        isOriginalMap[name] = data["isOriginal"] ?? false;
      }
    } catch (e) {
      print("Firestore fetch failed: $e");
    }

    List<String> allG2 = [], allG3 = [];

    if (prefs.containsKey(cacheKey) && now - cacheTime < cacheDuration) {
      final cached = jsonDecode(prefs.getString(cacheKey)!);
      allG2 = List<String>.from(cached["grade2"]);
      allG3 = List<String>.from(cached["grade3"]);
    } else {
      allG2 = await TimetableDataApi.getSubjects(grade: 2);
      allG3 = await TimetableDataApi.getSubjects(grade: 3);

      final cachedData = {"grade2": allG2, "grade3": allG3};
      await prefs.setString(cacheKey, jsonEncode(cachedData));
      await prefs.setInt(cacheTimeKey, now);
    }

    final g2Total = {...g2Subjects, ...allG2}.toList()..sort();
    final g3Total = {...g3Subjects, ...allG3}.toList()..sort();

    setState(() {
      grade2Subjects = g2Total;
      grade3Subjects = g3Total;
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
    String? category = categoryMap[subject];
    bool isOriginal = isOriginalMap[subject] ?? false;

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredSubject = subject),
      onExit: (_) => setState(() => hoveredSubject = null),
      child: Card(
        color: hoveredSubject == subject ? Colors.blue.withOpacity(0.05) : null,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Row(
            children: [
              Text(subject),
              const SizedBox(width: 8),
              if (category == null)
                const Icon(Icons.error, color: Colors.red, size: 16),
            ],
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text("분류: "),
                DropdownButton<String>(
                  value: category,
                  hint: const Text("선택"),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (newVal) {
                    setState(() {
                      categoryMap[subject] = newVal;
                    });
                    FirebaseFirestore.instance
                        .collection("subjects")
                        .doc(subject)
                        .set({
                      "category": newVal,
                      "isOriginal": isOriginal,
                      "grade": grade,
                    }, SetOptions(merge: true));
                  },
                ),
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("원반수업", style: TextStyle(fontSize: 12)),
                  Switch(
                    value: isOriginal,
                    onChanged: (val) {
                      setState(() {
                        isOriginalMap[subject] = val;
                      });
                      FirebaseFirestore.instance
                          .collection("subjects")
                          .doc(subject)
                          .set({
                        "category": category,
                        "isOriginal": val,
                        "grade": grade,
                      }, SetOptions(merge: true));
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
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
            child: Text("2학년 과목",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...grade2Subjects.map((s) => buildSubjectItem(s, 2)).toList(),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text("3학년 과목",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...grade3Subjects.map((s) => buildSubjectItem(s, 3)).toList(),
        ],
      ),
    );
  }
}
