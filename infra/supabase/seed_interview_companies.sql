-- ============================================================================
-- SQL SEED SCRIPT: Interview Company Profiles & Contexts
-- Target Tables: public.interview_company_profiles & public.interview_company_contexts
-- Generated at: 2026-08-29T04:52:40.477Z
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Company: PT Adhi Karya (Persero) Tbk (adhi-karya)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('adhi-karya', 'PT Adhi Karya (Persero) Tbk', 'PT Adhi Karya (Persero) Tbk. Didirikan dari nasionalisasi perusahaan Belanda (Architecten-Ingenicure-en Annemersbedrijf Associatie Selleen de Bruyn, Reyerse en de Vries N.V.) pada 11 Maret 1960 menjadi PN Adhi Karya. Menjadi PT (Persero) pada 1 Juni 1974. IPO pada 18 Maret 2004. Lebih dari 60+ tahun pengalaman di konstruksi infrastruktur Indonesia. Visi: Menjadi Korporasi Inovatif dan Berbudaya Unggul untuk Pertumbuhan Berkelanjutan.', 'v1', 'Management Trainee')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'adhi-karya';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Sejarah & Profil Utama', 'Overview & Sejarah:
Didirikan dari nasionalisasi perusahaan Belanda (Architecten-Ingenicure-en Annemersbedrijf Associatie Selleen de Bruyn, Reyerse en de Vries N.V.) pada 11 Maret 1960 menjadi PN Adhi Karya. Menjadi PT (Persero) pada 1 Juni 1974. IPO pada 18 Maret 2004. Lebih dari 60+ tahun pengalaman di konstruksi infrastruktur Indonesia.

Milestones:
- 1960: Nasionalisasi dan pendirian sebagai PN Adhi Karya
- 1974: Menjadi Persero
- 2004: IPO di BEI
- 2020+: Redefinisi visi-misi, transformasi digital, fokus ESG dan TOD (Transit Oriented Development)
- Ongoing: Proyek-proyek strategis nasional seperti jalan tol, LRT, MRT, bendungan, dll.', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Visi & Misi', 'Visi:
Menjadi Korporasi Inovatif dan Berbudaya Unggul untuk Pertumbuhan Berkelanjutan.

Misi:
- Membangun insan yang unggul, profesional, amanah, dan berjiwa wirausaha.
- Mengembangkan bisnis konstruksi, rekayasa, properti, industri, dan investasi yang bereputasi.
- Mengembangkan inovasi produk dan proses untuk memberi solusi serta impact bagi stakeholders.
- Menjalankan organisasi dengan tata kelola perusahaan yang baik.
- Menjalankan sistem manajemen yang menjamin pencapaian sasaran, kualitas, keselamatan, kesehatan dan lingkungan kerja.
- Mengembangkan teknologi informasi dan komunikasi sebagai sarana untuk pembuatan keputusan dan pengelolaan risiko korporasi.', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Budaya Kerja & Core Values', 'Nilai Utama & Budaya (AKHLAK/Core Values):
- Amanah
- Kompeten
- Harmonis
- Loyal
- Adaptif
- Kolaboratif

Budaya Kerja: Berbasis AKHLAK BUMN dengan penekanan pada inovasi, profesionalisme, kolaborasi, dan keberlanjutan. Didukung ADHI Learning Center (ALC) untuk pengembangan SDM. Fokus pada K3 (Keselamatan & Kesehatan Kerja), etika bisnis, dan adaptasi teknologi.', 40);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Lini Bisnis & Peran Utama', 'Lini Bisnis Utama:
• Engineering & Construction: Proyek sipil, gedung, perkeretaapian (stasiun, jalan, jembatan), industri, petrokimia, kelistrikan, telekomunikasi, perminyakan, agro, mekanikal, elektrikal. Termasuk EPC.
• Property & Hospitality: Pengembangan properti (TOD, apartemen, high-rise, landed house, mall, hotel). Dikelola melalui anak perusahaan seperti Adhi Commuter Properti dan Adhi Persada Properti.
• Manufacture: Produksi beton pracetak (precast), ready mix, dan produk manufaktur terkait.
• Investment & Concession: Investasi infrastruktur, konsesi (termasuk fasilitas pengolahan limbah, dll.), dan recurring income.', 50);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Struktur Kepemimpinan & Governance', 'Dewan Komisaris:
• Komisaris Utama: Dody Usodo Hargosuseno
• Komisaris Independen: R. Erwin M. Singajuru
• Komisaris: Bob Arthur Lombogia
• Komisaris Independen: Rustam Sofyan Sirait
• Komisaris Independen: Elan Suherlan
• Komisaris: Amelia Tetriana

Dewan Direksi:
• Direktur Utama: Moeharmein Zein Chaniago
• Direktur Human Capital & Legal: Ki Syahgolang Permata
• Direktur Keuangan: Bani Iqbal
• Direktur Manajemen Risiko & Kesisteman: Yan Arianto
• Direktur Operasi I: Alloysius Suko Widigdo
• Direktur Operasi II: Harimawan
• Direktur Operasi III: Vera Kirana', 60);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('adhi-karya', 'Inisiatif Strategis, Digital & ESG', 'Komitmen ESG: Komitmen kuat terhadap Environmental, Social, Governance (ESG) melalui ''ADHI for ESG'', Roadmap ESG, Komite ESG, dan Biro ESG. Selaras dengan SDGs dan transisi hijau Indonesia.', 70);

-- ----------------------------------------------------------------------------
-- Company: Bank Indonesia (bank-indonesia)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('bank-indonesia', 'Bank Indonesia', 'Bank Indonesia. Bank Indonesia adalah bank sentral Republik Indonesia yang bertugas menjaga stabilitas nilai rupiah, menjaga stabilitas sistem keuangan, dan mendukung pembangunan ekonomi berkelanjutan. BI berperan sebagai otoritas moneter, regulator perbankan (sebagian), dan pengelola cadangan devisa. Visi: Menjadi bank sentral yang kredibel dan terbaik di kawasan melalui penguatan nilai-nilai strategis berlandaskan integritas, profesionalisme, dan inovasi untuk mendukung stabilitas dan pembangunan ekonomi nasional yang berkelanjutan.', 'v1', 'Asisten Manajer')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'bank-indonesia';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-indonesia', 'Sejarah & Profil Utama', 'Overview & Sejarah:
Bank Indonesia adalah bank sentral Republik Indonesia yang bertugas menjaga stabilitas nilai rupiah, menjaga stabilitas sistem keuangan, dan mendukung pembangunan ekonomi berkelanjutan. BI berperan sebagai otoritas moneter, regulator perbankan (sebagian), dan pengelola cadangan devisa.

Dasar Hukum: Undang-Undang No. 23 Tahun 1999 tentang Bank Indonesia (sebagaimana diubah dengan UU No. 6 Tahun 2023)', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-indonesia', 'Visi & Misi', 'Visi:
Menjadi bank sentral yang kredibel dan terbaik di kawasan melalui penguatan nilai-nilai strategis berlandaskan integritas, profesionalisme, dan inovasi untuk mendukung stabilitas dan pembangunan ekonomi nasional yang berkelanjutan.

Misi:
- Mencapai dan memelihara stabilitas nilai rupiah
- Menjaga stabilitas sistem keuangan
- Mendukung pertumbuhan ekonomi berkelanjutan dan inklusif
- Meningkatkan peran BI dalam sistem keuangan internasional', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-indonesia', 'Budaya Kerja & Core Values', 'Nilai Utama & Budaya (AKHLAK/Core Values):
- Integritas, Profesionalisme, Inovasi, Kolaborasi, dan Akuntabilitas

Budaya Kerja: Budaya BI menekankan integritas tinggi, profesionalisme, dan inovasi untuk mendukung tugas negara. Karyawan BI (Pegawai BI) diharapkan memiliki semangat nasionalisme, disiplin, dan komitmen terhadap good governance.', 40);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-indonesia', 'Inisiatif Strategis, Digital & ESG', 'Komitmen ESG: Mendukung transisi ekonomi hijau dan keuangan berkelanjutan', 50);

-- ----------------------------------------------------------------------------
-- Company: PT Bank Mandiri (Persero) Tbk (bank-mandiri)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('bank-mandiri', 'PT Bank Mandiri (Persero) Tbk', 'PT Bank Mandiri (Persero) Tbk. PT Bank Mandiri (Persero) Tbk adalah bank terbesar di Indonesia yang berfokus pada layanan perbankan komersial, ritel, dan digital. Didirikan melalui merger empat bank BUMN pada 1998, Bank Mandiri menjadi salah satu pilar utama perekonomian Indonesia dengan transformasi digital yang kuat. Visi: Menjadi The Best Financial Institution in Southeast Asia melalui fondasi operasional kelas dunia, kapabilitas digital terdepan, dan budaya inovasi berkelanjutan.', 'v1', 'Officer Development Program')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'bank-mandiri';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-mandiri', 'Sejarah & Profil Utama', 'Overview & Sejarah:
PT Bank Mandiri (Persero) Tbk adalah bank terbesar di Indonesia yang berfokus pada layanan perbankan komersial, ritel, dan digital. Didirikan melalui merger empat bank BUMN pada 1998, Bank Mandiri menjadi salah satu pilar utama perekonomian Indonesia dengan transformasi digital yang kuat.', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-mandiri', 'Visi & Misi', 'Visi:
Menjadi The Best Financial Institution in Southeast Asia melalui fondasi operasional kelas dunia, kapabilitas digital terdepan, dan budaya inovasi berkelanjutan.

Misi:
- Menyediakan solusi keuangan terintegrasi dan inovatif berbasis teknologi dengan pelayanan unggul, fokus pada kepuasan nasabah, inklusi keuangan, dan peningkatan nilai bagi pemegang saham untuk mendorong pertumbuhan ekonomi Indonesia.', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('bank-mandiri', 'Budaya Kerja & Core Values', 'Nilai Utama & Budaya (AKHLAK/Core Values):
- Terdepan: Kerja keras, profesionalisme, dan semangat menjadi yang terbaik
Terpercaya: Integritas tinggi, transparansi, dan kepercayaan stakeholder
Tumbuh Bersama Anda: Kolaborasi dan pertumbuhan bersama karyawan, nasabah, serta masyarakat

Budaya Kerja: Budaya kerja Bank Mandiri dibangun di atas semangat profesionalisme, integritas, inovasi, dan kolaborasi. Perusahaan menekankan lingkungan kerja yang inspiratif, progresif, dan mendukung pengembangan karyawan.', 40);

-- ----------------------------------------------------------------------------
-- Company: PT Garuda Indonesia (Persero) Tbk (garuda-indonesia)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('garuda-indonesia', 'PT Garuda Indonesia (Persero) Tbk', 'PT Garuda Indonesia (Persero) Tbk. Sejarah penerbangan komersial Indonesia dimulai saat bangsa Indonesia sedang mempertahankan kemerdekaannya. Penerbangan sipil pertama atas inisiatif AURI dengan menyewakan pesawat ''Indonesian Airways'' ke Burma pada 26 Januari 1949. Visi: TO BECOME A SUSTAINABLE AVIATION GROUP BY CONNECTING INDONESIA ARCHIPELAGO AND BEYOND WHILE PASSIONATELY DELIVER INDONESIAN HOSPITALITY TO THE WORLD', 'v1', 'Management Trainee')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'garuda-indonesia';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Sejarah & Profil Utama', 'Overview & Sejarah:
Sejarah penerbangan komersial Indonesia dimulai saat bangsa Indonesia sedang mempertahankan kemerdekaannya. Penerbangan sipil pertama atas inisiatif AURI dengan menyewakan pesawat ''Indonesian Airways'' ke Burma pada 26 Januari 1949.

Milestones:
- 1949: Penerbangan komersial pertama
- 1950: Pendirian resmi PT Garuda Indonesia
- 2014: Mulai meraih 5-Star Skytrax dan World''s Best Cabin Crew
- 2017: 5-Star APEX rating
- 2020: Transformasi pasca-pandemi dan restrukturisasi
- 2023: Regain World''s Best Cabin Crew', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Visi & Misi', 'Visi:
TO BECOME A SUSTAINABLE AVIATION GROUP BY CONNECTING INDONESIA ARCHIPELAGO AND BEYOND WHILE PASSIONATELY DELIVER INDONESIAN HOSPITALITY TO THE WORLD

Misi:
- BUILDING A PROFITABLE AVIATION GROUP THROUGH STRONG BUSINESS FUNDAMENTALS WHILE DELIVERING SERVICE EXCELLENCE AND FOCUSING ON HIGH STANDARD OF SAFETY AND SECURITY BY PROFESSIONAL AND PASSIONATE EMPLOYEES', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Budaya Kerja & Core Values', 'Nilai Utama & Budaya (AKHLAK/Core Values):
- AKHLAK

Panduan Perilaku: 18 Panduan Perilaku yang mendukung profesionalisme, integritas, disiplin

Budaya Kerja: Indonesian Hospitality di setiap touchpoint. Fokus pada safety, customer-oriented, professional & passionate employees. Budaya transformasi: agile, dynamic, profitable.

Elemen Utama Budaya:
- Keramahtamahan Indonesia autentik
- Komitmen keselamatan tinggi
- Kolaborasi grup dan mitra
- Pengembangan SDM berkelanjutan
- Integritas dan etika bisnis', 40);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Lini Bisnis & Peran Utama', 'Anak Perusahaan & Unit Usaha:
• PT Citilink Indonesia (99.99%): Low Cost Carrier
• PT Garuda Maintenance Facility Aero Asia Tbk (high majority): Aircraft Maintenance, Repair & Overhaul (MRO)
• PT Aero Wisata (): Hospitality, Tourism, Catering
• PT Aero Systems Indonesia (): IT Systems, CRS, Consulting
• PT Sabre Travel Network Indonesia (): Travel Technology
• Garuda Indonesia Holiday France S.A.S. (): Holiday/Tourism

Produk & Layanan Utama: Scheduled & Non-scheduled passenger & cargo flights', 50);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Struktur Kepemimpinan & Governance', 'Dewan Komisaris:
• Independent President Commissioner: Fadjar Prasetyo
• Vice President Commissioner: Chairal Tanjung
• Independent Commissioner: Timur Sukirno

Dewan Direksi:
• President Director / President & CEO: Wamildan Tsani
• Director of Finance & Risk Management: Prasetio
• Director of Operation: Tumpal Manumpak Hutapea
• Director of Technical: Rahmat Hanafi
• Director of Human Capital & Corporate Services: Enny Kristiani Elisabeth
• Director of Service & Commercial: Ade Ruchyat Susardi', 60);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('garuda-indonesia', 'Inisiatif Strategis, Digital & ESG', 'Komitmen ESG: Rooted in Values, Sustainability in Action. Komitmen Net Zero Emission sesuai ICAO LTAG 2050, CORSIA, dan NDC Indonesia.

Penghargaan Utama:
- 5-Star Skytrax since 2014
- World''s Best Cabin Crew (multiple years)
- 5-Star APEX 2017
- Top 10 World''s Best Airline (Skytrax)
- Best Airline in Indonesia (TripAdvisor)
- Platinum ASRRAT 2025', 70);

-- ----------------------------------------------------------------------------
-- Company: PT Aviasi Pariwisata Indonesia (Persero) (injourney)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('injourney', 'PT Aviasi Pariwisata Indonesia (Persero)', 'PT Aviasi Pariwisata Indonesia (Persero). InJourney adalah holding BUMN pertama yang mengintegrasikan aset aviasi dan pariwisata nasional pasca-pandemi untuk kebangkitan sektor.', 'v1', NULL)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'injourney';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('injourney', 'Sejarah & Profil Utama', 'Overview & Sejarah:
InJourney adalah holding BUMN pertama yang mengintegrasikan aset aviasi dan pariwisata nasional pasca-pandemi untuk kebangkitan sektor.

Milestones:
- undefined: undefined
- undefined: undefined
- undefined: undefined
- undefined: undefined
- undefined: undefined
- undefined: undefined
- undefined: undefined', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('injourney', 'Budaya Kerja & Core Values', 'Budaya Kerja: Budaya transformasi yang inklusif, inovatif, berbasis talenta lokal, dan berorientasi hospitality Indonesia.', 30);

-- ----------------------------------------------------------------------------
-- Company: Kementerian Keuangan Republik Indonesia (kementerian-keuangan)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('kementerian-keuangan', 'Kementerian Keuangan Republik Indonesia', 'Kementerian Keuangan Republik Indonesia. Kementerian Keuangan adalah kementerian yang menyelenggarakan urusan pemerintahan di bidang keuangan negara untuk membantu Presiden dalam menyelenggarakan pemerintahan negara.', 'v1', 'Staf Pengelola Keuangan Negara')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'kementerian-keuangan';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('kementerian-keuangan', 'Vision', 'Menjadi Pengelola Keuangan Negara untuk Mewujudkan Perekonomian Indonesia yang Produktif, Kompetitif, Inklusif, dan Berkeadilan.', 10);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('kementerian-keuangan', 'Mission', 'Kementerian Keuangan berfokus pada penerimaan negara yang optimal, belanja negara yang produktif, pengelolaan aset yang akuntabel, pembiayaan yang dikelola dengan risiko terkendali, serta reformasi birokrasi.', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('kementerian-keuangan', 'Values', 'Nilai-nilai Kementerian Keuangan adalah Integritas, Profesionalisme, Sinergi, Pelayanan, dan Kesempurnaan.', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('kementerian-keuangan', 'Interview focus', 'Gunakan konteks kementerian hanya saat relevan. Untuk tahap awal, gali latar belakang, motivasi pelayanan publik, pengalaman umum, integritas, kemampuan belajar, dan kolaborasi.', 40);

-- ----------------------------------------------------------------------------
-- Company: PT Kereta Api Indonesia (Persero) (kereta-api-indonesia)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('kereta-api-indonesia', 'PT Kereta Api Indonesia (Persero)', 'PT Kereta Api Indonesia (Persero).', 'v1', NULL)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'kereta-api-indonesia';

-- ----------------------------------------------------------------------------
-- Company: PT Pertamina (Persero) (pertamina)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('pertamina', 'PT Pertamina (Persero)', 'PT Pertamina (Persero). PT Pertamina (Persero) adalah perusahaan energi terintegrasi milik negara Indonesia yang beroperasi dari hulu hingga hilir, termasuk pengembangan energi baru dan terbarukan. Lebih dari enam dekade menyediakan energi untuk seluruh Indonesia dan beberapa wilayah luar negeri. Visi: Menjadi perusahaan energi yang mengedepankan ketahanan, ketersediaan, dan keberlanjutan energi.', 'v1', 'Bimbingan Profesi Sarjana')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'pertamina';
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('pertamina', 'Sejarah & Profil Utama', 'Overview & Sejarah:
PT Pertamina (Persero) adalah perusahaan energi terintegrasi milik negara Indonesia yang beroperasi dari hulu hingga hilir, termasuk pengembangan energi baru dan terbarukan. Lebih dari enam dekade menyediakan energi untuk seluruh Indonesia dan beberapa wilayah luar negeri.', 20);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('pertamina', 'Visi & Misi', 'Visi:
Menjadi perusahaan energi yang mengedepankan ketahanan, ketersediaan, dan keberlanjutan energi.

Misi:
- Menyediakan energi melalui solusi inovatif yang memberi nilai tambah untuk masyarakat.', 30);
INSERT INTO public.interview_company_contexts (company_id, category, content, priority)
VALUES ('pertamina', 'Budaya Kerja & Core Values', 'Nilai Utama & Budaya (AKHLAK/Core Values):
- AKHLAK

Budaya Kerja: Tata Nilai AKHLAK adalah core values utama yang diinternalisasi oleh seluruh Perwira Pertamina.', 40);

-- ----------------------------------------------------------------------------
-- Company: PT PLN (Persero) (perusahaan-listrik-negara)
-- ----------------------------------------------------------------------------
INSERT INTO public.interview_company_profiles (id, name, summary, content_version, default_role)
VALUES ('perusahaan-listrik-negara', 'PT PLN (Persero)', 'PT PLN (Persero).', 'v1', NULL)
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, summary = EXCLUDED.summary, default_role = COALESCE(EXCLUDED.default_role, interview_company_profiles.default_role), updated_at = now();

DELETE FROM public.interview_company_contexts WHERE company_id = 'perusahaan-listrik-negara';

COMMIT;
