select
  not exists (
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
  ) as passed,
  'Every question category matches its canonical subcategory.' as check_name;
