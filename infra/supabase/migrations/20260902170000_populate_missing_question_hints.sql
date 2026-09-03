begin;

-- Populate contextual hints for any questions currently missing hints in public.questions.
update public.questions
set
  hint = case
    -- TIU & TKD: Verbal
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and lower(prompt) like '%sinonim%'
      then 'Cari kata yang memiliki makna sepadan atau arti inti yang paling dekat.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and (lower(prompt) like '%antonim%' or lower(prompt) like '%lawan%')
      then 'Cari kata yang maknanya paling berlawanan secara langsung.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and (lower(prompt) like '%hubungan konsep%' or lower(prompt) like '%analogi%' or lower(prompt) like '%setara%')
      then 'Identifikasi relasi fungsional atau pola hubungan khusus pada pasangan kata pertama.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and lower(prompt) like '%semua%' and lower(prompt) like '%kesimpulan%'
      then 'Gunakan hukum silogisme dan perhatikan cakupan kuantor serta diagram himpunan anggota.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and (lower(prompt) like '%penyaji%' or lower(prompt) like '%urutan%')
      then 'Petakan urutan pasti dan relasi posisi sebelum/sesudah antarsubjek secara bertahap.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal' and (lower(prompt) like '%memo%' or lower(prompt) like '%median%')
      then 'Bandingkan indikator perubahan secara objektif tanpa membuat asumsi di luar data.'
    when category in ('tiu', 'tkd') and subcategory = 'verbal'
      then 'Perhatikan arti kata dan konteks kalimat untuk menemukan jawaban yang paling tepat.'

    -- TIU & TKD: Numerik
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and lower(prompt) like '%diskon%'
      then 'Hitung potongan harga (persentase × harga awal) lalu kurangi dari harga awal.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and (lower(prompt) like '%persen%' or lower(prompt) like '%\%%' or lower(prompt) like '%kapasitas naik%')
      then 'Hitung nilai perubahan dari persentase terhadap nilai dasar, lalu sesuaikan dengan pertanyaan.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and (lower(prompt) like '%rasio%' or lower(prompt) like '%perbandingan%')
      then 'Tentukan nilai per satu bagian rasio dari total anggaran, lalu sesuaikan dengan proporsi baru.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and (lower(prompt) like '%petugas%' or lower(prompt) like '%pekerja%' or lower(prompt) like '%produktivitas%')
      then 'Gunakan prinsip perbandingan berbalik nilai: total beban kerja = jumlah pekerja × waktu.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and (lower(prompt) like '%rata-rata%' or lower(prompt) like '%skor%')
      then 'Hitung total seluruh nilai (rata-rata × jumlah data) lalu kurangi dengan nilai yang diketahui.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and lower(prompt) like '%deret%'
      then 'Perhatikan pola selisih atau rasio antarsuku yang bertambah secara teratur.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik' and (lower(prompt) like '%kecepatan%' or lower(prompt) like '%km/jam%' or lower(prompt) like '%tertunda%')
      then 'Gunakan rumus jarak = kecepatan × waktu dan perhitungkan waktu efektif perjalanan.'
    when category in ('tiu', 'tkd') and subcategory = 'numerik'
      then 'Lakukan perhitungan matematis secara terstruktur sesuai angka dan relasi pada soal.'

    -- TIU & TKD: Logis
    when category in ('tiu', 'tkd') and subcategory = 'logis' and lower(prompt) like '%berkas%' and lower(prompt) like '%urutan%'
      then 'Identifikasi posisi awal dan akhir yang sudah pasti, lalu tempatkan pasangan berkas yang harus berdampingan.'
    when category in ('tiu', 'tkd') and subcategory = 'logis' and lower(prompt) like '%jika%' and lower(prompt) like '%maka%'
      then 'Terapkan aturan Modus Ponens secara berantai dari premis pertama ke premis berikutnya.'
    when category in ('tiu', 'tkd') and subcategory = 'logis' and lower(prompt) like '%peserta%' and (lower(prompt) like '%menguasai%' or lower(prompt) like '%aplikasi%')
      then 'Gunakan rumus gabungan dua himpunan: total dikurangi jumlah yang menguasai setidaknya satu bagian.'
    when category in ('tiu', 'tkd') and subcategory = 'logis' and lower(prompt) like '%unit%' and lower(prompt) like '%dipilih%'
      then 'Mulai dari syarat mutlak (unit yang wajib dipilih) lalu eliminasi atau sertakan unit lainnya sesuai aturan.'
    when category in ('tiu', 'tkd') and subcategory = 'logis'
      then 'Analisis premis yang ada secara objektif untuk menarik kesimpulan yang pasti dan logis.'

    -- TIU & TKD: Figural
    when category in ('tiu', 'tkd') and subcategory = 'figural' and (lower(prompt) like '%panah%' or lower(prompt) like '%rotasi%')
      then 'Gunakan pola siklus 4 arah mata angin dan hitung sisa langkah setelah dibagi 4 (modulo 4).'
    when category in ('tiu', 'tkd') and subcategory = 'figural' and (lower(prompt) like '%lingkaran%' or lower(prompt) like '%titik%')
      then 'Pisahkan analisis siklus bentuk dan pola keteraturan penambahan titik berselang.'
    when category in ('tiu', 'tkd') and subcategory = 'figural' and (lower(prompt) like '%matriks%' or lower(prompt) like '%sisi%')
      then 'Hitung perubahan jumlah sisi poligon dan jumlah titik secara terpisah berdasarkan siklus masing-masing.'
    when category in ('tiu', 'tkd') and subcategory = 'figural' and (lower(prompt) like '%kisi 3×3%' or lower(prompt) like '%kisi%')
      then 'Hitung perubahan baris dan kolom secara terpisah menggunakan perpindahan melingkar (modulo 3).'
    when category in ('tiu', 'tkd') and subcategory = 'figural'
      then 'Perhatikan arah perputaran, pola pencerminan, atau pergantian bentuk gambar secara konsisten.'

    -- TWK
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%dasar negara%'
      then 'Dasar falsafah dan ideologi negara Republik Indonesia adalah Pancasila.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%sila pertama%'
      then 'Sila pertama berfokus pada nilai Ketuhanan Yang Maha Esa.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%sila kedua%'
      then 'Sila kedua berfokus pada nilai Kemanusiaan yang adil dan beradab.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%sila ketiga%'
      then 'Sila ketiga berfokus pada nilai Persatuan Indonesia.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%sila keempat%'
      then 'Sila keempat berfokus pada permusyawaratan, hikmat kebijaksanaan, dan perwakilan.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi' and lower(prompt) like '%sila kelima%'
      then 'Sila kelima berfokus pada Keadilan sosial bagi seluruh rakyat Indonesia.'
    when category = 'twk' and subcategory = 'pancasila_dan_ideologi'
      then 'Kaitkan keputusan dengan pengamalan nilai-nilai luhur Pancasila (kemanusiaan, musyawarah, dan keadilan sosial).'

    when category = 'twk' and subcategory = 'konstitusi_dan_negara' and lower(prompt) like '%uud 1945%' and lower(prompt) like '%disahkan%'
      then 'UUD 1945 disahkan sehari setelah proklamasi oleh PPKI pada 18 Agustus 1945.'
    when category = 'twk' and subcategory = 'konstitusi_dan_negara' and lower(prompt) like '%bentuk negara%'
      then 'Berdasarkan Pasal 1 ayat (1) UUD 1945, bentuk negara Indonesia adalah Negara Kesatuan.'
    when category = 'twk' and subcategory = 'konstitusi_dan_negara' and lower(prompt) like '%bentuk pemerintahan%'
      then 'Berdasarkan konstitusi, bentuk pemerintahan Indonesia adalah Republik.'
    when category = 'twk' and subcategory = 'konstitusi_dan_negara'
      then 'Fokus pada supremasi hukum, pemisahan kekuasaan, akuntabilitas tata kelola, dan perlindungan hak konstitusional warga.'

    when category = 'twk' and subcategory = 'sejarah_dan_kebangsaan' and lower(prompt) like '%lambang negara%'
      then 'Lambang resmi negara Indonesia adalah Garuda Pancasila dengan semboyan Bhinneka Tunggal Ika.'
    when category = 'twk' and subcategory = 'sejarah_dan_kebangsaan' and lower(prompt) like '%proklamasi%' and lower(prompt) like '%tanggal%'
      then 'Ingat momentum proklamasi kemerdekaan Republik Indonesia pada 17 Agustus 1945.'
    when category = 'twk' and subcategory = 'sejarah_dan_kebangsaan' and (lower(prompt) like '%tokoh yang membacakan proklamasi%' or lower(prompt) like '%proklamator%')
      then 'Proklamasi Kemerdekaan dibacakan oleh Ir. Soekarno didampingi Drs. Mohammad Hatta.'
    when category = 'twk' and subcategory = 'sejarah_dan_kebangsaan'
      then 'Analisis peristiwa dari sudut pandang sejarah kritis, semangat persatuan bangsa, dan keberlanjutan cita-cita nasional.'

    when category = 'twk' and subcategory = 'bhinneka_tunggal_ika' and lower(prompt) like '%semboyan%'
      then 'Semboyan resmi negara Indonesia dalam kitab Sutasoma adalah Bhinneka Tunggal Ika.'
    when category = 'twk' and subcategory = 'bhinneka_tunggal_ika'
      then 'Pilih pendekatan yang menjunjung kesetaraan, merawat kebinekaan, dan membangun integrasi nasional.'

    -- TKP
    when category = 'tkp' and subcategory = 'pelayanan_dan_integritas'
      then 'Fokus pada tindakan berintegritas tinggi, kepatuhan prosedur, transparansi, dan pelayanan prima tanpa diskriminasi.'
    when category = 'tkp' and subcategory = 'kerja_sama_dan_komunikasi'
      then 'Pilih pendekatan komunikasi terbuka, penyamaan fakta, dan pembagian peran yang terstruktur serta solutif.'
    when category = 'tkp' and subcategory = 'adaptasi_dan_pengembangan_diri'
      then 'Pilih respon proaktif belajar, adaptif terhadap perubahan, dan berorientasi pada peningkatan kompetensi berkelanjutan.'
    when category = 'tkp' and subcategory = 'pengambilan_keputusan_dan_kinerja'
      then 'Pilih keputusan yang berbasis kriteria objektif, mempertimbangkan manajemen risiko, dan berorientasi solusi terukur.'

    -- AKHLAK
    when category = 'akhlak' and subcategory = 'amanah'
      then 'Pilih tindakan yang memegang teguh kepercayaan, jujur, transparan, dan bertanggung jawab atas setiap mandat.'
    when category = 'akhlak' and subcategory = 'kompeten'
      then 'Pilih tindakan yang menunjukkan semangat belajar, keunggulan mutu hasil kerja, dan transfer pengetahuan.'
    when category = 'akhlak' and subcategory = 'harmonis'
      then 'Pilih sikap saling peduli, menghormati keragaman, dan menjaga suasana kerja yang kondusif serta inklusif.'
    when category = 'akhlak' and subcategory = 'loyal'
      then 'Pilih tindakan yang berdedikasi tinggi serta mendahulukan kepentingan organisasi dan bangsa di atas kepentingan pribadi.'
    when category = 'akhlak' and subcategory = 'adaptif'
      then 'Pilih sikap yang cepat menyesuaikan diri terhadap perubahan dan terus berinovasi.'
    when category = 'akhlak' and subcategory = 'kolaboratif'
      then 'Pilih langkah yang membangun kerja sama sinergis antardisiplin atau antarunit.'

    -- Wawasan Kebangsaan (BUMN)
    when category = 'wawasan_kebangsaan' and subcategory = 'pancasila'
      then 'Pilih kebijakan korporasi yang menyeimbangkan efisiensi bisnis dengan keadilan sosial dan kemanusiaan.'
    when category = 'wawasan_kebangsaan' and subcategory = 'uud_1945'
      then 'Fokus pada tata kelola yang taat asas konstitusi, kepatuhan hukum, dan pemanfaatan sumber daya untuk kemakmuran rakyat.'
    when category = 'wawasan_kebangsaan' and subcategory = 'nkri'
      then 'Pilih langkah yang memperkuat konektivitas antardaerah, ketahanan nasional, dan pemerataan manfaat ekonomi.'
    when category = 'wawasan_kebangsaan' and subcategory = 'bhinneka_tunggal_ika'
      then 'Pilih budaya kerja inklusif yang menghargai keberagaman latar belakang dan memberikan peluang yang setara.'

    else 'Perhatikan kata kunci pada pertanyaan dan pilih jawaban yang paling sesuai dengan kaidah yang berlaku.'
  end,
  updated_at = now()
where hint is null or trim(hint) = '';

commit;
