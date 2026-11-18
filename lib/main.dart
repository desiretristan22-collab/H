import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

// TODO: remplace par ton "client_id" Jamendo (devportal.jamendo.com)
const String kClientId = 'f62b3';

const Color kBg = Color(0xFF07090D);
const Color kPanel = Color(0xFF0F141B);
const Color kLine = Color(0xFF1E2A36);
const Color kCyan = Color(0xFF00E5FF);
const Color kText = Color(0xFFE8F1F5);
const Color kMuted = Color(0xFF8A98A6);
const String kMono = 'monospace';

void main() => runApp(const MyApp());

class Track {
  final String id, name, artist, audio, image;
  final int duration;
  Track({
    required this.id,
    required this.name,
    required this.artist,
    required this.audio,
    required this.image,
    required this.duration,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        artist: (j['artist_name'] ?? '').toString(),
        audio: (j['audio'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        duration: (j['duration'] as num?)?.toInt() ?? 0,
      );
}

Future<List<Track>> fetchTracks(String query) async {
  final params = <String, String>{
    'client_id': kClientId,
    'format': 'json',
    'limit': '30',
    'imagesize': '200',
    'audioformat': 'mp32',
    if (query.isNotEmpty) 'search': query else 'order': 'popularity_week',
  };
  final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', params);
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('Erreur serveur (${res.statusCode})');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final results = (data['results'] as List?) ?? [];
  return results
      .map((e) => Track.fromJson(e as Map<String, dynamic>))
      .where((t) => t.audio.isNotEmpty)
      .toList();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kCyan,
          surface: kBg,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _search = TextEditingController();
  List<Track> _tracks = [];
  int _current = -1;
  bool _loading = true;
  bool _searching = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _next();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    if (kClientId == 'METS_TON_CLIENT_ID_ICI') {
      setState(() {
        _loading = false;
        _error = 'Il manque ton client_id Jamendo.\nOuvre lib/main.dart et remplace METS_TON_CLIENT_ID_ICI.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _query = q.trim();
    });
    try {
      final t = await fetchTracks(_query);
      setState(() => _tracks = t);
    } catch (e) {
      setState(() => _error = 'Impossible de charger la musique.\n$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _play(int i) async {
    if (i < 0 || i >= _tracks.length) return;
    setState(() => _current = i);
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_tracks[i].audio)));
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lecture impossible')));
    }
  }

  void _next() {
    if (_current + 1 < _tracks.length) _play(_current + 1);
  }

  void _prev() {
    if (_current > 0) _play(_current - 1);
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<String> get _artists {
    final seen = <String>[];
    for (final t in _tracks) {
      if (t.artist.isNotEmpty && !seen.contains(t.artist)) seen.add(t.artist);
    }
    return seen.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            if (_current >= 0) _buildMini(),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(
          '// $text',
          style: const TextStyle(
            fontFamily: kMono,
            fontSize: 13,
            color: kCyan,
          ),
        ),
      );

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        Row(
          children: [
            const Text(
              'HOME',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: kCyan,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Rechercher',
              icon: Icon(_searching ? Icons.close : Icons.search, color: kCyan),
              onPressed: () => setState(() => _searching = !_searching),
            ),
          ],
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _load,
              style: const TextStyle(fontFamily: kMono, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Rechercher un artiste ou un titre',
                hintStyle: TextStyle(fontFamily: kMono, color: kMuted),
                prefixIcon: Icon(Icons.search, color: kCyan),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: kCyan),
                ),
              ),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: kCyan)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: kMono, color: kMuted)),
          )
        else if (_tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
                child: Text('Aucun r茅sultat',
                    style: TextStyle(fontFamily: kMono, color: kMuted))),
          )
        else ...[
          _label('脌 LA UNE'),
          _buildFeatured(_tracks.first),
          _label('ARTISTES'),
          _buildArtists(),
          _label(_query.isEmpty ? 'TOP DE LA SEMAINE' : 'R脡SULTATS'),
          for (int i = 0; i < _tracks.length; i++) _buildRow(i),
        ],
      ],
    );
  }

  Widget _buildFeatured(Track t) {
    return Material(
      color: kPanel,
      clipBehavior: Clip.antiAlias,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: InkWell(
        onTap: () => _play(0),
        child: SizedBox(
          height: 190,
          child: Column(
            children: [
              Container(height: 3, color: kCyan),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.artist.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                height: 1,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: kMono, fontSize: 12, color: kMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 52,
                        height: 52,
                        color: kCyan,
                        child: const Icon(Icons.play_arrow, color: kBg, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtists() {
    final artists = _artists;
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final name = artists[i];
          final initials = name.length >= 2
              ? name.substring(0, 2).toUpperCase()
              : name.toUpperCase();
          return InkWell(
            onTap: () {
              _search.text = name;
              _load(name);
            },
            child: SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: kPanel,
                    shape: const BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: kText)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(int i) {
    final t = _tracks[i];
    final selected = i == _current;
    return InkWell(
      onTap: () => _play(i),
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                (i + 1).toString().padLeft(2, '0'),
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 15, color: kCyan),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? kCyan : kText)),
                  Text(t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 12, color: kMuted)),
                ],
              ),
            ),
            if (t.duration > 0)
              Text(_fmt(t.duration),
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMini() {
    final t = _tracks[_current];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kCyan),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: kMono, fontSize: 11, color: kMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Pr茅c茅dent',
                  icon: const Icon(Icons.skip_previous, color: kText),
                  onPressed: _prev,
                ),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snap) {
                    final st = snap.data;
                    final busy =
                        st?.processingState == ProcessingState.loading ||
                            st?.processingState == ProcessingState.buffering;
                    if (busy) {
                      return const SizedBox(
                        width: 48,
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kCyan),
                        ),
                      );
                    }
                    final playing = st?.playing ?? false;
                    return IconButton(
                      tooltip: playing ? 'Pause' : 'Lecture',
                      iconSize: 32,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                          color: kCyan),
                      onPressed: playing ? _player.pause : _player.play,
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Suivant',
                  icon: const Icon(Icons.skip_next, color: kText),
                  onPressed: _next,
                ),
              ],
            ),
          ),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = _player.duration ?? Duration.zero;
              final v = dur.inMilliseconds > 0
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;
              return LinearProgressIndicator(
                value: v,
                minHeight: 3,
                color: kCyan,
                backgroundColor: kLine,
              );
            },
          ),
        ],
      ),
    );
  }
}
