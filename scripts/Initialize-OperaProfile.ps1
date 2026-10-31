[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [switch] $Gx,
    [switch] $Enforce
)

$preferencesPath = Join-Path $ProfilePath 'Default\Preferences'
if ((Test-Path -LiteralPath $preferencesPath -PathType Leaf) -and -not $Enforce) { return }
if (Test-Path -LiteralPath $preferencesPath -PathType Leaf) {
    $preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $preferencesPath) | Out-Null
    $preferences = @{}
}

if ($Gx -and -not $preferences.ContainsKey('gx')) {
    $preferences = @{
        'continue_on_mixed' = @{ enabled = $false }
        'dropdown' = @{ cities = @{ enabled = $false }; promotedSuggestions = @{ enabled = $false } }
        'gx' = @{ memory_pressure_tab_snooze = $false; play_sounds = $false }
        'personal_news' = @{ history_recommendations_enabled = $false }
        'pinboard' = @{ enabled = $false }
        'player_service' = @{ enabled = $false; id = 'home' }
        'privacy_sandbox' = @{ first_party_sets_enabled = $false }
        'profile' = @{ default_content_setting_values = @{ notifications = 2 } }
        'play_again' = @{ enabled = $false }
        'search_in_tabs' = @{ enabled = $false }
        'signin' = @{ allowed = $false }
        'speeddial' = @{ bigger_tiles = $false; tile_animation = ''; tile_show_title = $false }
        'startpage' = @{ adjust_columns = $false; show_news_container = $false }
        'sticky_site_in_sidebar' = $false
        'ui' = @{
            'accent_colored_icons' = $false
            'ai_tools' = @{ prompts = @{ highlighted_text = $false } }
            'ask_ai' = @{ button_visible = $false; enabled = $false }
            'browser' = @{ sidebar = @{ notifications_enabled = $false; visible = $true; item_prefs = @{ visibility = @{ GamingCorner = $false; Pinboards = $false; Player = $false } } } }
            'show_easy_files' = $false
            'tab_media_underline_indicator_enabled' = $false
            'toolbar' = @{ opera_account_button_visible = $false }
        }
    }
} elseif (-not $Gx -and $preferences.Count -eq 0) {
    $preferences = @{
        'continue_on_mixed' = @{ enabled = $false }
        'dropdown' = @{ cities = @{ enabled = $false }; promotedSuggestions = @{ enabled = $false } }
        'personal_news' = @{ history_recommendations_enabled = $false }
        'player_service' = @{ id = 'home'; promote_service = $false }
        'privacy_sandbox' = @{ first_party_sets_enabled = $false }
        'profile' = @{ default_content_setting_values = @{ notifications = 2 } }
        'search_in_tabs' = @{ enabled = $false }
        'signin' = @{ allowed = $false }
        'startpage' = @{ show_news_container = $false }
        'ui' = @{
            'ask_ai' = @{ enabled = $false }
            'browser' = @{ sidebar = @{ notifications_enabled = $false; visible = $false } }
            'toolbar' = @{ opera_account_button_visible = $false }
        }
    }
}

if (-not $preferences.ContainsKey('continue_on_mixed')) { $preferences['continue_on_mixed'] = @{} }
$preferences['continue_on_mixed']['enabled'] = $false
if (-not $preferences.ContainsKey('privacy_sandbox')) { $preferences['privacy_sandbox'] = @{} }
$preferences['privacy_sandbox']['first_party_sets_enabled'] = $false
if (-not $preferences.ContainsKey('profile')) { $preferences['profile'] = @{} }
if (-not $preferences['profile'].ContainsKey('default_content_setting_values')) { $preferences['profile']['default_content_setting_values'] = @{} }
$preferences['profile']['default_content_setting_values']['notifications'] = 2
if (-not $preferences.ContainsKey('signin')) { $preferences['signin'] = @{} }
$preferences['signin']['allowed'] = $false
if ($Gx) {
    if (-not $preferences.ContainsKey('gx')) { $preferences['gx'] = @{} }
    $preferences['gx']['memory_pressure_tab_snooze'] = $false
    if (-not $preferences.ContainsKey('startpage')) { $preferences['startpage'] = @{} }
    $preferences['startpage']['show_news_container'] = $false
}

$preferences | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $preferencesPath -Encoding utf8
