import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'partie1.dart';
part 'partie2.dart';
part 'partie3.dart';
part 'partie4.dart';

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
    _askNotif();
    await _loadFavs();
    await load('');
  }

  Future<void> _askNotif() async {
    try {
      await Permission.notification.request();
    } catch (_) {}
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
      final t = list[i];
      await player.setAudioSource(AudioSource.uri(
        Uri.parse(t.audio),
        tag: MediaItem(
          id: t.id,
          title: t.name,
          artist: t.artist,
          duration: t.duration > 0 ? Duration(seconds: t.duration) : null,
          artUri: t.image.isNotEmpty ? Uri.parse(t.image) : null,
        ),
      ));
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
