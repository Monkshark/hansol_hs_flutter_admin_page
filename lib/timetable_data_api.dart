import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class niesApiKeys {
  static const NIES_API_KEY = 'db3161d360da4d07b650348a167d4411';
  static const ATPT_OFCDC_SC_CODE = 'I10';
  static const SD_SCHUL_CODE = '9300058';
}

class TimetableDataApi {
  static Future<List<String>> getSubjects({required int grade}) async {
    List<String> subjects = [];
    DateTime now = DateTime.now();

    DateTime startDate = DateTime(now.year, 3, 8);
    DateTime endDate = DateTime(now.year, 3, 14);

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      if (date.weekday >= 6) continue;

      for (var i = 1; i < await getClassCount(grade) + 1; i++) {
        List<String> timetable = await getTimeTable(
          date: date,
          grade: grade.toString(),
          classNum: i.toString(),
        );

        subjects.addAll(timetable.where((name) => !name.contains('[보강]')));
      }
    }

    subjects = subjects.toSet().toList()..sort();
    return subjects;
  }

  static Future<int> getClassCount(int grade) async {
    final requestURL = 'https://open.neis.go.kr/hub/classInfo?'
        'key=${niesApiKeys.NIES_API_KEY}'
        '&Type=json&ATPT_OFCDC_SC_CODE=${niesApiKeys.ATPT_OFCDC_SC_CODE}'
        '&SD_SCHUL_CODE=${niesApiKeys.SD_SCHUL_CODE}'
        '&AY=${DateTime.now().year}'
        '&GRADE=$grade';

    final data = await fetchData(requestURL);
    if (data == null) return 0;

    final classInfo = data['classInfo'][0]['head'][0];
    return classInfo['list_total_count'];
  }

  static Future<List<String>> getTimeTable({
    required DateTime date,
    required String grade,
    required String classNum,
  }) async {
    final formattedDate = DateFormat('yyyyMMdd').format(date);

    final requestURL = 'https://open.neis.go.kr/hub/hisTimetable?'
        'key=${niesApiKeys.NIES_API_KEY}'
        '&Type=json&ATPT_OFCDC_SC_CODE=${niesApiKeys.ATPT_OFCDC_SC_CODE}'
        '&SD_SCHUL_CODE=${niesApiKeys.SD_SCHUL_CODE}'
        '&ALL_TI_YMD=$formattedDate'
        '&GRADE=$grade'
        '&CLASS_NM=$classNum';

    final data = await fetchData(requestURL);
    if (data == null) return [];

    return processTimetable(data['hisTimetable']);
  }

  static Future<Map<String, dynamic>?> fetchData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  static List<String> processTimetable(List<dynamic> timetableArray) {
    List<String> resultList = [];
    for (var data in timetableArray) {
      final rowArray = data['row'];
      if (rowArray != null) {
        for (var item in rowArray) {
          final content = item['ITRT_CNTNT'];
          if (content is String) resultList.add(content);
        }
      }
    }
    return resultList;
  }
}
