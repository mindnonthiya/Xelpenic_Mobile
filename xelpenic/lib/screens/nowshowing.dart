import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NowShowingScreen extends StatefulWidget {
  const NowShowingScreen({super.key});

  @override
  State<NowShowingScreen> createState() => _NowShowingScreenState();
}

class _NowShowingScreenState extends State<NowShowingScreen> {

  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _nowShowingMoveis;

  final List<String> _categories = ['กำลังฉาย','IMAX','4DX','Atmos+','ScreenX','Kids'];
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
  }

  void _fetchMovies() {
    _nowShowingMoveis = _supabase.from('movies').select().eq('movie_showing', true).order('movie_release', ascending: false);
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
            onPressed: () => {},
          ),
        ],
      ),

    );
  }
}