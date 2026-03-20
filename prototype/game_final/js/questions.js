// ============================================================
//  questions.js  –  Bank soal CPNS (Verbal, Spasial, Numerik, TWK)
// ============================================================

const QUESTIONS = {
  verbal: [
    { q: 'Sinonim dari "AGRESIF" adalah?', options: ['Pasif','Ofensif','Defensif','Tenang'], answer: 1 },
    { q: 'Antonim dari "EKSPLISIT" adalah?', options: ['Jelas','Tersurat','Implisit','Nyata'], answer: 2 },
    { q: 'Kata yang paling tepat melengkapi: "Ia __ pidatonya dengan penuh semangat."', options: ['menyampaikan','mengatakan','bercerita','berbicara'], answer: 0 },
    { q: 'Sinonim "KONKRET" adalah?', options: ['Abstrak','Nyata','Imajinatif','Teoretis'], answer: 1 },
    { q: 'Analogi: PANAS : API = DINGIN : ?', options: ['Angin','Air','Es','Salju'], answer: 2 },
    { q: 'Antonim "STATIS" adalah?', options: ['Diam','Tetap','Dinamis','Pasif'], answer: 2 },
    { q: 'Sinonim "PROGRESI" adalah?', options: ['Kemunduran','Stagnasi','Kemajuan','Penurunan'], answer: 2 },
    { q: 'DOKTER : PASIEN = GURU : ?', options: ['Sekolah','Siswa','Pelajaran','Kelas'], answer: 1 },
    { q: 'Kata baku yang benar adalah?', options: ['Apotik','Apotek','Apotec','Aphotek'], answer: 1 },
    { q: 'Sinonim "KOLABORASI" adalah?', options: ['Persaingan','Kerja sama','Konflik','Kompetisi'], answer: 1 },
    { q: 'Antonim "EFISIEN" adalah?', options: ['Cepat','Tepat','Boros','Hemat'], answer: 2 },
    { q: 'PENA : MENULIS = PISAU : ?', options: ['Masak','Memotong','Dapur','Tajam'], answer: 1 },
    { q: 'Sinonim "AMBIGUITAS" adalah?', options: ['Kejelasan','Ketegasan','Kekaburan','Kepastian'], answer: 2 },
    { q: 'Kata yang tepat: "Masalah itu diselesaikan secara __."', options: ['musyawarah','berunding','mufakat','perundingan'], answer: 0 },
  ],
  spatial: [
    { q: 'Sebuah kubus memiliki berapa sisi?', options: ['4','6','8','12'], answer: 1 },
    { q: 'Bangun apa yang terbentuk jika sebuah kerucut dipotong tegak dari puncaknya?', options: ['Trapesium','Segitiga','Persegi','Lingkaran'], answer: 1 },
    { q: 'Berapa banyak diagonal pada sebuah segiempat?', options: ['1','2','3','4'], answer: 1 },
    { q: 'Bayangan cermin: jika tangan kanan diangkat, bayangan mengangkat tangan?', options: ['Kanan','Kiri','Kedua tangan','Tidak bergerak'], answer: 1 },
    { q: 'Pola: ▲ ■ ● ▲ ■ __ ?', options: ['▲','■','●','◆'], answer: 2 },
    { q: 'Sebuah dadu standar: jika angka 1 di atas, angka berapa di bawah?', options: ['2','3','5','6'], answer: 3 },
    { q: 'Kubus bervolume 27 cm³. Panjang sisi = ?', options: ['3 cm','6 cm','9 cm','27 cm'], answer: 0 },
    { q: 'Gambar tampak atas bola adalah?', options: ['Persegi','Elips','Lingkaran','Segitiga'], answer: 2 },
    { q: 'Benda yang tampak sama dari semua sudut pandang adalah?', options: ['Kerucut','Silinder','Bola','Kubus'], answer: 2 },
    { q: 'Rotasi 90° searah jarum jam dari atas: panah → menghadap ke?', options: ['Kiri','Kanan','Bawah','Atas'], answer: 1 },
    { q: 'Jaring-jaring kubus memiliki berapa persegi?', options: ['4','5','6','8'], answer: 2 },
    { q: 'Sebuah persegi panjang dilipat menjadi dua diagonal: membentuk?', options: ['Persegi','2 segitiga','Trapesium','Jajar genjang'], answer: 1 },
  ],
  numerik: [
    { q: '12 × 8 = ?', options: ['86','96','106','76'], answer: 1 },
    { q: '√144 = ?', options: ['11','14','12','13'], answer: 2 },
    { q: '25% dari 200 = ?', options: ['40','50','60','25'], answer: 1 },
    { q: '7³ = ?', options: ['343','243','441','314'], answer: 0 },
    { q: '15² − 100 = ?', options: ['115','125','135','145'], answer: 1 },
    { q: '3/4 + 1/2 = ?', options: ['1','5/4','7/4','1/4'], answer: 1 },
    { q: '2x + 6 = 20, x = ?', options: ['5','6','7','8'], answer: 2 },
    { q: '18 ÷ 0.6 = ?', options: ['3','12','30','108'], answer: 2 },
    { q: '45% dari 80 = ?', options: ['32','36','40','44'], answer: 1 },
    { q: '2¹⁰ = ?', options: ['512','1024','2048','256'], answer: 1 },
    { q: 'FPB dari 36 dan 48 adalah?', options: ['6','8','12','16'], answer: 2 },
    { q: '(-4) × (-7) = ?', options: ['-28','28','-11','11'], answer: 1 },
    { q: '5! (faktorial) = ?', options: ['25','60','120','720'], answer: 2 },
    { q: '0.75 dalam pecahan = ?', options: ['1/2','2/3','3/4','4/5'], answer: 2 },
    { q: 'Barisan: 2, 4, 8, 16, __ ?', options: ['24','28','32','36'], answer: 2 },
    { q: 'Deret Fibonacci: 1,1,2,3,5,8,__ ?', options: ['11','12','13','14'], answer: 2 },
    { q: 'Barisan: 100, 50, 25, 12.5, __ ?', options: ['5','6','6.25','7.5'], answer: 2 },
  ],
  twk: [
    { q: 'Pancasila sebagai dasar negara tercantum dalam?', options: ['Batang Tubuh UUD','Pembukaan UUD 1945','TAP MPR','KUHP'], answer: 1 },
    { q: 'Sila ke-3 Pancasila adalah?', options: ['Kemanusiaan yang Adil','Persatuan Indonesia','Kerakyatan yang Dipimpin','Keadilan Sosial'], answer: 1 },
    { q: 'Lambang negara Indonesia adalah?', options: ['Garuda','Banteng','Pohon Beringin','Padi dan Kapas'], answer: 0 },
    { q: 'UUD 1945 pertama kali disahkan pada tanggal?', options: ['17 Agustus 1945','18 Agustus 1945','1 Juni 1945','22 Juni 1945'], answer: 1 },
    { q: 'Semboyan negara Indonesia adalah?', options: ['Bhinneka Tunggal Ika','Tan Hana Dharma Mangrwa','Jalesveva Jayamahe','Swa Bhuwana Paksa'], answer: 0 },
    { q: 'Proklamasi kemerdekaan Indonesia dibacakan oleh?', options: ['Soekarno saja','Hatta saja','Soekarno & Hatta','BPUPKI'], answer: 2 },
    { q: 'Lembaga yang berwenang mengubah UUD 1945 adalah?', options: ['DPR','MPR','MA','Presiden'], answer: 1 },
    { q: 'Ibu kota Indonesia saat ini adalah?', options: ['Bandung','Surabaya','Jakarta','Nusantara'], answer: 2 },
    { q: 'NKRI adalah singkatan dari?', options: ['Negara Kesatuan Republik Indonesia','Negara Kesatuan Rakyat Indonesia','Negara Keadilan Republik Indonesia','Negara Kebangsaan Republik Indonesia'], answer: 0 },
    { q: 'Sistem pemerintahan Indonesia adalah?', options: ['Monarki','Parlementer','Presidensial','Federal'], answer: 2 },
    { q: 'Hari Sumpah Pemuda diperingati setiap tanggal?', options: ['28 Oktober','17 Agustus','20 Mei','10 November'], answer: 0 },
    { q: 'Keberagaman budaya Indonesia dijaga melalui prinsip?', options: ['Uniformitas','Bhinneka Tunggal Ika','Sentralisasi','Singularitas'], answer: 1 },
    { q: 'Pasal UUD 1945 yang mengatur tentang HAM adalah?', options: ['Pasal 26','Pasal 27','Pasal 28','Pasal 29'], answer: 2 },
    { q: 'BPUPKI dibentuk pada tahun?', options: ['1943','1944','1945','1946'], answer: 1 },
  ],
};

function getRandomQuestion(category = 'numerik') {
  const pool = QUESTIONS[category] || QUESTIONS.numerik;
  return pool[Math.floor(Math.random() * pool.length)];
}
