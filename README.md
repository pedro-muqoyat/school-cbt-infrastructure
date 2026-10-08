# Setup Infrastruktur CBT (Computer-Based Test)

Repositori ini berisi rancangan *Infrastructure-as-Code* (IaC) dan cetak biru kontainerisasi tingkat produksi yang dirancang untuk menjalankan **Extraordinary CBT (ExoCbt)**. Arsitektur ini dioptimalkan untuk menangani hingga **1.000 siswa konkuren** secara bersamaan selama ujian massal sekolah dengan *downtime* nol, efisiensi sumber daya maksimal, dan pengerasan keamanan (*security hardening*) yang ketat.

## Arsitektur Sistem & Komponen

Infrastruktur ini diorkestrasi menggunakan **Docker Compose** dalam jaringan jembatan (*bridge network*) yang terisolasi, memisahkan logika aplikasi inti dari lapisan database:

- **Application Server:** Mesin Utama Extraordinary CBT, berjalan di dalam **Google Distroless Container** (berbasis Debian 11) yang aman untuk meminimalkan permukaan serangan (*attack surface*) dan mengurangi ukuran *image*.
- **Database Engine:** **PostgreSQL 15 (Alpine Linux)** yang dikonfigurasi khusus untuk transaksi baca/tulis bervolume tinggi (`shared_buffers=2GB`, `max_connections=300`).
- **Ingress & Security Proxy:** **Cloudflare Tunnel (`cloudflared`)** yang bertindak sebagai konektor aplikasi keluar (*outbound*) yang aman.

---

## Mengapa Menggunakan Cloudflare Tunnel (`cloudflared`)?

Alih-alih menggunakan *setup reverse proxy* tradisional seperti Nginx dengan membuka port masuk (80/443), arsitektur ini mengarahkan semua lalu lintas ujian sekolah melalui **Cloudflare Tunnel**. Berikut adalah alasan struktural, arsitektural, dan keamanan di balik pilihan desain ini:

### 1. Menghilangkan Port Masuk Terbuka (Zero Inbound Firewalls)
Setup tradisional memaksa Anda membuka port publik pada VPS, membuat server rentan terhadap pemindai port otomatis (*port scanners*) dan serangan *brute-force*. `cloudflared` bekerja dengan membuat **koneksi keluar saja (outbound-only)** ke jaringan global Cloudflare. Server Anda sepenuhnya menyembunyikan IP publik aslinya dari internet, sehingga bertindak sebagai infrastruktur siluman (*ghost infrastructure*).

### 2. Perlindungan DDoS Bawaan untuk Ujian Massal
Saat ujian sekolah berlangsung, 1.000 siswa akan melakukan *login* secara bersamaan. Lonjakan lalu lintas ini menyerupai pola serangan Layer 7 DDoS. Dengan menyalurkan lalu lintas melalui Cloudflare Tunnel, lonjakan data yang masif atau upaya *scraping* berbahaya akan diredam terlebih dahulu oleh jaringan edge global Cloudflare sebelum menyentuh sumber daya komputasi VPS Hostinger Anda.

### 3. Mitigasi Overhead SSL/CORS Secara Total
Mengelola sertifikat Let's Encrypt, pembaruan otomatis, dan konfigurasi CORS Nginx yang rumit di dalam kontainer dapat menambah beban pemeliharaan (*maintenance overhead*) dan potensi kegagalan sistem saat jam ujian. Cloudflare menangani terminasi SSL/TLS di sisi *edge* secara bawaan, memastikan lalu lintas HTTPS yang terenkripsi mengalir lancar langsung ke dalam jaringan Docker *backend*.

### 4. Melewati Batasan ISP & Port Kustom
Banyak jaringan sekolah atau perumahan memblokir port non-standar atau tidak memiliki IP publik statis yang didedikasikan. Karena Cloudflare Tunnel memulai koneksi dari dalam server ke luar, sistem ini dapat melewati firewall jaringan yang ketat dan lingkungan NAT dengan mudah, memastikan ketersediaan tinggi (*high availability*) dalam kondisi infrastruktur apa pun.

---

## Manajemen & Batasan Sumber Daya (Resource Limits)

Untuk memastikan stabilitas sistem di bawah beban kerja yang berat, batasan CPU dan memori diterapkan secara ketat pada setiap kontainer guna menghindari kegagalan sistem akibat kehabisan memori (*Out-of-Memory kernel panics*):

| Layanan Kontainer | Batasan CPU | Batasan RAM | Tujuan / Konfigurasi |
| :--- | :--- | :--- | :--- |
| `db_cbt` (PostgreSQL) | 0.90 Core | 4 GB | Dioptimalkan untuk caching kueri & pengindeksan agresif |
| `app_cbt` (ExoCbt) | 1.00 Core | 4 GB | Mesin aplikasi throughput tinggi di belakang proxy |
| `cloudflared_tunnel` | 0.10 Core | 128 MB | Daemon ringan yang mengarahkan lalu lintas jaringan edge |

---

## Panduan Memulai Deployment Cepat

### Prasyarat
- Docker Engine & Docker Compose CLI sudah terinstal.
- VPS atau lingkungan Linux Server (Ubuntu 24.04 LTS / Debian 13).
- Akun Cloudflare yang valid dengan Token Tunnel Zero Trust yang sudah dikonfigurasi.

### Langkah Instalasi

1. **Klon repositori ini:**
   ```bash
   git clone https://github.com
   cd school-cbt-infrastructure
   ```

2. **Siapkan Environment Variables:**
   Salin file template aman dan isi dengan rahasia operasional Anda (Kunci Lisensi, Password DB, Token Cloudflare):
   ```bash
   cp .env.example .env
   nano .env
   ```

3. **Inisialisasi Dump Database:**
   Tempatkan file inisialisasi struktur database awal Anda di dalam direktori berikut:
   ```bash
   mv exo-dump-master.sql ./db-init/
   ```

4. **Jalankan Stack Produksi:**
   Bangun *image* aplikasi kustom dan jalankan seluruh layanan dalam mode latar belakang (*detached daemon mode*):
   ```bash
   docker compose up --build -d
   ```

5. **Verifikasi Stabilitas & Kesehatan Aplikasi:**
   Pantau log kontainer aplikasi secara langsung untuk memastikan evaluasi lisensi berjalan valid dan status mesin melaporkan sehat:
   ```bash
   docker logs app_cbt -f
   ```

---

## Penulis
- **Lifani** - *DevOps & Systems Administrator* - [Profil GitHub](https://github.com/pedro-muqoyat)
