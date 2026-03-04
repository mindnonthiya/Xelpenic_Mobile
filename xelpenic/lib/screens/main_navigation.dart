import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'HomeScreen.dart';
import 'more_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 2; // เริ่มต้นที่หน้า Home (ปุ่ม X ตรงกลาง)
  final _supabase = Supabase.instance.client;

  // ฟังก์ชัน Logout ส่วนกลางที่ใช้ได้จริง
  Future<void> _handleLogout() async {
    await _supabase.auth.signOut(); // สั่ง Supabase ให้จบ Session
    if (mounted) {
      // รีเฟรชแอปเพื่อให้กลับไปสถานะ Guest ทั้งหมด
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // รายชื่อหน้าต่างตาม Prototype
    final List<Widget> _pages = [
      const Center(child: Text('Now Showing')), // หน้า 0
      const Center(child: Text('Coins')),       // หน้า 1
      const HomeScreen(),                       // หน้า 2 (Home)
      const Center(child: Text('Cinema')),      // หน้า 3
      MoreScreen(onLogout: _handleLogout),      // หน้า 4 (More พร้อมปุ่ม Logout)
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages), // รักษา State ทุกหน้า
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.brown,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'NOW SHOWING'),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'COINS'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.theaters), label: 'CINEMA'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'MORE'),
        ],
      ),
    );
  }
}