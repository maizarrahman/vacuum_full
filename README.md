# vacuum_full
Vacuum Full di PostgreSQL hanya tabel berukuran ~1GB oleh user postgres.
Sebelum vacuum dilakukan, dicek dulu sisa disk dan jam pelaksanaan.
Jika sisa disk kurang dari besar tabel maka vacuum dibatalkan.
Asumsi: vacuum dilaksanakan mulai jam 00.00, sehingga dibatasi hingga jam 05.00
