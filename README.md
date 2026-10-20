# IPTV Pro

Android ve Windows için Xtream Codes uyumlu IPTV oynatıcı. Tek kod tabanı (Flutter), oynatma motoru libmpv (media_kit).

## Özellikler

- **Xtream Codes** girişi, birden fazla hesap
- Ana ekranda ayrı bölümler: **Canlı TV · Filmler · Diziler · Favoriler · Geçmiş · Ayarlar**
- **2K / 4K / 8K** oynatma: libmpv + donanım hızlandırma (Android MediaCodec, Windows D3D11); üstte çözünürlük rozeti (ör. `4K 3840×2160`)
- **MPEG-TS, HLS (m3u8), MP4, MKV** ve libmpv'nin desteklediği tüm biçimler; H.264/H.265/AV1
- Canlı yayında otomatik yeniden bağlanma, önceki/sonraki kanala geçiş
- **Kanal sıralama**: sunucu sırası, A→Z, Z→A, en yeni, **özel sıralama (sürükle-bırak)** — her kategori için ayrı kaydedilir
- **Favoriler** (canlı / film / dizi ayrı sekmeler)
- **İzleme geçmişi** + film/dizide **kaldığı yerden devam**
- **Yetişkin kilidi**: yetişkin kategoriler varsayılan olarak gizli; PIN (SHA-256 + tuz ile saklanır) ile açılır; uygulama arka plana alınınca otomatik kilitlenir; hangi kategorilerin yetişkin sayılacağını sen seçebilirsin. Kilitli kategoriler arama, favori ve geçmişte de görünmez.
- Ses / altyazı parçası seçimi, en-boy oranı, tam ekran

## Kurulum dosyalarını almak (bilgisayarına hiçbir şey kurmadan)

1. GitHub'da boş bir depo aç, bu klasörün içeriğini yükle (`main` dalına).
2. Deponun **Actions** sekmesinde **Build IPTV Pro** iş akışı otomatik çalışır (yaklaşık 15–25 dk).
3. Bittiğinde çalıştırmanın altındaki **Artifacts** bölümünden indir:
   - `IPTVPro-Android` → `app-release.apk` (tüm cihazlar) ve mimariye özel küçük APK'lar (`app-arm64-v8a-release.apk` çoğu modern telefon/TV kutusu için)
   - `IPTVPro-Windows` → `IPTVPro-Setup.exe` (kurulum sihirbazı) ve `IPTVPro-Windows-portable.zip` (kurulumsuz)

Android'de APK'yı açarken "bilinmeyen kaynaklardan yüklemeye izin ver" gerekir.

## Kendi bilgisayarında derlemek

```bash
# Flutter SDK (stable) kurulu olmalı
bash tool/setup_platforms.sh      # android/ ve windows/ klasörlerini üretir, izinleri ekler
flutter pub get
flutter run -d windows            # denemek için
flutter build apk --release       # Android
flutter build windows --release   # Windows (Visual Studio "Desktop development with C++" gerekir)
```

## Windows kısayolları

Boşluk: oynat/duraklat · F: tam ekran · M: sessiz · ↑/↓: önceki/sonraki kanal · ←/→: ±10 sn · Esc: geri

## Notlar

- Uygulama yalnızca senin kendi IPTV aboneliğindeki (Xtream Codes) içerikleri oynatır; kanal/içerik sağlamaz.
- 8K akışlar için cihazın 8K'yı donanımla çözebilmesi gerekir. Çoğu telefon/PC 8K HEVC/AV1'i yazılımla akıcı çözemez; bu durumda sorun uygulamada değil donanım sınırındadır.
- Ayarlar'dan canlı yayın formatını TS ↔ HLS değiştirebilirsin; bazı sunucular yalnızca birini sorunsuz verir.
