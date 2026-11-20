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
}part of 'main.dart';

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
}part of 'main.dart';

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
                            fontFamily: kMono, fontSize: 11, color: kMuted)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? kCyan : kLine,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? kBg : kMuted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('PARAMÈTRES',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
}part of 'main.dart';

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
