# Auth And Match Smoke Test

Use this after running `infra/supabase/bootstrapv2.sql` and setting backend env values.

## Environment

Both backends need:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_KEY=your_supabase_publishable_key
```

## Register

```powershell
$body = @{
  email = "player1@example.com"
  password = "secret123"
  username = "player1"
  fullName = "Player One"
  target = "cpns"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "http://localhost:3000/auth/register" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

If Supabase email confirmation is enabled, confirm the email before login.

## Login

```powershell
$body = @{
  email = "player1@example.com"
  password = "secret123"
} | ConvertTo-Json

$login = Invoke-RestMethod `
  -Uri "http://localhost:3000/auth/login" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body

$token = $login.session.access_token
```

## Fetch Profile

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:3000/profile" `
  -Method Get `
  -Headers @{ Authorization = "Bearer $token" }
```

## Play Match

Start `backend-game`, then connect two Socket.IO clients to:

```txt
http://localhost:<backend-game-port>/match
```

Use auth payload:

```json
{
  "token": "<Supabase access token>"
}
```

Both clients should:

1. receive `connection_success`
2. emit `join_queue`
3. receive `match_found`
4. receive initial `game_state_update`
5. emit `open_card`
6. emit `play_card`
7. receive `play_card_result`
8. eventually receive `match_result`

For a full player-vs-player smoke test, register and login two different users and use each user's own access token.
