# Application configuration

## Administrator login

Administrator credentials are not stored in the source code or QML bundle.
Configure them in the environment before starting the application:

- `SMART_PARKING_ADMIN_USERNAME`: administrator username; defaults to `admin`.
- `SMART_PARKING_ADMIN_PASSWORD_SHA256`: lowercase SHA-256 hash of the password.

PowerShell example:

```powershell
$password = Read-Host "Admin password" -AsSecureString
$credential = [pscredential]::new("admin", $password)
$plainText = $credential.GetNetworkCredential().Password
$bytes = [Text.Encoding]::UTF8.GetBytes($plainText)
$env:SMART_PARKING_ADMIN_USERNAME = "admin"
$env:SMART_PARKING_ADMIN_PASSWORD_SHA256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bytes)
).ToLowerInvariant()
Remove-Variable plainText, bytes
```

If the password hash is missing or malformed, administrator login remains disabled.

## Demo data

The application does not insert demo records during a normal startup. To populate the empty database with sample records, start it once with:

```text
appsmart_parking_system.exe --seed-demo-data
```
