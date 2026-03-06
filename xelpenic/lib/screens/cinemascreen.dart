import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xelpenic/screens/notificationscreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xelpenic/screens/cinema_branch_schedule_screen.dart';

class CinemaScreen extends StatefulWidget {
  const CinemaScreen({super.key});

  @override
  State<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends State<CinemaScreen> {
  final _supabase = Supabase.instance.client;

  Position? _currentPosition;
  List<Map<String, dynamic>> _cinemas = [];
  List<Map<String, dynamic>> _filteredCinemas = [];

  String _searchText = '';
  Set<int> _favoriteCinemas = {};
  final Set<String> _selectedFilters = {};

  int _selectedTopTab = 0;

  final List<String> _filters = [
    'IMAX',
    'Dolby Vision+Atmos',
    '4DX',
    'Screen X',
    'KIDS',
    'LED',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getLocation();
    await _fetchCinemas();
  }

  Future<void> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _fetchCinemas() async {
    final data = await _supabase.from('cinema').select().order('cm_name');

    _cinemas = List<Map<String, dynamic>>.from(data);
    _sortByDistance();
    _applyFilters();
  }

  void _sortByDistance() {
    if (_currentPosition == null) return;

    _cinemas.sort((a, b) {
      final distA = _calculateDistance(a);
      final distB = _calculateDistance(b);
      return distA.compareTo(distB);
    });
  }

  double _calculateDistance(Map<String, dynamic> cinema) {
    if (_currentPosition == null ||
        cinema['latitude'] == null ||
        cinema['longitude'] == null) {
      return 0;
    }

    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          cinema['latitude'],
          cinema['longitude'],
        ) /
        1000;
  }

  List<String> _extractCinemaFormats(Map<String, dynamic> cinema) {
    final dynamic rawFormats = cinema['formats'] ?? cinema['cm_formats'];
    if (rawFormats is List) {
      return rawFormats.map((item) => item.toString()).toList();
    }
    if (rawFormats is String) {
      return rawFormats
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool _matchesSelectedFormats(Map<String, dynamic> cinema) {
    if (_selectedFilters.isEmpty) return true;

    final cinemaFormats = _extractCinemaFormats(cinema);

    if (cinemaFormats.isEmpty) {
      return true;
    }

    return cinemaFormats.any(_selectedFilters.contains);
  }

  void _searchCinema(String text) {
    setState(() {
      _searchText = text.toLowerCase();
      _applyFilters();
    });
  }

  void _toggleFavorite(int cinemaId) {
    setState(() {
      if (_favoriteCinemas.contains(cinemaId)) {
        _favoriteCinemas.remove(cinemaId);
      } else {
        _favoriteCinemas.add(cinemaId);
      }
      _applyFilters();
    });
  }

  void _toggleFormatFilter(String filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
      _applyFilters();
    });
  }

  void _applyFilters() {
    final source = _selectedTopTab == 1
        ? _cinemas.where((c) => _favoriteCinemas.contains(c['cm_id'])).toList()
        : _cinemas;

    _filteredCinemas = source.where((cinema) {
      final name = cinema['cm_name'].toString().toLowerCase();
      final matchesSearch = name.contains(_searchText);
      final matchesFormat = _matchesSelectedFormats(cinema);
      return matchesSearch && matchesFormat;
    }).toList();
  }

  void _openMap({Map<String, dynamic>? focusCinema}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CinemaMapScreen(
          cinemas: _filteredCinemas,
          currentPosition: _currentPosition,
          focusCinema: focusCinema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedTopTab == 1 ? 'สาขาที่ชอบ' : 'รายการแนะนำ';

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
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _cinemas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopTabs(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFilterTags(),
                    const SizedBox(height: 16),
                    _buildMapLauncher(),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_filteredCinemas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('ยังไม่มีสาขาที่ตรงกับเงื่อนไขที่เลือก'),
                      )
                    else
                      ..._filteredCinemas.map((cinema) => _buildCinemaItem(cinema)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMapLauncher() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openMap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFE6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBAE82)),
        ),
        child: const Row(
          children: [
            Icon(Icons.map_outlined, color: Color(0xFF8B5E3C)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'เปิดแผนที่โรงหนัง',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8B5E3C)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFD4C1A0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTabButton('สาขาทั้งหมด', 0),
          _buildTabButton('สาขาที่ชอบ', 1),
          _buildTabButton('ล่าสุด', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTopTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTopTab = index;
            _applyFilters();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCBAE82) : Colors.transparent,
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
              onChanged: _searchCinema,
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
        const Icon(Icons.filter_list, color: Colors.brown),
      ],
    );
  }

  Widget _buildFilterTags() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final label = _filters[index];
          final isSelected = _selectedFilters.contains(label);

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _toggleFormatFilter(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCBAE82) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFCBAE82)
                      : Colors.brown.shade200,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCinemaItem(Map<String, dynamic> cinema) {
    final distance = _calculateDistance(cinema);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CinemaBranchScheduleScreen(cinema: cinema),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/x_logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XELPENIC ${cinema['cm_name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distance.toStringAsFixed(2)} กม.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: Colors.brown),
              onPressed: () => _openMap(focusCinema: cinema),
            ),
            IconButton(
              icon: Icon(
                _favoriteCinemas.contains(cinema['cm_id'])
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.brown,
              ),
              onPressed: () => _toggleFavorite(cinema['cm_id']),
            ),
          ],
        ),
      ),
    );
  }
}

class CinemaMapScreen extends StatefulWidget {
  const CinemaMapScreen({
    required this.cinemas,
    required this.currentPosition,
    this.focusCinema,
    super.key,
  });

  final List<Map<String, dynamic>> cinemas;
  final Position? currentPosition;
  final Map<String, dynamic>? focusCinema;

  @override
  State<CinemaMapScreen> createState() => _CinemaMapScreenState();
}

class _CinemaMapScreenState extends State<CinemaMapScreen> {
  final MapController _mapController = MapController();
  int? _selectedCinemaId;

  LatLng get _defaultCenter {
    final focus = widget.focusCinema;
    if (focus != null && focus['latitude'] != null && focus['longitude'] != null) {
      return LatLng(focus['latitude'], focus['longitude']);
    }
    if (widget.currentPosition != null) {
      return LatLng(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
      );
    }
    return const LatLng(13.736717, 100.523186);
  }

  @override
  void initState() {
    super.initState();
    _selectedCinemaId = widget.focusCinema?['cm_id'] as int?;
  }

  void _moveToCinema(Map<String, dynamic> cinema) {
    if (cinema['latitude'] == null || cinema['longitude'] == null) return;

    _mapController.move(
      LatLng(cinema['latitude'], cinema['longitude']),
      15,
    );

    setState(() {
      _selectedCinemaId = cinema['cm_id'] as int?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แผนที่โรงหนัง')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _defaultCenter, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(markers: _buildMapMarkers()),
              ],
            ),
          ),
          Container(
            height: 190,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รายการแนะนำ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.cinemas.length,
                    itemBuilder: (_, index) {
                      final cinema = widget.cinemas[index];
                      final cinemaId = cinema['cm_id'] as int?;
                      final selected = cinemaId != null && cinemaId == _selectedCinemaId;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                        leading: Icon(
                          Icons.location_on,
                          color: selected ? const Color(0xFFCBAE82) : Colors.grey,
                        ),
                        title: Text(cinema['cm_name']?.toString() ?? '-'),
                        onTap: () => _moveToCinema(cinema),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    if (widget.currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.red, size: 32),
        ),
      );
    }

    for (final cinema in widget.cinemas) {
      if (cinema['latitude'] == null || cinema['longitude'] == null) {
        continue;
      }

      final cinemaId = cinema['cm_id'] as int?;
      final selected = cinemaId != null && cinemaId == _selectedCinemaId;

      markers.add(
        Marker(
          width: 46,
          height: 46,
          point: LatLng(cinema['latitude'], cinema['longitude']),
          child: GestureDetector(
            onTap: () => _moveToCinema(cinema),
            child: Icon(
              Icons.location_on,
              color: selected ? const Color(0xFFCBAE82) : Colors.brown,
              size: selected ? 38 : 34,
            ),
          ),
        ),
      );
    }

    return markers;
  }
}
