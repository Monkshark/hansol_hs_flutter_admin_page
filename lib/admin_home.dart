import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'subject_dashboard_ui.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("관리자 메뉴"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("📚 과목 분류"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubjectCategoryDashboard(),
                  ),
                );
              },
            ),
            // 추후 확장 예시
            // ElevatedButton(
            //   child: Text("📢 공지사항 관리"),
            //   onPressed: () {},
            // ),
          ],
        ),
      ),
    );
  }
}
