import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ton client_id Jamendo
const String kClientId = 'f62b3ab1';

const Color kBg = Color(0xFF07090D);
const Color kPanel = Color(0xFF0F141B);
const Color kBox = Color(0xFF1A2430);
const Color kLine = Color(0xFF1E2A36);
const Color kCyan = Color(0xFF00E5FF);
const Color kText = Color(0xFFE8F1F5);
const Color kMuted = Color(0xFF8A98A6);
const String kMono = 'monospace';

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

void toast(String msg) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------------------
// Données
// ---------------------------------------------------------------------------

int? _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class Track {
  final String id, name, artist, audio, image, shareUrl, lyrics;
  final int duration;
  final int? plays;

  Track({
    required this.id,
    required this.name,
    required this.artist,
    required this.audio,
    required this.image,
    required this.shareUrl,
    required this.lyrics,
    required this.duration,
    required this.plays,
  });

  factory Track.fromJson(Map<String, dynamic> j) {
    int? plays = _toInt(j['plays']);
    final stats = j['stats'];
    if (plays == null && stats is Map) {
      for (final e in stats.entries) {
        if (e.key.toString() == 'rate_listened_total') {
          plays = _toInt(e.value);
        }
      }
      if (plays == null) {
        for (final e in stats.entries) {
          if (e.key.toString().contains('listen')) {
            plays = _toInt(e.value);
            break;
          }
        }
      }
    }
    final ly = j['lyrics'];
    return Track(
      id: j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      artist: (j['artist_name'] ?? '').toString(),
      audio: (j['audio'] ?? '').toString(),
      image: (j['image'] ?? '').toString(),
      shareUrl: (j['shareurl'] ?? '').toString(),
      lyrics: ly is String ? ly : '',
      duration: _toInt(j['duration']) ?? 0,
      plays: plays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist_name': artist,
        'audio': audio,
        'image': image,
        'shareurl': shareUrl,
        'lyrics': lyrics,
        'duration': duration,
        'plays': plays,
      };
}

Future<List<Track>> fetchTracks({
  String query = '',
  String order = 'popularity_week',
  String format = 'mp32',
  int limit = 30,
}) async {
  Future<List<Track>> call(bool withInclude) async {
    final params = <String, String>{
      'client_id': kClientId,
      'format': 'json',
      'limit': '$limit',
      'imagesize': '200',
      'audioformat': format,
      if (withInclude) 'include': 'stats lyrics',
      if (query.isNotEmpty) 'search': query else 'order': order,
    };
    final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', params);
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Erreur serveur (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final header = data['headers'];
    if (header is Map && header['status'] == 'failed') {
      throw Exception((header['error_message'] ?? 'Erreur Jamendo').toString());
    }
    final results = (data['results'] as List?) ?? [];
    return results
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .where((t) => t.audio.isNotEmpty)
        .toList();
  }

  try {
    return await call(true);
  } catch (_) {
    return await call(false);
  }
}

String fmtCount(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtPlays(int? n) => n == null ? '—' : fmtCount(n);

String fmtTime(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class Evt {
  final String day, month, title, place;
  const Evt(this.day, this.month, this.title, this.place);
}

// Exemples : les vrais événements viendront avec ton catalogue.
const List<Evt> kEvents = [
  Evt('28', 'NOV', 'Concert Artiste 1', 'Port-au-Prince · 20h00'),
  Evt('05', 'DÉC', "Sortie du single de l'Artiste 2", 'Sur Home · 18h00'),
  Evt('19', 'DÉC', "Soirée live avec l'Artiste 3", 'En direct · 21h00'),
];

// ---------------------------------------------------------------------------
// État de l'application
// ---------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final TextEditingController searchCtl = TextEditingController();

  List<Track> feed = [];
  List<Track> top = [];
  List<Track> queue = [];
  List<Track> favorites = [];
  Track? current;
  int index = -1;
  bool loading = true;
  String? error;
  String query = '';

  bool economy = false;
  bool wifiOnly = true;
  bool notifNew = true;
  bool notifEvents = true;
  String lang = 'Français';

  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) next();
    });
    await _loadFavs();
    await load('');
  }

  List<MapEntry<String, int>> get artists {
    final m = <String, int>{};
    for (final t in feed) {
      if (t.artist.isNotEmpty) m[t.artist] = (m[t.artist] ?? 0) + 1;
    }
    return m.entries.take(8).toList();
  }

  Future<void> load(String q) async {
    query = q.trim();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final fmt = economy ? 'mp31' : 'mp32';
      if (query.isEmpty) {
        final res = await Future.wait([
          fetchTracks(order: 'popularity_week', format: fmt, limit: 40),
          fetchTracks(order: 'listens_week', format: fmt, limit: 10),
        ]);
        feed = res[0];
        top = res[1];
      } else {
        feed = await fetchTracks(query: query, format: fmt, limit: 40);
        top = [];
      }
    } catch (e) {
      error = 'Impossible de charger la musique.\nVérifie ta connexion internet.';
    }
    loading = false;
    notifyListeners();
  }

  void search(String q) {
    searchCtl.text = q;
    load(q);
  }

  Future<void> play(List<Track> list, int i) async {
    if (i < 0 || i >= list.length) return;
    queue = list;
    index = i;
    current = list[i];
    notifyListeners();
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse(list[i].audio)));
      await player.play();
    } catch (e) {
      toast('Lecture impossible');
    }
  }

  void next() {
    if (index + 1 < queue.length) play(queue, index + 1);
  }

  void prev() {
    if (index > 0) play(queue, index - 1);
  }

  bool isFav(Track t) => favorites.any((f) => f.id == t.id);

  Future<void> toggleFav(Track t) async {
    if (isFav(t)) {
      favorites.removeWhere((f) => f.id == t.id);
    } else {
      favorites.insert(0, t);
    }
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
          'favs', favorites.map((f) => jsonEncode(f.toJson())).toList());
    } catch (_) {}
  }

  Future<void> _loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('favs') ?? [];
      favorites = l
          .map((s) => Track.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> share(Track t) async {
    final link = t.shareUrl.isNotEmpty ? '\n${t.shareUrl}' : '';
    final text = 'Écoute « ${t.name} » de ${t.artist} sur Home$link';
    await Clipboard.setData(ClipboardData(text: text));
    toast('Lien copié. Colle-le dans WhatsApp.');
  }

  void setEconomy(bool v) {
    economy = v;
    notifyListeners();
    load(query);
  }

  void setWifi(bool v) {
    wifiOnly = v;
    notifyListeners();
  }

  void setNotifNew(bool v) {
    notifNew = v;
    notifyListeners();
  }

  void setNotifEvents(bool v) {
    notifEvents = v;
    notifyListeners();
  }

  void setLang(String v) {
    lang = v;
    notifyListeners();
  }
}

final AppState app = AppState();

// ---------------------------------------------------------------------------
// Petits composants
// ---------------------------------------------------------------------------

ShapeBorder bevel(double r) => BeveledRectangleBorder(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(r),
        bottomLeft: Radius.circular(r),
      ),
    );

Widget cover(String url, double size, {double radius = 0}) {
  final placeholder = Container(
    width: size,
    height: size,
    color: kBox,
    child: Icon(Icons.music_note, color: kMuted, size: size * 0.45),
  );
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: url.isEmpty
        ? placeholder
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        '// $text',
        style: const TextStyle(fontFamily: kMono, fontSize: 13, color: kCyan),
      ),
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  final double size;
  const PlayPauseButton({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: app.player.playerStateStream,
      builder: (context, snap) {
        final st = snap.data;
        final busy = st?.processingState == ProcessingState.loading ||
            st?.processingState == ProcessingState.buffering;
        final playing = st?.playing ?? false;
        return SizedBox(
          width: size,
          height: size,
          child: Material(
            color: kCyan,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: busy ? null : (playing ? app.player.pause : app.player.play),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: kBg),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow,
                        color: kBg, size: size * 0.55),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FavButton extends StatelessWidget {
  final Track track;
  final double size;
  const FavButton({super.key, required this.track, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final fav = app.isFav(track);
        return IconButton(
          tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: () => app.toggleFav(track),
          icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
              color: kCyan, size: size),
        );
      },
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: app.player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur =
            app.player.duration ?? Duration(seconds: app.current?.duration ?? 0);
        final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final val = pos.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
        return Row(
          children: [
            Text(fmtTime(pos.inSeconds),
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 11, color: kMuted)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: kCyan,
                  inactiveTrackColor: kLine,
                  thumbColor: kCyan,
                ),
                child: Slider(
                  value: val,
                  max: max,
                  onChanged: (v) =>
                      app.player.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
            ),
            Text(fmtTime(dur.inSeconds),
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 11, color: kMuted)),
          ],
        );
      },
    );
  }
}

class TrackRow extends StatelessWidget {
  final List<Track> list;
  final int index;
  final int? rank;
  const TrackRow({
    super.key,
    required this.list,
    required this.index,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final t = list[index];
    final selected = app.current?.id == t.id;
    return InkWell(
      onTap: () => app.play(list, index),
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 30,
                child: Text(
                  rank!.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 17, color: kCyan),
                ),
              ),
            cover(t.image, 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? kCyan : kText,
                    ),
                  ),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: kMono, fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtPlays(t.plays),
                    style: const TextStyle(
                        fontFamily: kMono, fontSize: 12, color: kText)),
                const Text('écoutes',
                    style: TextStyle(
                        fontFamily: kMono, fontSize: 11, color: kMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ArtistCard extends StatelessWidget {
  final String name;
  final int count;
  const ArtistCard({super.key, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    final initials =
        name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    return Material(
      color: kPanel,
      clipBehavior: Clip.antiAlias,
      shape: bevel(14),
      child: InkWell(
        onTap: () => app.search(name),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                color: kBox,
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kCyan)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('$count titre${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontFamily: kMono, fontSize: 11, color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Evt e;
  const EventCard({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPanel,
      shape: bevel(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(e.day,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kCyan,
                          height: 1)),
                  Text(e.month,
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 11, color: kMuted)),
                ],
              ),
            ),
            Container(
                width: 1,
                height: 36,
                color: kLine,
                margin: const EdgeInsets.symmetric(horizontal: 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(e.place,
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 11, color: kMuted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Activer le rappel',
              onPressed: () => toast('Les rappels arriveront bientôt.'),
              icon:
                  const Icon(Icons.notifications_none, color: kCyan, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kCyan, surface: kBg),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

// --- Écran de démarrage -----------------------------------------------------

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    app.init();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'logo.png',
              width: 300,
              errorBuilder: (_, __, ___) => const Text(
                'HOME',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: kCyan,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: kCyan,
                backgroundColor: kLine,
              ),
            ),
            const SizedBox(height: 12),
            const Text('chargement...',
                style:
                    TextStyle(fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

// --- Accueil ----------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Builder(
          builder: (ctx) {
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        'logo.png',
                        height: 40,
                        errorBuilder: (_, __, ___) => const Text(
                          'HOME',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: kCyan,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: NowPlayingCard(),
                    ),
                    const Expanded(child: FeedView()),
                    const SearchBarBottom(),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: MediaQuery.of(ctx).size.height * 0.42,
                  child: Material(
                    color: kCyan,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: const SizedBox(
                        width: 18,
                        height: 76,
                        child:
                            Icon(Icons.chevron_right, color: kBg, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final t = app.current;
        return Container(
          decoration: BoxDecoration(
            color: kPanel,
            border: Border.all(color: kCyan),
            borderRadius: BorderRadius.circular(20),
          ),
          child: t == null
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.headphones, color: kCyan),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choisis un titre pour commencer',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlayerPage()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              cover(t.image, 56, radius: 12),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('EN LECTURE',
                                        style: TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 11,
                                            color: kCyan)),
                                    Text(t.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(t.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 12,
                                            color: kMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Précédent',
                                onPressed: app.prev,
                                icon: const Icon(Icons.skip_previous,
                                    color: kText),
                              ),
                              const PlayPauseButton(size: 44),
                              IconButton(
                                tooltip: 'Suivant',
                                onPressed: app.next,
                                icon:
                                    const Icon(Icons.skip_next, color: kText),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: ProgressBar(),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.headphones,
                                  color: kCyan, size: 16),
                              const SizedBox(width: 6),
                              Text('${fmtPlays(t.plays)} écoutes',
                                  style: const TextStyle(
                                      fontFamily: kMono,
                                      fontSize: 12,
                                      color: kText)),
                              const Spacer(),
                              FavButton(track: t, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        if (app.loading) {
          return const Center(child: CircularProgressIndicator(color: kCyan));
        }
        if (app.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                app.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: kMono, color: kMuted),
              ),
            ),
          );
        }
        if (app.feed.isEmpty) {
          return const Center(
            child: Text('Aucun résultat',
                style: TextStyle(fontFamily: kMono, color: kMuted)),
          );
        }
        final artists = app.artists;
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 0, 16, 16),
          children: [
            const SectionLabel('ARTISTES SUGGÉRÉS'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              padding: EdgeInsets.zero,
              children: [
                for (final a in artists) ArtistCard(name: a.key, count: a.value),
              ],
            ),
            if (app.top.isNotEmpty && app.query.isEmpty) ...[
              const SectionLabel('TOP DE LA SEMAINE'),
              for (int i = 0; i < app.top.length && i < 3; i++)
                TrackRow(list: app.top, index: i, rank: i + 1),
            ],
            SectionLabel(app.query.isEmpty ? 'TITRES SUGGÉRÉS' : 'RÉSULTATS'),
            for (int i = 0; i < app.feed.length; i++)
              TrackRow(list: app.feed, index: i),
          ],
        );
      },
    );
  }
}

class SearchBarBottom extends StatelessWidget {
  const SearchBarBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: app.searchCtl,
        textInputAction: TextInputAction.search,
        onSubmitted: app.load,
        style: const TextStyle(fontFamily: kMono, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher un artiste ou un titre',
          hintStyle:
              const TextStyle(fontFamily: kMono, fontSize: 13, color: kMuted),
          prefixIcon: const Icon(Icons.search, color: kCyan),
          filled: true,
          fillColor: kPanel,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan, width: 2),
          ),
        ),
      ),
    );
  }
}

// --- Menu latéral -----------------------------------------------------------

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kCyan, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  Widget _stat(String v, String l, {bool last = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : const BorderSide(color: kLine),
          ),
        ),
        child: Column(
          children: [
            Text(v,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: kCyan)),
            Text(l,
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 11, color: kMuted)),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0B1017),
      width: 312,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: app,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                Row(
                  children: [
                    Material(
                      color: kBox,
                      shape: bevel(12),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: Text('TU',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kCyan)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nom utilisateur',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('@pseudo',
                              style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 12,
                                  color: kMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer le menu',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left, color: kCyan),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration:
                      BoxDecoration(border: Border.all(color: kLine)),
                  child: Row(
                    children: [
                      _stat('${app.favorites.length}', 'favoris'),
                      _stat('0', 'playlists'),
                      _stat('${kEvents.length}', 'événements', last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MenuItem(
                  icon: Icons.favorite_border,
                  label: 'Mes favoris',
                  trailing: '${app.favorites.length}',
                  onTap: () => _open(context, const FavoritesPage()),
                ),
                _MenuItem(
                  icon: Icons.queue_music,
                  label: 'Mes playlists',
                  onTap: () => toast('Les playlists arriveront bientôt.'),
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: "Historique",
                  onTap: () => toast("L'historique arrivera bientôt."),
                ),
                const SectionLabel('ÉVÉNEMENTS À VENIR'),
                for (final e in kEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EventCard(e: e),
                  ),
                const Text('Exemples : les vrais événements viendront plus tard.',
                    style: TextStyle(
                        fontFamily: kMono, fontSize: 11, color: kMuted)),
                const SizedBox(height: 12),
                _MenuItem(
                  icon: Icons.tune,
                  label: 'Paramètres',
                  onTap: () => _open(context, const SettingsPage()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- Favoris ----------------------------------------------------------------

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('MES FAVORIS',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          if (app.favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucun favori pour le moment.\nAppuie sur le cœur d'un titre pour l'ajouter.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kMono, color: kMuted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (int i = 0; i < app.favorites.length; i++)
                TrackRow(list: app.favorites, index: i),
            ],
          );
        },
      ),
    );
  }
}

// --- Paramètres -------------------------------------------------------------

class Segmented extends StatelessWidget {
  final List<Track> list;
  final int index;
  final int? rank;
  const TrackRow({
    super.key,
    required this.list,
    required this.index,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final t = list[index];
    final selected = app.current?.id == t.id;
    return InkWell(
      onTap: () => app.play(list, index),
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 30,
                child: Text(
                  rank!.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 17, color: kCyan),
                ),
              ),
            cover(t.image, 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? kCyan : kText,
                    ),
                  ),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: kMono, fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtPlays(t.plays),
                    style: const TextStyle(
                        fontFamily: kMono, fontSize: 12, color: kText)),
                const Text('écoutes',
                    style: TextStyle(
                        fontFamily: kMono, fontSize: 11, color: kMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ArtistCard extends StatelessWidget {
  final String name;
  final int count;
  const ArtistCard({super.key, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    final initials =
        name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    return Material(
      color: kPanel,
      clipBehavior: Clip.antiAlias,
      shape: bevel(14),
      child: InkWell(
        onTap: () => app.search(name),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                color: kBox,
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kCyan)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('$count titre${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontFamily: kMono, fontSize: 11, color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Evt e;
  const EventCard({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPanel,
      shape: bevel(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(e.day,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kCyan,
                          height: 1)),
                  Text(e.month,
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 11, color: kMuted)),
                ],
              ),
            ),
            Container(
                width: 1,
                height: 36,
                color: kLine,
                margin: const EdgeInsets.symmetric(horizontal: 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(e.place,
                      style: const TextStyle(
                          fontFamily: kMono, fontSize: 11, color: kMuted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Activer le rappel',
              onPressed: () => toast('Les rappels arriveront bientôt.'),
              icon:
                  const Icon(Icons.notifications_none, color: kCyan, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kCyan, surface: kBg),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

// --- Écran de démarrage -----------------------------------------------------

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    app.init();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'logo.png',
              width: 300,
              errorBuilder: (_, __, ___) => const Text(
                'HOME',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: kCyan,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: kCyan,
                backgroundColor: kLine,
              ),
            ),
            const SizedBox(height: 12),
            const Text('chargement...',
                style:
                    TextStyle(fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

// --- Accueil ----------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Builder(
          builder: (ctx) {
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        'logo.png',
                        height: 40,
                        errorBuilder: (_, __, ___) => const Text(
                          'HOME',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: kCyan,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: NowPlayingCard(),
                    ),
                    const Expanded(child: FeedView()),
                    const SearchBarBottom(),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: MediaQuery.of(ctx).size.height * 0.42,
                  child: Material(
                    color: kCyan,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: const SizedBox(
                        width: 18,
                        height: 76,
                        child:
                            Icon(Icons.chevron_right, color: kBg, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final t = app.current;
        return Container(
          decoration: BoxDecoration(
            color: kPanel,
            border: Border.all(color: kCyan),
            borderRadius: BorderRadius.circular(20),
          ),
          child: t == null
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.headphones, color: kCyan),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choisis un titre pour commencer',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlayerPage()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              cover(t.image, 56, radius: 12),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('EN LECTURE',
                                        style: TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 11,
                                            color: kCyan)),
                                    Text(t.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(t.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 12,
                                            color: kMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Précédent',
                                onPressed: app.prev,
                                icon: const Icon(Icons.skip_previous,
                                    color: kText),
                              ),
                              const PlayPauseButton(size: 44),
                              IconButton(
                                tooltip: 'Suivant',
                                onPressed: app.next,
                                icon:
                                    const Icon(Icons.skip_next, color: kText),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: ProgressBar(),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.headphones,
                                  color: kCyan, size: 16),
                              const SizedBox(width: 6),
                              Text('${fmtPlays(t.plays)} écoutes',
                                  style: const TextStyle(
                                      fontFamily: kMono,
                                      fontSize: 12,
                                      color: kText)),
                              const Spacer(),
                              FavButton(track: t, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        if (app.loading) {
          return const Center(child: CircularProgressIndicator(color: kCyan));
        }
        if (app.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                app.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: kMono, color: kMuted),
              ),
            ),
          );
        }
        if (app.feed.isEmpty) {
          return const Center(
            child: Text('Aucun résultat',
                style: TextStyle(fontFamily: kMono, color: kMuted)),
          );
        }
        final artists = app.artists;
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 0, 16, 16),
          children: [
            const SectionLabel('ARTISTES SUGGÉRÉS'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              padding: EdgeInsets.zero,
              children: [
                for (final a in artists) ArtistCard(name: a.key, count: a.value),
              ],
            ),
            if (app.top.isNotEmpty && app.query.isEmpty) ...[
              const SectionLabel('TOP DE LA SEMAINE'),
              for (int i = 0; i < app.top.length && i < 3; i++)
                TrackRow(list: app.top, index: i, rank: i + 1),
            ],
            SectionLabel(app.query.isEmpty ? 'TITRES SUGGÉRÉS' : 'RÉSULTATS'),
            for (int i = 0; i < app.feed.length; i++)
              TrackRow(list: app.feed, index: i),
          ],
        );
      },
    );
  }
}

class SearchBarBottom extends StatelessWidget {
  const SearchBarBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: app.searchCtl,
        textInputAction: TextInputAction.search,
        onSubmitted: app.load,
        style: const TextStyle(fontFamily: kMono, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher un artiste ou un titre',
          hintStyle:
              const TextStyle(fontFamily: kMono, fontSize: 13, color: kMuted),
          prefixIcon: const Icon(Icons.search, color: kCyan),
          filled: true,
          fillColor: kPanel,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan, width: 2),
          ),
        ),
      ),
    );
  }
}

// --- Menu latéral -----------------------------------------------------------

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kCyan, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HomeDrawer(),
      body: SafeArea(
        child: Builder(
          builder: (ctx) {
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        'logo.png',
                        height: 40,
                        errorBuilder: (_, __, ___) => const Text(
                          'HOME',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: kCyan,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: NowPlayingCard(),
                    ),
                    const Expanded(child: FeedView()),
                    const SearchBarBottom(),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: MediaQuery.of(ctx).size.height * 0.42,
                  child: Material(
                    color: kCyan,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: const SizedBox(
                        width: 18,
                        height: 76,
                        child:
                            Icon(Icons.chevron_right, color: kBg, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final t = app.current;
        return Container(
          decoration: BoxDecoration(
            color: kPanel,
            border: Border.all(color: kCyan),
            borderRadius: BorderRadius.circular(20),
          ),
          child: t == null
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.headphones, color: kCyan),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choisis un titre pour commencer',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlayerPage()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              cover(t.image, 56, radius: 12),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('EN LECTURE',
                                        style: TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 11,
                                            color: kCyan)),
                                    Text(t.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(t.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: kMono,
                                            fontSize: 12,
                                            color: kMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Précédent',
                                onPressed: app.prev,
                                icon: const Icon(Icons.skip_previous,
                                    color: kText),
                              ),
                              const PlayPauseButton(size: 44),
                              IconButton(
                                tooltip: 'Suivant',
                                onPressed: app.next,
                                icon:
                                    const Icon(Icons.skip_next, color: kText),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: ProgressBar(),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.headphones,
                                  color: kCyan, size: 16),
                              const SizedBox(width: 6),
                              Text('${fmtPlays(t.plays)} écoutes',
                                  style: const TextStyle(
                                      fontFamily: kMono,
                                      fontSize: 12,
                                      color: kText)),
                              const Spacer(),
                              FavButton(track: t, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        if (app.loading) {
          return const Center(child: CircularProgressIndicator(color: kCyan));
        }
        if (app.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                app.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: kMono, color: kMuted),
              ),
            ),
          );
        }
        if (app.feed.isEmpty) {
          return const Center(
            child: Text('Aucun résultat',
                style: TextStyle(fontFamily: kMono, color: kMuted)),
          );
        }
        final artists = app.artists;
        return ListView(
          padding: const EdgeInsets.fromLTRB(26, 0, 16, 16),
          children: [
            const SectionLabel('ARTISTES SUGGÉRÉS'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              padding: EdgeInsets.zero,
              children: [
                for (final a in artists) ArtistCard(name: a.key, count: a.value),
              ],
            ),
            if (app.top.isNotEmpty && app.query.isEmpty) ...[
              const SectionLabel('TOP DE LA SEMAINE'),
              for (int i = 0; i < app.top.length && i < 3; i++)
                TrackRow(list: app.top, index: i, rank: i + 1),
            ],
            SectionLabel(app.query.isEmpty ? 'TITRES SUGGÉRÉS' : 'RÉSULTATS'),
            for (int i = 0; i < app.feed.length; i++)
              TrackRow(list: app.feed, index: i),
          ],
        );
      },
    );
  }
}

class SearchBarBottom extends StatelessWidget {
  const SearchBarBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: app.searchCtl,
        textInputAction: TextInputAction.search,
        onSubmitted: app.load,
        style: const TextStyle(fontFamily: kMono, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher un artiste ou un titre',
          hintStyle:
              const TextStyle(fontFamily: kMono, fontSize: 13, color: kMuted),
          prefixIcon: const Icon(Icons.search, color: kCyan),
          filled: true,
          fillColor: kPanel,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: const BorderSide(color: kCyan, width: 2),
          ),
        ),
      ),
    );
  }
}

// --- Menu latéral -----------------------------------------------------------

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kCyan, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: const TextStyle(
                      fontFamily: kMono, fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  Widget _stat(String v, String l, {bool last = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : const BorderSide(color: kLine),
          ),
        ),
        child: Column(
          children: [
            Text(v,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: kCyan)),
            Text(l,
                style: const TextStyle(
                    fontFamily: kMono, fontSize: 11, color: kMuted)),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0B1017),
      width: 312,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: app,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                Row(
                  children: [
                    Material(
                      color: kBox,
                      shape: bevel(12),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: Text('TU',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kCyan)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nom utilisateur',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('@pseudo',
                              style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 12,
                                  color: kMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer le menu',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left, color: kCyan),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration:
                      BoxDecoration(border: Border.all(color: kLine)),
                  child: Row(
                    children: [
                      _stat('${app.favorites.length}', 'favoris'),
                      _stat('0', 'playlists'),
                      _stat('${kEvents.length}', 'événements', last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MenuItem(
                  icon: Icons.favorite_border,
                  label: 'Mes favoris',
                  trailing: '${app.favorites.length}',
                  onTap: () => _open(context, const FavoritesPage()),
                ),
                _MenuItem(
                  icon: Icons.queue_music,
                  label: 'Mes playlists',
                  onTap: () => toast('Les playlists arriveront bientôt.'),
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: "Historique",
                  onTap: () => toast("L'historique arrivera bientôt."),
                ),
                const SectionLabel('ÉVÉNEMENTS À VENIR'),
                for (final e in kEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EventCard(e: e),
                  ),
                const Text('Exemples : les vrais événements viendront plus tard.',
                    style: TextStyle(
                        fontFamily: kMono, fontSize: 11, color: kMuted)),
                const SizedBox(height: 12),
                _MenuItem(
                  icon: Icons.tune,
                  label: 'Paramètres',
                  onTap: () => _open(context, const SettingsPage()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- Favoris ----------------------------------------------------------------

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('MES FAVORIS',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          if (app.favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucun favori pour le moment.\nAppuie sur le cœur d'un titre pour l'ajouter.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kMono, color: kMuted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (int i = 0; i < app.favorites.length; i++)
                TrackRow(list: app.favorites, index: i),
            ],
          );
        },
      ),
    );
  }
}

// --- Paramètres -------------------------------------------------------------

class Segmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kLine)),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  color: i == selected ? kCyan : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: i == selected ? kBg : kText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingToggle extends StatelessWidget {
  final String title;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingToggle({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (sub != null)
                    Text(sub!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const SectionLabel('ÉCONOMIE DE DONNÉES'),
              const Text('Qualité de la musique',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Segmented(
                options: const ['Économique', 'Normale'],
                selected: app.economy ? 0 : 1,
                onChanged: (i) => app.setEconomy(i == 0),
              ),
              const SizedBox(height: 6),
              const Text(
                'Économique : moins de données (≈ 96 kbps). Actif dès le prochain chargement.',
                style:
                    TextStyle(fontFamily: kMono, fontSize: 11, color: kMuted),
              ),
              const SizedBox(height: 10),
              SettingToggle(
                title: 'Télécharger en Wi-Fi seulement',
                sub: 'Bientôt disponible',
                value: app.wifiOnly,
                onChanged: app.setWifi,
              ),
              const SectionLabel('NOTIFICATIONS'),
              SettingToggle(
                title: 'Nouveaux titres des artistes suivis',
                sub: 'Bientôt disponible',
                value: app.notifNew,
                onChanged: app.setNotifNew,
              ),
              SettingToggle(
                title: 'Événements à venir',
                sub: 'Bientôt disponible',
                value: app.notifEvents,
                onChanged: app.setNotifEvents,
              ),
              const SectionLabel('LANGUE'),
              Segmented(
                options: const ['Français', 'Kreyòl'],
                selected: app.lang == 'Français' ? 0 : 1,
                onChanged: (i) => app.setLang(i == 0 ? 'Français' : 'Kreyòl'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Le kreyòl arrivera bientôt : l\'appli reste en français pour l\'instant.',
                style:
                    TextStyle(fontFamily: kMono, fontSize: 11, color: kMuted),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('Home · version 1.0',
                    style: TextStyle(
                        fontFamily: kMono, fontSize: 11, color: kMuted)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Lecteur plein écran ----------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kText,
          side: const BorderSide(color: kLine),
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(0, 48),
        ),
        icon: Icon(icon, color: kCyan, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: app,
          builder: (context, _) {
            final t = app.current;
            if (t == null) {
              return const Center(child: Text('Aucun titre en lecture'));
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Réduire',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.expand_more,
                            color: kCyan, size: 30),
                      ),
                      const Text('// EN LECTURE',
                          style: TextStyle(
                              fontFamily: kMono, fontSize: 13, color: kCyan)),
                      IconButton(
                        tooltip: 'Partager',
                        onPressed: () => app.share(t),
                        icon: const Icon(Icons.share, color: kCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: kPanel,
                    shape: bevel(26),
                    clipBehavior: Clip.antiAlias,
                    child: cover(t.image, 170),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1)),
                            const SizedBox(height: 2),
                            Text(t.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: kMono,
                                    fontSize: 13,
                                    color: kMuted)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.headphones,
                                    color: kCyan, size: 15),
                                const SizedBox(width: 6),
                                Text('${fmtPlays(t.plays)} écoutes',
                                    style: const TextStyle(
                                        fontFamily: kMono,
                                        fontSize: 12,
                                        color: kText)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      FavButton(track: t, size: 26),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const ProgressBar(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Précédent',
                        onPressed: app.prev,
                        icon: const Icon(Icons.skip_previous,
                            color: kText, size: 34),
                      ),
                      const SizedBox(width: 12),
                      const PlayPauseButton(size: 64),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Suivant',
                        onPressed: app.next,
                        icon: const Icon(Icons.skip_next,
                            color: kText, size: 34),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPanel,
                        border: Border.all(color: kLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('// PAROLES',
                              style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 12,
                                  color: kCyan)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                t.lyrics.isEmpty
                                    ? 'Les paroles de ce titre ne sont pas encore disponibles.'
                                    : t.lyrics,
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.4,
                                  color: t.lyrics.isEmpty ? kMuted : kText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.share,
                        label: 'Partager',
                        onTap: () => app.share(t),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.download,
                        label: 'Hors ligne',
                        onTap: () => toast('Bientôt disponible'),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.ondemand_video,
                        label: 'Vidéo',
                        onTap: () => toast('Bientôt disponible'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
