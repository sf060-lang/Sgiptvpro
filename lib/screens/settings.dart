import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'login.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final acc = s.account;

    return ListView(
      children: [
        const _Header('Hesap'),
        ListTile(
          leading: const Icon(Icons.dns),
          title: Text(acc?.name ?? '-'),
          subtitle: Text('${acc?.host ?? ''} · ${acc?.username ?? ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen(canClose: true)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Listeleri yenile'),
          subtitle: const Text('Kanal, film ve dizi listelerini sunucudan yeniden çeker'),
          onTap: () {
            s.reloadAll();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Listeler bir sonraki açılışta yenilenecek.')));
          },
        ),
        const _Header('Oynatıcı'),
        ListTile(
          leading: const Icon(Icons.stream),
          title: const Text('Canlı yayın formatı'),
          subtitle: const Text('MPEG-TS genelde daha hızlı açılır; HLS (m3u8) bazı sunucularda daha kararlıdır'),
          trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'ts', label: Text('TS')),
              ButtonSegment(value: 'm3u8', label: Text('HLS')),
            ],
            selected: {s.liveFormat},
            onSelectionChanged: (v) => s.setLiveFormat(v.first),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.memory),
          title: const Text('Donanım hızlandırma'),
          subtitle: const Text('4K/8K için açık kalmalı. Görüntü bozuksa kapatıp dene.'),
          value: s.hwAccel,
          onChanged: s.setHwAccel,
        ),
        const _Header('Yetişkin içerik'),
        ListTile(
          leading: Icon(s.adultUnlocked ? Icons.lock_open : Icons.lock_outline),
          title: Text(s.adultUnlocked ? 'Kilit açık — şimdi kilitle' : 'Kilidi aç'),
          subtitle: Text(s.hasPin
              ? 'Yetişkin kategoriler PIN ile korunuyor. Uygulama arka plana alınınca otomatik kilitlenir.'
              : 'Henüz PIN belirlenmedi. Kilidi açmaya çalışınca PIN oluşturulur.'),
          onTap: () async {
            if (s.adultUnlocked) {
              s.lockAdult();
            } else {
              await askUnlock(context);
            }
          },
        ),
        if (s.hasPin)
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('PIN değiştir'),
            onTap: () async {
              if (!await askUnlock(context)) return;
              if (!context.mounted) return;
              await showDialog<bool>(
                context: context,
                builder: (_) => const PinDialog(create: true),
              );
            },
          ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Yetişkin kategorilerini seç'),
          subtitle: const Text('Otomatik algılananları düzeltebilir, yenilerini ekleyebilirsin'),
          onTap: () async {
            if (!await askUnlock(context)) return;
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdultCatsScreen()),
            );
          },
        ),
        const _Header('Veri'),
        ListTile(
          leading: const Icon(Icons.history_toggle_off),
          title: const Text('İzleme geçmişini temizle'),
          onTap: s.clearHistory,
        ),
        ListTile(
          leading: const Icon(Icons.star_border),
          title: const Text('Favorileri temizle'),
          onTap: s.clearFavorites,
        ),
        const _Header('Kısayollar (Windows)'),
        const ListTile(
          leading: Icon(Icons.keyboard),
          title: Text('Boşluk: oynat/duraklat · F: tam ekran · M: sessiz'),
          subtitle: Text('↑ / ↓: önceki / sonraki kanal · ← / →: ±10 sn · Esc: geri'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class AdultCatsScreen extends StatefulWidget {
  const AdultCatsScreen({super.key});
  @override
  State<AdultCatsScreen> createState() => _AdultCatsScreenState();
}

class _AdultCatsScreenState extends State<AdultCatsScreen> {
  late Future<void> _fut;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _fut = Future.wait([for (final t in MediaType.values) s.ensureCats(t)]);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Yetişkin kategorileri')),
      body: FutureBuilder<void>(
        future: _fut,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
          }
          return ListView(
            children: [
              for (final t in MediaType.values) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(switch (t) {
                    MediaType.live => 'Canlı TV',
                    MediaType.movie => 'Filmler',
                    MediaType.series => 'Diziler',
                  }, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final c in s.cats[t] ?? const <Category>[])
                  CheckboxListTile(
                    dense: true,
                    title: Text(c.name),
                    value: s.catIsAdult(t, c),
                    onChanged: (v) => s.setCatAdult(t, c, v ?? false),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
