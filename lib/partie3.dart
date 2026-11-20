part of 'main.dart';

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
}
