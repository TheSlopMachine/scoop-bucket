[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [switch] $Vivaldi,
    [switch] $Enforce
)

$preferencesPath = Join-Path $ProfilePath 'Default\Preferences'
if (Test-Path -LiteralPath $preferencesPath -PathType Leaf) {
    if (-not $Enforce) { return }
    $preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $preferencesPath) | Out-Null
    $preferences = @{}
}

if (-not $preferences.ContainsKey('privacy_sandbox')) { $preferences['privacy_sandbox'] = @{} }
$preferences['privacy_sandbox']['first_party_sets_enabled'] = $false
if (-not $preferences.ContainsKey('profile')) { $preferences['profile'] = @{} }
if (-not $preferences['profile'].ContainsKey('default_content_setting_values')) { $preferences['profile']['default_content_setting_values'] = @{} }
$preferences['profile']['default_content_setting_values']['notifications'] = 2
if (-not $preferences.ContainsKey('signin')) { $preferences['signin'] = @{} }
$preferences['signin']['allowed'] = $false

if ($Vivaldi) {
    if (-not $preferences.ContainsKey('vivaldi')) { $preferences['vivaldi'] = @{} }
    $preferences['vivaldi']['context_dialogs'] = @{ seen = @{ EnableCalendarContextDialog = $true; EnableMailContextDialog = $true; EnableSyncContextDialog = $true } }
    $preferences['vivaldi']['startup'] = @{ has_seen_welcome_page = $true }
    $preferences['vivaldi']['system'] = @{ show_exit_confirmation_dialog = $false }
}

$preferences | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $preferencesPath -Encoding utf8
