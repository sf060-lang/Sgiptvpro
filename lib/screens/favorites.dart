import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'player_screen.dart';
import 'series_detail.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // Yetişkin kategorilerini tanıyabilmek için kategori adlarını yükle.
    final s = context.read<AppState>();
    for (final t in MediaType.values) {
      s.ensureCats(t).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = [for (final f in s.favorites) if (!s.itemLocked(f)) f];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv), text: 'Canlı'),
              Tab(icon: Icon(Icons.movie), text: 'Filmler'),
              Tab(icon: Icon(Icons.video_library), text: 'Diziler'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in MediaType.values)
                  _FavList(type: t, list: [for (final f in all) if (f.type == t) f]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavList extends StatelessWidget {
  const _FavList({required this.type, required this.list});
  final MediaType type;
  final List<Item> list;

  void _open(BuildContext context, int i) {
    final it = list[i];
    final Widget page;
    switch (it.type) {
      case MediaType.series:
        page = SeriesDetailScreen(series: it);
      case MediaType.live:
        page = PlayerScreen(entries: [for (final x in list) PlayEntry.fromItem(x)], index: i);
      case MediaType.movie:
        page = PlayerScreen(entries: [PlayEntry.fromItem(it)]);
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Center(
        child: Text('Henüz favori ${typeLabel(type).toLowerCase()} yok.\n'
            'Yıldız simgesine dokunarak ekleyebilirsin.',
            textAlign: TextAlign.center),
      );
    }
    if (type == MediaType.live) {
      return ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => LiveTile(item: list[i], onTap: () => _open(context, i)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.62,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => Poster(item: list[i], onTap: () => _open(context, i)),
    );
  }
}
