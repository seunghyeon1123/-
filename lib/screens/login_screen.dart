// lib/screens/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool isLoading = false;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);

  Future<void> _handleLogin() async {
    if (idCtrl.text.isEmpty || pwCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아이디와 비밀번호를 모두 입력하세요.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🚀 수정된 부분: 구글 보안 출입증(headers) 달고 요청하기!
      var res = await http.post(
          Uri.parse(AppConfig.webAppUrl),
          headers: {'Content-Type': 'text/plain'}, // 🟢 필수: 구글 문전박대 방지용
          body: jsonEncode({
            "action": "login",
            "id": idCtrl.text.trim(),
            "pw": pwCtrl.text.trim()
          })
      ).timeout(const Duration(seconds: 15));

      // 🚀 수정된 부분: 구글 특유의 리다이렉트(옆문으로 돌아가기) 처리
      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) {
          res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 15));
        }
      }

      // 서버 응답이 200(정상)일 때만 데이터 해석
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['ok'] == true) {
          // 로그인 성공 시 기기에 정보 저장
          await AuthService.saveAuth(data['name'], data['role']);

          if (mounted) {
            // 성공하면 메인 화면으로 이동
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        } else {
          // 아이디/비번 틀렸을 때
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error']), backgroundColor: Colors.red));
          }
        }
      } else {
        throw Exception('서버 에러: 상태 코드 ${res.statusCode}');
      }

    } catch (e) {
      // 에러가 나면 팝업으로 보여줌
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hanjiIvory,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.inventory_2, size: 80, color: Color(0xFF586B54)),
                const SizedBox(height: 16),
                const Text('안동한지 WMS', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('관리자 및 직원 로그인', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 48),

                TextField(
                  controller: idCtrl,
                  decoration: InputDecoration(
                    labelText: '아이디',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 60,
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('로그인', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}