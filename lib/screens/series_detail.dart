import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});
  final Item series;
  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late Future<SeriesInfo> _fut;
  int? _season;

  @override
  void initState() {
    super.initState();
    _fut = context.read<AppState>().api!.seriesInfo(widget.series);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final fav = s.isFav(widget.series);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
            icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? Colors.amber : null),
            onPressed: () => s.toggleFav(widget.series),
          ),
        ],
      ),
      body: FutureBuilder<SeriesInfo>(
        future: _fut,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}'.replaceFirst('Exception: ', '')),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(
                          () => _fut = s.api!.seriesInfo(widget.series)),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          }
          final info = snap.data!;
          if (info.seasons.isEmpty) {
            return const Center(child: Text('Bu dizi için bölüm bulunamadı.'));
          }
          final seasons = info.seasons.keys.toList();
          final season = seasons.contains(_season) ? _season! : seasons.first;
          final eps = info.seasons[season]!;

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: netImage(context, info.cover ?? widget.series.icon,
                            Icons.video_library, cache: 320),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (info.genre != null) Text(info.genre!),
                          if (info.rating != null) Text('Puan: ${info.rating}'),
                          const SizedBox(height: 8),
                          Text(info.plot ?? '', maxLines: 8, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final sn in seasons)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Sezon $sn'),
                          selected: sn == season,
                          onSelected: (_) => setState(() => _season = sn),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < eps.length; i++)
                ListTile(
                  leading: SizedBox(
                    width: 72,
                    height: 44,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: netImage(context, eps[i].icon, Icons.play_arrow, cache: 200),
                    ),
                  ),
                  title: Text('${eps[i].num}. ${eps[i].title}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: (s.positions['series:${eps[i].id}'] ?? 0) > 0
                      ? const Icon(Icons.history, size: 18)
                      : const Icon(Icons.play_arrow),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PlayerScreen(
                      entries: [for (final e in eps) e.toEntry(widget.series)],
                      index: i,
                    ),
                  )),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
