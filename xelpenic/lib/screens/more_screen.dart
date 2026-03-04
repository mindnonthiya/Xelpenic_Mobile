import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  // 1. ตรวจสอบว่ามีตัวแปรรับฟังก์ชัน onLogout หรือยัง
  final VoidCallback onLogout;

  const MoreScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เมนูเพิ่มเติม', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuTile(Icons.person_outline, 'แก้ไขโปรไฟล์', () {}),
          _buildMenuTile(Icons.history, 'ประวัติการจอง', () {}),
          _buildMenuTile(Icons.confirmation_number_outlined, 'คูปองของฉัน', () {}),
          
          const Divider(height: 32),

          // 2. จุดสำคัญ: ต้องใส่ onTap: onLogout เพื่อให้ปุ่มทำงาน
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'ออกจากระบบ', 
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
            ),
            onTap: onLogout, // <--- ตรวจสอบบรรทัดนี้ครับ ต้องมี onLogout ตรงนี้
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.red.withOpacity(0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.brown),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}