import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

// TODO: remplace par ton "client_id" Jamendo (devportal.jamendo.com)
const String kClientId = 'METS_TON_CLIENT_ID_ICI';

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
      setState(() 
