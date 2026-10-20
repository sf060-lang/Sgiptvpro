import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'player_screen.dart';
import 'series_detail.dart';

/// Canlı TV / Filmler / Diziler için ortak liste ekranı:
/// kategori seçimi, arama, sıralama (özel sıralama dahil) ve favori ekleme.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.type});
  final MediaType type;
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String? _catId;
  String _q = '';
  late Future<void> _fut;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fut = context.read<AppState>().ensureLoaded(widget.type);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload({bool force = false}) {
    setState(() => _fut = context.read<AppState>().ensureLoaded(widget.type, force: force));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _fut,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Liste yükleniyor…'),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 8),
                  Text('${snap.error}'.replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () => _reload(force: true), child: const Text('Tekrar dene')),
                ],
              ),
            ),
          );
        }
        return _body(ctx);
      },
    );
  }

  Widget _body(BuildContext context) {
    final s = context.watch<AppState>();
    final t = widget.type;
    final cats = s.visibleCats(t);
    if (_catId != null && !cats.any((c) => c.id == _catId)) _catId = null;

    final key = '${t.name}_${_catId ?? 'all'}';
    final mode = s.sortFor(key);

    var list = s.visibleItems(t);
    if (_catId != null) list = [for (final i in list) if (i.cat == _catId) i];
    final query = _q.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = [for (final i in list) if (i.name.toLowerCase().contains(query)) i];
    }
    list = s.applySort(list, key, mode);

    final catName = _catId == null ? 'Tümü' : cats.firstWhere((c) => c.id == _catId).name;

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 820;
      final content = Column(
        children: [
          _toolbar(context, s, key, mode, catName, wide, list.length),
          Expanded(child: _results(context, s, list, key, mode, query)),
        ],
      );
      if (!wide) return content;
      return Row(
        children: [
          SizedBox(
            width: 270,
            child: _CatList(
              cats: cats,
              selected: _catId,
              onPick: (id) => setState(() => _catId = id),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      );
    });
  }

  Widget _toolbar(BuildContext context, AppState s, String key, String mode, String catName,
      bool wide, int count) {
    final t = widget.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          if (!wide)
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.category_outlined, size: 18),
                  label: Text(catName, overflow: TextOverflow.ellipsis),
                  onPressed: () => _pickCategory(context, s),
                ),
              ),
            ),
          if (!wide) const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: '${typeLabel(t)} ara…  ($count)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            onSelected: (m) => s.setSort(key, m),
            itemBuilder: (_) => [
              _sortItem('default', 'Sunucu sırası', mode),
              _sortItem('az', 'A → Z', mode),
              _sortItem('za', 'Z → A', mode),
              _sortItem('new', 'En yeni eklenen', mode),
              if (t == MediaType.live) _sortItem('manual', 'Özel sıralama (sürükle)', mode),
            ],
          ),
          IconButton(
            tooltip: 'Listeyi yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => _reload(force: true),
          ),
          IconButton(
            tooltip: s.adultUnlocked ? 'Yetişkin içeriği kilitle' : 'Yetişkin içeriği aç',
            icon: Icon(s.adultUnlocked ? Icons.lock_open : Icons.lock_outline,
                color: s.adultUnlocked ? Colors.orangeAccent : null),
            onPressed: () async {
              if (s.adultUnlocked) {
                s.lockAdult();
              } else {
                await askUnlock(context);
              }
            },
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String v, String label, String cur) => PopupMenuItem(
        value: v,
        child: Row(
          children: [
            SizedBox(width: 24, child: cur == v ? const Icon(Icons.check, size: 18) : null),
            Text(label),
          ],
        ),
      );

  void _pickCategory(BuildContext context, AppState s) {
    final cats = s.visibleCats(widget.type);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: _CatList(
          cats: cats,
          selected: _catId,
          onPick: (id) {
            Navigator.pop(ctx);
            setState(() => _catId = id);
          },
        ),
      ),
    );
  }

  Widget _results(
      BuildContext context, AppState s, List<Item> list, String key, String mode, String query) {
    if (list.isEmpty) return const Center(child: Text('Sonuç yok'));
    final t = widget.type;

    if (t == MediaType.live) {
      if (mode == 'manual' && query.isEmpty) {
        return ReorderableListView.builder(
          itemCount: list.length,
          buildDefaultDragHandles: false,
          onReorder: (o, n) {
            if (n > o) n -= 1;
            final ids = [for (final i in list) i.id];
            final id = ids.removeAt(o);
            ids.insert(n, id);
            s.setOrder(key, ids);
          },
          itemBuilder: (_, i) => LiveTile(
            key: ValueKey(list[i].id),
            item: list[i],
            dragIndex: i,
            onTap: () => _open(context, list, i),
          ),
        );
      }
      return ListView.builder(
        itemCount: list.length,
        itemExtent: 64,
        itemBuilder: (_, i) => LiveTile(item: list[i], onTap: () => _open(context, list, i)),
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
      itemBuilder: (_, i) => Poster(item: list[i], onTap: () => _open(context, list, i)),
    );
  }

  void _open(BuildContext context, List<Item> list, int i) {
    final it = list[i];
    final Widget page;
    switch (it.type) {
      case MediaType.series:
        page = SeriesDetailScreen(series: it);
      case MediaType.live:
        page = PlayerScreen(
          entries: [for (final x in list) PlayEntry.fromItem(x)],
          index: i,
        );
      case MediaType.movie:
        page = PlayerScreen(entries: [PlayEntry.fromItem(it)]);
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _CatList extends StatelessWidget {
  const _CatList({required this.cats, required this.selected, required this.onPick});
  final List<Category> cats;
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: cats.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return ListTile(
            dense: true,
            selected: selected == null,
            leading: const Icon(Icons.apps, size: 20),
            title: const Text('Tümü'),
            onTap: () => onPick(null),
          );
        }
        final c = cats[i - 1];
        return ListTile(
          dense: true,
          selected: selected == c.id,
          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onPick(c.id),
        );
      },
    );
  }
}
