# Database Hellbound

Jalankan migrasi sekali dan berurutan melalui SQL Editor Supabase:

1. `migrations/202611180001_hellbound_schema.sql`: tabel, Auth trigger, RLS, dan bucket privat. Lewati jika sudah dipasang.
2. `migrations/202611180002_pact_workflows.sql`: RPC pembuatan, persetujuan, bukti, verifikasi, konsekuensi, dan policy Storage.

3. `migrations/202611210003_creator_auto_accept.sql`: pembuat pact otomatis menerima; memperbarui pact lama yang masih menunggu persetujuan pembuat.

Semua migrasi memakai transaksi. Jangan menjalankan ulang migrasi yang sudah berhasil; skrip bukan reset database dan tidak menghapus data. Untuk database dengan skema berbeda, periksa kecocokan terlebih dahulu.

Flutter memakai publishable key dan sesi Supabase Auth. Jangan masukkan secret/service-role key ke aplikasi. Profil menggunakan tabel `user`; email/password dikelola Auth. Peserta memakai UUID sehingga username yang sama tidak tertukar.

RPC memvalidasi peran dan mengunci pact selama perubahan. Pembuat pact otomatis dianggap menerima. Peserta lainnya harus menerima sebelum pact aktif. Hanya responsible yang dapat mengirim bukti sebelum deadline, dan hanya verifier yang dapat menerima/menolaknya. Penolakan menjalankan konsekuensi sekali. Bukti tepat waktu tetap menunggu verifikasi walaupun deadline sudah lewat.

Foto disimpan di bucket privat `pact-evidence`, maksimal 10 MiB, PNG/JPEG/WebP. Path disimpan di tabel; foto hanya bisa dibaca pengunggah serta pembuat/peserta pact. Wall of Shame hanya menampilkan pengumuman dengan audience komunitas yang telah disetujui peserta.

Saat aplikasi memuat/refresh, server memeriksa pact aktif yang lewat deadline dan membuat pengingat untuk deadline 24 jam ke depan. Preferensi undangan, pengingat, dan hasil verifikasi dipakai saat membuat notifikasi. Belum ada cron/push/background worker: pemeriksaan deadline dan pengingat tidak berjalan saat tidak ada pengguna yang membuka/refresh aplikasi. Ban tetap berupa simulasi dalam Hellbound, bukan pemblokiran aplikasi perangkat.

## Validasi

`tests/workflows.mjs` menguji kedua migrasi pada PGlite (PostgreSQL lokal), memakai stub schema Auth/Storage. Pengujian mencakup pembuatan akun, alur pact, pembatasan peran, RLS pengguna luar, dan larangan update status langsung. Ini bukan pengujian layanan Supabase Auth/Storage di project produksi.

Dari root project:

```sh
check_dir=$(mktemp -d)
npm install --prefix "$check_dir" @electric-sql/pglite
cp supabase/tests/workflows.mjs "$check_dir/workflows.mjs"
node "$check_dir/workflows.mjs"
```

Untuk tes layanan sebenarnya setelah migrasi dipasang: daftarkan dua akun milik penguji, konfirmasi email jika diminta, buat pact, terima undangan dari kedua akun, kirim bukti dari responsible, lalu verifikasi dari akun verifier. Refresh atau login ulang untuk memastikan data tersimpan. Jangan memakai service-role untuk tes akses pengguna.
