[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [switch] $Vivaldi
)

$preferencesPath = Join-Path $ProfilePath 'Default\Preferences'
if (Test-Path -LiteralPath $preferencesPath -PathType Leaf) {
    return
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $preferencesPath) | Out-Null
$preferences = @{
    'privacy_sandbox' = @{ first_party_sets_enabled = $false }
    'profile' = @{ default_content_setting_values = @{ notifications = 2 } }
    'signin' = @{ allowed = $false }
}

if ($Vivaldi) {
    $preferences['vivaldi'] = @{
        'context_dialogs' = @{ seen = @{ EnableCalendarContextDialog = $true; EnableMailContextDialog = $true; EnableSyncContextDialog = $true } }
        'startup' = @{ has_seen_welcome_page = $true }
        'system' = @{ show_exit_confirmation_dialog = $false }
    }
}

$preferences | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $preferencesPath -Encoding utf8
