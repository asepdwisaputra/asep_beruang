# Asep Beruang

Aplikasi pencatatan keuangan pribadi Android yang offline-first, dibangun dengan Flutter, Provider, dan SQLite.

## Fitur MVP

- Ringkasan saldo dompet aktif, pemasukan, pengeluaran, budget, dan streak harian.
- Transaksi pengeluaran/pemasukan dan transfer internal dengan pembaruan saldo atomik.
- Peringatan sebelum transaksi membuat saldo dompet negatif.
- Budget per kategori dengan carry-over bulanan yang dapat diedit atau dihapus.
- Dompet dan kategori dengan penghapusan aman untuk data yang sudah memiliki riwayat.
- Ekspor laporan `.xlsx` empat sheet ke folder `Download` melalui Android MediaStore.
- Data contoh awal: satu dompet tunai dan kategori pemasukan/pengeluaran.

## Menjalankan aplikasi

Perlu Flutter stable dan Android SDK. ID paket aplikasi: `com.asepberuang.app`.

```powershell
flutter pub get
flutter run
```

Ekspor langsung ke `Download` memerlukan Android 10 atau lebih baru.

## Validasi

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
