import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'xtream_api.dart';

/// Kategori adından yetişkin içeriği tahmin eden desen.
final _adultRe = RegExp(
    r'(^|[^a-z0-9])(xxx|adults?|porn\w*|sex\w*|erot\w*|18\+|\+18|yeti[sş]kin|hustler|playboy|brazzers|dorcel|penthouse|hardcore)([^a-z0-9]|$)');

class AppState extends ChangeNotifier {
  AppState(this.prefs) {
    _loadGlobal();
  }
  final SharedPreferences prefs;

  // ---- genel ayarlar ----
  List<Account> accounts = [];
  int active = -1;
  String liveFormat = 'ts'; // 'ts' | 'm3u8'
  bool hwAccel = true;
  String? _pinHash, _pinSalt;
  bool adultUnlocked = false;

  // ---- aktif hesaba ait veriler ----
  List<Item> favorites = [];
  List<Map<String, dynamic>> history = [];
  Map<String, List<String>> orders = {};
  Map<String, String> sorts = {};
  Map<String, int> positions = {};
  Set<String> manualAdult = {}, manualSafe = {};

  XtreamApi? api;
  final Map<MediaType, List<Category>> cats = {};
  final Map<MediaType, List<Item>> items = {};
  final Map<MediaType, Future<void>> _catLoading = {}, _itemLoading = {};

  Account? get account =>
      (active >= 0 && active < accounts.length) ? accounts[active] : null;

  // ------------------------------------------------------------------
  // Kalıcı depolama
  // ------------------------------------------------------------------
  String get _p => account == null
      ? 'none_'
      : 'a_${base64Url.encode(utf8.encode(account!.key))}_';

  dynamic _dec(String? s) => s == null ? null : jsonDecode(s);

  void _loadGlobal() {
    final raw = _dec(prefs.getString('accounts'));
    if (raw is List) {
      accounts = [for (final e in raw) Account.fromJson(Map<String, dynamic>.from(e))];
    }
    liveFormat = prefs.getString('liveFormat') ?? 'ts';
    hwAccel = prefs.getBool('hw') ?? true;
    _pinHash = prefs.getString('pinHash');
    _pinSalt = prefs.getString('pinSalt');
    final a = prefs.getInt('active') ?? (accounts.isEmpty ? -1 : 0);
    if (a >= 0 && a < accounts.length) _activate(a, save: false);
  }

  void _loadAccountData() {
    final p = _p;
    final fav = _dec(prefs.getString('${p}fav'));
    favorites = fav is List
        ? [for (final e in fav) Item.fromJson(Map<String, dynamic>.from(e))]
        : [];
    final his = _dec(prefs.getString('${p}his'));
    history = his is List ? [for (final e in his) Map<String, dynamic>.from(e)] : [];
    final ord = _dec(prefs.getString('${p}ord'));
    orders = ord is Map
        ? {for (final e in ord.entries) '${e.key}': [for (final x in e.value) '$x']}
        : {};
    final so = _dec(prefs.getString('${p}sort'));
    sorts = so is Map ? {for (final e in so.entries) '${e.key}': '${e.value}'} : {};
    final po = _dec(prefs.getString('${p}pos'));
    positions = po is Map
        ? {for (final e in po.entries) '${e.key}': (e.value as num).toInt()}
        : {};
    manualAdult = (prefs.getStringList('${p}madult') ?? []).toSet();
    manualSafe = (prefs.getStringList('${p}msafe') ?? []).toSet();
  }

  Future<void> _saveAccounts() =>
      prefs.setString('accounts', jsonEncode([for (final a in accounts) a.toJson()]));
  Future<void> _saveFav() =>
      prefs.setString('${_p}fav', jsonEncode([for (final f in favorites) f.toJson()]));
  Future<void> _saveHistory() => prefs.setString('${_p}his', jsonEncode(history));

  // ------------------------------------------------------------------
  // Hesaplar
  // ------------------------------------------------------------------
  void _activate(int i, {bool save = true}) {
    active = i;
    api = XtreamApi(accounts[i]);
    cats.clear();
    items.clear();
    _catLoading.clear();
    _itemLoading.clear();
    adultUnlocked = false;
    _loadAccountData();
    if (save) prefs.setInt('active', i);
  }

  Future<void> addAccount(Account a) async {
    final i = accounts.indexWhere((x) => x.key == a.key);
    if (i >= 0) {
      accounts[i] = a;
    } else {
      accounts.add(a);
    }
    await _saveAccounts();
    _activate(i >= 0 ? i : accounts.length - 1);
    notifyListeners();
  }

  void selectAccount(int i) {
    _activate(i);
    notifyListeners();
  }

  Future<void> removeAccount(int i) async {
    final wasActive = i == active;
    accounts.removeAt(i);
    await _saveAccounts();
    if (accounts.isEmpty) {
      active = -1;
      api = null;
      cats.clear();
      items.clear();
      _catLoading.clear();
      _itemLoading.clear();
      await prefs.remove('active');
    } else if (wasActive) {
      _activate(0);
    } else if (i < active) {
      active -= 1;
      await prefs.setInt('active', active);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Liste yükleme
  // ------------------------------------------------------------------
  Future<void> ensureCats(MediaType t) => _catLoading[t] ??= _loadCats(t);

  Future<void> _loadCats(MediaType t) async {
    try {
      cats[t] = await api!.categories(t);
      notifyListeners();
    } catch (_) {
      _catLoading.remove(t);
      rethrow;
    }
  }

  Future<void> _loadItems(MediaType t) async {
    try {
      items[t] = await api!.items(t);
    } catch (_) {
      _itemLoading.remove(t);
      rethrow;
    }
  }

  Future<void> ensureLoaded(MediaType t, {bool force = false}) {
    if (force) {
      cats.remove(t);
      items.remove(t);
      _catLoading.remove(t);
      _itemLoading.remove(t);
    }
    return Future.wait([
      ensureCats(t),
      _itemLoading[t] ??= _loadItems(t),
    ]).then((_) => notifyListeners());
  }

  Future<void> reloadAll() async {
    for (final t in MediaType.values) {
      cats.remove(t);
      items.remove(t);
      _catLoading.remove(t);
      _itemLoading.remove(t);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Yetişkin kilidi
  // ------------------------------------------------------------------
  bool get hasPin => _pinHash != null;

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    _pinSalt = salt;
    _pinHash = _hash(pin, salt);
    await prefs.setString('pinSalt', salt);
    await prefs.setString('pinHash', _pinHash!);
    adultUnlocked = true;
    notifyListeners();
  }

  bool verifyPin(String pin) =>
      _pinHash != null && _pinSalt != null && _hash(pin, _pinSalt!) == _pinHash;

  bool unlock(String pin) {
    if (!verifyPin(pin)) return false;
    adultUnlocked = true;
    notifyListeners();
    return true;
  }

  void lockAdult() {
    if (!adultUnlocked) return;
    adultUnlocked = false;
    notifyListeners();
  }

  bool catIsAdult(MediaType t, Category c) {
    final k = '${t.name}:${c.id}';
    if (manualSafe.contains(k)) return false;
    if (manualAdult.contains(k)) return true;
    return _adultRe.hasMatch(c.name.toLowerCase());
  }

  Future<void> setCatAdult(MediaType t, Category c, bool adult) async {
    final k = '${t.name}:${c.id}';
    if (adult) {
      manualAdult.add(k);
      manualSafe.remove(k);
    } else {
      manualSafe.add(k);
      manualAdult.remove(k);
    }
    await prefs.setStringList('${_p}madult', manualAdult.toList());
    await prefs.setStringList('${_p}msafe', manualSafe.toList());
    notifyListeners();
  }

  Set<String> adultCatIds(MediaType t) =>
      {for (final c in cats[t] ?? const <Category>[]) if (catIsAdult(t, c)) c.id};

  List<Category> visibleCats(MediaType t) {
    final all = cats[t] ?? const <Category>[];
    if (adultUnlocked) return all;
    return [for (final c in all) if (!catIsAdult(t, c)) c];
  }

  List<Item> visibleItems(MediaType t) {
    final all = items[t] ?? const <Item>[];
    if (adultUnlocked) return all;
    final adult = adultCatIds(t);
    if (adult.isEmpty) return all;
    return [for (final i in all) if (!adult.contains(i.cat)) i];
  }

  bool itemLocked(Item i) =>
      !adultUnlocked && (i.adult || adultCatIds(i.type).contains(i.cat));

  bool entryLocked(PlayEntry e) =>
      !adultUnlocked && (e.adult || adultCatIds(e.type).contains(e.cat));

  // ------------------------------------------------------------------
  // Ayarlar
  // ------------------------------------------------------------------
  void setLiveFormat(String f) {
    liveFormat = f;
    prefs.setString('liveFormat', f);
    notifyListeners();
  }

  void setHwAccel(bool v) {
    hwAccel = v;
    prefs.setBool('hw', v);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Sıralama
  // ------------------------------------------------------------------
  String sortFor(String key) => sorts[key] ?? 'default';

  void setSort(String key, String mode) {
    sorts[key] = mode;
    prefs.setString('${_p}sort', jsonEncode(sorts));
    notifyListeners();
  }

  void setOrder(String key, List<String> ids) {
    orders[key] = ids;
    prefs.setString('${_p}ord', jsonEncode(orders));
    notifyListeners();
  }

  List<Item> applySort(List<Item> src, String key, String mode) {
    switch (mode) {
      case 'az':
        return [...src]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'za':
        return [...src]
          ..sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'new':
        return [...src]..sort((a, b) => b.added.compareTo(a.added));
      case 'manual':
        final order = orders[key];
        if (order == null || order.isEmpty) return src;
        final idx = {for (var i = 0; i < order.length; i++) order[i]: i};
        final known = [for (final i in src) if (idx.containsKey(i.id)) i]
          ..sort((a, b) => idx[a.id]!.compareTo(idx[b.id]!));
        final rest = [for (final i in src) if (!idx.containsKey(i.id)) i];
        return [...known, ...rest];
      default:
        return src;
    }
  }

  // ------------------------------------------------------------------
  // Favoriler
  // ------------------------------------------------------------------
  bool isFav(Item i) => favorites.any((f) => f.type == i.type && f.id == i.id);

  bool isFavEntry(PlayEntry e) =>
      favorites.any((f) => f.type == e.type && f.id == e.id);

  void toggleFav(Item i) {
    final idx = favorites.indexWhere((f) => f.type == i.type && f.id == i.id);
    if (idx >= 0) {
      favorites.removeAt(idx);
    } else {
      i.adult = adultCatIds(i.type).contains(i.cat);
      favorites.insert(0, i);
    }
    _saveFav();
    notifyListeners();
  }

  void toggleFavEntry(PlayEntry e) {
    toggleFav(Item(
      type: e.type,
      id: e.id,
      name: e.title,
      cat: e.cat,
      icon: e.icon,
      ext: e.ext,
    ));
  }

  void clearFavorites() {
    favorites.clear();
    _saveFav();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Geçmiş ve izleme konumu
  // ------------------------------------------------------------------
  void addHistory(PlayEntry e) {
    e.adult = adultCatIds(e.type).contains(e.cat);
    history.removeWhere((h) => '${h['type']}:${h['id']}' == e.key);
    history.insert(0, {...e.toJson(), 'ts': DateTime.now().millisecondsSinceEpoch});
    if (history.length > 300) history = history.sublist(0, 300);
    _saveHistory();
    notifyListeners();
  }

  void removeHistory(int index) {
    history.removeAt(index);
    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    notifyListeners();
  }

  void savePosition(String key, int seconds) {
    if (seconds <= 0) {
      positions.remove(key);
    } else {
      positions[key] = seconds;
    }
    prefs.setString('${_p}pos', jsonEncode(positions));
  }
}
