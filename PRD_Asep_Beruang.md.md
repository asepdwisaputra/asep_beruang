# Product Requirement Document (PRD): Asep Beruang

| Informasi Dokumen | Detail |
| :--- | :--- |
| **Nama Produk** | Asep Beruang |
| **Versi Rilis** | v1.0 (MVP) |
| **Platform** | Android (Offline-First) |
| **Tech Stack** | Flutter & SQLite (`sqflite`), Provider State Management, Package `excel` |
| **Maskot Utama** | Beruang Grizzly (Coklat / Brown Bear) dengan Ekspresi Dinamis |
| **Format Mata Uang** | Rupiah (IDR) — Pemisah ribuan titik (contoh: `Rp 1.000.000`) |
| **Status Dokumen** | **Approved & Production-Ready** |

---

## 1. Ringkasan Eksekutif & Tujuan Produk
**Asep Beruang** adalah aplikasi pencatatan keuangan pribadi dan *budgeting* berbasis Android yang bekerja 100% secara luring (*offline-first*). Aplikasi ini dirancang dengan pendekatan antarmuka yang ceria dan interaktif ala Duolingo untuk mengubah rutinitas mencatat keuangan menjadi kebiasaan (*habit*) yang menyenangkan.

**Tujuan Utama:**
1. Membangun kebiasaan mencatat arus kas harian secara konsisten melalui sistem *streak* dan reaksi maskot interaktif.
2. Memberikan visibilitas penuh atas saldo tiap dompet serta mutasi transfer internal tanpa merusak laporan arus kas.
3. Mengontrol pengeluaran bulanan melalui alokasi budget per kategori dengan indikator peringatan visual jika mendekati atau melewati batas (*over-budget*).
4. Menyediakan laporan keuangan mandiri dalam format Microsoft Excel (`.xlsx`) yang tersimpan langsung di folder *Download* perangkat menggunakan API modern Android.

---

## 2. Spesifikasi Desain UI/UX & Gamifikasi ("Duolingo-Vibe")
* **Gaya Visual:** *Playful*, sudut membulat (*rounded corners*), tombol dengan elevasi halus, dan animasi responsif (*bouncy*).
* **Maskot Beruang Grizzly & Ekspresi Dinamis (di Dashboard):**
  * **Senyum Lebar & Makan Madu:** Pengeluaran < 50% budget dan *streak* aktif aman.
  * **Mata Berbinar & Keringat Dingin:** Pengeluaran menyentuh 75% - 99% dari budget.
  * **Tidur/Pingsan Lucu (Mata Silang):** Ada kategori yang *over-budget* atau *streak* terputus.
* **Navigasi & Tombol Aksi Utama:**
  * **Bottom Navigation Bar** dengan **Floating Action Button (FAB) bundar besar berwarna kontras di tengah** (ikon `+`).
  * Saat diketuk, tombol tengah beranimasi *bouncy* dan memunculkan menu pilihan cepat: **Pengeluaran**, **Pemasukan**, atau **Transfer**.
* **Sistem Pencapaian (Badge) Lokal:**
  * Halaman lencana rahasia yang terbuka otomatis berdasarkan pencapaian pengguna (contoh: *Pencatat Pemula* untuk streak 3 hari, *Anti Jebol* untuk disiplin anggaran bulanan, dll).
* **Aksesibilitas & Kontras:** Indikator *over-budget* tidak hanya mengandalkan warna merah, melainkan didukung ikon peringatan eksplisit dan teks status yang jelas.

---

## 3. Spesifikasi Fungsional & Aturan Bisnis

### 3.1. Dashboard & Pelacakan Streak Harian
* **Ringkasan Saldo & Arus Kas:** Menampilkan total saldo gabungan seluruh dompet aktif, total pemasukan, dan total pengeluaran bulan berjalan.
* **Widget Maskot & Streak Counter:** Menampilkan jumlah hari beruntun pengguna aktif mencatat berdasarkan zona waktu lokal perangkat (`00:00–23:59`).
* **Tombol "Tidak Ada Pengeluaran Hari Ini":**
  * Mengamankan *streak* harian tanpa mengubah saldo dompet.
  * **Aturan Konflik Log:** Jika pagi hari tombol "Tidak Ada Pengeluaran" ditekan, namun malam harinya pengguna mencatat transaksi, status *daily log* otomatis ter-upgrade menjadi `transaction_recorded` (streak tetap sah `+1`, tidak duplikat).
* **Aturan Backdate Streak:** Pencatatan transaksi untuk tanggal lampau (*backdate*) akan memperbarui status *daily log* pada tanggal transaksi tersebut.

### 3.2. Pencatatan Transaksi & Mutasi Dompet
1. **Pengeluaran (Expense):** Mengurangi saldo dompet sumber, mencatat kategori dan tanggal.
2. **Pemasukan (Income):** Menambah saldo dompet tujuan, mencatat kategori dan tanggal.
3. **Transfer Antar Dompet (Transfer):** Memindahkan dana antar dompet. Wajib memvalidasi bahwa `amount > 0` dan `wallet_id != target_wallet_id`. Transaksi transfer dicatat sebagai mutasi internal dan **tidak** masuk ke dalam perhitungan grafik pemasukan/pengeluaran bulanan.
4. **Validasi Saldo Dompet Minus:** Jika pengeluaran/transfer melebihi saldo dompet, sistem akan memunculkan dialog peringatan (*"Saldo dompet tidak mencukupi. Lanjutkan transaksi dan biarkan saldo minus?"*). Pengguna dapat memilih untuk melanjutkan atau membatalkan.

### 3.3. Budgeting Bulanan, Total Budget, & Carry-Over
* **Alokasi Per Kategori:** Bersifat opsional. Unique constraint diberlakukan pada `(category_id, month_year)` agar tidak terjadi duplikasi budget dalam satu bulan.
* **Definisi Total Budget & Realisasi:**
  * **Total Budget:** Akumulasi dari seluruh nominal budget pada kategori yang di-set di bulan tersebut.
  * **Realisasi:** Hanya menghitung total pengeluaran pada kategori-kategori yang memiliki alokasi budget (mengabaikan pengeluaran di luar kategori ber-budget).
* **Auto-Carry Over Idempotent:** Saat tanggal berganti ke bulan baru, sistem secara otomatis menyalin alokasi budget bulan sebelumnya jika belum ada entri di bulan baru (idempotent untuk mencegah dobel insert saat aplikasi dibuka berkali-kali). Pengguna bebas melakukan **edit** atau **hapus** kapan saja.

### 3.4. Export Laporan Excel (.xlsx) Lokal
* **Penyimpanan Android Modern:** Menggunakan `path_provider` dan MediaStore API / SAF untuk menulis file `.xlsx` langsung ke folder `Download` publik perangkat tanpa memerlukan izin berbahaya `MANAGE_EXTERNAL_STORAGE`.
* **Struktur 4 Sheet di Dalam File Excel:**
  1. **Ringkasan:** Saldo akhir dompet aktif, total aset, total pemasukan/pengeluaran, selisih arus kas, dan status realisasi budget.
  2. **Daftar Pengeluaran:** Tanggal, Kategori, Dompet, Catatan, Nominal (format angka murni).
  3. **Daftar Pemasukan:** Tanggal, Kategori, Dompet, Catatan, Nominal (format angka murni).
  4. **Riwayat Transfer:** Tanggal, Dompet Asal, Dompet Tujuan, Catatan, Nominal (format angka murni).

### 3.5. Pengaturan Master Data (Soft Delete)
* **Manajemen Dompet & Kategori:** Pengguna dapat menambah, mengedit, atau menghapus dompet dan kategori.
* **Aturan Soft Delete (`is_active`):** Jika dompet atau kategori sudah memiliki riwayat transaksi, penghapusan dilakukan secara *soft delete* (`is_active = 0`). Data disembunyikan dari pilihan transaksi baru, namun tetap aman dan utuh tampil pada riwayat transaksi lama.

---

## 4. Arsitektur Teknis & Skema Database SQLite

* **State Management:** Provider.
* **Database Helper:** SQLite (`sqflite`) dengan eksekusi **Atomic Transaction** untuk setiap mutasi data (misal: Insert transaksi + Update `wallets.balance` dalam satu transaksi database tunggal agar tidak terjadi inkonsistensi saldo).

### Skema Tabel Utama:
1. **`wallets`**
   * `id` (INTEGER, PK, AI)
   * `name` (TEXT)
   * `balance` (INTEGER)
   * `icon` (TEXT)
   * `is_active` (INTEGER, default 1) — untuk soft delete
2. **`categories`**
   * `id` (INTEGER, PK, AI)
   * `name` (TEXT)
   * `type` (TEXT: `'expense'` / `'income'`)
   * `icon` (TEXT)
   * `color` (TEXT)
   * `is_active` (INTEGER, default 1) — untuk soft delete
3. **`transactions`**
   * `id` (INTEGER, PK, AI)
   * `type` (TEXT: `'expense'`, `'income'`, `'transfer'`)
   * `amount` (INTEGER)
   * `date` (TEXT, ISO-8601)
   * `wallet_id` (INTEGER, FK)
   * `target_wallet_id` (INTEGER, FK, Nullable)
   * `category_id` (INTEGER, FK, Nullable)
   * `note` (TEXT, Nullable)
4. **`budgets`**
   * `id` (INTEGER, PK, AI)
   * `category_id` (INTEGER, FK)
   * `amount_limit` (INTEGER)
   * `month_year` (TEXT, format `YYYY-MM`)
   * *Constraint:* `UNIQUE(category_id, month_year)`
5. **`daily_logs`**
   * `date` (TEXT, PK, format `YYYY-MM-DD`)
   * `status` (TEXT: `'transaction_recorded'` / `'no_expense_checked'`)

### Database Indexes (Optimalisasi Performa):
* `CREATE INDEX idx_trans_date ON transactions(date);`
* `CREATE INDEX idx_trans_wallet ON transactions(wallet_id);`
* `CREATE INDEX idx_trans_category ON transactions(category_id);`
* `CREATE INDEX idx_budget_cat_month ON budgets(category_id, month_year);`

---

## 5. First-Run Seed Data
Saat aplikasi pertama kali dibuka (*first-run*), sistem akan secara otomatis melakukan *seeding* data awal agar pengguna tidak mendapati layar kosong:
* **Dompet Default:** "Cash / Tunai" (Saldo awal Rp 0).
* **Kategori Default Pemasukan:** Gaji, Hadiah, Lain-lain.
* **Kategori Default Pengeluaran:** Makanan & Minuman, Transportasi, Belanja, Tagihan, Lain-lain.

---

## 6. Changelog & Roadmap
* **v1.0 (MVP Scope - Current):** Seluruh fitur inti pencatatan, transfer, budget per kategori, *streak* harian, *soft delete*, dan export Excel lokal.
* **v1.1 (Backlog / Future):** Penambahan fitur *Backup & Restore* file database lokal (`.db` / `.json`) secara manual sebagai opsi pengaman data tambahan.