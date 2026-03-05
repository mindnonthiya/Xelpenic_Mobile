import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xelpenic/screens/notificationscreen.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _cinemasFuture;
  LatLng? _currentLocation;
  String? _locationErrorMessage;

  // ตัวแปรสำหรับแท็บ "สาขาทั้งหมด / สาขาที่ชอบ / ล่าสุด"
  int _selectedTopTab = 0; 

  // รายการฟิลเตอร์โรงหนัง (Mock data)
  final List<String> _filters = ['IMAX', 'Dolby Vision+Atmos', '4DX', 'Screen X', 'KIDS', 'LED'];

  @override
  void initState() {
    super.initState();
    _fetchCinemas();
    _loadCurrentLocation();
  }

  void _fetchCinemas() {
    // ดึงข้อมูลสาขาจากตาราง cinema
    _cinemasFuture = _supabase.from('cinema').select().order('cm_name');
  }

  Future<void> _loadCurrentLocation() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (!mounted) return;
      setState(() {
        _locationErrorMessage = 'กรุณาเปิด Location Service เพื่อดูแผนที่ใกล้คุณ';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _locationErrorMessage = 'ไม่ได้รับสิทธิ์เข้าถึงตำแหน่งปัจจุบัน';
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationErrorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'XELPENIC',
          style: TextStyle(
            color: Colors.brown,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline, color: Colors.brown),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
        ],
      ),
      // ใช้ SingleChildScrollView เพื่อให้เลื่อนดูได้ทั้งหน้า
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopTabs(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilterTags(),
              const SizedBox(height: 24),
              _buildNearbyMapCard(),
              const SizedBox(height: 24),
              // ใช้ FutureBuilder ดึงข้อมูลจากฐานข้อมูลมาแสดง
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _cinemasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
                  }
                  
                  final cinemas = snapshot.data ?? [];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Section: ใกล้เคียง ---
                      const Text(
                        'ใกล้เคียง',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // สมมติว่าดึง 2 สาขาแรกมาเป็นสาขาใกล้เคียง (ถ้ามีระบบ GPS ค่อยมาปรับแก้ทีหลัง)
                      if (cinemas.isNotEmpty)
                        ...cinemas.take(2).map((cinema) => _buildCinemaItem(cinema)),
                      
                      const SizedBox(height: 24),

                      // --- Section: สาขาทั้งหมด ---
                      const Text(
                        'สาขาทั้งหมด',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (cinemas.isEmpty)
                        const Text('ยังไม่มีข้อมูลสาขาในระบบ', style: TextStyle(color: Colors.grey)),
                      ...cinemas.map((cinema) => _buildCinemaItem(cinema)),
                      
                      const SizedBox(height: 80), // เว้นที่ว่างด้านล่างกันปุ่มเมนูทับ
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. แท็บด้านบน (สาขาทั้งหมด / สาขาที่ชอบ / ล่าสุด) ---
  Widget _buildTopTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFD4C1A0), // สีพื้นหลังรวม (น้ำตาลอ่อน)
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTabButton(title: 'สาขาทั้งหมด', index: 0),
          _buildTabButton(title: 'สาขาที่ชอบ', index: 1),
          _buildTabButton(title: 'ล่าสุด', index: 2),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isSelected = _selectedTopTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTopTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCBAE82) : Colors.transparent, // สีเข้มขึ้นเมื่อถูกเลือก
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. ช่องค้นหา ---
  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหา',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.filter_list, color: Colors.brown), // ไอคอนฟิลเตอร์
      ],
    );
  }

  // --- 3. แท็บฟิลเตอร์แนวนอน (IMAX, 4DX, ...) ---
  Widget _buildFilterTags() {
    return SizedBox(
      height: 20,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Text(
            _filters[index],
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline, // ขีดเส้นใต้ตามดีไซน์
            ),
          );
        },
      ),
    );
  }

  // --- 4. ไอเทมรายชื่อโรงหนัง 1 แถว ---
  Widget _buildNearbyMapCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'แผนที่ใกล้คุณ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: _currentLocation != null
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.xelpenic',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Text(
                        _locationErrorMessage ?? 'กำลังโหลดตำแหน่งปัจจุบัน...',
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinemaItem(Map<String, dynamic> cinema) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          // โลโก้ (ถ้ารูปใน DB ไม่มี จะแสดงตัว X แทน)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: cinema['cm_image_url'] != null
                ? Image.network(cinema['cm_image_url'], fit: BoxFit.cover)
                : const Center(
                    child: Text('X', style: TextStyle(color: Colors.brown, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
          ),
          const SizedBox(width: 12),
          // ชื่อสาขาและระยะทาง
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // ถ้าชื่อใน DB ว่าง ให้แสดงคำว่า XELPENIC ตามด้วยข้อความ default
                  cinema['cm_name'] != null ? 'XELPENIC ${cinema['cm_name']}' : 'XELPENIC สาขาไม่ระบุ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                // สมมติระยะทางไปก่อน เพราะใน DB ยังไม่มีข้อมูลพิกัดผู้ใช้
                const Text(
                  '5.33 กม.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // ปุ่มรูปดาว
          IconButton(
            icon: const Icon(Icons.star_border, color: Colors.brown),
            onPressed: () {
              // เพิ่ม Logic กดไลค์สาขาที่ชอบได้ที่นี่
            },
          ),
        ],
      ),
    );
  }
}
