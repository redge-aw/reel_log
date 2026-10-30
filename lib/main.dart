import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const _ink = Color(0xFF151C23);
const _fieldBorder = Color(0xFFDBE5E0);
const _cardSurface = Color(0xFFF3F3F6);
const _sheetHandle = Color(0xFFC6C6C9);

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
    this.year,
    required this.watchedYear,
    required this.rating, // 0 = unrated, else whole stars 1-5
    this.notes,
  });

  final int id;
  final String title;
  final int? year;
  final int watchedYear;
  final int rating;
  final String? notes;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'title': title,
      'watched': watchedYear,
      'rating': rating,
    };
    if (year != null) m['year'] = year;
    if (notes != null && notes!.trim().isNotEmpty) m['notes'] = notes;
    return m;
  }

  static Film fromJson(Map<String, dynamic> j) {
    final w = j['watched'];
    return Film(
      id: (j['id'] ?? 0) as int,
      title: j['title'] as String,
      year: j['year'] as int?,
      watchedYear: w is int ? w : DateTime.parse(w as String).year,
      rating: (j['rating'] ?? 0) as int,
      notes: j['notes'] as String?,
    );
  }

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

// Demo seed.
final _seed = [
  Film(
    id: 3,
    title: 'Dune: Part Two',
    year: 2024,
    watchedYear: 2026,
    rating: 4,
  ),
  Film(
    id: 5,
    title: 'Arrival',
    year: 2016,
    watchedYear: 2026,
    rating: 5,
    notes: 'Third watch. The structure still lands.',
  ),
  Film(
    id: 6,
    title: 'Oppenheimer',
    year: 2023,
    watchedYear: 2026,
    rating: 3,
    notes: 'Great sound design, an hour too long.',
  ),
  Film(
    id: 7,
    title: 'Spirited Away',
    year: 2001,
    watchedYear: 2025,
    rating: 5,
  ),
  Film(
    id: 8,
    title: 'Parasite',
    year: 2019,
    watchedYear: 2025,
    rating: 5,
    notes: 'Staircases everywhere once you notice them.',
  ),
];

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
  late final Future<void> _loadDone;

  /// Serializes full-list writes (log-sheet saves and detail edits) so
  /// concurrent saves can never interleave or clobber one another.
  Future<void> _writeChain = Future.value();

  /// Runs [op] after the initial load and all previously queued writes.
  /// A failed op does not break the chain for later writes.
  Future<void> _enqueueWrite(Future<void> Function() op) {
    final run = _writeChain.then((_) => _loadDone).then((_) => op());
    _writeChain = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  void initState() {
    super.initState();
    _loadDone = _loadOrSeed();
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
      if (q.isNotEmpty && !f.title.toLowerCase().contains(q)) return false;
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.rated4Plus:
          return f.rating >= 4;
        case _Filter.withNotes:
          return f.notes?.trim().isNotEmpty ?? false;
        case _Filter.y2026:
          return f.watchedYear == 2026;
      }
    }).toList();
    out.sort((a, b) => b.watchedYear.compareTo(a.watchedYear));
    return out;
  }

  void _openLogSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 300), curve: Curves.easeOut),
      builder: (ctx) => _LogSheet(onSave: _saveDraft),
    );
  }

  /// Appends the draft, writes the full list, then closes the sheet and
  /// confirms. Throws after rolling back when the write fails, so the sheet
  /// can stay open with the draft intact for a retry.
  Future<void> _saveDraft(_Draft d) async {
    Film? added;
    try {
      await _enqueueWrite(() async {
        var id = DateTime.now().microsecondsSinceEpoch;
        while (_films.any((f) => f.id == id)) {
          id++;
        }
        added = Film(
            id: id,
            title: d.title,
            year: d.year,
            watchedYear: d.watchedYear,
            rating: d.rating,
            notes: d.notes);
        final prev = _films;
        setState(() => _films = [..._films, added!]);
        try {
          final store = await SharedPreferences.getInstance();
          await store.setString(
              _prefsKey, jsonEncode(_films.map((f) => f.toJson()).toList()));
        } catch (_) {
          if (mounted) {
            setState(() => _films = prev);
          }
          rethrow;
        }
      });
    } catch (_) {
      rethrow;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${d.title}"')));
  }

  /// Replaces the film with [updated.id], writes the full list, and refreshes
  /// the list. Throws after rolling back when the write fails.
  Future<void> _updateFilm(Film updated) {
    return _enqueueWrite(() async {
      final prev = _films;
      setState(() => _films = [
            for (final f in _films) f.id == updated.id ? updated : f
          ]);
      try {
        final store = await SharedPreferences.getInstance();
        await store.setString(
            _prefsKey, jsonEncode(_films.map((f) => f.toJson()).toList()));
      } catch (_) {
        if (mounted) {
          setState(() => _films = prev);
        }
        rethrow;
      }
    });
  }

  void _openDetail(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FilmDetailScreen(
          filmId: id,
          ensureLoaded: () => _loadDone,
          loadFilm: (fid) {
            try {
              return _films.firstWhere((f) => f.id == fid);
            } catch (_) {
              return null;
            }
          },
          updateFilm: _updateFilm,
          onMissingFilm: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Film not found.')));
          },
        ),
      ),
    );
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
        onPressed: _openLogSheet,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetail(f.id),
      child: Padding(
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
                if (f.year != null)
                  Text('${f.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: _subtle)),
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
                    Text('${f.watchedYear}',
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

/// A validated new-film draft: title and notes trimmed, blank notes as null.
class _Draft {
  const _Draft({
    required this.title,
    required this.year,
    required this.watchedYear,
    required this.rating,
    required this.notes,
  });

  final String title;
  final int? year;
  final int watchedYear;
  final int rating; // 0 = unrated
  final String? notes;
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.onSave});

  final Future<void> Function(_Draft draft) onSave;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final _title = TextEditingController();
  final _releaseYear = TextEditingController();
  late final _watchedYear =
      TextEditingController(text: '${DateTime.now().year}');
  final _notes = TextEditingController();
  int _rating = 0;
  bool _titleTouched = false;
  bool _saving = false;
  String? _releaseYearError;
  String? _watchedYearError;
  String? _saveError;

  @override
  void dispose() {
    _title.dispose();
    _releaseYear.dispose();
    _watchedYear.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleTouched = true);
      return;
    }
    final release = _releaseYear.text;
    final watched = _watchedYear.text;
    setState(() {
      _releaseYearError =
          release.isNotEmpty && release.length != 4
              ? 'Enter a 4-digit year.'
              : null;
      _watchedYearError =
          watched.length != 4 ? 'Enter a 4-digit year.' : null;
      _saveError = null;
    });
    if (_releaseYearError != null || _watchedYearError != null) return;
    final notes = _notes.text.trim();
    setState(() => _saving = true);
    try {
      await widget.onSave(_Draft(
        title: title,
        year: release.isEmpty ? null : int.parse(release),
        watchedYear: int.parse(watched),
        rating: _rating,
        notes: notes.isEmpty ? null : notes,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Couldn\'t save "$title". Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _sheetHandle,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              const Text('Log a film',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                key: const Key('logClose'),
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          const SizedBox(height: 16),
          _label('Title'),
          TextField(
            key: const Key('logTitle'),
            controller: _title,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 15),
            decoration: _field(hint: 'e.g. Aftersun').copyWith(
              errorText: _titleTouched && _title.text.trim().isEmpty
                  ? 'Enter a title.'
                  : null,
            ),
            onChanged: (_) => setState(() => _titleTouched = true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Release year'),
                    TextField(
                      key: const Key('logReleaseYear'),
                      controller: _releaseYear,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: _field(
                          hint: '2022', error: _releaseYearError),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Watched year'),
                    TextField(
                      key: const Key('logWatchedYear'),
                      controller: _watchedYear,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 15),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration:
                          _field(error: _watchedYearError),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Rating'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) const SizedBox(width: 4),
                IconButton(
                  tooltip: '$i of 5',
                  iconSize: 28,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  icon: Icon(i <= _rating ? Icons.star : Icons.star_border,
                      color: i <= _rating ? _primary : _outline),
                  onPressed: () =>
                      setState(() => _rating = _rating == i ? 0 : i),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            const TextSpan(
              text: 'Notes ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _ink),
              children: [
                TextSpan(
                    text: '(optional)',
                    style: TextStyle(fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('logNotes'),
            controller: _notes,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, height: 1.45),
            decoration: _field(hint: 'What stayed with you?').copyWith(
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 8),
            Text(_saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _primary.withValues(alpha: 0.38),
                  disabledForegroundColor:
                      Colors.white.withValues(alpha: 0.7),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: _canSave ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
    );

InputDecoration _field({String? hint, String? error}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 15, color: _subtle),
      errorText: error,
      errorStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: _surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _fieldBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _fieldBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5)),
    );

/// Film detail screen: header with inline title/year inputs, a sticky
/// tap-to-save rating card, an inline watched-year input, and debounced
/// autosaving notes. All writes go through [updateFilm], which serializes
/// them in `_ReelLogHomeState` and throws on failure.
class _FilmDetailScreen extends StatefulWidget {
  const _FilmDetailScreen({
    required this.filmId,
    required this.ensureLoaded,
    required this.loadFilm,
    required this.updateFilm,
    required this.onMissingFilm,
  });

  final int filmId;
  final Future<void> Function() ensureLoaded;
  final Film? Function(int id) loadFilm;
  final Future<void> Function(Film film) updateFilm;
  final void Function() onMissingFilm;

  @override
  State<_FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<_FilmDetailScreen> {
  Film? _film; // last persisted film; null while resolving
  int _rating = 0; // displayed rating

  final _title = TextEditingController();
  final _releaseYear = TextEditingController();
  final _watchedYear = TextEditingController();
  final _notes = TextEditingController();
  final _titleFocus = FocusNode();
  final _releaseFocus = FocusNode();
  final _watchedFocus = FocusNode();

  bool _titleDirty = false;
  bool _releaseDirty = false;
  bool _watchedDirty = false;
  bool _notesDirty = false;

  String? _titleError;
  String? _releaseYearError;
  String? _watchedYearError;
  String? _saveError;

  Timer? _notesTimer;
  bool _savingNotes = false;
  bool _backBusy = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onTitleFocusChange);
    _releaseFocus.addListener(_onReleaseFocusChange);
    _watchedFocus.addListener(_onWatchedFocusChange);
    widget.ensureLoaded().then((_) {
      if (!mounted) return;
      final film = widget.loadFilm(widget.filmId);
      if (film == null) {
        widget.onMissingFilm();
        return;
      }
      setState(() {
        _film = film;
        _rating = film.rating;
        _title.text = film.title;
        _releaseYear.text = film.year?.toString() ?? '';
        _watchedYear.text = '${film.watchedYear}';
        _notes.text = film.notes ?? '';
      });
    });
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    _titleFocus.removeListener(_onTitleFocusChange);
    _releaseFocus.removeListener(_onReleaseFocusChange);
    _watchedFocus.removeListener(_onWatchedFocusChange);
    _title.dispose();
    _releaseYear.dispose();
    _watchedYear.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _releaseFocus.dispose();
    _watchedFocus.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) unawaited(_commitTitle());
  }

  void _onReleaseFocusChange() {
    if (!_releaseFocus.hasFocus) unawaited(_commitReleaseYear());
  }

  void _onWatchedFocusChange() {
    if (!_watchedFocus.hasFocus) unawaited(_commitWatchedYear());
  }

  void _onTitleChanged(String v) {
    setState(() {
      _titleDirty = true;
      if (_titleError != null && v.trim().isNotEmpty) _titleError = null;
    });
  }

  void _onReleaseYearChanged(String v) {
    setState(() {
      _releaseDirty = true;
      if (_releaseYearError != null && (v.isEmpty || v.length == 4)) {
        _releaseYearError = null;
      }
    });
  }

  void _onWatchedYearChanged(String v) {
    setState(() {
      _watchedDirty = true;
      if (_watchedYearError != null && v.length == 4) {
        _watchedYearError = null;
      }
    });
  }

  void _onNotesChanged(String _) {
    setState(() => _notesDirty = true);
    _notesTimer?.cancel();
    _notesTimer = Timer(
        const Duration(milliseconds: 500), () => unawaited(_commitNotes()));
  }

  /// Writes [updated] through the home queue. Shows the save-failure copy
  /// and returns false when the write throws.
  Future<bool> _persist(Film updated) async {
    setState(() => _saveError = null);
    try {
      await widget.updateFilm(updated);
    } catch (_) {
      if (!mounted) return false;
      setState(() => _saveError = "Couldn't save. Try again.");
      return false;
    }
    if (!mounted) return false;
    return true;
  }

  /// Sticky rating: any tap sets that rating and writes immediately.
  Future<void> _rate(int stars) async {
    final film = _film;
    if (film == null || stars == _rating) return;
    final prev = _rating;
    setState(() => _rating = stars);
    final updated = Film(
        id: film.id,
        title: film.title,
        year: film.year,
        watchedYear: film.watchedYear,
        rating: stars,
        notes: film.notes);
    try {
      await widget.updateFilm(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rating = prev;
        _saveError = "Couldn't save. Try again.";
      });
      return;
    }
    if (!mounted) return;
    setState(() => _film = updated);
  }

  Future<bool> _commitTitle() async {
    final film = _film;
    if (!mounted || film == null) return false;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a title.');
      return false;
    }
    if (title == film.title) {
      setState(() {
        _titleError = null;
        _titleDirty = false;
      });
      return true;
    }
    final updated = Film(
        id: film.id,
        title: title,
        year: film.year,
        watchedYear: film.watchedYear,
        rating: _rating,
        notes: film.notes);
    final ok = await _persist(updated);
    if (!mounted) return false;
    if (ok) {
      setState(() {
        _film = updated;
        _titleDirty = false;
        _titleError = null;
      });
    }
    return ok;
  }

  Future<bool> _commitReleaseYear() async {
    final film = _film;
    if (!mounted || film == null) return false;
    final raw = _releaseYear.text;
    if (raw.isNotEmpty && raw.length != 4) {
      setState(() => _releaseYearError = 'Enter a 4-digit year.');
      return false;
    }
    final year = raw.isEmpty ? null : int.parse(raw);
    if (year == film.year) {
      setState(() {
        _releaseYearError = null;
        _releaseDirty = false;
      });
      return true;
    }
    final updated = Film(
        id: film.id,
        title: film.title,
        year: year,
        watchedYear: film.watchedYear,
        rating: _rating,
        notes: film.notes);
    final ok = await _persist(updated);
    if (!mounted) return false;
    if (ok) {
      setState(() {
        _film = updated;
        _releaseDirty = false;
        _releaseYearError = null;
      });
    }
    return ok;
  }

  Future<bool> _commitWatchedYear() async {
    final film = _film;
    if (!mounted || film == null) return false;
    final raw = _watchedYear.text;
    if (raw.length != 4) {
      setState(() => _watchedYearError = 'Enter a 4-digit year.');
      return false;
    }
    final watchedYear = int.parse(raw);
    if (watchedYear == film.watchedYear) {
      setState(() {
        _watchedYearError = null;
        _watchedDirty = false;
      });
      return true;
    }
    final updated = Film(
        id: film.id,
        title: film.title,
        year: film.year,
        watchedYear: watchedYear,
        rating: _rating,
        notes: film.notes);
    final ok = await _persist(updated);
    if (!mounted) return false;
    if (ok) {
      setState(() {
        _film = updated;
        _watchedDirty = false;
        _watchedYearError = null;
      });
    }
    return ok;
  }

  Future<bool> _commitNotes() async {
    final film = _film;
    if (!mounted || film == null) return false;
    _notesTimer?.cancel();
    final trimmed = _notes.text.trim();
    final notes = trimmed.isEmpty ? null : trimmed;
    final current = film.notes?.trim();
    if ((notes ?? '') == (current ?? '')) {
      setState(() => _notesDirty = false);
      return true;
    }
    setState(() => _savingNotes = true);
    final updated = Film(
        id: film.id,
        title: film.title,
        year: film.year,
        watchedYear: film.watchedYear,
        rating: _rating,
        notes: notes);
    final ok = await _persist(updated);
    if (!mounted) return false;
    setState(() {
      _savingNotes = false;
      if (ok) {
        _film = updated;
        _notesDirty = false;
      }
    });
    return ok;
  }

  /// Commits dirty fields, awaits pending writes, and pops on success.
  /// Stays on the detail screen when validation or a write fails.
  Future<void> _handleBack() async {
    if (_backBusy) return;
    if (!mounted || _film == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _backBusy = true;
    try {
      _notesTimer?.cancel();
      var ok = true;
      if (_titleDirty) ok = await _commitTitle() && ok;
      if (_releaseDirty) ok = await _commitReleaseYear() && ok;
      if (_watchedDirty) ok = await _commitWatchedYear() && ok;
      if (_notesDirty) ok = await _commitNotes() && ok;
      if (ok && mounted) Navigator.of(context).pop();
    } finally {
      _backBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final film = _film;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: film == null
              ? const Center(child: CircularProgressIndicator())
              : _body(film),
        ),
      ),
    );
  }

  Widget _body(Film film) {
    final tone = _tones[film.id % _tones.length];
    final ratingLabel = _rating == 0 ? 'Not rated' : '$_rating of 5';
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                InkWell(
                  key: const Key('detailBack'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _handleBack,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left,
                              size: 20, color: _primary),
                          const SizedBox(width: 4),
                          const Text('Watched',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 112,
                      height: 168,
                      decoration: BoxDecoration(
                        color: Color(tone.$1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.bottomLeft,
                      child: Text(film.initials,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: Color(tone.$2))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            key: const Key('detailTitle'),
                            controller: _title,
                            focusNode: _titleFocus,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: _ink),
                            decoration: InputDecoration(
                              hintText: 'Title',
                              hintStyle: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: _subtle),
                              errorText: _titleError,
                              errorStyle: const TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: _onTitleChanged,
                            onSubmitted: (_) => _commitTitle(),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('detailReleaseYear'),
                            controller: _releaseYear,
                            focusNode: _releaseFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                                fontSize: 13, color: _subtle),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: _field(
                                    hint: 'Release year',
                                    error: _releaseYearError)
                                .copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: _onReleaseYearChanged,
                            onSubmitted: (_) => _commitReleaseYear(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardSurface,
                    border: Border.all(color: _fieldBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text('Your rating',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _ink)),
                          const Spacer(),
                          Text(ratingLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _subtle)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 1; i <= 5; i++) ...[
                            if (i > 1) const SizedBox(width: 4),
                            IconButton(
                              tooltip: '$i of 5',
                              iconSize: 32,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                  width: 44, height: 44),
                              icon: Icon(
                                  i <= _rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color:
                                      i <= _rating ? _primary : _outline),
                              onPressed: () => _rate(i),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Watched',
                              style:
                                  TextStyle(fontSize: 12, color: _subtle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('detailWatchedYear'),
                              controller: _watchedYear,
                              focusNode: _watchedFocus,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                  fontSize: 13, color: _subtle),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: _field(error: _watchedYearError)
                                  .copyWith(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onChanged: _onWatchedYearChanged,
                              onSubmitted: (_) => _commitWatchedYear(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Notes',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('detailNotes'),
                  controller: _notes,
                  minLines: 5,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                  decoration:
                      _field(hint: 'What stayed with you?').copyWith(
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: _onNotesChanged,
                ),
                const SizedBox(height: 8),
                Text(
                    _savingNotes
                        ? 'Saving...'
                        : 'Saved automatically',
                    style:
                        const TextStyle(fontSize: 12, color: _subtle)),
                if (_saveError != null) ...[
                  const SizedBox(height: 8),
                  Text(_saveError!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
