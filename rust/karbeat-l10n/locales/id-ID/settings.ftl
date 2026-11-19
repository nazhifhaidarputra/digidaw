## Language

settings-language-title = Bahasa
settings-language-field = Bahasa aplikasi
settings-language-system = Bawaan sistem ({ $language })
settings-language-help = Mengubah bahasa menu, dialog, dan pesan. Nama parameter plugin tetap memakai nama dari plugin-nya.
settings-language-change-title = Ganti bahasa?
settings-language-change-warning = Anda akan mengganti bahasa aplikasi. Ingat letak menunya agar Anda tidak tersesat dalam terjemahan. Apakah Anda yakin ingin mengganti bahasa?
settings-language-change-confirm = Ganti bahasa
settings-language-change-failed = Tidak dapat mengganti bahasa
settings-language-load-failed = Tidak dapat memuat pengaturan bahasa

## Settings screen

settings-title = Pengaturan
settings-close = Tutup pengaturan
settings-page-placeholder = Halaman pengaturan ini akan dibuat pada tahap berikutnya.
settings-menu-general = Umum
settings-menu-general-description = Atur perilaku aplikasi secara umum, seperti penyimpanan riwayat urungkan.
settings-menu-host-devices = Host & Perangkat
settings-menu-host-devices-description = Pilih host audio dan perangkat keluaran. Perangkat masukan belum didukung.
settings-menu-project = Proyek
settings-menu-project-description = Sunting metadata yang tersimpan bersama proyek saat ini.
settings-menu-appearance = Tampilan
settings-menu-appearance-description = Sesuaikan tema, warna, latar belakang, dan tipografi aplikasi.
settings-menu-audio = Audio
settings-menu-audio-description = Atur sample rate dan ukuran blok pemrosesan DSP.
settings-menu-key-bindings = Pintasan Keyboard
settings-menu-key-bindings-description = Tinjau dan sesuaikan pintasan keyboard aplikasi.
settings-menu-plugins = Plugin
settings-menu-plugins-description = Pengaturan pencarian dan hosting plugin pihak ketiga.
settings-menu-logs = Log
settings-menu-logs-description = Atur diagnostik dan periksa log aplikasi terbaru.
settings-menu-info = Info
settings-menu-info-description = Lihat versi aplikasi, lisensi, dan informasi pelaporan bug.

## General

settings-general-history-limit = Jumlah maksimum riwayat urungkan
settings-general-history-entries = { $count } entri
settings-general-history-help = Nilai yang lebih kecil memakai lebih sedikit memori. Menurunkan batas langsung menghapus entri urungkan dan ulangi yang paling lama. Memilih Nonaktif mengosongkan kedua riwayat.
settings-general-auto-save = Simpan otomatis
settings-general-auto-save-enable = Aktifkan simpan otomatis
settings-general-auto-save-interval = Simpan otomatis setiap
settings-general-auto-save-help = Simpan otomatis menulis salinan pemulihan dari perubahan yang belum disimpan. Salinan ini tidak pernah menimpa file proyek Anda; setelah crash, { -app-name } menawarkan untuk memulihkannya saat dibuka berikutnya.
settings-general-interval-seconds = { $count } detik
settings-general-interval-minutes = { $count } menit
settings-general-folders = Folder
settings-general-project-folder = Folder proyek bawaan
settings-general-project-folder-unset = Belum diatur. Dialog simpan dan buka dimulai di lokasi pilihan sistem.
settings-general-project-folder-choose = Pilih folder proyek bawaan
settings-general-export-folder = Folder ekspor bawaan
settings-general-export-folder-unset = Belum diatur. Pilih folder untuk setiap ekspor.
settings-general-export-folder-choose = Pilih folder ekspor bawaan
settings-general-folder-missing = Folder ini sudah tidak ada, jadi tidak dipakai.
settings-general-recent-projects = Proyek terbaru
settings-general-recent-projects-show = Tampilkan proyek terbaru
settings-general-recent-projects-help = Menampilkan proyek yang baru dibuka di bawah Buka terbaru pada menu Proyek. Menyembunyikannya tetap menyimpan daftarnya.
settings-general-load-failed = Tidak dapat memuat pengaturan
settings-general-history-apply-failed = Tidak dapat menerapkan batas riwayat
settings-general-history-update-failed = Tidak dapat memperbarui batas riwayat
settings-general-history-not-saved = Batas riwayat diterapkan tetapi tidak disimpan
settings-general-auto-save-load-failed = Tidak dapat memuat pengaturan simpan otomatis
settings-general-auto-save-apply-failed = Tidak dapat menerapkan pengaturan simpan otomatis
settings-general-auto-save-update-failed = Tidak dapat memperbarui simpan otomatis
settings-general-auto-save-not-saved = Simpan otomatis diterapkan tetapi tidak disimpan
settings-general-folder-choose-failed = Tidak dapat memilih folder
settings-general-folder-save-failed = Tidak dapat menyimpan folder
settings-general-recent-projects-save-failed = Tidak dapat menyimpan pengaturan proyek terbaru

## Audio

settings-audio-description = Pengaturan DSP mengatur worker pemrosesan khusus. Nilai stream perangkat hanya-baca dan boleh berbeda dengan aman.
settings-audio-sample-rate = Sample rate DSP
settings-audio-hertz = { $value } Hz
settings-audio-block-size = Ukuran blok DSP
settings-audio-frames = { $count } frame
settings-audio-block-latency = Satu blok DSP mewakili sekitar { $milliseconds } ms. Blok yang lebih kecil mengurangi latensi pemrosesan tetapi menambah beban penjadwalan CPU.
settings-audio-applying = Menerapkan…
settings-audio-revert = Kembalikan
settings-audio-metronome = Suara metronom
settings-audio-metronome-default = Klik bawaan
settings-audio-metronome-choose = Pilih suara
settings-audio-metronome-use-default = Pakai bawaan
settings-audio-metronome-help = Suara Anda diputar apa adanya pada ketukan lemah dan satu oktaf lebih tinggi pada ketukan pertama. Setiap ketukan memotong sisa ketukan sebelumnya.
settings-audio-device-stream = Stream perangkat (hanya-baca)
settings-audio-device-stream-starting = Stream perangkat aktif sedang dimulai.
settings-audio-device-output = Keluaran: { $device }
settings-audio-device-sample-rate = Sample rate perangkat: { $value } Hz
settings-audio-device-buffer = Buffer callback perangkat: { $count } frame
settings-audio-device-channels = Kanal: { $count }
settings-audio-reset-title = Pengaturan DSP diatur ulang
settings-audio-reset-message = Nilai DSP tersimpan yang tidak didukung dikembalikan ke bawaan.
settings-audio-initialize-failed = Tidak dapat menyiapkan pengaturan DSP
settings-audio-apply-failed = Tidak dapat menerapkan pengaturan DSP
settings-audio-not-saved = Pengaturan DSP diterapkan tetapi tidak disimpan

## Host & Devices

settings-host-description = Pilih ke mana audio diputar dan dari perangkat mana trek audio merekam.
settings-host-audio-host = Host audio
settings-host-system-default = Bawaan sistem
settings-host-output-device = Perangkat keluaran
settings-host-system-default-output = Keluaran bawaan sistem
settings-host-current-default = { $device } (bawaan saat ini)
settings-host-audio-input = Masukan audio
settings-host-input-enable = Aktifkan masukan audio
settings-host-input-help = Memungkinkan trek audio merekam dan memantau perangkat masukan. Mempersenjatai trek akan menyalakannya.
settings-host-input-device = Perangkat masukan
settings-host-system-default-input = Masukan bawaan sistem
settings-host-input-retry = Cari ulang perangkat masukan
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } kanal
settings-host-retry = Cari ulang
settings-host-fallback-active = { $reason } Keluaran bawaan sistem sedang aktif.
settings-host-active-stream = Stream perangkat aktif
settings-host-active-stream-summary = { $rate } Hz · { $frames } frame · { $channels } kanal
settings-host-output-load-failed = Tidak dapat memuat pengaturan keluaran
settings-host-input-load-failed = Tidak dapat memuat pengaturan masukan
settings-host-discover-hosts-failed = Tidak dapat menemukan host audio
settings-host-saved-host-unavailable = Host audio yang tersimpan tidak tersedia.
settings-host-saved-output-unavailable = Perangkat keluaran yang tersimpan tidak tersedia.
settings-host-output-fallback-title = Keluaran audio cadangan
settings-host-output-fallback-message = { $reason } Memakai keluaran bawaan sistem.
settings-host-input-enabled-not-saved = Masukan audio dinyalakan tetapi tidak disimpan
settings-host-input-fallback-title = Masukan audio cadangan
settings-host-input-fallback-message = Perangkat masukan yang tersimpan tidak tersedia. Memakai masukan bawaan sistem.
settings-host-input-change-failed = Tidak dapat mengubah masukan audio
settings-host-input-not-saved = Masukan audio diubah tetapi tidak disimpan
settings-host-discover-outputs-failed = Tidak dapat menemukan perangkat keluaran
settings-host-output-change-failed = Tidak dapat mengubah keluaran audio
settings-host-output-not-saved = Keluaran audio diubah tetapi tidak disimpan

## Project

settings-project-image-open-failed = Tidak dapat membuka gambar
settings-project-cover-save-failed = Tidak dapat menyimpan sampul
settings-project-updated = Informasi proyek diperbarui
settings-project-title = Judul
settings-project-title-required = Judul wajib diisi
settings-project-author = Pembuat
settings-project-author-help = Pisahkan beberapa artis dengan ;
settings-project-genre = Genre
settings-project-version = Versi proyek
settings-project-description = Deskripsi
settings-project-created-at = Dibuat pada
settings-project-saving = Menyimpan…
settings-project-save = Simpan info proyek
settings-project-cover = Sampul
settings-project-cover-help = Gambar persegi yang disematkan ke audio hasil ekspor
settings-project-cover-choose = Pilih gambar…
settings-project-cover-replace = Ganti…
settings-project-changed-banner = Proyek saat ini berubah selagi formulir ini memiliki suntingan yang belum disimpan.
settings-project-keep-edits = Pertahankan suntingan
settings-project-reload = Muat ulang proyek

## Appearance

settings-appearance-color-theme = Tema warna
settings-appearance-load-theme = Muat tema JSON
settings-appearance-color-theme-help = Tema warna yang dipilih menentukan kecerahan dan warnanya sendiri. Pilih Bawaan untuk memakai mode tema dan palet aksen.
settings-appearance-theme-mode = Mode tema
settings-appearance-mode-system = Sistem
settings-appearance-mode-light = Terang
settings-appearance-mode-dark = Gelap
settings-appearance-accent = Palet aksen
settings-appearance-background = Latar belakang ruang kerja
settings-appearance-background-default = Latar belakang bawaan
settings-appearance-background-choose = Pilih gambar
settings-appearance-background-fit = Penyesuaian gambar
settings-appearance-overlay = Lapisan gelap: { $percent }%
settings-appearance-font = Font aplikasi
settings-appearance-font-system = Font sistem
settings-appearance-font-choose = Pilih TTF atau OTF
settings-appearance-font-use-system = Pakai font sistem
settings-appearance-assets-help = Aset kustom tetap berada di lokasi file aslinya. Jika file dipindahkan atau dihapus, { -app-name } dengan aman memakai bawaan lagi.
settings-appearance-theme = Tema
settings-appearance-theme-remove = Hapus tema
settings-appearance-theme-remove-title = Hapus tema warna?
settings-appearance-theme-remove-message = “{ $name }” akan dihapus dari menu tema.{ $active ->
    [yes] {" "}Tema ini sedang aktif, jadi { -app-name } kembali ke tema Bawaan.
   *[no] {""}
}

    File { $file } tidak dihapus. Anda dapat memuatnya lagi dengan Muat tema JSON.
settings-appearance-palette-purple = Ungu
settings-appearance-palette-blue = Biru
settings-appearance-palette-teal = Hijau kebiruan
settings-appearance-palette-orange = Oranye
settings-appearance-palette-red = Merah
settings-appearance-palette-green = Hijau
settings-appearance-palette-pink = Merah muda
settings-appearance-palette-cyan = Sian
settings-appearance-palette-indigo = Nila
settings-appearance-palette-amber = Kuning amber
settings-appearance-palette-lime = Hijau limau
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Grafit
settings-appearance-fit-cover = Tutupi
settings-appearance-fit-contain = Muat
settings-appearance-fit-fill = Isi
settings-appearance-load-failed = Tidak dapat memuat pengaturan tampilan
settings-appearance-background-unavailable-title = Gambar latar belakang tidak tersedia
settings-appearance-background-unavailable-message = Gambar latar belakang yang tersimpan tidak tersedia. Latar belakang bawaan sedang dipakai.
settings-appearance-font-unavailable-title = Font kustom tidak tersedia
settings-appearance-font-unavailable-message = Font kustom yang tersimpan tidak tersedia. Font sistem sedang dipakai.
settings-appearance-theme-unavailable-title = Tema warna tidak tersedia
settings-appearance-theme-unavailable-message = { $count } file tema warna tersimpan tidak tersedia atau sudah tidak valid, dan telah dihapus dari menu tema.
settings-appearance-theme-apply-failed = Tidak dapat menerapkan tema warna
settings-appearance-theme-choose-failed = Tidak dapat memilih tema warna
settings-appearance-theme-load-failed = Tidak dapat memuat tema warna
settings-appearance-theme-remove-failed = Tidak dapat menghapus tema warna
settings-appearance-background-choose-failed = Tidak dapat memilih gambar latar belakang
settings-appearance-font-choose-failed = Tidak dapat memilih font
settings-appearance-font-load-failed = Tidak dapat memuat font
settings-appearance-not-saved = Tampilan diubah tetapi tidak disimpan

## Key bindings

settings-keys-search = Cari perintah
settings-keys-reset-all = Atur ulang semua
settings-keys-no-match = Tidak ada perintah yang cocok dengan pencarian ini.
settings-keys-capture-hint = { $hint } Escape membatalkan perekaman tombol.
settings-keys-reset-all-title = Atur ulang semua pintasan?
settings-keys-reset-all-message = Setiap perintah akan kembali ke kombinasi tombol bawaannya.
settings-keys-default = Bawaan: { $chord }
settings-keys-reset = Atur ulang { $command }
settings-keys-change = Ubah
settings-keys-change-title = Ubah { $command }
settings-keys-press = Tekan pintasan baru

## Plugins

settings-plugins-description = { -app-name } memuat katalog tersimpan saat dibuka. Pemindaian hanya berjalan bila diminta dan memeriksa setiap plugin di proses pembantu yang terisolasi.
settings-plugins-additional-folders = Folder pindai tambahan
settings-plugins-no-additional-folders = Belum ada folder tambahan.
settings-plugins-add-folder = Tambah folder
settings-plugins-system-folders = Folder pindai sistem
settings-plugins-no-system-folders = Tidak ada folder standar di platform ini.
settings-plugins-timeout = Batas waktu per plugin
settings-plugins-scanning = Memindai…
settings-plugins-scan-now = Pindai sekarang
settings-plugins-cancelling = Membatalkan…
settings-plugins-cancel-scan = Batalkan pemindaian
settings-plugins-retry-failed = Coba lagi plugin yang gagal/dikarantina
settings-plugins-preparing = Menyiapkan pemindaian…
settings-plugins-progress = { $completed } dari { $total } modul · { $count } plugin ditemukan
settings-plugins-scan-cancelled = Pemindaian dibatalkan. { $count } plugin dipertahankan.
settings-plugins-scan-complete = Pemindaian selesai. { $count } plugin ditemukan.
settings-plugins-failures = { $count } kegagalan pemindaian
settings-plugins-external-catalog = Katalog eksternal
settings-plugins-catalog-summary = { $available } tersedia, { $unavailable } tidak tersedia
settings-plugins-remove-folder = Hapus folder
settings-plugins-folder-choose = Pilih folder plugin
settings-plugins-initialize-failed = Tidak dapat menyiapkan pengaturan plugin
settings-plugins-folder-choose-failed = Tidak dapat memilih folder plugin
settings-plugins-save-failed = Tidak dapat menyimpan pengaturan plugin
settings-plugins-scan-failed = Pemindaian plugin gagal
settings-plugins-cancel-failed = Tidak dapat membatalkan pemindaian plugin

## Logs

settings-logs-description = Penampil ini berisi log aplikasi Flutter dan log mesin audio Rust. Setiap entri diberi label sumbernya.
settings-logs-capture-level = Tingkat perekaman
settings-logs-retained = Entri yang disimpan
settings-logs-search = Cari log
settings-logs-display-level = Tingkat tampilan
settings-logs-source = Sumber
settings-logs-source-all = Semua
settings-logs-resume = Lanjutkan tampilan
settings-logs-pause = Jeda tampilan
settings-logs-copy = Salin hasil filter
settings-logs-export = Ekspor hasil filter
settings-logs-count = { $shown } ditampilkan • { $captured }/{ $maximum } terekam{ $paused ->
    [yes] {" "}• tampilan dijeda
   *[no] {""}
}
settings-logs-empty = Tidak ada entri log yang cocok.
settings-logs-copy-failed = Tidak dapat menyalin log
settings-logs-copied = Log hasil filter disalin
settings-logs-export-failed = Tidak dapat mengekspor log
settings-logs-exported = Log diekspor ke { $path }
settings-logs-export-dialog = Ekspor log { -app-name }
settings-logs-clear-title = Hapus log yang terekam?
settings-logs-clear-message = Ini menghapus semua entri dari penampil di memori.
settings-logs-clear-confirm = Hapus log
settings-logs-load-failed = Tidak dapat memuat pengaturan log
settings-logs-not-saved = Pengaturan log diterapkan tetapi tidak disimpan

## Info

settings-info-description = { -app-name } adalah digital audio workstation lintas platform yang dibangun dengan Flutter dan Rust.
settings-info-application = Aplikasi
settings-info-version-unavailable = Informasi versi tidak tersedia.
settings-info-name = Nama
settings-info-version = Versi
settings-info-report-bug = Laporkan bug
settings-info-report-bug-help = Sertakan versi { -app-name }, sistem operasi, langkah untuk mereproduksi, hasil yang diharapkan, hasil sebenarnya, dan log yang relevan.
settings-info-copy-url = Salin URL laporan bug
settings-info-copy-url-failed = Tidak dapat menyalin URL
settings-info-url-copied = URL laporan bug disalin

## Cover art and file dialogs

settings-cover-crop-title = Pangkas sampul
settings-cover-crop-help = Seret untuk memindahkan, gulir atau cubit untuk memperbesar
settings-cover-crop-use = Pakai gambar
settings-project-cover-dialog = Pilih gambar sampul
settings-audio-metronome-dialog = Pilih suara metronom
settings-audio-metronome-setting-load-failed = Tidak dapat memuat pengaturan suara metronom
settings-audio-metronome-unavailable-title = Suara metronom tidak tersedia
settings-audio-metronome-unavailable-message = Suara metronom yang tersimpan tidak tersedia. Klik bawaan sedang dipakai.
settings-audio-metronome-choose-failed = Tidak dapat memilih suara metronom
settings-audio-metronome-load-failed = Tidak dapat memuat suara metronom
settings-audio-metronome-restore-failed = Tidak dapat mengembalikan suara metronom bawaan
settings-audio-metronome-not-saved = Suara metronom diubah tetapi tidak disimpan
settings-appearance-background-dialog = Pilih latar belakang ruang kerja
settings-appearance-font-dialog = Pilih font aplikasi
settings-appearance-theme-dialog = Pilih tema warna
settings-appearance-theme-too-large = File tema warna lebih besar dari 1 MB

## Color theme files

settings-theme-invalid = Tema warna tidak valid:
settings-theme-invalid-json = File ini bukan JSON yang valid: { $reason }
settings-theme-not-object = Tema harus berupa objek JSON.
settings-theme-unknown-field = Field "{ $field }" tidak dikenal.
settings-theme-missing-field = "{ $field }" tidak ada.
settings-theme-colors-not-object = "colors" harus berupa objek berisi peran warna.
settings-theme-name-not-text = "name" harus berupa teks.
settings-theme-name-empty = "name" tidak boleh kosong.
settings-theme-name-too-long = "name" paling banyak { $maximum } karakter.
settings-theme-brightness-invalid = "brightness" harus "light" atau "dark".
settings-theme-missing-color = Warna wajib "{ $role }" tidak ada.
settings-theme-color-invalid = Warna "{ $role }" harus ditulis sebagai "#RRGGBB" atau "#RRGGBBAA".
settings-theme-unknown-color = Warna "{ $role }" tidak dikenal.
