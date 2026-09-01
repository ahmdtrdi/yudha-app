begin;

-- Normalize aliases that previously split one logical topic into multiple cards.
update public.questions
set
  subcategory = case subcategory
    when 'kemampuan_verbal' then 'verbal'
    when 'kemampuan_numerik' then 'numerik'
    when 'kemampuan_logis' then 'logis'
    when 'kemampuan_logika' then 'logis'
    when 'logika' then 'logis'
    when 'kemampuan_figural' then 'figural'
    when 'pancasila_ideologi' then 'pancasila_dan_ideologi'
    when 'konstitusi_negara' then 'konstitusi_dan_negara'
    when 'sejarah_kebangsaan' then 'sejarah_dan_kebangsaan'
    when 'pelayanan_integritas' then 'pelayanan_dan_integritas'
    when 'kerja_sama_komunikasi' then 'kerja_sama_dan_komunikasi'
    when 'adaptasi_pengembangan_diri' then 'adaptasi_dan_pengembangan_diri'
    when 'pengambilan_keputusan_kinerja' then 'pengambilan_keputusan_dan_kinerja'
    else subcategory
  end,
  category = case
    when target = 'cpns' and subcategory in ('pancasila_dan_ideologi', 'pancasila_ideologi', 'konstitusi_dan_negara', 'konstitusi_negara', 'sejarah_dan_kebangsaan', 'sejarah_kebangsaan', 'bhinneka_tunggal_ika') then 'twk'
    when target = 'cpns' and subcategory in ('verbal', 'kemampuan_verbal', 'numerik', 'kemampuan_numerik', 'logis', 'logika', 'kemampuan_logis', 'kemampuan_logika', 'figural', 'kemampuan_figural') then 'tiu'
    when target = 'cpns' and subcategory in ('pelayanan_dan_integritas', 'pelayanan_integritas', 'kerja_sama_dan_komunikasi', 'kerja_sama_komunikasi', 'adaptasi_dan_pengembangan_diri', 'adaptasi_pengembangan_diri', 'pengambilan_keputusan_dan_kinerja', 'pengambilan_keputusan_kinerja') then 'tkp'
    when target = 'bumn' and subcategory in ('pancasila', 'uud_1945', 'nkri', 'bhinneka_tunggal_ika') then 'wawasan_kebangsaan'
    when target = 'bumn' and subcategory in ('verbal', 'kemampuan_verbal', 'numerik', 'kemampuan_numerik', 'logis', 'logika', 'kemampuan_logis', 'kemampuan_logika', 'figural', 'kemampuan_figural') then 'tkd'
    when target = 'bumn' and subcategory in ('amanah', 'kompeten', 'harmonis', 'loyal') then 'akhlak'
    else category
  end,
  updated_at = now()
where target in ('cpns', 'bumn');

-- The old source only marked these records as TWK/AKHLAK. Their content is
-- classified explicitly so repeatable imports never have to guess by keyword.
with assignments(source_key, subcategory) as (
  values
    ('legacy:cpns:189', 'pancasila_dan_ideologi'),
    ('legacy:cpns:190', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:191', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:192', 'pancasila_dan_ideologi'),
    ('legacy:cpns:193', 'pancasila_dan_ideologi'),
    ('legacy:cpns:194', 'pancasila_dan_ideologi'),
    ('legacy:cpns:195', 'pancasila_dan_ideologi'),
    ('legacy:cpns:196', 'pancasila_dan_ideologi'),
    ('legacy:cpns:197', 'pancasila_dan_ideologi'),
    ('legacy:cpns:198', 'pancasila_dan_ideologi'),
    ('legacy:cpns:199', 'pancasila_dan_ideologi'),
    ('legacy:cpns:200', 'pancasila_dan_ideologi'),
    ('legacy:cpns:201', 'pancasila_dan_ideologi'),
    ('legacy:cpns:202', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:203', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:204', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:205', 'konstitusi_dan_negara'),
    ('legacy:cpns:206', 'pancasila_dan_ideologi'),
    ('legacy:cpns:207', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:208', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:209', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:210', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:211', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:212', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:213', 'konstitusi_dan_negara'),
    ('legacy:cpns:214', 'konstitusi_dan_negara'),
    ('legacy:cpns:215', 'konstitusi_dan_negara'),
    ('legacy:cpns:216', 'konstitusi_dan_negara'),
    ('legacy:cpns:217', 'pancasila_dan_ideologi'),
    ('legacy:cpns:218', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:219', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:220', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:221', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:222', 'konstitusi_dan_negara'),
    ('legacy:cpns:223', 'konstitusi_dan_negara'),
    ('legacy:cpns:224', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:225', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:226', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:227', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:228', 'konstitusi_dan_negara'),
    ('legacy:cpns:229', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:230', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:231', 'pancasila_dan_ideologi'),
    ('legacy:cpns:232', 'pancasila_dan_ideologi'),
    ('legacy:cpns:233', 'bhinneka_tunggal_ika'),
    ('legacy:cpns:234', 'pancasila_dan_ideologi'),
    ('legacy:cpns:235', 'pancasila_dan_ideologi'),
    ('legacy:cpns:236', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:237', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:238', 'konstitusi_dan_negara'),
    ('legacy:cpns:239', 'konstitusi_dan_negara'),
    ('legacy:cpns:240', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:241', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:242', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:243', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:244', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:245', 'konstitusi_dan_negara'),
    ('legacy:cpns:246', 'konstitusi_dan_negara'),
    ('legacy:cpns:247', 'pancasila_dan_ideologi'),
    ('legacy:cpns:248', 'sejarah_dan_kebangsaan'),
    ('legacy:cpns:249', 'pancasila_dan_ideologi'),
    ('legacy:cpns:250', 'konstitusi_dan_negara'),
    ('legacy:bumn:76', 'harmonis'),
    ('legacy:bumn:77', 'kompeten'),
    ('legacy:bumn:78', 'harmonis'),
    ('legacy:bumn:79', 'amanah'),
    ('legacy:bumn:80', 'kompeten'),
    ('legacy:bumn:81', 'harmonis'),
    ('legacy:bumn:82', 'kompeten'),
    ('legacy:bumn:83', 'kompeten'),
    ('legacy:bumn:84', 'amanah'),
    ('legacy:bumn:85', 'harmonis'),
    ('legacy:bumn:86', 'kompeten'),
    ('legacy:bumn:87', 'loyal'),
    ('legacy:bumn:88', 'harmonis'),
    ('legacy:bumn:89', 'amanah'),
    ('legacy:bumn:90', 'kompeten'),
    ('legacy:bumn:91', 'loyal'),
    ('legacy:bumn:92', 'kompeten'),
    ('legacy:bumn:93', 'amanah'),
    ('legacy:bumn:94', 'harmonis'),
    ('legacy:bumn:95', 'harmonis'),
    ('legacy:bumn:96', 'amanah'),
    ('legacy:bumn:97', 'harmonis'),
    ('legacy:bumn:98', 'kompeten'),
    ('legacy:bumn:99', 'loyal'),
    ('legacy:bumn:100', 'kompeten')
)
update public.questions as question
set
  subcategory = assignments.subcategory,
  updated_at = now()
from assignments
where question.source_key = assignments.source_key
  and question.subcategory is distinct from assignments.subcategory;

do $$
begin
  if exists (
    select 1
    from public.questions
    where subcategory is null
      or not (
        (target = 'cpns' and category = 'twk' and subcategory in ('pancasila_dan_ideologi', 'konstitusi_dan_negara', 'sejarah_dan_kebangsaan', 'bhinneka_tunggal_ika'))
        or (target = 'cpns' and category = 'tiu' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
        or (target = 'cpns' and category = 'tkp' and subcategory in ('pelayanan_dan_integritas', 'kerja_sama_dan_komunikasi', 'adaptasi_dan_pengembangan_diri', 'pengambilan_keputusan_dan_kinerja'))
        or (target = 'bumn' and category = 'tkd' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
        or (target = 'bumn' and category = 'akhlak' and subcategory in ('amanah', 'kompeten', 'harmonis', 'loyal'))
        or (target = 'bumn' and category = 'wawasan_kebangsaan' and subcategory in ('pancasila', 'uud_1945', 'nkri', 'bhinneka_tunggal_ika'))
      )
  ) then
    raise exception 'Question taxonomy normalization left an empty or invalid path.';
  end if;
end;
$$;

alter table public.questions
  drop constraint if exists questions_taxonomy_check;

alter table public.questions
  add constraint questions_taxonomy_check check (
    subcategory is not null
    and (
      (target = 'cpns' and category = 'twk' and subcategory in ('pancasila_dan_ideologi', 'konstitusi_dan_negara', 'sejarah_dan_kebangsaan', 'bhinneka_tunggal_ika'))
      or (target = 'cpns' and category = 'tiu' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
      or (target = 'cpns' and category = 'tkp' and subcategory in ('pelayanan_dan_integritas', 'kerja_sama_dan_komunikasi', 'adaptasi_dan_pengembangan_diri', 'pengambilan_keputusan_dan_kinerja'))
      or (target = 'bumn' and category = 'tkd' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
      or (target = 'bumn' and category = 'akhlak' and subcategory in ('amanah', 'kompeten', 'harmonis', 'loyal'))
      or (target = 'bumn' and category = 'wawasan_kebangsaan' and subcategory in ('pancasila', 'uud_1945', 'nkri', 'bhinneka_tunggal_ika'))
    )
  );

commit;
