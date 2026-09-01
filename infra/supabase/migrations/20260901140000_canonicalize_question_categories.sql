begin;

-- One taxonomy path owns both the card face and the opened question label.
-- Subcategory is the most specific value, so it repairs legacy rows whose
-- broad category was imported incorrectly.
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

do $$
begin
  if exists (
    select 1
    from public.questions
    where target in ('cpns', 'bumn')
      and not (
        (target = 'cpns' and category = 'twk' and subcategory in ('pancasila_dan_ideologi', 'konstitusi_dan_negara', 'sejarah_dan_kebangsaan', 'bhinneka_tunggal_ika'))
        or (target = 'cpns' and category = 'tiu' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
        or (target = 'cpns' and category = 'tkp' and subcategory in ('pelayanan_dan_integritas', 'kerja_sama_dan_komunikasi', 'adaptasi_dan_pengembangan_diri', 'pengambilan_keputusan_dan_kinerja'))
        or (target = 'bumn' and category = 'wawasan_kebangsaan' and subcategory in ('pancasila', 'uud_1945', 'nkri', 'bhinneka_tunggal_ika'))
        or (target = 'bumn' and category = 'tkd' and subcategory in ('verbal', 'numerik', 'logis', 'figural'))
        or (target = 'bumn' and category = 'akhlak' and subcategory in ('amanah', 'kompeten', 'harmonis', 'loyal'))
      )
  ) then
    raise exception 'Question category canonicalization left an invalid taxonomy path.';
  end if;
end;
$$;

commit;
