## Ringkasan Rilis v1.2.0

Pembaruan **v1.2.0** untuk aplikasi **Karcis Parkir** menghadirkan penyempurnaan menyeluruh pada manajemen lokasi & profil tarif kustom, live persistent notification timer, quick actions, serta optimasi stabilitas sistem.

---

### Fitur Baru & Peningkatan Utama

#### 1. Template Lokasi Parkir & Auto-Detection Cerdas
- **Manajemen Template Lokasi**: Tambah, edit, dan kelola daftar lokasi favorit (misal Grand Indonesia, PIM, Stasiun, Bandara) lengkap dengan default tarif dan preset lantai/blok parkir.
- **Pendeteksian Lokasi Otomatis**: Secara otomatis mencocokkan hasil scan karcis atau input nama lokasi dengan template yang sudah tersimpan untuk mengisi skema tarif secara instan.
- **Quick Location Picker**: Memilih lokasi dari template langsung dari layar pemindaian / scan sebelum atau sesudah tiket dibuat.

#### 2. Aturan Tarif Parkir Kustom & Fleksibel
- **Multi-Type Rate Calculation**:
  - Tarif Flat (sekali bayar).
  - Tarif Per Jam (jam pertama vs jam berikutnya).
  - Tarif Progresif dengan tier bertingkat.
  - Batas Tarif Maksimal Harian (Daily Cap / Max Fee).
  - Grace Period (menit bebas bayar).
- **Dialog Edit Aturan Tarif**: Antarmuka intuitif untuk mengubah konfigurasi perhitungan biaya langsung per lokasi atau per tiket.

#### 3. Live Persistent Notification & Real-Time Parking Timer
- **Sticky Notification**: Notifikasi waktu nyata yang tetap aktif di status bar ponsel selama parkir masih berjalan tanpa tertutup oleh sistem.
- **Dynamic Timer & Quick Info**: Menampilkan durasi berjalan, nama lokasi, dan estimasi biaya terkini langsung dari notifikasi tanpa harus membuka aplikasi.
- **Quick Actions**: Tombol aksi langsung dari panel notifikasi (Buka Tiket, Lihat QR/Barcode, atau Selesaikan Parkir).

#### 4. Peningkatan Berbagi Tiket & Keamanan File (FileProvider)
- **Android FileProvider Path**: Integrasi path FileProvider yang aman untuk membagikan bukti fisik karcis dan kode barcode/QR ke aplikasi pihak ketiga (WhatsApp, Telegram, System Share Sheet) tanpa izin storage berlebih.
- **Dukungan Ekspor Bersih**: Peningkatan resolusi gambar barcode 1D dan QR saat diekspor.

#### 5. Optimasi Kinerja & Pengujian Menyeluruh
- 98 automated unit & widget tests yang mencakup kalkulasi tarif, integrasi scanner multi-format, navigasi notifikasi, dan pengelolaan template.

---

### Unduhan
- Unduh file `karcis-parkir-v1.2.0.apk` yang terlampir di bawah untuk memasang atau memperbarui aplikasi di perangkat Android Anda.
