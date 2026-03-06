import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // สำหรับทำปุ่ม Copy
import 'package:supabase_flutter/supabase_flutter.dart';

class CoinScreen extends StatefulWidget {
  const CoinScreen({super.key});

  @override
  State<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends State<CoinScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  // จำลองข้อมูลผู้ใช้
  int _currentCoins = 0;
  String _profileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;
  bool _isProcessing = false; // ป้องกันการกดปุ่มซ้ำรัวๆ

  late final StreamSubscription<AuthState> _authStateSubscription;

  // จำลองแพ็กเกจเติมเงิน
  final List<Map<String, dynamic>> _topUpPackages = [
    {'coins': 50, 'price': 50},
    {'coins': 150, 'price': 150},
    {'coins': 250, 'price': 250},
    {'coins': 500, 'price': 500},
    {'coins': 750, 'price': 750},
    {'coins': 1000, 'price': 1000},
    {'coins': 1500, 'price': 1500},
    {'coins': 2000, 'price': 2000},
  ];

  // 💡 แพ็กเกจ XELPASS (ต้องตั้งค่า id ให้ตรงกับ items_id ใน Database ด้วยนะครับ)
  final List<Map<String, dynamic>> _xelpassPackages = [
    {
      'id': 991,
      'name': 'Student Pass',
      'cost': 1500,
      'desc':
          'สิทธิพิเศษดูหนังฟรี 1 ครั้ง/เรื่อง (ที่นั่ง Normal) พร้อมรับส่วนลดขนม 10%',
    },
    {
      'id': 992,
      'name': 'Standard Pass',
      'cost': 2500,
      'desc':
          'สิทธิพิเศษดูหนังฟรี 1 ครั้ง/เรื่อง (ที่นั่ง Normal) และส่วนลดป๊อปคอร์น 20%',
    },
    {
      'id': 993,
      'name': 'Premium Pass',
      'cost': 4000,
      'desc':
          'ดูหนังฟรีไม่จำกัดเรื่อง (สิทธิ์ 1 ครั้ง/เรื่อง) อัปเกรดที่นั่ง Honeymoon ฟรี',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchUserProfile();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) _fetchUserProfile();
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  void _fetchItems() {
    // 💡 สมมติว่าของรางวัลทั่วไปมี items_id น้อยกว่า 900
    _itemsFuture = _supabase.from('items').select().lt('items_id', 900);
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('customer_points, customer_avatar_url, customer_username')
            .eq('customer_ID', user.id)
            .single();

        setState(() {
          _currentCoins = response['customer_points'] ?? 0;
          _profileImageUrl =
              response['customer_avatar_url'] ??
              'https://i.pravatar.cc/150?img=47';
          _userName = response['customer_username'] ?? 'John Doe';
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _currentCoins = 0;
          _profileImageUrl = 'https://i.pravatar.cc/150?img=47';
          _userName = 'John Doe';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('==== ❌ Error Fetching Profile ====');
      print(e);
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _processTopUp(int coinsToAdd) async {
    try {
      final user = _supabase.auth.currentUser;
      final newTotalCoins = _currentCoins + coinsToAdd;

      if (user != null) {
        await _supabase
            .from('profiles')
            .update({'customer_points': newTotalCoins})
            .eq('customer_ID', user.id);
      }

      setState(() {
        _currentCoins = newTotalCoins;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เติมเงินสำเร็จ! ได้รับ $coinsToAdd Coins'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเติมเงิน'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 💡 ฟังก์ชันหลักสำหรับการแลกของรางวัลและ XELPASS
  Future<void> _processRedeem(int cost, int itemsId, String itemName) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // โชว์ Loading หน้าจอ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFDDAA55)),
      ),
    );

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("กรุณาเข้าสู่ระบบ");

      final newTotalCoins = _currentCoins - cost;

      // 1. หักเหรียญลงตาราง profiles
      await _supabase
          .from('profiles')
          .update({'customer_points': newTotalCoins})
          .eq('customer_ID', userId);

      // 2. บันทึกประวัติและสร้างโค้ดลง change_log
      final logResult = await _supabase
          .from('change_log')
          .insert({
            'chl_user_id': userId,
            'chl_items_id': itemsId,
            'chl_redeem': false, // สถานะยังไม่ใช้งาน
          })
          .select()
          .single();

      setState(() => _currentCoins = newTotalCoins);

      if (mounted) Navigator.pop(context); // ปิด Loading

      // 3. โชว์หน้าต่างรหัสโค้ด
      _showCodeDialog(itemName, logResult['chl_items_code'].toString());
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 💡 Dialog โชว์โค้ดที่สร้างสำเร็จ
  void _showCodeDialog(String itemName, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 60,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'แลก $itemName สำเร็จ!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'รหัส Redeem ของคุณคือ:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'คัดลอกรหัสนี้ไปกรอกในหน้า Redeem Code\nเพื่อรับสิทธิ์ได้ทันที',
              style: TextStyle(color: Colors.grey, fontSize: 10, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('คัดลอกรหัสแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'คัดลอกรหัส',
              style: TextStyle(color: Colors.brown),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDDAA55),
            ),
            child: const Text(
              'ปิด',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'COINS',
          style: TextStyle(
            color: Colors.brown,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
                const SizedBox(width: 4),
                _isLoadingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.brown,
                        ),
                      )
                    : Text(
                        '$_currentCoins',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _profileImageUrl.isNotEmpty
                      ? NetworkImage(_profileImageUrl)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: _profileImageUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(
                  _userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      // 💡 เปลี่ยนมาใช้ CustomScrollView เพื่อให้เลื่อนได้ทั้งหมดไม่ติดขัด
      body: RefreshIndicator(
        color: Colors.brown,
        onRefresh: () async {
          await _fetchUserProfile();
          setState(() => _fetchItems());
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTopUpBanner()),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 💡 ส่วน XELPASS Packages ด้านบน
                    const Text(
                      'อัปเกรด XELPASS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildXelpassSection(),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: Colors.black12),
                    ),

                    // 💡 ส่วนแลกของรางวัลทั่วไปด้านล่าง
                    const Text(
                      'แลกของรางวัลทั่วไป',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildItemsGrid(),
                    const SizedBox(height: 40), // เผื่อที่ว่างด้านล่าง
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4C1A0), Color(0xFFBCA67F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ยอดเหรียญคงเหลือ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  _isLoadingProfile
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '$_currentCoins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _showTopUpModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.brown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'เติมเงิน',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 Widget สำหรับแสดงแถวแนวนอน Xelpass
  Widget _buildXelpassSection() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _xelpassPackages.length,
        itemBuilder: (context, index) {
          final pass = _xelpassPackages[index];
          final bool canAfford = _currentCoins >= (pass['cost'] as int);

          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 16, bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414), // สีดำพรีเมียม
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: canAfford ? const Color(0xFFDDAA55) : Colors.white24,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDDAA55).withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: canAfford
                          ? const Color(0xFFDDAA55)
                          : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pass['name'],
                      style: TextStyle(
                        color: canAfford ? Colors.white : Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${pass['cost']} Coins',
                  style: TextStyle(
                    color: canAfford ? const Color(0xFFDDAA55) : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!canAfford)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'ต้องการอีก ${(pass['cost'] as int) - _currentCoins} Coins',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: ElevatedButton(
                    // กดแล้วจะเด้ง Bottom Sheet ขึ้นมาโชว์รายละเอียด
                    onPressed: () => _showXelpassDetailSheet(pass),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? const Color(0xFFDDAA55)
                          : Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'ดูรายละเอียด',
                      style: TextStyle(
                        color: canAfford ? Colors.black : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 💡 หน้าต่าง Bottom Sheet ของ XELPASS
  void _showXelpassDetailSheet(Map<String, dynamic> pass) {
    final cost = pass['cost'] as int;
    final bool canAfford = _currentCoins >= cost;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414), // ธีมดำพรีเมียม
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDDAA55).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFFDDAA55),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFDDAA55),
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  pass['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFDDAA55),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$cost Coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDDAA55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'รายละเอียดแพ็กเกจ:',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pass['desc'] ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canAfford
                      ? () {
                          Navigator.pop(context);
                          _processRedeem(
                            cost,
                            pass['id'],
                            pass['name'],
                          ); // เรียกฟังก์ชันหักเหรียญ
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDDAA55),
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    canAfford ? 'แลกรับสิทธิ์ XELPASS' : 'Coins ไม่เพียงพอ',
                    style: TextStyle(
                      color: canAfford ? Colors.black : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- Grid แสดงรายการของที่ใช้เหรียญแลกได้ ---
  Widget _buildItemsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));

        final items = snapshot.data ?? [];
        if (items.isEmpty)
          return const Center(child: Text('ไม่มีของรางวัลในขณะนี้'));

        return GridView.builder(
          physics:
              const NeverScrollableScrollPhysics(), // ปิด scroll ตัวมันเอง ให้เลื่อนไปกับจอใหญ่
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final int cost = item['items_cost'] as int? ?? 0;
    final bool canAfford = _currentCoins >= cost;

    return GestureDetector(
      // 💡 กดแล้วเด้ง Bottom Sheet ของรางวัลทั่วไป
      onTap: () => _showItemDetailSheet(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: canAfford
                ? const Color(0xFFDDAA55).withOpacity(0.5)
                : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  item['items_url'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade100,
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['items_name'] ?? 'ไม่มีชื่อ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: canAfford
                            ? const Color(0xFFD4AF37)
                            : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$cost',
                        style: TextStyle(
                          color: canAfford ? Colors.brown : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 หน้าต่าง Bottom Sheet ของรางวัลทั่วไป
  void _showItemDetailSheet(Map<String, dynamic> item) {
    final int cost = item['items_cost'] as int? ?? 0;
    final bool canAfford = _currentCoins >= cost;
    final String imageUrl = item['items_url'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: Colors.grey.shade100,
                            child: const Icon(
                              Icons.image,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFFF0E8D8),
                          child: const Icon(
                            Icons.card_giftcard,
                            size: 60,
                            color: Color(0xFFDDAA55),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                item['items_name'] ?? 'ไม่มีชื่อ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFDDAA55),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$cost Coins',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDDAA55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'รายละเอียดของรางวัล:',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (item['items_des'] != null &&
                        item['items_des'].toString().isNotEmpty)
                    ? item['items_des']
                    : 'นำรหัสที่ได้ไปแสดงเพื่อรับสิทธิ์ที่หน้าเคาน์เตอร์ XELPENIC',
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canAfford
                      ? () {
                          Navigator.pop(context);
                          _processRedeem(
                            cost,
                            item['items_id'],
                            item['items_name'] ?? 'ของรางวัล',
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    canAfford ? 'แลกของรางวัล' : 'Coins ไม่เพียงพอ',
                    style: TextStyle(
                      color: canAfford ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- หน้าต่าง (Bottom Sheet) สำหรับเลือกแพ็กเกจเติมเงิน ---
  void _showTopUpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'เลือกแพ็กเกจเติมเหรียญ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _topUpPackages.length,
                  itemBuilder: (context, index) {
                    final pkg = _topUpPackages[index];
                    return _buildPackageCard(pkg);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _processTopUp(pkg['coins']);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue.shade100, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${pkg['coins']} Coins',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '฿${pkg['price']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
