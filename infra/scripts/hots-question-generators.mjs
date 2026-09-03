const PEOPLE = [
  'Ardi', 'Bela', 'Citra', 'Damar', 'Elin', 'Farhan', 'Gita', 'Hana',
  'Indra', 'Jihan', 'Karin', 'Lukman', 'Maya', 'Nadia', 'Oki', 'Putri',
];

const UNITS = [
  'layanan perizinan', 'pusat data', 'unit pengadaan', 'kantor regional',
  'tim transformasi', 'layanan pelanggan', 'unit kepatuhan', 'tim operasi',
  'pusat pelatihan', 'unit audit', 'tim proyek', 'sekretariat',
];

const ANALOGIES = [
  ['arsitek', 'cetak biru', 'komposer', 'partitur'],
  ['hakim', 'putusan', 'auditor', 'opini'],
  ['dokter', 'diagnosis', 'analis', 'kesimpulan'],
  ['kompas', 'arah', 'termometer', 'suhu'],
  ['benih', 'tanaman', 'gagasan', 'inovasi'],
  ['premis', 'kesimpulan', 'data', 'rekomendasi'],
  ['kamus', 'kata', 'atlas', 'wilayah'],
  ['editor', 'naskah', 'kurator', 'koleksi'],
  ['fondasi', 'bangunan', 'prinsip', 'kebijakan'],
  ['mikroskop', 'sel', 'teleskop', 'bintang'],
  ['latihan', 'kemahiran', 'evaluasi', 'perbaikan'],
  ['arsip', 'dokumen', 'repositori', 'data'],
  ['konstitusi', 'negara', 'anggaran', 'program'],
  ['peta', 'navigasi', 'indikator', 'pengendalian'],
  ['akar', 'pohon', 'nilai', 'perilaku'],
  ['filter', 'kotoran', 'verifikasi', 'kesalahan'],
  ['prototipe', 'produk', 'simulasi', 'kebijakan'],
  ['jadwal', 'waktu', 'anggaran', 'biaya'],
  ['jembatan', 'tepi', 'dialog', 'perbedaan'],
  ['vaksin', 'pencegahan', 'audit', 'pengendalian'],
  ['kunci', 'pintu', 'otorisasi', 'sistem'],
  ['radar', 'objek', 'survei', 'kebutuhan'],
  ['mentor', 'peserta', 'pemimpin', 'tim'],
  ['bukti', 'klaim', 'alasan', 'keputusan'],
  ['akar masalah', 'perbaikan', 'gejala', 'penanganan sementara'],
  ['etika', 'tindakan', 'tata bahasa', 'kalimat'],
  ['indikator', 'capaian', 'rubrik', 'kompetensi'],
  ['enkripsi', 'kerahasiaan', 'cadangan', 'ketersediaan'],
  ['musyawarah', 'mufakat', 'negosiasi', 'kesepakatan'],
  ['observasi', 'hipotesis', 'audit awal', 'dugaan risiko'],
];

const SYMBOL_SETS = [
  ['▲', '▶', '▼', '◀'],
  ['↑', '→', '↓', '←'],
  ['△', '▷', '▽', '◁'],
  ['⬆', '➡', '⬇', '⬅'],
];

export function generateHotsQuestion(path, index) {
  const [target, category, subcategory] = path.split('/');
  const seed = hash(`${path}:${index}`);
  let content;
  if (['tiu', 'tkd'].includes(category)) {
    content = generateReasoning(subcategory, index, seed, target);
  } else if (['tkp', 'akhlak'].includes(category)) {
    content = generateJudgment(path, index, seed);
  } else {
    content = generateCivics(path, index, seed);
  }
  return finalize({ target, category, subcategory, index, seed, ...content });
}

function generateReasoning(subcategory, index, seed, target) {
  if (subcategory === 'verbal') return verbal(index, seed, target);
  if (subcategory === 'numerik') return numeric(index, seed);
  if (subcategory === 'logis') return logical(index, seed, target);
  if (subcategory === 'figural') return figural(index, seed, target);
  throw new Error(`Unsupported reasoning subcategory ${subcategory}.`);
}

function verbal(index, seed, target) {
  const family = index % 4;
  if (family === 0) {
    const [a, b, c, answer] = ANALOGIES[Math.floor(index / 4) % ANALOGIES.length];
    return mcq(
      `Hubungan konsep ${a} terhadap ${b} setara dengan hubungan ${c} terhadap .... Pilih pasangan berdasarkan fungsi yang paling spesifik, bukan sekadar kedekatan bidang.`,
      answer,
      takeDistinct([
        ANALOGIES[(seed + 7) % ANALOGIES.length][3],
        ANALOGIES[(seed + 13) % ANALOGIES.length][1],
        ANALOGIES[(seed + 19) % ANALOGIES.length][3],
        ...ANALOGIES.flatMap((analogy) => [analogy[1], analogy[3]]),
      ], answer),
      `Relasi yang dipakai adalah fungsi atau keluaran utama: ${a} menghasilkan/menggunakan ${b}, sebagaimana ${c} menghasilkan/menggunakan ${answer}.`,
      'medium',
      'Identifikasi relasi fungsional atau fungsi utama pasangan konsep pertama untuk diterapkan pada konsep kedua.',
    );
  }
  if (family === 1) {
    const [a, b, c] = orderedRoles(Math.floor((index - 1) / 4));
    return mcq(
      `Semua ${a} yang lolos evaluasi adalah ${b}. Tidak satu pun ${b} merupakan ${c}. Sebagian ${a} lolos evaluasi. Kesimpulan yang pasti benar adalah ....`,
      `Sebagian ${a} bukan ${c}`,
      [
        `Semua ${a} bukan ${c}`,
        `Sebagian ${c} adalah ${a}`,
        `Tidak ada ${a} yang menjadi ${b}`,
      ],
      `Anggota ${a} yang lolos termasuk ${b}, sedangkan seluruh ${b} berada di luar himpunan ${c}; karena keberadaan sebagian anggota dipastikan, sebagian ${a} pasti bukan ${c}.`,
      'hard',
      'Gunakan hukum silogisme dan perhatikan cakupan kuantor serta diagram himpunan anggota.',
    );
  }
  if (family === 2) {
    const names = orderedPeople(Math.floor((index - 1) / 4), 4);
    return mcq(
      `Empat penyaji—${names.join(', ')}—tampil satu per satu. ${names[1]} tampil tepat setelah ${names[0]}; ${names[2]} tampil sebelum ${names[0]}; dan ${names[3]} tampil terakhir. Urutan yang memenuhi seluruh ketentuan adalah ....`,
      `${names[2]} – ${names[0]} – ${names[1]} – ${names[3]}`,
      [
        `${names[0]} – ${names[1]} – ${names[2]} – ${names[3]}`,
        `${names[2]} – ${names[1]} – ${names[0]} – ${names[3]}`,
        `${names[3]} – ${names[2]} – ${names[0]} – ${names[1]}`,
      ],
      `Pasangan ${names[0]}–${names[1]} harus berurutan, ${names[2]} mendahului pasangan itu, dan ${names[3]} menutup urutan.`,
      'hard',
      'Petakan urutan pasti dan relasi posisi sebelum/sesudah antarsubjek secara bertahap.',
    );
  }
  const before = 64 + (seed % 37);
  const reduction = 8 + (seed % 9);
  const after = before - reduction;
  const unit = UNITS[seed % UNITS.length];
  return mcq(
    `Memo ${unit} mencatat waktu penyelesaian median turun dari ${before} menit menjadi ${after} menit, tetapi tingkat pengembalian berkas naik dari ${6 + (seed % 4)}% menjadi ${10 + (seed % 5)}%. Simpulan paling tepat dari data tersebut adalah ....`,
    'Kecepatan membaik, tetapi mutu proses perlu diperiksa sebelum menyatakan kinerja keseluruhan meningkat',
    [
      'Kinerja pasti meningkat karena waktu median menurun',
      'Kinerja pasti menurun karena masih ada berkas yang selesai',
      'Data membuktikan penambahan pegawai selalu menyelesaikan masalah',
    ],
    'Dua indikator bergerak berlawanan. Penalaran yang sah harus mempertimbangkan efisiensi sekaligus mutu, tanpa menarik sebab yang tidak tersedia dalam data.',
    'hard',
    'Bandingkan dua indikator perubahan secara objektif tanpa membuat asumsi di luar data yang disajikan.',
  );
}

function numeric(index, seed, originalIndex = index) {
  const family = index % 6;
  const ordinal = Math.floor((originalIndex - 1) / 6);
  if (family === 0) {
    const base = 200 + ordinal * 20;
    const pct = [10, 15, 20, 25][ordinal % 4];
    const increase = (base * pct) / 100;
    const answer = base + increase;
    return numberMcq(
      `Sebuah unit menuntaskan ${base} berkas per minggu. Setelah perbaikan alur, kapasitas naik ${pct}% tanpa menambah jam kerja. Berapa berkas yang dapat dituntaskan per minggu?`,
      answer,
      [base - increase, base + pct, answer + increase],
      `Kenaikan = ${pct}% × ${base} = ${increase}; kapasitas baru = ${base} + ${increase} = ${answer}.`,
      'medium',
      '',
      'Hitung nilai kenaikan dari persentase terhadap nilai dasar, lalu jumlahkan untuk memperoleh kapasitas baru.',
    );
  }
  if (family === 1) {
    const ratioPairs = [[2, 3], [3, 4], [4, 5], [3, 5], [5, 6], [2, 5]];
    const [ratioA, ratioB] = ratioPairs[ordinal % ratioPairs.length];
    const multiplier = 12 + Math.floor(ordinal / ratioPairs.length);
    const total = (ratioA + ratioB) * multiplier;
    const answer = (ratioB + 1) * multiplier;
    return numberMcq(
      `Dana pelatihan dan penguatan sistem semula dibagi dengan rasio ${ratioA}:${ratioB}. Dari total ${total} juta rupiah, hasil evaluasi memindahkan satu bagian anggaran dari pelatihan ke penguatan sistem. Alokasi akhir penguatan sistem adalah ....`,
      answer,
      [ratioB * multiplier, ratioA * multiplier, (ratioB + 2) * multiplier],
      `Jumlah bagian ${ratioA + ratioB}; setiap bagian ${total} ÷ ${ratioA + ratioB} = ${multiplier}. Setelah satu bagian dipindahkan, penguatan sistem mendapat ${ratioB + 1} × ${multiplier} = ${answer} juta rupiah.`,
      'hard',
      ' juta rupiah',
      'Cari nilai per satu bagian rasio dari total anggaran, lalu sesuaikan dengan rasio yang baru.',
    );
  }
  if (family === 2) {
    const workers = 6 + (ordinal % 5);
    const days = 8 + 2 * (ordinal % 7);
    const newWorkers = workers * 2;
    const totalWork = workers * days;
    const answer = totalWork / newWorkers;
    return numberMcq(
      `${workers} petugas dengan produktivitas sama menyelesaikan verifikasi dalam ${days} hari. Jika petugas menjadi ${newWorkers} orang dan volume kerja tetap, waktu yang diperlukan adalah ....`,
      answer,
      [days, answer + 2, Math.max(1, answer - 2)],
      `Beban tetap ${workers} × ${days} = ${totalWork} hari-orang. Waktu baru = ${totalWork} ÷ ${newWorkers} = ${answer} hari.`,
      'hard',
      ' hari',
      'Gunakan prinsip perbandingan berbalik nilai: total beban kerja = jumlah petugas × hari.',
    );
  }
  if (family === 3) {
    const average = 70 + ordinal;
    const values = [average - 8, average - 3, average + 4, average + 7];
    const missing = average * 5 - values.reduce((sum, value) => sum + value, 0);
    return numberMcq(
      `Rata-rata lima skor evaluasi adalah ${average}. Empat skor pertama ${values.join(', ')}. Skor kelima adalah ....`,
      missing,
      [missing - 5, missing + 5, average],
      `Total lima skor = 5 × ${average} = ${average * 5}. Jumlah empat skor = ${values.reduce((a, b) => a + b, 0)}, sehingga skor kelima ${missing}.`,
      'medium',
      '',
      'Hitung total seluruh skor (rata-rata × jumlah data) lalu kurangi dengan jumlah skor yang diketahui.',
    );
  }
  if (family === 4) {
    const start = 2 + (ordinal % 7);
    const firstStep = 2 + (Math.floor(ordinal / 7) % 5);
    const stepGrowth = 1 + (Math.floor(ordinal / 35) % 3);
    const sequence = [start];
    let step = firstStep;
    for (let i = 0; i < 4; i += 1) {
      sequence.push(sequence.at(-1) + step);
      step += stepGrowth;
    }
    const answer = sequence.at(-1) + step;
    return numberMcq(
      `Perhatikan deret ${sequence.join(', ')}, .... Angka berikutnya adalah ....`,
      answer,
      [answer - stepGrowth, answer + stepGrowth, answer + firstStep],
      `Selisih berturut-turut dimulai ${firstStep} dan naik ${stepGrowth}; selisih berikutnya ${step}, sehingga hasilnya ${answer}.`,
      'hard',
      '',
      'Perhatikan pola selisih antarsuku yang bertambah secara konstan.',
    );
  }
  const speed = 40 + (ordinal % 6) * 5;
  const hours = 2 + (Math.floor(ordinal / 6) % 4);
  const delayMinutes = [15, 20, 30, 40][(ordinal * 3) % 4];
  const distance = speed * hours;
  const effectiveHours = hours - delayMinutes / 60;
  const answer = Math.round((distance / effectiveHours) * 10) / 10;
  return numberMcq(
    `Perjalanan sejauh ${distance} km semula direncanakan ditempuh dalam ${hours} jam. Setelah tertunda ${delayMinutes} menit, berapa kecepatan rata-rata minimum agar tiba sesuai jadwal?`,
    answer,
    [speed, Math.round((answer - 5) * 10) / 10, Math.round((answer + 5) * 10) / 10],
    `Waktu efektif ${hours} − ${delayMinutes}/60 = ${effectiveHours} jam. Kecepatan minimum = ${distance} ÷ ${effectiveHours} = ${answer} km/jam.`,
    'hard',
    ' km/jam',
    'Kurangi total waktu dengan durasi penundaan untuk mencari waktu efektif, lalu hitung kecepatan = jarak / waktu efektif.',
  );
}

function logical(index, seed) {
  const family = index % 4;
  const ordinal = Math.floor((index - 1) / 4);
  const names = orderedPeople(ordinal, 5);
  if (family === 0) {
    return mcq(
      `Lima berkas milik ${names.join(', ')} diperiksa berurutan. Berkas ${names[0]} tepat sebelum ${names[1]}; ${names[2]} berada di urutan pertama; ${names[3]} sesudah ${names[1]}; dan ${names[4]} terakhir. Siapa yang pasti berada di urutan kedua?`,
      names[0],
      [names[1], names[3], names[4]],
      `${names[2]} pertama dan ${names[4]} terakhir. Pasangan ${names[0]}–${names[1]} harus bersebelahan sebelum ${names[3]}, sehingga pasangan hanya dapat menempati urutan kedua–ketiga.`,
      'hard',
      'Identifikasi posisi awal dan akhir yang sudah pasti, lalu tempatkan pasangan berkas yang harus berdampingan.',
    );
  }
  if (family === 1) {
    const [a, b, c] = orderedUnits(ordinal, 3);
    return mcq(
      `Jika ${a} menyelesaikan audit, maka ${b} membuka layanan. Jika ${b} membuka layanan, maka ${c} tidak melakukan pemeliharaan. Hari ini ${a} menyelesaikan audit. Pernyataan yang pasti benar adalah ....`,
      `${c} tidak melakukan pemeliharaan`,
      [`${a} tidak menyelesaikan audit`, `${b} tidak membuka layanan`, `${c} membuka layanan baru`],
      `Modus ponens diterapkan dua kali: audit ${a} memicu layanan ${b}, dan layanan ${b} memastikan ${c} tidak melakukan pemeliharaan.`,
      'hard',
      'Terapkan aturan Modus Ponens secara berantai dari premis pertama ke premis berikutnya.',
    );
  }
  if (family === 2) {
    const total = 80 + (seed % 9) * 10;
    const a = 40 + (seed % 4) * 5;
    const b = 35 + ((seed >>> 2) % 4) * 5;
    const both = 10 + (seed % 5);
    const neither = total - (a + b - both);
    return numberMcq(
      `Dari ${total} peserta, ${a} menguasai aplikasi A, ${b} menguasai aplikasi B, dan ${both} menguasai keduanya. Peserta yang tidak menguasai A maupun B berjumlah ....`,
      neither,
      [total - a, total - b, a + b - both],
      `Gabungan A atau B = ${a} + ${b} − ${both} = ${a + b - both}. Di luar gabungan = ${total} − ${a + b - both} = ${neither}.`,
      'medium',
      '',
      'Gunakan rumus gabungan dua himpunan: total peserta dikurangi jumlah peserta yang menguasai setidaknya satu aplikasi.',
    );
  }
  const units = orderedUnits(ordinal, 4);
  return mcq(
    `Empat unit dipertimbangkan untuk proyek: ${units.join(', ')}. Minimal salah satu dari ${units[0]} atau ${units[1]} harus dipilih; jika ${units[0]} dipilih maka ${units[2]} tidak boleh dipilih; ${units[1]} hanya boleh dipilih bila ${units[3]} dipilih; dan ${units[2]} wajib dipilih. Kombinasi yang memenuhi seluruh ketentuan adalah ....`,
    `${units[1]}, ${units[2]}, dan ${units[3]}`,
    [
      `${units[0]} dan ${units[2]}`,
      `${units[1]} dan ${units[2]}`,
      `${units[0]}, ${units[1]}, dan ${units[3]}`,
    ],
    `${units[2]} wajib dipilih sehingga ${units[0]} tidak dapat dipilih. Syarat minimal kemudian memaksa ${units[1]} dipilih, dan pemilihan ${units[1]} mensyaratkan ${units[3]}.`,
    'hard',
    'Mulai dari syarat mutlak (unit yang wajib dipilih) lalu eliminasi atau sertakan unit lainnya sesuai aturan.',
  );
}

function figural(index, seed) {
  const family = index % 4;
  if (family === 0) {
    const symbols = SYMBOL_SETS[seed % SYMBOL_SETS.length];
    const start = seed % 4;
    const direction = (seed >>> 3) % 2 === 0 ? 1 : -1;
    const requestedStep = 5 + Math.floor(index / 4);
    const answer = symbols[(start + direction * (requestedStep - 1) + 400) % 4];
    const directionLabel = direction === 1 ? 'searah' : 'berlawanan arah';
    return mcq(
      `Sebuah panah dimulai dari ${symbols[start]} lalu berotasi 90° ${directionLabel} jarum jam pada tiap langkah. Jika posisi awal dihitung sebagai langkah pertama, simbol pada langkah ke-${requestedStep} adalah ....`,
      answer,
      symbols.filter((symbol) => symbol !== answer),
      `Rotasi membentuk siklus empat arah. Selisih ${requestedStep - 1} langkah direduksi modulo 4, kemudian diterapkan dari posisi awal sesuai arah rotasi.`,
      'medium',
      'Gunakan pola siklus 4 arah mata angin dan hitung sisa langkah setelah dibagi 4 (modulo 4).',
    );
  }
  if (family === 1) {
    const shapes = ['○', '□', '△'];
    const start = seed % 3;
    const direction = (seed >>> 3) % 2 === 0 ? 1 : -1;
    const dotPhase = (seed >>> 5) % 2;
    const requestedStep = 6 + Math.floor(index / 4);
    const position = requestedStep - 1;
    const base = shapes[(start + direction * position + 300) % 3];
    const answer = position % 2 === dotPhase ? base : `${base}•`;
    return mcq(
      `Pola dimulai dari ${shapes[start]} dan bentuk bergerak ${direction === 1 ? 'maju' : 'mundur'} dalam siklus lingkaran–persegi–segitiga. Satu titik ditambahkan secara berselang mulai pada posisi ${dotPhase === 0 ? 'pertama' : 'kedua'}. Bentuk pada posisi ke-${requestedStep} adalah ....`,
      answer,
      shapes.flatMap((shape) => [shape, `${shape}•`, `${shape}••`]),
      `Indeks bentuk dihitung modulo 3 dan tanda titik modulo 2. Pada posisi ke-${requestedStep}, kedua siklus menghasilkan ${answer}.`,
      'hard',
      'Pisahkan analisis siklus bentuk (lingkaran-persegi-segitiga) dan pola kemunculan titik berselang.',
    );
  }
  if (family === 2) {
    const sides = 3 + (seed % 4);
    const dots = 1 + ((seed >>> 2) % 4);
    const sideStep = 1 + ((seed >>> 5) % 2);
    const dotStep = 1 + ((seed >>> 6) % 2);
    const moves = 2 + Math.floor(index / 4);
    const nextSides = 3 + ((sides - 3 + sideStep * moves) % 4);
    const nextDots = 1 + ((dots - 1 + dotStep * moves) % 4);
    const answer = `${nextSides} sisi, ${nextDots} titik`;
    return mcq(
      `Dalam suatu matriks, banyak sisi bertambah ${sideStep} (setelah 6 kembali ke 3) dan banyak titik bertambah ${dotStep} (setelah 4 kembali ke 1). Jika sel awal memiliki ${sides} sisi dan ${dots} titik, isi sel setelah ${moves} perpindahan adalah ....`,
      answer,
      [3, 4, 5, 6].flatMap((sideCount) => [1, 2, 3, 4].map((dotCount) => `${sideCount} sisi, ${dotCount} titik`)),
      `Kedua atribut berubah independen selama ${moves} langkah dan direduksi pada siklus empat nilai: sisi menjadi ${nextSides} dan titik menjadi ${nextDots}.`,
      'hard',
      'Hitung perubahan jumlah sisi dan jumlah titik secara terpisah berdasarkan siklus masing-masing.',
    );
  }
  const row = 1 + (seed % 3);
  const col = 1 + ((seed >>> 2) % 3);
  const rowDirection = (seed >>> 5) % 2 === 0 ? 1 : -1;
  const colDirection = (seed >>> 6) % 2 === 0 ? 1 : -1;
  const moves = 2 + Math.floor(index / 4);
  const nextRow = 1 + ((row - 1 + rowDirection * moves + 300) % 3);
  const nextCol = 1 + ((col - 1 + colDirection * moves + 300) % 3);
  const rowLabel = rowDirection === 1 ? 'ke bawah' : 'ke atas';
  const colLabel = colDirection === 1 ? 'ke kanan' : 'ke kiri';
  return mcq(
    `Sebuah penanda pada kisi 3×3 bergerak satu baris ${rowLabel} dan satu kolom ${colLabel}, dengan perpindahan melingkar saat melewati tepi. Dari posisi (${row},${col}), posisi setelah ${moves} perpindahan adalah ....`,
    `(${nextRow},${nextCol})`,
    [1, 2, 3].flatMap((rowValue) => [1, 2, 3].map((colValue) => `(${rowValue},${colValue})`)),
    `Perubahan baris dan kolom diterapkan bersamaan selama ${moves} langkah dan dihitung modulo 3, menghasilkan (${nextRow},${nextCol}).`,
    'medium',
    'Hitung perubahan baris dan kolom secara terpisah menggunakan perpindahan melingkar (modulo 3).',
  );
}

const JUDGMENT_SPECS = {
  'cpns/tkp/pelayanan_dan_integritas': {
    value: 'pelayanan publik dan integritas',
    cases: [
      ['Antrean meningkat karena sistem utama melambat', 'membuka prosedur layanan cadangan yang sah, memberi estimasi transparan, dan memprioritaskan kebutuhan darurat', 'melewati pemeriksaan wajib agar antrean cepat habis', 'menunggu sistem pulih tanpa memberi informasi', 'melayani kenalan lebih dahulu agar tidak mengeluh', 'Layanan harus tetap cepat, adil, transparan, dan patuh prosedur.'],
      ['Pemohon menawarkan hadiah setelah berkasnya selesai', 'menolak secara sopan, menjelaskan aturan gratifikasi, dan melaporkan sesuai mekanisme', 'menerima karena proses telah selesai', 'menolak tetapi tidak mencatat kejadian yang berulang', 'meminta hadiah dialihkan kepada rekan', 'Integritas menuntut penolakan gratifikasi dan pencatatan melalui kanal resmi.'],
      ['Data pada berkas pemohon berbeda dengan basis data', 'memverifikasi sumber data, menjelaskan ketidaksesuaian, dan memberi jalur koreksi yang setara', 'mengubah data tanpa bukti agar layanan selesai', 'menolak permanen tanpa penjelasan', 'meminta pemohon menghubungi pegawai tertentu secara pribadi', 'Keputusan layanan harus berbasis bukti dan menyediakan proses koreksi yang jelas.'],
      ['Kelompok rentan kesulitan menggunakan kanal digital', 'menyediakan pendampingan yang aksesibel tanpa mengurangi standar verifikasi', 'meminta mereka mencari bantuan sendiri', 'menghapus seluruh verifikasi khusus untuk kelompok tersebut', 'memindahkan semua antrean ke kanal manual', 'Aksesibilitas perlu diperkuat sambil menjaga keabsahan dan kesetaraan proses.'],
      ['Seorang pejabat meminta berkas kerabatnya dipercepat', 'menolak perlakuan khusus, menerapkan prioritas objektif, dan mencatat intervensi', 'mengikuti permintaan demi hubungan kerja', 'menunda semua berkas agar tidak terlihat memihak', 'mempercepat secara diam-diam tanpa dokumentasi', 'Imparsialitas dan jejak audit melindungi keadilan layanan.'],
      ['Keluhan viral memuat sebagian informasi yang benar', 'memverifikasi fakta, memperbaiki bagian layanan yang salah, dan memberi tanggapan publik tanpa membuka data pribadi', 'membantah seluruh keluhan untuk menjaga citra', 'membuka data pemohon sebagai pembelaan', 'menghapus komentar dan tidak memperbaiki proses', 'Respons berintegritas menggabungkan verifikasi, perbaikan, transparansi, dan perlindungan data.'],
    ],
  },
  'cpns/tkp/kerja_sama_dan_komunikasi': {
    value: 'kerja sama dan komunikasi',
    cases: [
      ['Dua unit memiliki interpretasi berbeda atas prosedur baru', 'menyamakan fakta, memetakan perbedaan, lalu menyepakati keputusan dan PIC tertulis', 'memaksakan tafsir unit sendiri', 'meneruskan perdebatan melalui pesan pribadi', 'menunggu konflik reda tanpa keputusan', 'Kolaborasi efektif membutuhkan fakta bersama, keputusan eksplisit, dan kepemilikan tindak lanjut.'],
      ['Anggota tim jarang berbicara tetapi menguasai risiko teknis', 'meminta pandangannya secara aman dan memasukkan bukti teknis ke keputusan tim', 'menganggap diam berarti setuju', 'menyerahkan seluruh keputusan kepadanya', 'membahas kekurangannya di luar rapat', 'Komunikasi inklusif memastikan keahlian relevan memengaruhi keputusan.'],
      ['Mitra eksternal terlambat mengirim data kritis', 'menjelaskan dampak, menyepakati batas baru, dan menyiapkan data pengganti yang tervalidasi', 'menyalahkan mitra di forum publik', 'mengubah angka agar jadwal tidak bergeser', 'diam-diam mengambil data lama tanpa catatan', 'Koordinasi harus tegas pada kebutuhan sekaligus menjaga validitas dan hubungan kerja.'],
      ['Rapat berulang tidak menghasilkan keputusan', 'mengirim agenda berbasis keputusan, membatasi isu, dan menutup rapat dengan keputusan serta penanggung jawab', 'menambah peserta tanpa mengubah cara kerja', 'menghentikan seluruh komunikasi', 'membuat keputusan sendiri setelah rapat', 'Struktur komunikasi mengubah diskusi menjadi keputusan yang dapat dijalankan.'],
      ['Terjadi salah paham karena pesan singkat yang ambigu', 'mengklarifikasi maksud melalui percakapan langsung dan merangkum kesepakatan tertulis', 'membalas dengan nada yang sama', 'meneruskan pesan kepada banyak orang', 'mengabaikan karena dianggap sepele', 'Klarifikasi cepat dan dokumentasi mencegah eskalasi serta pengulangan salah paham.'],
      ['Satu anggota tim menanggung pekerjaan paling banyak', 'meninjau kapasitas dan dependensi lalu membagi ulang tugas secara terbuka', 'memintanya bertahan karena paling mampu', 'membagi tugas sama rata tanpa melihat kompetensi', 'menunggu sampai ia mengeluh resmi', 'Pembagian kerja perlu adil, transparan, dan mempertimbangkan kompetensi serta beban.'],
    ],
  },
  'cpns/tkp/adaptasi_dan_pengembangan_diri': {
    value: 'adaptasi dan pengembangan diri',
    cases: [
      ['Aplikasi baru menggantikan proses yang telah lama dikuasai', 'mempelajari fungsi kritis, berlatih pada data uji, dan membagikan temuan kepada tim', 'menolak sampai sistem lama dimatikan', 'mencoba langsung pada data produksi tanpa panduan', 'menyerahkan seluruh tugas digital kepada rekan', 'Adaptasi yang aman menggabungkan pembelajaran aktif, eksperimen terkendali, dan berbagi pengetahuan.'],
      ['Umpan balik menunjukkan analisis Anda terlalu deskriptif', 'meminta contoh standar, berlatih pada kasus baru, dan meminta evaluasi ulang', 'membela hasil lama tanpa memeriksa masukan', 'mengubah gaya secara acak', 'menghindari tugas analisis berikutnya', 'Pengembangan diri memerlukan sasaran spesifik, latihan, dan umpan balik lanjutan.'],
      ['Regulasi berubah saat pekerjaan hampir selesai', 'memetakan dampak perubahan, memperbarui bagian terdampak, dan mengomunikasikan risiko jadwal', 'mengabaikan aturan baru karena pekerjaan hampir selesai', 'mengulang seluruh pekerjaan tanpa analisis', 'menunggu instruksi meski dampaknya sudah jelas', 'Respons adaptif proporsional terhadap dampak dan tetap transparan pada risiko.'],
      ['Anda ditugaskan pada bidang di luar pengalaman utama', 'memetakan kesenjangan kompetensi, mencari mentor, dan menetapkan hasil belajar bertahap', 'menolak karena bukan spesialisasi', 'mengaku menguasai agar terlihat siap', 'membaca sekilas lalu bekerja tanpa validasi', 'Pembelajaran terarah mengurangi risiko sekaligus mempercepat kemandirian.'],
      ['Eksperimen perbaikan proses tidak mencapai target', 'menganalisis data kegagalan, mempertahankan bagian yang terbukti, dan menguji hipotesis baru', 'menyembunyikan hasil agar ide tetap dinilai baik', 'menghentikan semua inovasi', 'mengulang eksperimen tanpa perubahan', 'Kegagalan menjadi pembelajaran bila bukti digunakan untuk memperbaiki hipotesis.'],
      ['Beban kerja berubah cepat karena keadaan darurat', 'menentukan ulang prioritas berdasar dampak, mengamankan tugas kritis, dan menegosiasikan tenggat lain', 'mengerjakan semua tugas sekaligus', 'hanya mengerjakan tugas yang paling disukai', 'menunggu situasi normal tanpa tindakan', 'Adaptasi menuntut prioritisasi sadar risiko dan komunikasi kapasitas.'],
    ],
  },
  'cpns/tkp/pengambilan_keputusan_dan_kinerja': {
    value: 'pengambilan keputusan dan kinerja',
    cases: [
      ['Dua alternatif sama-sama memenuhi tujuan tetapi risikonya berbeda', 'membandingkan manfaat, risiko, biaya, dan reversibilitas lalu mendokumentasikan pilihan', 'memilih yang paling populer', 'menunda sampai salah satu pilihan tidak tersedia', 'memilih yang termurah tanpa menilai dampak', 'Keputusan yang dapat dipertanggungjawabkan memakai kriteria eksplisit dan jejak alasan.'],
      ['Indikator output tercapai tetapi keluhan meningkat', 'menelaah indikator mutu dan akar keluhan sebelum menetapkan kinerja berhasil', 'menyatakan berhasil hanya dari jumlah output', 'menghapus indikator output', 'menyalahkan ekspektasi pengguna', 'Kinerja harus dinilai dari kuantitas, mutu, dan dampak.'],
      ['Data yang tersedia belum lengkap sementara keputusan mendesak', 'menentukan data minimum, memilih tindakan yang dapat dibalik, dan menetapkan titik evaluasi', 'mengarang data yang hilang', 'tidak mengambil keputusan apa pun', 'mengambil keputusan permanen berdasarkan intuisi saja', 'Dalam ketidakpastian, keputusan bertahap dan reversibel membatasi risiko.'],
      ['Proyek terlambat karena satu dependensi kritis', 'mengidentifikasi jalur kritis, mengalihkan sumber daya, dan memperbarui proyeksi secara jujur', 'meminta semua orang lembur tanpa analisis', 'menyembunyikan keterlambatan', 'mengurangi pengujian agar tampak tepat waktu', 'Pemulihan kinerja berfokus pada hambatan kritis tanpa mengorbankan mutu.'],
      ['Target baru lebih tinggi tetapi sumber daya tetap', 'menilai kapasitas, menyederhanakan aktivitas rendah nilai, dan menyepakati prioritas terukur', 'menerima semua target tanpa rencana', 'menolak target tanpa analisis', 'menurunkan mutu secara diam-diam', 'Target ambisius perlu diterjemahkan menjadi prioritas dan kapasitas yang realistis.'],
      ['Kesalahan kecil berulang pada tahapan yang sama', 'mengukur pola, memperbaiki kontrol pada sumber kesalahan, dan memantau hasil', 'menegur orang berbeda setiap kali', 'menambah pemeriksaan di semua tahapan', 'menganggap tiap kesalahan tidak berkaitan', 'Perbaikan sistemik menyasar pola dan akar penyebab, bukan hanya gejala.'],
    ],
  },
  'bumn/akhlak/amanah': {
    value: 'Amanah',
    cases: [
      ['Rekonsiliasi menemukan selisih kecil yang tidak memengaruhi laba', 'menelusuri selisih, mengoreksi catatan, dan melaporkan penyebabnya', 'mengabaikan karena nilainya kecil', 'memindahkan selisih ke periode berikutnya', 'mengubah angka tanpa bukti', 'Amanah terlihat dari akurasi, transparansi, dan tanggung jawab meskipun nilai kesalahan kecil.'],
      ['Vendor mengirim bingkisan setelah evaluasi tender', 'menolak dan melaporkan melalui mekanisme gratifikasi', 'menerima karena pemenang belum diumumkan', 'membagikan bingkisan agar dianggap netral', 'menyimpan tanpa menggunakannya', 'Kepercayaan dijaga dengan menghindari konflik kepentingan dan membuat pelaporan resmi.'],
      ['Target tidak tercapai karena asumsi Anda keliru', 'mengakui asumsi, menjelaskan dampak, dan membawa rencana koreksi berbasis data', 'menyalahkan perubahan pasar sepenuhnya', 'mengubah target setelah periode berakhir', 'menyembunyikan asumsi dari laporan', 'Akuntabilitas mencakup pengakuan, penjelasan, dan perbaikan.'],
      ['Anda memperoleh akses data pelanggan di luar kebutuhan tugas', 'tidak mengakses data, meminta penyesuaian hak, dan melaporkan kelemahan kontrol', 'memeriksa data sekadar memastikan akses', 'membagikan temuan kepada rekan', 'menunggu sampai ada penyalahgunaan', 'Amanah menuntut penggunaan kewenangan secara minimal dan perlindungan data proaktif.'],
      ['Atasan meminta tanggal laporan dimundurkan', 'menolak perubahan yang tidak benar dan mengeskalasi melalui jalur tata kelola', 'mengikuti karena atasan bertanggung jawab', 'mengubah sebagian agar tidak mencolok', 'menghapus laporan', 'Integritas catatan tidak boleh dikompromikan oleh hierarki.'],
      ['Kesalahan sistem memberi keuntungan finansial kepada unit Anda', 'melaporkan, menghentikan pemanfaatan, dan mengoreksi dampak', 'memakai keuntungan sampai sistem diperbaiki', 'diam karena bukan kesalahan unit', 'membagikan keuntungan ke unit lain', 'Amanah mengharuskan koreksi walau kesalahan menguntungkan diri sendiri.'],
    ],
  },
  'bumn/akhlak/kompeten': {
    value: 'Kompeten',
    cases: [
      ['Hasil audit menunjukkan kesalahan analisis berulang', 'mempelajari akar kesalahan, mengikuti pelatihan terarah, dan menguji penerapan pada kasus baru', 'mengganti format laporan saja', 'menyerahkan analisis kepada rekan selamanya', 'menghafal jawaban kasus lama', 'Kompetensi tumbuh melalui diagnosis kesenjangan, latihan terarah, dan transfer ke situasi baru.'],
      ['Teknologi baru berpotensi memangkas waktu proses', 'membuat uji terbatas, mengukur mutu dan risiko, lalu menyusun rekomendasi penerapan', 'langsung menerapkan ke seluruh perusahaan', 'menolak karena tim belum berpengalaman', 'mengikuti tren tanpa indikator', 'Kompeten berarti belajar cepat sekaligus membuktikan manfaat dan risiko.'],
      ['Rekan junior meminta tinjauan pekerjaannya', 'memberi umpan balik spesifik, menjelaskan prinsip, dan memintanya memperbaiki sendiri', 'mengambil alih seluruh pekerjaan', 'hanya menunjukkan kesalahan', 'memberi jawaban jadi tanpa penjelasan', 'Pengembangan kompetensi membantu orang memahami prinsip dan berlatih mandiri.'],
      ['Anda harus memberi rekomendasi di bidang baru', 'mempelajari sumber tepercaya, berkonsultasi dengan ahli, dan menyatakan batas kepastian', 'mengandalkan pengalaman bidang lama', 'menunda tanpa rencana belajar', 'menyajikan dugaan sebagai fakta', 'Profesionalisme memadukan pembelajaran, kolaborasi ahli, dan kejujuran epistemik.'],
      ['Kinerja cepat tetapi koreksi ulang tinggi', 'menganalisis titik cacat, memperbaiki metode, dan mengukur first-pass quality', 'menaikkan target kecepatan lagi', 'menambah pemeriksa tanpa memperbaiki proses', 'menghapus catatan koreksi', 'Keunggulan kompetensi mengoptimalkan kecepatan dan mutu secara bersamaan.'],
      ['Sertifikasi yang dimiliki akan kedaluwarsa', 'menyusun pembaruan kompetensi sebelum tenggat dan menerapkan pembelajaran pada pekerjaan', 'menunggu perusahaan mengingatkan', 'mencantumkan sertifikasi lama tanpa keterangan', 'mengikuti pelatihan apa pun sekadar memenuhi jam', 'Kompeten bersifat proaktif, relevan, dan dibuktikan dalam kinerja.'],
    ],
  },
  'bumn/akhlak/harmonis': {
    value: 'Harmonis',
    cases: [
      ['Candaan rapat merendahkan latar belakang seorang rekan', 'menghentikan dengan sopan, menegaskan dampaknya, dan memulihkan ruang kerja yang aman', 'ikut tertawa agar suasana tidak tegang', 'membahasnya hanya dengan korban setelah rapat', 'membalas dengan candaan lain', 'Harmonis berarti menghargai martabat dan bertindak saat lingkungan tidak inklusif.'],
      ['Konflik gaya kerja menghambat dua anggota tim', 'memfasilitasi kebutuhan masing-masing dan menyepakati cara kerja yang dapat diuji', 'meminta salah satu mengalah permanen', 'memisahkan mereka dari semua tugas', 'membiarkan konflik selesai sendiri', 'Hubungan harmonis dibangun lewat empati, batas yang jelas, dan kesepakatan kerja.'],
      ['Rekan mengalami beban pribadi yang menurunkan fokus', 'mendengarkan tanpa menghakimi, menawarkan dukungan wajar, dan menjaga kerahasiaan', 'menyebarkan cerita agar tim memahami', 'mengabaikan karena bukan urusan kerja', 'mengambil semua tugas tanpa berdialog', 'Kepedulian perlu menghormati privasi dan tetap membangun solusi kerja.'],
      ['Tim lintas daerah berbeda kebiasaan komunikasi', 'menyepakati norma komunikasi yang inklusif dan memberi ruang klarifikasi', 'memaksakan kebiasaan kantor pusat', 'menghindari pertemuan lintas daerah', 'menganggap perbedaan sebagai ketidakmampuan', 'Harmonis mengubah perbedaan menjadi aturan kolaborasi yang disepakati.'],
      ['Kontribusi anggota pendiam tidak diakui', 'menyebut kontribusinya secara proporsional dan memperbaiki cara pencatatan kontribusi', 'memberinya pujian berlebihan', 'diam agar tidak menimbulkan konflik', 'mengkritik anggota dominan di depan umum', 'Penghargaan yang adil memperkuat rasa aman dan kebersamaan.'],
      ['Perubahan jadwal berdampak lebih berat pada sebagian tim', 'mendengar dampak, memakai kriteria adil, dan mencari mitigasi bersama', 'menerapkan sama rata tanpa melihat dampak', 'membatalkan perubahan tanpa analisis', 'memprioritaskan kelompok paling vokal', 'Keharmonisan bukan sekadar keseragaman, melainkan keadilan dan kepedulian.'],
    ],
  },
  'bumn/akhlak/loyal': {
    value: 'Loyal',
    cases: [
      ['Strategi perusahaan berubah setelah keputusan resmi', 'menjalankan keputusan, menyampaikan risiko melalui kanal internal, dan menjaga informasi strategis', 'menolak karena usulan Anda tidak dipilih', 'membocorkan perdebatan internal', 'menjalankan tanpa memantau risiko', 'Loyal mendahulukan kepentingan organisasi tanpa menghilangkan tanggung jawab profesional.'],
      ['Informasi negatif perusahaan belum terverifikasi beredar', 'memverifikasi melalui fungsi berwenang dan tidak menyebarkan spekulasi', 'membela perusahaan dengan informasi yang juga belum pasti', 'meneruskan agar rekan waspada', 'menghapus semua percakapan terkait', 'Loyalitas menjaga nama baik melalui fakta, bukan penyangkalan atau spekulasi.'],
      ['Kebijakan unit menguntungkan unit tetapi merugikan grup', 'mengusulkan keputusan yang mengoptimalkan kepentingan perusahaan secara keseluruhan', 'mempertahankan target unit apa pun dampaknya', 'mengalihkan kerugian tanpa transparansi', 'menunggu unit lain memprotes', 'Loyal menempatkan kepentingan organisasi di atas ego unit.'],
      ['Anda diminta mewakili perusahaan pada forum publik', 'menyampaikan posisi resmi secara akurat dan mencatat pertanyaan yang perlu tindak lanjut', 'menambahkan pendapat pribadi sebagai kebijakan', 'menolak semua pertanyaan', 'membuka informasi internal untuk terlihat transparan', 'Representasi loyal harus akurat, profesional, dan menjaga informasi yang dilindungi.'],
      ['Program penting membutuhkan dukungan di luar jam biasa', 'mengatur kontribusi yang proporsional, menjaga keselamatan kerja, dan memastikan keberlanjutan tim', 'memaksa seluruh tim lembur tanpa batas', 'menolak karena di luar rutinitas', 'mengerjakan sendiri tanpa koordinasi', 'Dedikasi yang sehat menyeimbangkan kepentingan organisasi dan keberlanjutan manusia.'],
      ['Rekan mengajak mengkritik perusahaan melalui akun anonim', 'menolak, menggunakan kanal pengaduan resmi, dan menyertakan bukti yang dapat ditindaklanjuti', 'ikut agar masalah cepat viral', 'diam meski ada pelanggaran serius', 'menyerang rekan yang mengajak', 'Loyalitas yang benar tidak menutupi masalah; ia memperbaikinya melalui mekanisme yang bertanggung jawab.'],
    ],
  },
};

const JUDGMENT_HINTS = {
  'cpns/tkp/pelayanan_dan_integritas': 'Fokus pada tindakan berintegritas tinggi, kepatuhan prosedur, transparansi, dan pelayanan prima tanpa diskriminasi.',
  'cpns/tkp/kerja_sama_dan_komunikasi': 'Pilih pendekatan komunikasi terbuka, penyamaan fakta, dan pembagian peran yang terstruktur serta solutif.',
  'cpns/tkp/adaptasi_dan_pengembangan_diri': 'Pilih respon proaktif belajar, adaptif terhadap perubahan, dan berorientasi pada peningkatan kompetensi berkelanjutan.',
  'cpns/tkp/pengambilan_keputusan_dan_kinerja': 'Pilih keputusan yang berbasis kriteria objektif, mempertimbangkan manajemen risiko, dan berorientasi solusi terukur.',
  'bumn/akhlak/amanah': 'Pilih tindakan yang memegang teguh kepercayaan, jujur, transparan, dan bertanggung jawab atas setiap mandat.',
  'bumn/akhlak/kompeten': 'Pilih tindakan yang menunjukkan semangat belajar, keunggulan mutu hasil kerja, dan transfer pengetahuan.',
  'bumn/akhlak/harmonis': 'Pilih sikap saling peduli, menghormati keragaman, dan menjaga suasana kerja yang kondusif serta inklusif.',
  'bumn/akhlak/loyal': 'Pilih tindakan yang berdedikasi tinggi serta mendahulukan kepentingan organisasi dan bangsa di atas kepentingan pribadi.',
};

function generateJudgment(path, index, seed) {
  const spec = JUDGMENT_SPECS[path];
  if (!spec) throw new Error(`Missing judgment specification for ${path}.`);
  const [situation, best, risky, passive, partial, rationale] =
    spec.cases[index % spec.cases.length];
  const variant = Math.floor((index - 1) / spec.cases.length);
  const unit = UNITS[variant % UNITS.length];
  const constraints = [
    'keputusan harus diambil hari ini',
    'sumber daya tambahan belum tersedia',
    'dampaknya menyentuh beberapa pemangku kepentingan',
    'proses tetap harus memiliki jejak audit',
    'layanan tidak boleh berhenti',
    'informasi yang tersedia belum sepenuhnya lengkap',
  ];
  const constraint = constraints[Math.floor(variant / UNITS.length) % constraints.length];
  const hint = JUDGMENT_HINTS[path] ?? `Pilih respon yang paling mencerminkan nilai ${spec.value} secara nyata dan profesional.`;
  return mcq(
    `${situation}. Kondisi di ${unit}: ${constraint}. Tindakan yang paling mencerminkan ${spec.value} adalah ....`,
    capitalize(best),
    [capitalize(risky), capitalize(passive), capitalize(partial)],
    `${rationale} Pilihan terbaik menangani akar persoalan, menjaga batas etis atau prosedural, dan memungkinkan tindak lanjut yang terukur.`,
    'hard',
    hint,
  );
}

const CIVICS_HINTS = {
  'cpns/twk/pancasila_dan_ideologi': 'Kaitkan keputusan dengan pengamalan nilai-nilai luhur Pancasila (kemanusiaan, musyawarah, dan keadilan sosial).',
  'cpns/twk/konstitusi_dan_negara': 'Fokus pada supremasi hukum, pemisahan kekuasaan, akuntabilitas tata kelola, dan perlindungan hak konstitusional warga.',
  'cpns/twk/sejarah_dan_kebangsaan': 'Analisis peristiwa dari sudut pandang sejarah kritis, semangat persatuan bangsa, dan keberlanjutan cita-cita nasional.',
  'cpns/twk/bhinneka_tunggal_ika': 'Pilih pendekatan yang menjunjung kesetaraan, merawat kebinekaan, dan membangun integrasi nasional.',
  'bumn/wawasan_kebangsaan/pancasila': 'Pilih kebijakan korporasi yang menyeimbangkan efisiensi bisnis dengan keadilan sosial dan kemanusiaan.',
  'bumn/wawasan_kebangsaan/uud_1945': 'Fokus pada tata kelola yang taat asas konstitusi, kepatuhan hukum, dan pemanfaatan sumber daya untuk kemakmuran rakyat.',
  'bumn/wawasan_kebangsaan/nkri': 'Pilih langkah yang memperkuat konektivitas antardaerah, ketahanan nasional, dan pemerataan manfaat ekonomi.',
  'bumn/wawasan_kebangsaan/bhinneka_tunggal_ika': 'Pilih budaya kerja inklusif yang menghargai keberagaman latar belakang dan memberikan peluang yang setara.',
};

const CIVICS_SPECS = {
  'cpns/twk/pancasila_dan_ideologi': [
    ['Musyawarah warga buntu karena kelompok mayoritas ingin langsung melakukan pemungutan suara', 'memperjelas kepentingan bersama, memberi kesempatan setara, lalu memakai pemungutan suara bila mufakat sungguh tidak tercapai', 'Sila keempat menempatkan musyawarah sebagai proses bijaksana, bukan sekadar dominasi jumlah.'],
    ['Program bantuan hanya menjangkau wilayah yang mudah diakses', 'memakai data kebutuhan dan menambah mekanisme jangkauan bagi wilayah tertinggal', 'Keadilan sosial menuntut distribusi berdasarkan kebutuhan dan hambatan nyata.'],
    ['Kebijakan disiplin diterapkan tanpa ruang bagi kondisi disabilitas', 'mempertahankan tujuan disiplin sambil menyediakan akomodasi yang layak dan terukur', 'Kemanusiaan yang adil menghormati martabat dan kesetaraan substantif.'],
    ['Konten digital memecah warga berdasarkan pilihan politik', 'menguatkan literasi, dialog berbasis fakta, dan tujuan kebangsaan bersama tanpa membungkam kritik', 'Persatuan Indonesia dirawat melalui ruang dialog yang faktual dan inklusif.'],
    ['Petugas menemukan konflik antara kepentingan pribadi dan keputusan publik', 'mengungkap konflik, mengundurkan diri dari keputusan, dan menyerahkan pada proses objektif', 'Ideologi Pancasila menuntun integritas serta kepentingan umum di atas kepentingan pribadi.'],
    ['Usulan pembangunan efisien tetapi menggusur warga tanpa pemulihan', 'menilai manfaat dan dampak, melibatkan warga, serta memastikan pemulihan yang adil', 'Pembangunan harus mengintegrasikan kemanusiaan, musyawarah, dan keadilan sosial.'],
  ],
  'cpns/twk/konstitusi_dan_negara': [
    ['Sebuah aturan daerah membatasi hak warga lebih jauh daripada undang-undang', 'menguji kesesuaiannya melalui mekanisme hukum dan menangguhkan penerapan yang berpotensi melanggar hak', 'Negara hukum menempatkan tindakan pemerintah dalam hierarki norma dan mekanisme pengujian.'],
    ['Lembaga pelaksana ingin sekaligus menetapkan dan mengadili pelanggaran aturannya sendiri', 'memisahkan fungsi serta menyediakan pemeriksaan oleh pihak yang independen', 'Pembatasan kekuasaan dan proses yang adil mencegah penyalahgunaan kewenangan.'],
    ['Keadaan darurat menuntut pembatasan sementara', 'menetapkan dasar hukum, tujuan sah, proporsionalitas, batas waktu, dan pengawasan', 'Pembatasan hak harus legal, perlu, proporsional, terbatas, dan dapat diawasi.'],
    ['Data pribadi warga hendak dibuka untuk transparansi anggaran', 'membuka informasi penggunaan anggaran sambil menganonimkan data pribadi yang tidak relevan', 'Keterbukaan pemerintahan harus diseimbangkan dengan perlindungan hak pribadi.'],
    ['Pejabat menggunakan diskresi ketika aturan teknis belum tersedia', 'mendasarkan diskresi pada tujuan kewenangan, kepentingan umum, dokumentasi, dan pengawasan', 'Diskresi bukan kebebasan tanpa batas; penggunaannya tetap tunduk pada asas pemerintahan yang baik.'],
    ['Warga tidak diberi kesempatan menanggapi keputusan yang merugikannya', 'memberikan alasan keputusan dan mekanisme keberatan yang efektif', 'Due process mengharuskan pemberitahuan, alasan, dan kesempatan untuk didengar.'],
  ],
  'cpns/twk/sejarah_dan_kebangsaan': [
    ['Peringatan sejarah hanya menonjolkan satu tokoh dan mengabaikan gerakan rakyat', 'menyajikan peran tokoh, organisasi, konteks, dan kontribusi masyarakat secara kritis', 'Pemahaman sejarah yang kuat membaca hubungan sebab, konteks, dan banyak pelaku.'],
    ['Generasi muda menganggap Sumpah Pemuda sekadar hafalan tanggal', 'mengaitkan bahasa persatuan dan identitas bersama dengan tantangan kolaborasi masa kini', 'Makna historis diuji melalui kemampuan menerapkan semangat persatuan pada konteks baru.'],
    ['Narasi lokal tampak berbeda dari buku nasional', 'memeriksa sumber, konteks, dan sudut pandang lalu menempatkannya dalam sejarah nasional', 'Perbedaan sumber perlu dianalisis, bukan langsung dihapus atau diterima tanpa kritik.'],
    ['Informasi viral mengubah isi peristiwa Proklamasi', 'memeriksa sumber primer dan kajian kredibel sebelum menyimpulkan', 'Literasi sejarah bertumpu pada kritik sumber dan pembuktian.'],
    ['Pembangunan situs sejarah berbenturan dengan kebutuhan ekonomi warga', 'merancang pemanfaatan yang melestarikan bukti sejarah sekaligus memberi manfaat wajar bagi warga', 'Kebangsaan menghubungkan pelestarian memori dengan kesejahteraan secara berkelanjutan.'],
    ['Perjuangan daerah diajarkan terpisah dari pembentukan Indonesia', 'menjelaskan hubungan perjuangan lokal, jaringan antardaerah, dan tujuan kemerdekaan bersama', 'Sejarah kebangsaan memperlihatkan keragaman jalan yang bertemu pada cita-cita nasional.'],
  ],
  'cpns/twk/bhinneka_tunggal_ika': [
    ['Forum publik didominasi satu kelompok budaya', 'mengubah desain partisipasi agar kelompok lain aman berbicara dan keputusan tetap berbasis kepentingan bersama', 'Bhinneka Tunggal Ika mengakui perbedaan sekaligus membangun ruang setara untuk tujuan bersama.'],
    ['Tradisi lokal berbenturan dengan hak dasar sebagian warga', 'berdialog dengan tokoh terkait sambil memastikan hak dasar tetap terlindungi', 'Penghormatan keragaman tidak membenarkan pelanggaran martabat dan hak.'],
    ['Sekolah ingin menyeragamkan semua ekspresi budaya', 'membuat standar kebersamaan yang memberi ruang ekspresi sepanjang menghormati hak pihak lain', 'Persatuan tidak identik dengan penyeragaman.'],
    ['Rumor berbasis identitas memicu ketegangan', 'memverifikasi fakta, melibatkan pemimpin lintas kelompok, dan menghentikan penyebaran ujaran yang membahayakan', 'Konflik identitas ditangani dengan fakta, dialog, dan perlindungan setara.'],
    ['Pelayanan menggunakan satu bahasa teknis yang tidak dipahami warga', 'menyediakan penjelasan yang mudah dipahami tanpa merendahkan bahasa negara', 'Bahasa persatuan berfungsi menjembatani keragaman dan memastikan akses.'],
    ['Perwakilan kelompok dipilih hanya sebagai simbol tanpa suara', 'memberi mandat, informasi, dan pengaruh nyata dalam keputusan', 'Inklusi substantif menuntut partisipasi bermakna, bukan sekadar representasi simbolik.'],
  ],
  'bumn/wawasan_kebangsaan/pancasila': [
    ['BUMN menilai proyek hanya dari keuntungan jangka pendek', 'memasukkan dampak pelayanan, keadilan, lingkungan, dan keberlanjutan dalam keputusan', 'Pancasila mengarahkan kegiatan ekonomi agar efisien sekaligus berkeadilan dan manusiawi.'],
    ['Kebijakan tarif efisien tetapi membebani kelompok rentan', 'menguji skema berjenjang dan mitigasi yang tepat sasaran tanpa menghilangkan disiplin biaya', 'Keadilan sosial menuntut desain yang mempertimbangkan kemampuan dan kebutuhan.'],
    ['Rapat direksi menutup pandangan minoritas', 'menguji argumen minoritas berbasis data sebelum mengambil keputusan kolektif', 'Musyawarah berkualitas menilai alasan, bukan sekadar jumlah pendukung.'],
    ['Ekspansi usaha memerlukan relokasi masyarakat', 'melibatkan masyarakat, menilai alternatif, dan memastikan pemulihan mata pencaharian yang layak', 'Nilai kemanusiaan dan keadilan harus hadir dalam keputusan korporasi.'],
    ['Unit mengejar target sendiri dengan merugikan rantai layanan nasional', 'menyelaraskan target unit dengan manfaat perusahaan dan kepentingan nasional', 'Persatuan menempatkan tujuan bersama di atas ego organisasi.'],
    ['Pengadaan lokal sedikit lebih mahal tetapi memperkuat ekosistem nasional', 'membandingkan total nilai, mutu, risiko, dan dampak nasional secara transparan', 'Keputusan Pancasilais tidak otomatis proteksionis; ia memakai penilaian manfaat yang menyeluruh dan adil.'],
  ],
  'bumn/wawasan_kebangsaan/uud_1945': [
    ['Program layanan publik BUMN mengelola data sensitif', 'menetapkan dasar pemrosesan, pembatasan akses, akuntabilitas, dan pemulihan hak pengguna', 'Kegiatan korporasi tetap menghormati hak konstitusional dan prinsip negara hukum.'],
    ['Penugasan pemerintah berpotensi menekan kesehatan perusahaan', 'mendokumentasikan mandat, biaya, risiko, dan mekanisme kompensasi secara transparan', 'Pelaksanaan tujuan negara perlu tunduk pada tata kelola dan akuntabilitas.'],
    ['Kebijakan internal membatasi pegawai menyampaikan pelanggaran', 'menyediakan kanal aman, perlindungan pelapor, dan pemeriksaan yang adil', 'Hak menyampaikan informasi dan proses yang adil harus dijaga dalam tata kelola.'],
    ['Kontrak strategis dibuat tanpa kewenangan yang jelas', 'memastikan delegasi kewenangan, kepatuhan hukum, dan pengawasan sebelum penandatanganan', 'Negara hukum mengharuskan setiap tindakan memiliki dasar kewenangan.'],
    ['Aset yang menguasai hajat hidup dialihkan tanpa analisis layanan', 'menilai dampak pada akses publik, kendali negara, dan keberlanjutan layanan', 'Pengelolaan cabang produksi strategis harus dikaitkan dengan sebesar-besar kemakmuran rakyat.'],
    ['Krisis mendorong keputusan cepat tanpa dokumentasi', 'menggunakan prosedur darurat yang sah, terbatas, tercatat, dan ditinjau kembali', 'Kedaruratan tidak menghapus legalitas dan akuntabilitas.'],
  ],
  'bumn/wawasan_kebangsaan/nkri': [
    ['Jaringan layanan hanya terkonsentrasi di wilayah paling menguntungkan', 'menggabungkan efisiensi dengan strategi perluasan akses antardaerah yang terukur', 'Komitmen NKRI mendorong konektivitas dan pemerataan tanpa mengabaikan keberlanjutan.'],
    ['Gangguan rantai pasok di satu wilayah berdampak nasional', 'membangun redundansi antardaerah dan koordinasi pusat-daerah berbasis risiko', 'Ketahanan nasional memerlukan jejaring yang saling menopang.'],
    ['Unit daerah mengembangkan solusi efektif yang belum dikenal pusat', 'menguji bukti lalu mereplikasi dengan penyesuaian konteks daerah', 'NKRI menghubungkan standar nasional dengan pembelajaran dari keragaman wilayah.'],
    ['Investasi strategis bergantung pada satu pemasok luar negeri', 'menilai risiko kedaulatan, diversifikasi, dan penguatan kapasitas domestik', 'Kemandirian strategis dibangun melalui manajemen risiko, bukan isolasi.'],
    ['Bencana memutus layanan lintas provinsi', 'mengaktifkan komando insiden, berbagi sumber daya, dan memprioritaskan pemulihan layanan kritis', 'Solidaritas antardaerah menjaga keberlangsungan fungsi nasional.'],
    ['Data operasi tiap wilayah memakai standar berbeda', 'menetapkan interoperabilitas nasional sambil mempertahankan data lokal yang relevan', 'Kesatuan sistem tidak harus menghapus kebutuhan khas daerah.'],
  ],
  'bumn/wawasan_kebangsaan/bhinneka_tunggal_ika': [
    ['Produk layanan tidak aksesibel bagi komunitas tertentu', 'melibatkan pengguna beragam dan memperbaiki desain berdasarkan hambatan nyata', 'Keberagaman menjadi sumber desain layanan yang lebih inklusif.'],
    ['Tim nasional salah memahami kebiasaan kerja daerah', 'membangun norma bersama dan memberi ruang adaptasi lokal yang tidak melanggar standar', 'Bhinneka Tunggal Ika menyeimbangkan kesatuan tujuan dan keragaman cara.'],
    ['Kampanye pemasaran memakai stereotip budaya', 'menghentikan materi, berkonsultasi dengan pihak terkait, dan memperbaiki proses review', 'Penghormatan identitas memerlukan koreksi dan pencegahan, bukan pembelaan niat.'],
    ['Rekrutmen dari satu jaringan menghasilkan tim homogen', 'memperluas kanal rekrutmen dan memakai kriteria kompetensi yang konsisten', 'Kesempatan setara membutuhkan akses yang luas dan seleksi objektif.'],
    ['Konflik antarkelompok muncul dalam proyek lintas wilayah', 'memfasilitasi fakta, kebutuhan, dan tujuan bersama serta menetapkan aturan anti-diskriminasi', 'Persatuan dibangun melalui dialog terstruktur dan perlindungan setara.'],
    ['Hari budaya dirayakan tetapi kebijakan kerja tetap tidak inklusif', 'mengaudit hambatan struktural dan mengubah praktik yang membatasi partisipasi', 'Inklusi harus tampak dalam sistem kerja, bukan hanya seremoni.'],
  ],
};

function generateCivics(path, index, seed) {
  const cases = CIVICS_SPECS[path];
  if (!cases) throw new Error(`Missing civics specification for ${path}.`);
  const [situation, answer, rationale] = cases[index % cases.length];
  const variant = Math.floor((index - 1) / cases.length);
  const actors = [
    'sebuah tim lintas fungsi', 'pimpinan unit', 'forum pemangku kepentingan',
    'pengelola program', 'kelompok evaluasi', 'panitia kebijakan',
  ];
  const actor = actors[variant % actors.length];
  const setting = UNITS[Math.floor(variant / actors.length) % UNITS.length];
  const constraints = [
    'keputusan harus dapat dievaluasi dalam tiga bulan',
    'anggaran tambahan tidak tersedia',
    'kelompok terdampak memiliki kepentingan yang berbeda',
    'informasi publik harus tetap akurat',
    'layanan dasar tidak boleh terhenti',
    'risiko jangka panjang lebih besar daripada manfaat sesaat',
  ];
  const constraint = constraints[Math.floor(variant / (actors.length * UNITS.length)) % constraints.length];
  const correct = `${capitalize(answer)} serta menetapkan indikator untuk menilai dampaknya`;
  const hint = CIVICS_HINTS[path] ?? 'Pilih opsi yang paling selaras dengan prinsip kebangsaan dan tata kelola berintegritas.';
  return mcq(
    `${situation}. ${capitalize(actor)} di ${setting} harus mengambil keputusan dengan batasan bahwa ${constraint}. Keputusan yang paling tepat berdasarkan prinsip subkategori ini adalah ....`,
    correct,
    [
      'Memilih tindakan tercepat tanpa menguji dampak terhadap hak dan kepentingan pihak lain',
      'Menunda keputusan sampai semua pihak memiliki pendapat yang sama persis',
      'Mengutamakan kelompok paling kuat karena dianggap paling mampu menjaga stabilitas',
    ],
    `${rationale} Indikator dampak diperlukan agar penerapan prinsip dapat dievaluasi, bukan berhenti sebagai pernyataan normatif.`,
    'hard',
    hint,
  );
}

function mcq(prompt, answer, distractors, explanation, difficulty, hint = null) {
  return { prompt, answer, distractors, explanation, difficulty, hint };
}

function numberMcq(prompt, answer, distractors, explanation, difficulty, suffix = '', hint = null) {
  const answerText = `${formatNumber(answer)}${suffix}`;
  const candidateDistractors = distractors.map((value) => `${formatNumber(value)}${suffix}`);
  const step = Math.max(1, Math.round(Math.abs(Number(answer)) * 0.1));
  for (const offset of [step, -step, step * 2, -step * 2, step * 3, -step * 3]) {
    candidateDistractors.push(`${formatNumber(Number(answer) + offset)}${suffix}`);
  }
  return mcq(
    prompt,
    answerText,
    takeDistinct(candidateDistractors, answerText).slice(0, 3),
    explanation,
    difficulty,
    hint,
  );
}

function finalize({ target, category, subcategory, index, seed, prompt, answer, distractors, explanation, difficulty, hint }) {
  const values = [answer, ...takeDistinct(distractors, answer)].slice(0, 4);
  if (values.length !== 4) {
    throw new Error(`Question ${target}/${category}/${subcategory}/${index} does not have three distinct distractors.`);
  }
  const rotation = seed % 4;
  const options = [...values.slice(rotation), ...values.slice(0, rotation)];
  const correctOptionIndex = options.indexOf(answer);
  const completeExplanation = `${explanation} Karena itu, jawaban yang konsisten dengan seluruh informasi pada soal adalah ${answer}.`;
  const weight = difficulty === 'hard' ? 4 : difficulty === 'medium' ? 3 : 2;
  const effect = index % 5 === 0 ? 'heal' : 'damage';
  return {
    sourceKey: `hots-v1:${target}:${category}:${subcategory}:${String(index).padStart(4, '0')}`,
    revision: subcategory === 'figural' ? 2 : 3,
    target,
    category,
    subcategory,
    primarySkillId: `${target}.${category}.${subcategory}`,
    prerequisiteSkillIds: [],
    prompt,
    options,
    correctOptionIndex,
    explanation: completeExplanation,
    difficulty,
    questionType: 'multiple_choice',
    expectedTimeMs: difficulty === 'hard' ? 70000 : 55000,
    standardTimeLimitMs: difficulty === 'hard' ? 90000 : 75000,
    curriculumWeight: difficulty === 'hard' ? 1.25 : 1,
    assessmentEligible: false,
    qualityState: 'development',
    smeApproved: false,
    approvedAt: null,
    approverReference: null,
    weight,
    effect,
    damageValue: effect === 'damage' ? 10 : 0,
    healValue: effect === 'heal' ? 10 : 0,
    timeLimitSeconds: difficulty === 'hard' ? 90 : 75,
    hint: hint ?? 'Perhatikan kata kunci dan aturan logika pada soal untuk menentukan pilihan terbaik.',
    active: true,
  };
}

function hash(value) {
  let result = 2166136261;
  for (const char of value) {
    result ^= char.charCodeAt(0);
    result = Math.imul(result, 16777619);
  }
  return result >>> 0;
}

function role(seed, shift) {
  const roles = ['analis', 'auditor', 'verifikator', 'perencana', 'fasilitator', 'pengawas', 'penelaah', 'koordinator', 'asesor', 'mediator'];
  return roles[(seed + shift) % roles.length];
}

function rotatedPeople(seed, count) {
  const start = seed % PEOPLE.length;
  return Array.from({ length: count }, (_, index) => PEOPLE[(start + index * 3) % PEOPLE.length]);
}

function orderedPeople(ordinal, count) {
  const steps = [1, 3, 5, 7];
  const start = ordinal % PEOPLE.length;
  const step = steps[Math.floor(ordinal / PEOPLE.length) % steps.length];
  return Array.from({ length: count }, (_, index) => PEOPLE[(start + index * step) % PEOPLE.length]);
}

function orderedUnits(ordinal, count) {
  const steps = [1, 5, 7, 11];
  const start = ordinal % UNITS.length;
  const step = steps[Math.floor(ordinal / UNITS.length) % steps.length];
  return Array.from({ length: count }, (_, index) => UNITS[(start + index * step) % UNITS.length]);
}

function orderedRoles(ordinal) {
  const roles = ['analis', 'auditor', 'verifikator', 'perencana', 'fasilitator', 'pengawas', 'penelaah', 'koordinator', 'asesor', 'mediator'];
  const steps = [1, 3, 7, 9];
  const start = ordinal % roles.length;
  const step = steps[Math.floor(ordinal / roles.length) % steps.length];
  return [0, 1, 2].map((offset) => roles[(start + offset * step) % roles.length]);
}

function takeDistinct(values, excluded) {
  return [...new Set(values.filter((value) => value !== excluded))].slice(0, 3);
}

function formatNumber(value) {
  return Number.isInteger(value) ? String(value) : String(value).replace('.', ',');
}

function capitalize(value) {
  return `${value[0].toUpperCase()}${value.slice(1)}`;
}

function lowerFirst(value) {
  return `${value[0].toLowerCase()}${value.slice(1)}`;
}
