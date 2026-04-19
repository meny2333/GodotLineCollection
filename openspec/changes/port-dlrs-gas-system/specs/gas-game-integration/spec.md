## ADDED Requirements

### Requirement: Login scene with OAuth flow
The system SHALL provide a `gas_login.tscn` scene with `gas_login.gd` controller that uses SDK services (OAuthService, AutoLoginService, ProfileService) to implement the full OAuth flow, mirroring GASDemo's pattern.

#### Scenario: Auto-login on scene ready
- **WHEN** the login scene loads and finds stored email/access_token in the config file
- **THEN** it SHALL call `AutoLoginService.auto_login()` and proceed if valid

#### Scenario: Full OAuth flow
- **WHEN** auto-login fails or no stored tokens exist
- **THEN** the scene SHALL call `OAuthService.get_auth_token()`, open browser via `GASBrowserHandler.open_auth_browser()`, poll for access_token via `OAuthService.exchange_auth_token()`, and fetch profile via `ProfileService.get_profile()`

#### Scenario: Persist tokens after login
- **WHEN** OAuth flow completes successfully
- **THEN** email and access_token SHALL be saved to `user://gas_config.cfg` for future auto-login

#### Scenario: Emit login_finish signal
- **WHEN** login completes
- **THEN** the scene SHALL emit `login_finish(email, access_token)` and free itself

### Requirement: CloudArchiveService autoload
`CloudArchiveService` SHALL be registered as an autoload at `/root/CloudArchiveService`, managing cloud archive sync using SDK's `ArchiveService`.

#### Scenario: Sync on login — no cloud archive
- **WHEN** `sync_on_login()` is called and no cloud archive exists
- **THEN** the local state SHALL be uploaded to the cloud

#### Scenario: Sync on login — local newer
- **WHEN** `sync_on_login()` finds local save timestamp is newer than cloud
- **THEN** the local data SHALL be uploaded to the cloud

#### Scenario: Sync on login — cloud newer
- **WHEN** `sync_on_login()` finds cloud save timestamp is newer than local
- **THEN** the cloud data SHALL be applied to local state via `GASArchiveAdapter`

### Requirement: Debounced auto-save
`CloudArchiveService` SHALL debounce `queue_save()` calls with a 2-second Timer. Multiple calls within 2 seconds SHALL result in one cloud save.

#### Scenario: Rapid save requests
- **WHEN** `queue_save(reason)` is called multiple times within 2 seconds
- **THEN** only one `ArchiveService.save()` SHALL execute after the debounce period

### Requirement: GASArchiveAdapter
`GASArchiveAdapter` SHALL serialize game state to JSON for cloud upload and deserialize cloud JSON back to local state.

#### Scenario: Serialize to cloud JSON
- **WHEN** `GASArchiveAdapter.to_cloud_json()` is called
- **THEN** a JSON string of current game save data SHALL be returned

#### Scenario: Deserialize from cloud JSON
- **WHEN** `GASArchiveAdapter.apply_cloud_json(json)` is called
- **THEN** the local game state SHALL be updated from the cloud data

### Requirement: LevelManager login button
The LevelManager scene SHALL include a login button that opens `gas_login.tscn`.

#### Scenario: Open login from LevelManager
- **WHEN** the user clicks the login button
- **THEN** the `gas_login.tscn` scene SHALL be displayed

### Requirement: Save hook to CloudArchiveService
When the game saves data, `CloudArchiveService.queue_save("runtime")` SHALL be called.

#### Scenario: Game save triggers cloud save
- **WHEN** the game saves local data
- **THEN** a debounced cloud save SHALL be triggered