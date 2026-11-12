## Startup

app-settings-reset-title = Pengaturan diatur ulang
app-settings-reset-message = Pengaturan di { $file } tidak dapat dibaca ({ $reason }). Nilai bawaan dipakai; file lama disimpan sebagai { $backup }.

## Crash recovery

app-crash-recovery-unavailable = Pemulihan crash tidak tersedia
app-crash-discard-failed = Tidak dapat membuang proyek yang dipulihkan
app-crash-report-export-failed = Tidak dapat mengekspor laporan
app-crash-report-saved = Laporan disimpan
app-crash-report-exported = Laporan crash diekspor ke { $path }
app-crash-reports-delete-failed = Tidak dapat menghapus laporan crash

## Timeline

app-timeline-loop-set-failed = Tidak dapat mengatur wilayah loop
app-timeline-loop-clear-failed = Tidak dapat menghapus wilayah loop
app-timeline-cue-add-failed = Tidak dapat menambah penanda cue
app-timeline-cue-remove-failed = Tidak dapat menghapus penanda cue
app-timeline-cue-edit-failed = Tidak dapat menyunting penanda cue
app-timeline-bounce-failed = Tidak dapat me-render wilayah loop
app-timeline-bounced-title = Di-render ke sumber baru
app-timeline-bounced-message = Wilayah loop sekarang ada di daftar sumber.

## Background work

app-job-cancelled = Tugas latar belakang { $id } dibatalkan.
app-job-failed = Tugas latar belakang gagal
app-blocking-timeout-title = Operasi melewati batas waktu
app-blocking-timeout-message = “{ $task }” tidak selesai dalam { $seconds } detik dan dilepas; tugas ini tetap berjalan di latar belakang.
app-blocking-cancelled = “{ $task }” dibatalkan sebelum dimulai.
app-blocking-failed = Operasi gagal

## Recording

app-recording-arm-failed = Tidak dapat menyiapkan trek untuk merekam
app-recording-input-on-title = Masukan audio menyala
app-recording-input-on-message = Masukan audio tadinya mati, jadi dinyalakan. Ubah perangkat masukan di Pengaturan.
app-recording-nothing-title = Tidak ada yang direkam
app-recording-nothing-message = Pilih trek audio untuk merekam.
app-recording-save-failed = Tidak dapat menyimpan rekaman
app-recordings-save-failed = Tidak dapat menyimpan rekaman-rekaman

## Project

app-project-recover-failed = Tidak dapat memulihkan proyek
app-project-audio-load-failed = Tidak dapat memuat audio
app-project-source-delete-failed = Tidak dapat menghapus sumber audio
app-project-pattern-delete-failed = Tidak dapat menghapus pola
app-project-info-update-failed = Tidak dapat memperbarui informasi proyek
app-project-undo-failed = Tidak dapat mengurungkan
app-project-redo-failed = Tidak dapat mengulangi
app-project-refresh-failed = { $action }: gagal menyegarkan proyek
app-project-instrument-rename-failed = Tidak dapat mengganti nama instrumen
app-project-trim-failed = Tidak dapat memangkas audio
app-project-envelope-edit-failed = Tidak dapat menyunting envelope waveform
app-project-saved-title = Proyek disimpan
app-project-saved-message = Proyek berhasil disimpan ke { $path }

## Automation targets

app-automation-missing-effect = Efek hilang
app-automation-sampler = Sampler
app-automation-missing-instrument = Instrumen hilang
app-automation-track = Trek
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transport
app-automation-other-group = Lainnya

## Tracks

app-tracks-input-change-failed = Tidak dapat mengubah masukan trek
app-tracks-samples-audio-only = Sampel audio hanya bisa dijatuhkan ke trek audio
app-tracks-move-type-mismatch = Klip { $source ->
    [audio] audio
    [midi] MIDI
   *[automation] otomasi
} tidak dapat dipindahkan ke trek { $target ->
    [audio] audio
    [midi] MIDI
   *[automation] otomasi
}

## Mixer channel templates

app-mixer-template-save-failed = Tidak dapat menyimpan templat kanal
app-mixer-template-saved = Templat kanal disimpan ke { $path }
app-mixer-template-load-failed = Tidak dapat memuat templat kanal
app-mixer-template-loaded = Templat kanal dimuat
app-mixer-template-skipped = Plugin yang tidak tersedia dilewati: { $plugins }

## Menu bar

app-menu-project = Proyek
app-menu-new-project = Proyek baru
app-menu-open-project = Buka proyek
app-menu-open-recent = Buka terbaru
app-menu-save-project = Simpan Proyek
app-menu-save-as = Simpan Sebagai...
app-menu-import-audio = Impor Audio
app-menu-export-project = Ekspor Proyek
app-menu-settings = Pengaturan
app-menu-quit = Keluar dari { -app-name }
app-menu-edit = Sunting
app-menu-undo = Urungkan
app-menu-redo = Ulangi
app-menu-view = Tampilan
app-menu-zoom-in = Perbesar
app-menu-zoom-out = Perkecil
