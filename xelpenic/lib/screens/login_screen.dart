import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // สร้าง Controller เพื่อดึงข้อความจากช่องกรอกอีเมลและรหัสผ่าน
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // เรียกใช้งาน Supabase
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- ฟังก์ชันสมัครสมาชิก (Register) ---
  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      // 1. สร้าง User ในระบบ Auth ของ Supabase
      final AuthResponse res = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final Session? session = res.session;
      if (session != null) {
        print(
          'สมัครเสร็จและล็อกอินให้ทันที! Token: ${session.accessToken}',
        ); // นำมาใช้ปริ้นท์เช็คค่า
        // หรือสั่งให้เด้งไปหน้า Home ทันทีไม่ต้องรอให้กด Login ซ้ำ
        if (mounted) Navigator.pop(context);
      }
      final User? user = res.user;

      if (user != null) {
        // 2. นำ ID ที่ได้จาก Auth ไปสร้างข้อมูลในตาราง profiles
        // สมมติชื่อตารางคือ profiles และมีคอลัมน์ตามนี้ครับ
        await _supabase.from('profiles').insert({
          'id': user.id, // ต้องใช้ ID เดียวกับในระบบ Auth
          'full_name': 'New Member', // ค่าเริ่มต้น
          'avatar_url':
              'https://uxwing.com/wp-content/themes/uxwing/download/peoples-avatars/man-user-circle-icon.png',
          'xel_exp': 0,
          'xel_points': 0,
          'rank': 'Bronze',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ! ข้อมูลโปรไฟล์ถูกสร้างแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ฟังก์ชันเข้าสู่ระบบ (Login) ---
  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        // ถ้ายืนยันตัวตนผ่าน ให้ปิดหน้าต่าง Login กลับไปหน้า Home
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ล็อกอินล้มเหลว: อีเมลหรือรหัสผ่านไม่ถูกต้อง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // โลโก้แอป
              const Text(
                'XELPENIC',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'เข้าสู่ระบบเพื่อสะสมคะแนนแลกของรางวัล',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // ช่องกรอกอีเมล
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email, color: Colors.brown),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // ช่องกรอกรหัสผ่าน
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.brown),
                ),
                obscureText: true, // ปิดบังรหัสผ่านเป็นจุดกลมๆ
              ),
              const SizedBox(height: 32),

              // เช็คสถานะโหลด ถ้ากำลังโหลดให้โชว์วงกลมหมุนๆ
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.brown)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        // สั่งให้เด้งไปหน้า Register แทนการเรียกฟังก์ชันสมัครในหน้านี้
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text('สมัครสมาชิกใหม่'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ล้างค่า Controller ออกจากหน่วยความจำเมื่อปิดหน้านี้ทิ้ง
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
