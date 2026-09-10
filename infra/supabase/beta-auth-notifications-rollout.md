# Beta welcome, password recovery, and notifications

Apply the complete `migrations/20260910120000_beta_welcome_rewards.sql` transaction in the linked **Supabase Cloud SQL Editor** before deploying the backend, then release the Flutter app. Run `postchecks/20260910120000_beta_welcome_rewards.sql` and confirm every check passes. The migration activates the campaign at its installation time; only auth accounts created at or after that timestamp qualify. There is no existing-account backfill. The profile-insert trigger credits both currencies in the account provisioning transaction, including when email confirmation is pending. No local Supabase installation is required.

Disable future grants using a trusted database/admin connection:

```sql
update public.beta_welcome_campaigns set enabled = false where id = 'beta-welcome-v1';
```

Do not reset `starts_at`, delete grant records, or reuse the campaign ID for a new campaign. Disabling leaves balances and outstanding popup acknowledgments intact. Grant records survive profile/data resets and are removed only when the auth account is deleted. The legacy 100-coin `grant_beta_credit` function is not used by this campaign.

The linked project's migration history may not record changes applied manually in SQL Editor. Inspect the actual cloud schema before deployment; do not use a blanket `db push` to replay the older migrations. Apply only this new migration after verifying its prerequisites (`profiles`, `energy_transactions`, `coin_transactions`).

`tests/beta_welcome_rewards_test.sql` is a rollback-only pgTAP test transaction using disposable test account IDs. It checks eligibility, ledger entries, repeated calls, acknowledgment, data reset, refill, disabled campaigns, rollback, and RPC permissions. Run the entire file in a disposable cloud test branch with pgTAP available; never execute only a fragment without its final rollback. For the live project, use the read-only postcheck and a designated beta test account. Also exercise simultaneous `grant_beta_welcome_reward` calls for a disposable test account from two database sessions; verify one grant and one entry per ledger.

## Password recovery configuration

In the hosted Supabase project, add the exact redirect URL `com.yudha.app://reset-callback/` under Authentication > URL Configuration. Also add the deployed Flutter web origin followed by `/reset-password` (and the actual localhost port used for web development). Local `config.toml` does not change hosted project settings. Configure the web host to serve the Flutter app on `/reset-password`. Use the Supabase recovery email template with its confirmation URL and verify email delivery/SMTP in the target project.

On Android, request a link, close the app, open the email on the same phone, and set a new password. Repeat while the app is running. Verify the success message at sign-in, rejection of the old password, and acceptance of the new one. Repeat in Flutter web; test expired links and repeated email requests. Supabase manages PKCE and callback validation; a callback URL alone does not authorize a password update.

## Physical Android FCM validation

Connect the affected phone with USB debugging enabled. `adb devices` must list an authorized device. Record Android version and Google Play services status, then reproduce enabling **Notifikasi Harian**. The new native check identifies unavailable/outdated Google Play services. Registration retries transient failures up to three times, and no token or exception payload is printed by the app's diagnostic logger.

If registration still fails, capture a narrowly filtered `adb logcat` for FirebaseMessaging/FirebaseInstallations during reproduction. Review logs locally and redact account identifiers and registration tokens before sharing. Check the installed package/project/app IDs against Firebase Console and check API-key restrictions for Firebase Installations/FCM Registration. Do not rotate keys or change the Firebase project based only on an `unknown` error.

Test with working Google Play services over Wi-Fi and mobile data, offline then retry, denied notification permission, app restart, token refresh, and account switching. Confirm installation registration succeeds on the backend and send a test message to the connected installation. Verify foreground refresh, background notification display, and navigation when tapped. A successful APK build or mocked registration test is not proof of real-device delivery.
