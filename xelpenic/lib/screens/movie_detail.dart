import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // สำหรับจัดการรูปแบบวันที่และเวลา

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late YoutubePlayerController _controller;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // 1. จัดการตัวเล่นวิดีโอ (เทคนิคพิเศษข้อ 3.3)
    final trailerUrl = widget.movie['movie_trailer'] ?? "";
    final videoId = YoutubePlayer.convertUrlToId(trailerUrl);
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  // 2. ฟังก์ชันดึงสาขาและรอบฉาย (Nested Query)
  Future<List<Map<String, dynamic>>> _getShowtimes() async {
    final data = await _supabase
        .from('cinema')
        .select('*, showtime!inner(*)') // ดึงสาขาที่มีรอบฉายของหนังเรื่องนี้เท่านั้น
        .eq('showtime.st_movie_id', widget.movie['movie_id']);
    
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ส่วน Banner วิดีโอ
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.brown,
            flexibleSpace: FlexibleSpaceBar(
              background: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อเรื่องและประเภท
                  Text(
                    widget.movie['movie_title'] ?? 'Title',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${widget.movie['movie_genre'] ?? ''} • ${widget.movie['movie_duration'] ?? '0'} นาที",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // เรื่องย่อ (ข้อ 2.3 ความสมบูรณ์)
                  const Text("เรื่องย่อ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    widget.movie['movie_desc'] ?? 'ไม่มีข้อมูลเนื้อเรื่อง',
                    style: const TextStyle(color: Colors.black87, height: 1.5),
                  ),
                  
                  const Divider(height: 40),
                  
                  // ส่วนแสดงสาขาและรอบฉายตามดีไซน์ (ภาพที่ 5)
                  const Text(
                    "เลือกรอบฉาย", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)
                  ),
                  const SizedBox(height: 10),
                  
                  _buildCinemaList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Widget รายการสาขาโรงหนัง (ExpansionTile เพื่อทำปุ่ม V)
  Widget _buildCinemaList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getShowtimes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.brown));
        }
        
        final cinemas = snapshot.data ?? [];
        if (cinemas.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text("ไม่มีรอบฉายสำหรับภาพยนตร์เรื่องนี้ในขณะนี้", style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cinemas.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final cinema = cinemas[index];
            final List showtimes = cinema['showtime'];

            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CachedNetworkImage(
                  imageUrl: cinema['cm_image_url'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.theaters, color: Colors.brown),
                ),
              ),
              title: Text(
                cinema['cm_name'] ?? 'XELPENIC สาขา',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text("5.33 กม.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.brown),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 15, top: 5),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: showtimes.map((st) {
                      // จัดรูปแบบเวลา
                      DateTime time = DateTime.parse(st['st_time']);
                      String formattedTime = DateFormat('HH:mm').format(time);

                      return ActionChip(
                        label: Text(formattedTime),
                        onPressed: () {
                          // TODO: ไปหน้าเลือกที่นั่ง (Seat Selection) พร้อมส่ง st_id ไป
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เลือกสาขา ${cinema['cm_name']} รอบ $formattedTime'))
                          );
                        },
                        backgroundColor: Colors.brown.shade50,
                        side: BorderSide(color: Colors.brown.shade200),
                        labelStyle: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}