## 1. Common (addons/gas_sdk/GAS/Common/)

- [x] 1.1 Create `GASError.gd` — error class extending RefCounted: code (-500 default), message, raw_text; also GASNetworkException (with raw_text) and GASParseException (code=-1)
- [x] 1.2 Create `GASResponseChecker.gd` — static ensure_success(resp): returns GASError if code!=200, null if ok
- [x] 1.3 Create `GASResponseLogger.gd` — static log_request(method, url, body), log_response(method, url, status, response, ms), log_error(method, url, status, response, error, ms) using print/push_warning/push_error

## 2. Config (addons/gas_sdk/GAS/Config/)

- [x] 2.1 Create `GASConfig.gd` — Resource subclass with @export app_id: int = 0, @export app_token: String = ""
- [x] 2.2 Create `GASConfigManager.gd` — static class: lazy-loads GASConfig from res://addons/gas_sdk/Resources/GASConfig.tres; static app_id, app_token, lang (GASLang), lang_string properties
- [x] 2.3 Create `Resources/GASConfig.tres` — template config resource with app_id=0, app_token=""

## 3. Enum (addons/gas_sdk/GAS/Enum/)

- [x] 3.1 Create `GASLang.gd` — enum GASLang { ZH, EN }

## 4. Network (addons/gas_sdk/GAS/Network/)

- [x] 4.1 Create `GASApiRoute.gd` — static endpoint URLs: OAUTH, AUTO_LOGIN, PROFILE, ARCHIVE, VERSION, REDEEM, CONFIG (matching GASNetwork's GASApiRoute.cs exactly)
- [x] 4.2 Create `GASEncryption.gd` — static encrypt(plain_text, raw_key), decrypt(cipher_text, raw_key), derive_key_bytes(raw_key); AES-256-CBC, SHA-256 key, zero IV, base64 output (matching GASNetwork's GASEncryption.cs exactly)
- [x] 4.3 Create `GASHttpClient.gd` — post(url, body, type, resp_class) and get(url, resp_class); create temporary HTTPRequest node per request, await request_completed, parse JSON, queue_free node; include ?type=X&lang=XX query params

## 5. Handler (addons/gas_sdk/GAS/Handler/)

- [x] 5.1 Create `GASBrowserHandler.gd` — static open_auth_browser(app_id, auth_token), to_register(), to_acc_rules() (matching GASNetwork's GASBrowserHandler.cs)

## 6. Models (addons/gas_sdk/GAS/Models/)

- [x] 6.1 Create `OAuth/` — OAuthAuthTokenReq, OAuthExchangeReq, OAuthLogoutReq, OAuthAuthTokenResp (data: auth_token, expire), OAuthAccessResp (data: access_token, email, uid, user_group), OAuthLogoutResp
- [x] 6.2 Create `AutoLogin/` — AutoLoginReq (appid, email, access_token), AutoLoginResp
- [x] 6.3 Create `Profile/` — ProfileReq (appid, email, access_token), ProfileResp (data: uid, nickname, avatar, location, user_group)
- [x] 6.4 Create `Archive/` — ArchiveReadReq, ArchiveSaveReq (appid, email, access_token, app_version_encrypted, content_encrypted), ArchiveDeleteReq, ArchiveReadResp (data: content_encrypted, app_version, update_time), ArchiveSaveResp, ArchiveDeleteResp
- [x] 6.5 Create `Version/` — VersionReq (appid, sequence_encrypted), VersionResp (data: versions)
- [x] 6.6 Create `Redeem/` — RedeemAnonymousReq (appid, redeem_code), RedeemWithAccountReq (appid, email, access_token, redeem_code), RedeemResp (data: content_encrypted)
- [x] 6.7 Create `Config/` — ConfigReq (appid), ConfigResp (data: config)

## 7. Services (addons/gas_sdk/GAS/Service/)

- [x] 7.1 Create `OAuthService.gd` — RefCounted; get_auth_token() (encrypt appToken with itself, POST ?type=1), exchange_auth_token(auth_token) (POST ?type=4), logout(email, access_token) (POST ?type=5); all read app_id/app_token from GASConfigManager
- [x] 7.2 Create `AutoLoginService.gd` — RefCounted; auto_login(email, access_token) (POST to auto-login.php)
- [x] 7.3 Create `ProfileService.gd` — RefCounted; get_profile(email, access_token) (POST to profile.php)
- [x] 7.4 Create `ArchiveService.gd` — RefCounted; read(email, access_token) (type=1), save(email, access_token, version, plain_content) (encrypt content+version with appToken, type=2), delete(email, access_token) (type=3), decrypt_archive_content(encrypted_content) (decrypt with appToken)
- [x] 7.5 Create `VersionService.gd` — RefCounted; get_version(sequence) (encrypt sequence with appToken, POST to version.php), decrypt_version(encrypted_content) (decrypt with appToken, split by comma)
- [x] 7.6 Create `RedeemService.gd` — RefCounted; redeem_anonymous(redeem_code), redeem_with_account(email, access_token, redeem_code), decrypt_redeem_content(encrypted_content)
- [x] 7.7 Create `ConfigService.gd` — RefCounted; get_config() (POST to config.php with appId), decrypt_config(encrypted_config)

## 8. Demo (addons/gas_sdk/Demo/)

- [x] 8.1 Create `Demo/Scripts/GASDemo.gd` — demo controller mirroring GASNetwork's GASDemo.cs: instantiate all services, OAuth flow with polling, profile, save/read archive, version, redeem, logout, language switch, log panel
- [x] 8.2 Create `Demo/Scenes/GASDemo.tscn` — demo UI scene with buttons for each service, log text area, input fields for version sequence and redeem code

## 9. Game Integration — Login

- [x] 9.1 Create `Scripts/gas/gas_login_config.gd` — ConfigFile persistence for email/access_token at user://gas_config.cfg; save(), load(), clear() methods
- [x] 9.2 Create `Scripts/gas/gas_login.gd` — login controller using SDK services (OAuthService, AutoLoginService, ProfileService, GASBrowserHandler); auto-login → OAuth flow → profile fetch → emit login_finish; save tokens via gas_login_config
- [x] 9.3 Create `Scenes/gas_login.tscn` — login UI: login button, status label, user info display

## 10. Game Integration — Cloud Archive

- [x] 10.1 Create `Scripts/gas/gas_archive_adapter.gd` — GASArchiveAdapter: to_cloud_json() serializes game state, apply_cloud_json(json) deserializes cloud data to local state
- [x] 10.2 Create `Scripts/gas/cloud_archive_service.gd` — CloudArchiveService autoload: set_credentials(), sync_on_login() with conflict resolution, queue_save() with 2s debounce Timer, has_credentials(); uses SDK ArchiveService
- [x] 10.3 Register CloudArchiveService as autoload in project.godot → res://Scripts/gas/cloud_archive_service.gd

## 11. Game Integration — LevelManager

- [x] 11.1 Add login button to Scenes/LevelManager.tscn that opens gas_login.tscn
- [x] 11.2 Add CloudArchiveService.queue_save("runtime") call in game save flow

## 12. Verification

- [ ] 12.1 Test GASEncryption: encrypt/decrypt round-trip matches GASNetwork C# output for same input
- [ ] 12.2 Test GASHttpClient: successful POST/GET, network error handling, JSON parsing
- [ ] 12.3 Test OAuthService: get_auth_token → exchange_auth_token flow
- [ ] 12.4 Test ArchiveService: read, save (with encryption), delete, decrypt_archive_content
- [ ] 12.5 Test GASConfig: resource editing, GASConfigManager lazy-load
- [ ] 12.6 Test game login: auto-login → OAuth → profile → token persistence
- [ ] 12.7 Test cloud archive: sync_on_login, debounced save, conflict resolution
- [ ] 12.8 Run GASDemo scene and verify all service buttons work