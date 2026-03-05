import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late YoutubePlayerController _controller;
  final _supabase = Supabase.instance.client;
  
  // กำหนดสีทองหลักของแอปไว้เรียกใช้
  final Color goldColor = const Color(0xFFDDAA55);

  @override
  void initState() {
    super.initState();
    final trailerUrl = widget.movie['movie_trailer'] ?? "";
    final videoId = YoutubePlayer.convertUrlToId(trailerUrl);

    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  Future<List<Map<String, dynamic>>> _getShowtimes() async {
    final data = await _supabase
        .from('cinema')
        .select('*, showtime!inner(*, theater(*))')
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
      backgroundColor: const Color(0xFFFDFBF7), // สีขาวอมครีมนิดๆ ให้ดูหรูหรา
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.black, // เปลี่ยนพื้นหลังวิดีโอเป็นสีดำให้ดูดุดัน
            iconTheme: const IconThemeData(color: Color(0xFFDDAA55)), // ปุ่ม Back สีทอง
            flexibleSpace: FlexibleSpaceBar(
              background: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressColors: ProgressBarColors(
                  playedColor: goldColor, // หลอดวิดีโอสีทอง
                  handleColor: goldColor,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.movie['movie_title'] ?? 'ไม่ทราบชื่อภาพยนตร์',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${widget.movie['movie_genre'] ?? ''} • ${widget.movie['movie_duration'] ?? '0'} นาที",
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "เรื่องย่อ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie['movie_desc'] ?? 'ไม่มีข้อมูลเนื้อเรื่อง',
                    style: const TextStyle(color: Colors.black87, height: 1.6),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.black12),
                  ),

                  Row(
                    children: [
                      Icon(Icons.location_on, color: goldColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "เลือกรอบฉาย",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: goldColor, // หัวข้อสีทอง
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _buildCinemaList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getShowtimes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: goldColor),
            ),
          );
        }

        final cinemas = snapshot.data ?? [];
        if (cinemas.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "ไม่มีรอบฉายสำหรับภาพยนตร์เรื่องนี้ในขณะนี้",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cinemas.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cinema = cinemas[index];
            final List showtimes = cinema['showtime'];

            Map<String, List<dynamic>> groupedShowtimes = {};
            for (var st in showtimes) {
              String theaterName = st['theater']?['tt_name'] ?? 'โรงภาพยนตร์ทั่วไป'; // แก้กลับเป็น theator ตามตารางของแพทนะครับ
              if (!groupedShowtimes.containsKey(theaterName)) {
                groupedShowtimes[theaterName] = [];
              }
              groupedShowtimes[theaterName]!.add(st);
            }

            return Card(
              elevation: 4, // เพิ่มเงาให้ดูมีมิติ
              shadowColor: goldColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: goldColor.withOpacity(0.3), width: 1), // ขอบสีทองอ่อนๆ
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                collapsedIconColor: goldColor,
                iconColor: goldColor,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: goldColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: cinema['cm_image_url'] ?? '',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(
                        Icons.theaters,
                        color: goldColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  cinema['cm_name'] ?? 'XELPENIC สาขา',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  "5.33 กม.",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: groupedShowtimes.entries.map((entry) {
                        String theaterName = entry.key;
                        List<dynamic> timesInThisTheater = entry.value;

                        timesInThisTheater.sort((a, b) =>
                            DateTime.parse(a['st_time']).compareTo(DateTime.parse(b['st_time'])));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    theaterName.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('|', style: TextStyle(color: Colors.black26)),
                                  ),
                                  
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: goldColor, // ป้าย 2D สีทอง
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ทั่วไป',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: timesInThisTheater.map((st) {
                                  DateTime time = DateTime.parse(st['st_time']);
                                  String formattedTime = DateFormat('HH:mm').format(time);

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.black87,
                                          content: Text(
                                            'เลือก $theaterName รอบ $formattedTime น.',
                                            style: TextStyle(color: goldColor),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: goldColor, width: 1.5), // กรอบปุ่มเวลาสีทอง
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: goldColor.withOpacity(0.15),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      ),
                                      child: Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: goldColor,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              const Divider(color: Colors.black12),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}