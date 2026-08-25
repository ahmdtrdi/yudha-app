begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(7);

select has_table('public', 'notification_preferences', 'notification preferences table exists');
select has_table('public', 'push_installations', 'push installations table exists');
select has_table('public', 'notification_deliveries', 'notification deliveries table exists');
select has_function(
  'public',
  'claim_due_notification_deliveries',
  array['timestamp with time zone', 'integer'],
  'atomic reminder claim function exists'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_due_notification_deliveries(timestamp with time zone,integer)',
    'EXECUTE'
  ),
  'backend role can claim due reminders'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_due_notification_deliveries(timestamp with time zone,integer)',
    'EXECUTE'
  ),
  'authenticated users cannot claim reminders'
);
select col_is_pk(
  'public',
  'notification_preferences',
  'user_id',
  'notification preferences are account-owned'
);

select * from finish();
rollback;
