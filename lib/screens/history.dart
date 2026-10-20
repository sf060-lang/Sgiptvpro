import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  MediaType? _filter;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    for (final t in MediaType.values) {
      s.ensureCats(t).catchError((_) {});
    }
  }

  String _ago(int ms) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    if (d.inDays < 30) return '${d.inDays} gün önce';
    return '${(d.inDays / 30).floor()} ay önce';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rows = <MapEntry<int, PlayEntry>>[];
    for (var i = 0; i < s.history.length; i++) {
      final e = PlayEntry.fromJson(s.history[i]);
      if (s.entryLocked(e)) continue;
      if (_filter != null && e.type != _filter) continue;
      rows.add(MapEntry(i, e));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<MediaType?>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: null, label: Text('Tümü')),
                    ButtonSegment(value: MediaType.live, label: Text('Canlı')),
                    ButtonSegment(value: MediaType.movie, label: Text('Film')),
                    ButtonSegment(value: MediaType.series, label: Text('Dizi')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (v) => setState(() => _filter = v.first),
                ),
              ),
              IconButton(
                tooltip: 'Geçmişi temizle',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: s.history.isEmpty
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Geçmiş temizlensin mi?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Vazgeç')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Temizle')),
                            ],
                          ),
                        );
                        if (ok == true) s.clearHistory();
                      },
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('İzleme geçmişi boş.'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final idx = rows[i].key;
                    final e = rows[i].value;
                    final ts = (s.history[idx]['ts'] as num?)?.toInt() ?? 0;
                    final pos = s.positions[e.key] ?? 0;
                    return ListTile(
                      leading: SizedBox(
                        width: 52,
                        height: 40,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: netImage(context, e.icon, typeIcon(e.type),
                              fit: e.type == MediaType.live ? BoxFit.contain : BoxFit.cover,
                              cache: 120),
                        ),
                      ),
                      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        typeLabel(e.type),
                        _ago(ts),
                        if (pos > 0 && e.type != MediaType.live) '${(pos / 60).floor()} dk\'da kaldı',
                      ].join(' · ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => s.removeHistory(idx),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PlayerScreen(entries: [e]),
                      )),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
