# GEEZUS — Praktikum Mobile

Versi ringkas aplikasi fitness gamifikasi untuk praktikum Flutter. Salinan ini mempertahankan tema Geezus, lalu menyederhanakan alur latihan agar aktivitas gym dicatat manual tanpa chatbot AI dan pelacakan GPS.

## Fitur versi praktikum

- Login, registrasi, sesi otomatis, dan logout.
- Catat latihan gym dengan nama latihan, beban, set, dan repetisi.
- Simpan riwayat latihan dan hitung volume/damage untuk Boss Battle.
- Penghitung langkah menggunakan sensor akselerometer.
- Pengingat hidrasi dan aktivitas.
- Boss Battle dan lencana pencapaian. Fitur klaim NFT masih simulasi, bukan transaksi blockchain sungguhan.
- Profil, konversi mata uang/zona waktu, serta saran dan kesan.

Versi ini tidak menyediakan AI Coach/Gemini, live run GPS, peta, atau pencarian rute. Menu dan permission lokasi juga sudah dihapus.

## Teknologi

- Flutter dan Dart
- Supabase Auth dengan penyimpanan sesi lokal
- SQLite untuk catatan latihan dan langkah
- SharedPreferences untuk pengaturan ringan
- `sensors_plus` untuk penghitung langkah
- `flutter_local_notifications` untuk pengingat

## Menjalankan

Pastikan Flutter SDK dan Android toolchain sudah terpasang. Dari direktori project:

```bash
flutter pub get
flutter run
```

Untuk Android, hubungkan perangkat dengan USB debugging aktif atau gunakan emulator Android.

## Konfigurasi Supabase

File `.env.example` berisi variabel yang diperlukan. Salin menjadi `.env`, lalu isi URL project Supabase dan anon key:

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
```

Jangan commit `.env` yang berisi kredensial ke repository. Aplikasi masih memiliki fallback konfigurasi lokal di `lib/main.dart`; konfigurasi `.env` akan dipakai jika tersedia.

## Penyimpanan lokal

Data latihan disimpan pada tabel SQLite `gym_logs`, sedangkan penghitung langkah disimpan pada `step_counter`. Tabel riwayat lari lama tetap ada untuk kompatibilitas data lokal, tetapi versi ini tidak lagi mencatat lari GPS dan damage Boss Battle hanya dihitung dari volume latihan gym.
