import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // สร้าง Instance สำหรับเรียกใช้ Supabase
  final _supabase = Supabase.instance.client;

  // สร้างตัวแปรเก็บ Future ของข้อมูลแต่ละส่วน
  late Future<List<Map<String, dynamic>>> _nowShowingMovies;
  late Future<List<Map<String, dynamic>>> _comingSoonMovies;
  late Future<List<Map<String, dynamic>>> _redeemItems;

  @override
  void initState() {
    super.initState();
    // สั่งดึงข้อมูลตั้งแต่ตอนที่หน้านี้ถูกสร้างขึ้นมา
    _fetchData();
  }

  void _fetchData() {
    // 1. ดึงหนังที่กำลังฉาย (movie_showing = true)
    _nowShowingMovies = _supabase
        .from('movies')
        .select()
        .eq('movie_showing', true)
        .order('movie_release', ascending: false)
        .then((data) {
          return data;
        })
        .catchError((error) {
          print('==== ❌ Error หนังกำลังฉาย ====');
          print(error); // ปริ้นท์แจ้งเตือนถ้ามีปัญหา (เช่น ติด RLS)
          throw error;
        });

    // 2. ดึงโปรแกรมหน้า (movie_showing = false) ดึงมาแค่เรื่องเดียวตามดีไซน์
    _comingSoonMovies = _supabase
        .from('movies')
        .select()
        .eq('movie_showing', false)
        .then((data) {
          return data;
        })
        .catchError((error) {
          throw error;
        });

    // 3. ดึงรายการของสะสม
    _redeemItems = _supabase
        .from('items')
        .select()
        .then((data) {
          return data;
        })
        .catchError((error) {
          throw error;
        });
  }

  Widget _buildComingSoonSection() {
    return SizedBox(
      height: 280, // กำหนดความสูงให้พอดีกับรูปและตัวหนังสือ
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _comingSoonMovies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final movies = snapshot.data ?? [];
          if (movies.isEmpty) {
            return const Center(child: Text('ยังไม่มีโปรแกรมหน้า'));
          }

          // เปลี่ยนมาใช้ ListView.builder เพื่อให้เลื่อนซ้าย-ขวาได้
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Container(
                width: 140, // ปรับความกว้างให้เท่ากับหมวดกำลังฉาย
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          movie['movie_post'] ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie['movie_title'] ?? 'ไม่ทราบชื่อเรื่อง',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- ส่วน Profile ---
  Widget _buildProfileSection() {
    // ตอนนี้ให้แสดงเป็น Guest ไปก่อน ถ้าระบบ Auth เสร็จค่อยมาใส่ FutureBuilder เช็ค User
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.brown.shade800,
      child: const Center(
        child: Text(
          'Profile Section\n(รอเชื่อมต่อระบบ Login)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // --- ส่วน หนังกำลังฉาย ---
  Widget _buildHorizontalMovieList() {
    return SizedBox(
      height: 280, // เพิ่มความสูงนิดหน่อยเผื่อแสดงชื่อหนัง
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _nowShowingMovies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }
          final movies = snapshot.data ?? [];
          if (movies.isEmpty) {
            return const Center(child: Text('ไม่มีภาพยนตร์กำลังฉาย'));
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // แสดงรูปภาพจาก URL ที่เก็บใน DB (movie_post)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          movie['movie_post'] ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image_not_supported),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie['movie_title'] ?? 'ไม่ทราบชื่อเรื่อง',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Banner Section
            _buildProfileSection(),

            // 2. Now Showing Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'กำลังฉาย',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
            ),
            _buildHorizontalMovieList(),

            // 3. Coming Soon Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'โปรแกรมหน้า',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
            ),
            _buildComingSoonSection(),

            // 4. Promotions & Redeem Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'โปรโมชั่น แลกของสะสม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
            ),
            _buildHorizontalItemList(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- ส่วน ของสะสม (Items) ---
  Widget _buildHorizontalItemList() {
    return SizedBox(
      height:
          190, // เพิ่มความสูงจาก 150 เป็น 190 ให้มีพื้นที่วางข้อความและไอคอนไม่ให้ล้น
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _redeemItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่มีของสะสมในขณะนี้'));
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 140, // ปรับความกว้างให้เท่ากับปกหนัง
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. รูปภาพของสะสม
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          12,
                        ), // ปรับมุมให้โค้งมนขึ้นนิดนึงตามดีไซน์
                        child: Image.network(
                          item['items_url'] ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.shopping_bag),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. ชื่อไอเทม
                    Text(
                      item['items_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 3. ไอคอนและราคา (สีทอง)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons
                              .cancel, // ใช้ไอคอนนี้เพราะหน้าตาคล้ายเหรียญตัว X ในดีไซน์ที่สุดครับ
                          size: 16,
                          color: Color(
                            0xFFDDAA55,
                          ), // สีทอง/เหลืองหม่นๆ แบบในดีไซน์
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item['items_cost'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFDDAA55), // สีเดียวกับไอคอน
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
