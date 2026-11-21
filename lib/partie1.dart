part of 'main.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String diag = 'Notification : OK';
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.home.app.audio',
      androidNotificationChannelName: 'Home - lecture',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    diag = 'Erreur notification : $e';
  }
  runApp(const MyApp());
  Future.delayed(const Duration(seconds: 6), () {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(diag), duration: const Duration(seconds: 25)),
    );
  });
}

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
