import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'store.dart';

IconData typeIcon(MediaType t) => switch (t) {
      MediaType.live => Icons.live_tv,
      MediaType.movie => Icons.movie,
      MediaType.series => Icons.video_library,
    };

/// PIN ile yetişkin içeriğin kilidini açar. İlk kullanımda PIN oluşturtur.
Future<bool> askUnlock(BuildContext context) async {
  final s = context.read<AppState>();
  if (s.adultUnlocked) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinDialog(create: !s.hasPin),
  );
  return ok == true;
}

class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.create});
  final bool create;
  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  void _submit() {
    final s = context.read<AppState>();
    final pin = _a.text.trim();
    if (widget.create) {
      if (pin.length < 4) {
        setState(() => _err = 'PIN en az 4 haneli olmalı.');
      } else if (pin != _b.text.trim()) {
        setState(() => _err = 'PIN\'ler eşleşmiyor.');
      } else {
        s.setPin(pin).then((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } else {
      if (s.unlock(pin)) {
        Navigator.pop(context, true);
      } else {
        setState(() => _err = 'Yanlış PIN.');
      }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.create ? 'Yetişkin PIN\'i oluştur' : 'Yetişkin içerik PIN\'i'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _a,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
                labelText: widget.create ? 'Yeni PIN (en az 4 hane)' : 'PIN'),
            onSubmitted: (_) {
              if (!widget.create) _submit();
            },
          ),
          if (widget.create)
            TextField(
              controller: _b,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'PIN (tekrar)'),
              onSubmitted: (_) => _submit(),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: _submit, child: Text(widget.create ? 'Kaydet' : 'Aç')),
      ],
    );
  }
}

Widget _imgPlaceholder(BuildContext c, IconData icon) => Container(
      color: Theme.of(c).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: Theme.of(c).colorScheme.onSurfaceVariant),
    );

Widget netImage(BuildContext c, String? url, IconData fallback,
    {BoxFit fit = BoxFit.cover, int cache = 240}) {
  if (url == null) return _imgPlaceholder(c, fallback);
  return Image.network(
    url,
    fit: fit,
    cacheWidth: cache,
    gaplessPlayback: true,
    errorBuilder: (ctx, _, __) => _imgPlaceholder(ctx, fallback),
  );
}

/// Canlı kanal satırı.
class LiveTile extends StatelessWidget {
  const LiveTile({
    super.key,
    required this.item,
    required this.onTap,
    this.dragIndex,
    this.showFav = true,
  });
  final Item item;
  final VoidCallback onTap;
  final int? dragIndex;
  final bool showFav;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final fav = s.isFav(item);
    return ListTile(
      onTap: onTap,
      onLongPress: () => s.toggleFav(item),
      leading: SizedBox(
        width: 52,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: netImage(context, item.icon, Icons.live_tv, fit: BoxFit.contain, cache: 120),
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFav)
            IconButton(
              tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
              icon: Icon(fav ? Icons.star : Icons.star_border,
                  color: fav ? Colors.amber : null),
              onPressed: () => s.toggleFav(item),
            ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
      ),
    );
  }
}

/// Film / dizi afişi.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.item, required this.onTap});
  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final fav = s.isFav(item);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      onLongPress: () => s.toggleFav(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            netImage(context, item.icon, typeIcon(item.type)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                icon: Icon(fav ? Icons.star : Icons.star_border,
                    size: 20, color: fav ? Colors.amber : Colors.white),
                onPressed: () => s.toggleFav(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
