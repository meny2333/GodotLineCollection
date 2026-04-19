## ADDED Requirements

### Requirement: GASConfig Resource with app credentials
The SDK SHALL provide a `GASConfig` class extending `Resource` with `@export var app_id: int = 0` and `@export var app_token: String = ""`. A template `GASConfig.tres` SHALL exist at `res://addons/gas_sdk/Resources/GASConfig.tres`.

#### Scenario: Edit config in Inspector
- **WHEN** a developer opens `GASConfig.tres` in the Godot Editor Inspector
- **THEN** editable `app_id` and `app_token` fields SHALL be displayed

#### Scenario: Default template config
- **WHEN** the SDK is first installed
- **THEN** `GASConfig.tres` SHALL exist with `app_id=0` and `app_token=""`

### Requirement: GASConfigManager static accessor
`GASConfigManager` SHALL provide static properties `app_id`, `app_token`, `lang` (GASLang enum, default zh), and `lang_string` that lazy-load from `GASConfig.tres`.

#### Scenario: Lazy-load config
- **WHEN** `GASConfigManager.app_id` or `GASConfigManager.app_token` is first accessed
- **THEN** the system SHALL load `GASConfig.tres` via `ResourceLoader.load()` and return configured values

#### Scenario: Config not found
- **WHEN** `GASConfigManager` is accessed and `GASConfig.tres` does not exist
- **THEN** an error SHALL be logged and default values (app_id=0, app_token="") SHALL be returned

### Requirement: GASLang enum
The SDK SHALL provide a `GASLang` enum with values `ZH = 0` and `EN = 1`. `GASConfigManager.lang_string` SHALL return "zh" or "en".

### Requirement: GASError error class
The SDK SHALL provide a `GASError` class extending `RefCounted` with `code: int` (default -500), `message: String`, and `raw_text: String`. Services SHALL return `GASError` on failure.

#### Scenario: Check for error
- **WHEN** a service call fails (network error, non-200 response, JSON parse error)
- **THEN** a `GASError` instance SHALL be returned with appropriate code and message

### Requirement: GASResponse base and typed response classes
Each response class SHALL contain `code: int`, `msg: String`, and a typed `data` field (or Dictionary). `is_success()` SHALL return true when `code == 200`.

#### Scenario: Successful response check
- **WHEN** `is_success()` is called on a response with code 200
- **THEN** it SHALL return true

### Requirement: GASResponseChecker
`GASResponseChecker` SHALL provide a static `ensure_success(resp)` method that returns `GASError` if `resp.code != 200`, otherwise returns `null`.

### Requirement: GASResponseLogger
`GASResponseLogger` SHALL log all requests (method, URL, body) and responses (method, URL, status, response, time) to Godot console.

### Requirement: GASEncryption — AES-256-CBC with SHA-256 key
The SDK SHALL provide static `encrypt(plain_text, raw_key)` and `decrypt(cipher_text, raw_key)` using AES-256-CBC with SHA-256(raw_key) as the key and a zero 16-byte IV, outputting base64 ciphertext. This SHALL match GASNetwork's `GASEncryption` exactly.

#### Scenario: Encrypt then decrypt round-trip
- **WHEN** text is encrypted with `GASEncryption.encrypt(text, key)` then decrypted with `GASEncryption.decrypt(cipher, key)` using the same key
- **THEN** the decrypted result SHALL equal the original text

#### Scenario: Compatibility with GASNetwork
- **WHEN** the same plaintext and key are used in both GASEncryption (GDScript) and GASNetwork (C#)
- **THEN** the base64 output SHALL be identical

### Requirement: GASApiRoute endpoint constants
`GASApiRoute` SHALL provide static endpoint URLs: `OAUTH`, `AUTO_LOGIN`, `PROFILE`, `ARCHIVE`, `VERSION`, `REDEEM`, `CONFIG` — matching GASNetwork exactly.

### Requirement: GASHttpClient — await-based POST/GET
`GASHttpClient` SHALL provide `post(url, body, type, resp_class)` and `get(url, resp_class)` methods that return parsed response objects via `await`. Internally create a temporary `HTTPRequest` node, send the request, await completion, parse JSON, and free the node. URLs SHALL include `?type=X&lang=XX` or `?lang=XX` query params per GASNetwork.

#### Scenario: Successful POST request
- **WHEN** `await http_client.post(url, body, 1, OAuthAuthTokenResp)` is called
- **THEN** a typed response object SHALL be returned with parsed data

#### Scenario: Network error
- **WHEN** a request fails due to network issues
- **THEN** a `GASError` with `code` and `message` SHALL be returned

#### Scenario: Non-200 response
- **WHEN** the server returns a response with code != 200
- **THEN** `GASResponseChecker.ensure_success()` SHALL return a `GASError`

### Requirement: GASBrowserHandler
`GASBrowserHandler` SHALL provide static methods: `open_auth_browser(app_id, auth_token)` opening `https://gas.chinadlrs.com/oauth?appid={app_id}&token={auth_token}`, `to_register()` opening `https://chinadlrs.com/register/`, and `to_acc_rules()` opening `https://chinadlrs.com/policy/?page=account`.

#### Scenario: Open auth browser
- **WHEN** `GASBrowserHandler.open_auth_browser(67, "token123")` is called
- **THEN** `OS.shell_open("https://gas.chinadlrs.com/oauth?appid=67&token=token123")` SHALL be called

### Requirement: OAuthService — get_auth_token, exchange_auth_token, logout
`OAuthService` SHALL be a `RefCounted` class with:
- `get_auth_token()` → encrypts appToken with itself, POSTs to oauth?type=1, returns `OAuthAuthTokenResp`
- `exchange_auth_token(auth_token)` → POSTs to oauth?type=4, returns `OAuthAccessResp`
- `logout(email, access_token)` → POSTs to oauth?type=5, returns `OAuthLogoutResp`

All methods SHALL read `app_id` and `app_token` from `GASConfigManager`.

#### Scenario: Get auth_token
- **WHEN** `await oauth_service.get_auth_token()` is called
- **THEN** appToken SHALL be encrypted with itself, POSTed with appId to oauth?type=1, and an `OAuthAuthTokenResp` with `data.auth_token` SHALL be returned

#### Scenario: Exchange auth_token for access_token
- **WHEN** `await oauth_service.exchange_auth_token(auth_token)` is called
- **THEN** an `OAuthAccessResp` with `data.access_token`, `data.email`, `data.user_group` SHALL be returned

### Requirement: AutoLoginService
`AutoLoginService` SHALL provide `auto_login(email, access_token)` → POSTs to auto-login.php, returns `AutoLoginResp`.

### Requirement: ProfileService
`ProfileService` SHALL provide `get_profile(email, access_token)` → POSTs to profile.php, returns `ProfileResp` with `data.uid`, `data.nickname`, `data.avatar`, `data.location`, `data.user_group`.

### Requirement: ArchiveService — read, save, delete, decrypt
`ArchiveService` SHALL provide:
- `read(email, access_token)` → POSTs to archive?type=1, returns `ArchiveReadResp` with `data.content_encrypted`, `data.app_version`, `data.update_time`
- `save(email, access_token, version, plain_content)` → encrypts content+version with appToken, POSTs to archive?type=2, returns `ArchiveSaveResp`
- `delete(email, access_token)` → POSTs to archive?type=3, returns `ArchiveDeleteResp`
- `decrypt_archive_content(encrypted_content)` → decrypts with appToken, returns plain string

#### Scenario: Save encrypts content and version
- **WHEN** `await archive_service.save(email, token, "1.0", '{"level":1}')` is called
- **THEN** both content and version SHALL be encrypted with `GASEncryption.encrypt(text, GASConfigManager.app_token)` before sending

### Requirement: VersionService
`VersionService` SHALL provide:
- `get_version(sequence)` → encrypts sequence with appToken, POSTs to version.php, returns `VersionResp`
- `decrypt_version(encrypted_content)` → decrypts with appToken, splits by comma, returns `PackedStringArray`

### Requirement: RedeemService
`RedeemService` SHALL provide:
- `redeem_anonymous(redeem_code)` → POSTs to redeem.php without auth, returns `RedeemResp`
- `redeem_with_account(email, access_token, redeem_code)` → POSTs to redeem.php with auth, returns `RedeemResp`
- `decrypt_redeem_content(encrypted_content)` → decrypts with appToken

### Requirement: ConfigService
`ConfigService` SHALL provide:
- `get_config()` → POSTs to config.php with appId, returns `ConfigResp`
- `decrypt_config(encrypted_config)` → decrypts with appToken

### Requirement: Typed request/response model classes
The SDK SHALL provide request and response model classes matching GASNetwork's Models layer:
- OAuth: `OAuthAuthTokenReq`, `OAuthExchangeReq`, `OAuthLogoutReq`, `OAuthAuthTokenResp`, `OAuthAccessResp`, `OAuthLogoutResp`
- AutoLogin: `AutoLoginReq`, `AutoLoginResp`
- Profile: `ProfileReq`, `ProfileResp`
- Archive: `ArchiveReadReq`, `ArchiveSaveReq`, `ArchiveDeleteReq`, `ArchiveReadResp`, `ArchiveSaveResp`, `ArchiveDeleteResp`
- Version: `VersionReq`, `VersionResp`
- Redeem: `RedeemAnonymousReq`, `RedeemWithAccountReq`, `RedeemResp`
- Config: `ConfigReq`, `ConfigResp`

Each request class SHALL serialize to JSON-compatible Dictionary. Each response class SHALL parse from JSON Dictionary and contain `code`, `msg`, and typed `data` fields.

### Requirement: Demo scene
The SDK SHALL include a demo scene at `addons/gas_sdk/Demo/` with buttons for each service and a log panel, mirroring GASNetwork's `GASDemo.cs`.

#### Scenario: Run demo
- **WHEN** the demo scene is run in the Godot Editor
- **THEN** buttons for OAuth, Profile, Save Archive, Read Archive, Version, Redeem, Logout SHALL be visible and functional

#### Scenario: Unconfigured demo
- **WHEN** the demo runs with default `app_id=0`
- **THEN** a message SHALL instruct the developer to set `app_id` and `app_token` in `GASConfig.tres`