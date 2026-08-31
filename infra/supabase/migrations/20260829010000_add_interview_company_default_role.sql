alter table public.interview_company_profiles
  add column if not exists default_role text;

update public.interview_company_profiles
set default_role = case id
  when 'adhi-karya' then 'Management Trainee'
  when 'bank-indonesia' then 'Asisten Manajer'
  when 'bank-mandiri' then 'Officer Development Program'
  when 'garuda-indonesia' then 'Management Trainee'
  when 'kementerian-keuangan' then 'Staf Pengelola Keuangan Negara'
  when 'pertamina' then 'Bimbingan Profesi Sarjana'
end
where default_role is null
  and id in (
    'adhi-karya',
    'bank-indonesia',
    'bank-mandiri',
    'garuda-indonesia',
    'kementerian-keuangan',
    'pertamina'
  );
