# Hellbound

Aplikasi Flutter berdasarkan UI Figma Hellbound, menggunakan Supabase Auth, PostgreSQL, dan Storage. Data pact, peserta, bukti, profil, preferensi, notifikasi, serta konsekuensi berasal dari Supabase. State di Dart hanya menampung data tampilan dan isian formulir.

## Persiapan database

Ikuti urutan migrasi di [supabase/README.md](supabase/README.md). Migrasi kedua wajib agar operasi pact bisa dijalankan. Project URL dan publishable key saat ini dikonfigurasi langsung di `lib/main.dart`. Helper `supabase_connection.dart` dan konfigurasi dart-define lama belum digunakan oleh main saat ini.

## Menjalankan di Chrome

```sh
flutter pub get
flutter run -d chrome
```

Di VS Code dengan ekstensi Flutter/Dart, pilih **Hellbound (Chrome)** lalu tekan F5. Ini menjalankan Flutter Web di tab Chrome, bukan paket ekstensi browser.

Login/register menggunakan akun Supabase sebenarnya. Pembuatan pact membutuhkan minimal dua akun terdaftar. Gunakan tarik untuk refresh saat ingin mengambil pembaruan dari pengguna lain. Pemeriksaan deadline dan pengingat berjalan saat memuat/refresh, belum memakai scheduler. Ban merupakan simulasi dalam aplikasi.

## Struktur

- `lib/main.dart`: inisialisasi Supabase dan titik masuk.
- `lib/app.dart`: MaterialApp.
- `lib/hellbound.dart`: navigasi dan state tampilan.
- `lib/services/hellbound_repository.dart`: akses Auth, tabel, RPC, dan Storage.
- `lib/models/pact.dart`: model pact.
- `lib/screens/`: setiap view; login/register berbagi formulir.
- `lib/widgets/hellbound_components.dart`: komponen bersama.
- `lib/theme/`: tema dan palet.
- `assets/mascot/`: maskot asli.

Halaman menggunakan `part` dan extension builder untuk berbagi state privat. Form pembuatan pact merupakan StatefulWidget terpisah.
