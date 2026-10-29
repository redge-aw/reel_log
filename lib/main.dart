import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'reel_log_films';

// AW Design System tokens, resolved from Reel Log.html (HSL -> ARGB).
const _primary = Color(0xFF006B59);
const _primaryContainer = Color(0xFF5CFBD8);
const _onPrimaryContainer = Color(0xFF002019);
const _surface = Color(0xFFFCFCFF);
const _searchFill = Color(0xFFEDEEF1);
const _subtle = Color(0xFF76777A);
const _outline = Color(0xFF6F7975);
const _chipBorder = Color(0xFFBFC9C4);

// Poster tones cycle by film id, mirroring TONES[id % 5] in the prototype.
const _tones = [
  (0xFF5CFBD8, 0xFF002019), // primary-container
  (0xFF99F0FF, 0xFF001F24), // secondary-container
  (0xFFD3E4FF, 0xFF001C38), // tertiary-container
  (0xFF006B59, 0xFFFFFFFF), // primary
  (0xFF2E3134, 0xFFF0F0F4), // inverse-surface
];

class Film {
  const Film({
    required this.id,
    required this.title,
    required this.year,
    required this.director,
    required this.watched,
    required this.rating, // whole stars 1-5
    this.notes = '',
  });

  final int id;
  final String title;
  final int year;
  final String director;
  final DateTime watched;
  final int rating;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'director': director,
        'watched': watched.toIso8601String(),
        'rating': rating,
        'notes': notes,
      };

  static Film fromJson(Map<String, dynamic> j) => Film(
        id: (j['id'] ?? 0) as int,
        title: j['title'] as String,
        year: j['year'] as int,
        director: j['director'] as String,
        watched: DateTime.parse(j['watched'] as String),
        rating: j['rating'] as int,
        notes: (j['notes'] ?? '') as String,
      );

  String get initials {
    final words = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

// Seed copied from the prototype (ratings sum to 35 -> avg "4.4").
final _seed = [
  Film(
    id: 1,
    title: 'Past Lives',
    year: 2023,
    director: 'Celine Song',
    watched: DateTime(2026, 10, 24),
    rating: 5,
    notes:
        'The bar scene at the end is all in the silences. Rewatching with Maya next month.',
  ),
  Film(
    id: 2,
    title: 'Perfect Days',
    year: 2023,
    director: 'Wim Wenders',
    watched: DateTime(2026, 10, 11),
    rating: 4,
    notes: 'Slow in the best way. The cassette tapes do half the storytelling.',
  ),
  Film(
    id: 3,
    title: 'Dune: Part Two',
    year: 2024,
    director: 'Denis Villeneuve',
    watched: DateTime(2026, 9, 28),
    rating: 4,
  ),
  Film(
    id: 4,
    title: 'The Holdovers',
    year: 2023,
    director: 'Alexander Payne',
    watched: DateTime(2026, 9, 2),
    rating: 4,
    notes: 'Felt like a 1970 print. Da\'Vine Joy Randolph carries it.',
  ),
  Film(
    id: 5,
    title: 'Arrival',
    year: 2016,
    director: 'Denis Villeneuve',
    watched: DateTime(2026, 8, 15),
    rating: 5,
    notes: 'Third watch. The structure still lands.',
  ),
  Film(
    id: 6,
    title: 'Oppenheimer',
    year: 2023,
    director: 'Christopher Nolan',
    watched: DateTime(2026, 7, 30),
    rating: 3,
    notes: 'Great sound design, an hour too long.',
  ),
  Film(
    id: 7,
    title: 'Spirited Away',
    year: 2001,
    director: 'Hayao Miyazaki',
    watched: DateTime(2025, 12, 20),
    rating: 5,
  ),
  Film(
    id: 8,
    title: 'Parasite',
    year: 2019,
    director: 'Bong Joon-ho',
    watched: DateTime(2025, 11, 3),
    rating: 5,
    notes: 'Staircases everywhere once you notice them.',
  ),
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

enum _Filter { all, rated4Plus, withNotes, y2026 }

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reel Log',
      theme: ThemeData(
        scaffoldBackgroundColor: _surface,
        colorSchemeSeed: _primary,
        useMaterial3: true,
      ),
      home: const ReelLogHome(),
    );
  }
}

class ReelLogHome extends StatefulWidget {
  const ReelLogHome({super.key});

  @override
  State<ReelLogHome> createState() => _ReelLogHomeState();
}

class _ReelLogHomeState extends State<ReelLogHome> {
  List<Film> _films = List.of(_seed);
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _loadOrSeed();
  }

  Future<void> _loadOrSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      await prefs.setString(
          _prefsKey, jsonEncode(_seed.map((f) => f.toJson()).toList()));
      return; // seed already showing
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Film.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _films = list);
    } catch (_) {
      // corrupt prefs: keep seed showing
    }
  }

  List<Film> get _visible {
    final q = _query.trim().toLowerCase();
    final out = _films.where((f) {
      if (q.isNotEmpty &&
          !f.title.toLowerCase().contains(q) &&
          !f.director.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.rated4Plus:
          return f.rating >= 4;
        case _Filter.withNotes:
          return f.notes.trim().isNotEmpty;
        case _Filter.y2026:
          return f.watched.year == 2026;
      }
    }).toList();
    out.sort((a, b) => b.watched.compareTo(a.watched));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rated = _films.where((f) => f.rating > 0).toList();
    final avg = rated.isEmpty
        ? '–'
        : (rated.map((f) => f.rating).reduce((a, b) => a + b) / rated.length)
            .toStringAsFixed(1);
    final visible = _visible;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // visual only in demo scope
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        extendedIconLabelSpacing: 8,
        extendedPadding: const EdgeInsets.only(left: 16, right: 20),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Log a film',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REEL LOG',
                                style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                    color: _subtle,
                                    fontWeight: FontWeight.w500)),
                            Text('Watched',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      _Stat(value: '${_films.length}', label: 'films'),
                      const SizedBox(width: 16),
                      _Stat(value: avg, label: 'avg rating'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search your films',
                      prefixIcon:
                          Icon(Icons.search, size: 16, color: _subtle),
                      filled: true,
                      fillColor: _searchFill,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('All', _Filter.all),
                        const SizedBox(width: 8),
                        _chip('Rated 4+', _Filter.rated4Plus),
                        const SizedBox(width: 8),
                        _chip('With notes', _Filter.withNotes),
                        const SizedBox(width: 8),
                        _chip('2026', _Filter.y2026),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No films match'),
                          SizedBox(height: 4),
                          Text('Try another search or filter.',
                              style:
                                  TextStyle(fontSize: 14, color: _subtle)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.only(left: 8, right: 8, bottom: 96),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _row(visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? _onPrimaryContainer : null)),
      selected: selected,
      selectedColor: _primaryContainer,
      backgroundColor: Colors.transparent,
      side: BorderSide(
          color: selected ? Colors.transparent : _chipBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _row(Film f) {
    final tone = _tones[f.id % _tones.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 84,
            decoration: BoxDecoration(
              color: Color(tone.$1),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(6),
            alignment: Alignment.bottomLeft,
            child: Text(f.initials,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: Color(tone.$2))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${f.year} · ${f.director}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _subtle)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: i == 4 ? 0 : 2),
                        child: Icon(
                            i < f.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color:
                                i < f.rating ? _primary : _outline),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmtDate(f.watched),
                        style: const TextStyle(
                            fontSize: 12, color: _subtle)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _subtle),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 12, color: _subtle)),
      ],
    );
  }
}
