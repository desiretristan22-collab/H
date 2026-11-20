part of 'main.dart';

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
