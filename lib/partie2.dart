part of 'main.dart';

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
