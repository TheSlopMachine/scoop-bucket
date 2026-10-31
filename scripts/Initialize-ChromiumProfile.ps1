[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [switch] $Vivaldi,
    [switch] $Brave,
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
if (-not $preferences.ContainsKey('omnibox_everywhere')) { $preferences['omnibox_everywhere'] = @{} }
$preferences['omnibox_everywhere']['show_ai_mode'] = $false
$preferences['omnibox_everywhere']['fre_dismissed'] = $true
$preferences['omnibox_everywhere']['fre_intro_dismissed'] = $true
$preferences['omnibox_everywhere']['fre_shortcut_setup_dismissed'] = $true
$preferences['omnibox_everywhere']['fre_shortcut_reminder_dismissed'] = $true
$preferences['omnibox_everywhere']['screenshot_disclosure_accepted'] = $true
foreach ($key in 'omnibox_everywhere.show_ai_mode','omnibox_everywhere.fre_dismissed','omnibox_everywhere.fre_intro_dismissed','omnibox_everywhere.fre_shortcut_setup_dismissed','omnibox_everywhere.fre_shortcut_reminder_dismissed','omnibox_everywhere.screenshot_disclosure_accepted') { $preferences.Remove($key) }

if ($Vivaldi) {
    if (-not $preferences.ContainsKey('vivaldi')) { $preferences['vivaldi'] = @{} }
    $preferences['vivaldi']['context_dialogs'] = @{ seen = @{ EnableCalendarContextDialog = $true; EnableMailContextDialog = $true; EnableSyncContextDialog = $true } }
    if (-not $preferences['vivaldi'].ContainsKey('startup')) { $preferences['vivaldi']['startup'] = @{} }
    $preferences['vivaldi']['startup']['has_seen_welcome_page'] = $true
    $preferences['vivaldi']['startup']['check_is_default'] = $false
    if (-not $preferences['vivaldi'].ContainsKey('dashboard')) { $preferences['vivaldi']['dashboard'] = @{} }
    $preferences['vivaldi']['dashboard']['widgets'] = @()
    if (-not $preferences['vivaldi'].ContainsKey('system')) { $preferences['vivaldi']['system'] = @{} }
    $preferences['vivaldi']['system']['show_exit_confirmation_dialog'] = $false

    $bookmarksPath = Join-Path $ProfilePath 'Default\Bookmarks'
    if (-not (Test-Path -LiteralPath $bookmarksPath -PathType Leaf)) {
        $bookmarkFolder = { param($id, $name) @{ children = @(); date_added = '0'; date_modified = '0'; guid = $id; id = $id; name = $name; type = 'folder' } }
        $bookmarks = @{ checksum = ''; roots = @{ bookmark_bar = & $bookmarkFolder 'bookmark_bar' 'Bookmarks bar'; other = & $bookmarkFolder 'other' 'Other bookmarks'; synced = & $bookmarkFolder 'synced' 'Mobile bookmarks'; trash = & $bookmarkFolder 'trash' 'Trash' }; version = 1 }
        $bookmarks | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $bookmarksPath -Encoding utf8
    }
}

if ($Brave) {
    if (-not $preferences.ContainsKey('brave')) { $preferences['brave'] = @{} }
    if (-not $preferences['brave'].ContainsKey('ai_chat')) { $preferences['brave']['ai_chat'] = @{} }
    $preferences['brave']['ai_chat']['autocomplete_provider_enabled'] = $false
    $preferences['brave']['ai_chat']['context_menu_enabled'] = $false
    $preferences['brave']['ai_chat']['storage_enabled'] = $false
    $preferences['brave']['ai_chat']['tab_organization_enabled'] = $false
    if (-not $preferences['brave'].ContainsKey('brave_ads')) { $preferences['brave']['brave_ads'] = @{} }
    if (-not $preferences['brave']['brave_ads'].ContainsKey('sponsored')) { $preferences['brave']['brave_ads']['sponsored'] = @{} }
    $preferences['brave']['brave_ads']['sponsored']['enabled'] = $false
    if (-not $preferences['brave'].ContainsKey('new_tab_page')) { $preferences['brave']['new_tab_page'] = @{} }
    $preferences['brave']['new_tab_page']['show_brave_vpn'] = $false
    $preferences['brave']['new_tab_page']['show_stats'] = $false
    $preferences['brave']['new_tab_page']['show_together'] = $false
    if (-not $preferences['brave'].ContainsKey('sidebar')) { $preferences['brave']['sidebar'] = @{} }
    $hiddenSidebarItems = @($preferences['brave']['sidebar']['hidden_built_in_items'])
    if ($hiddenSidebarItems -notcontains 7) { $hiddenSidebarItems += 7 }
    $preferences['brave']['sidebar']['hidden_built_in_items'] = @($hiddenSidebarItems | Select-Object -Unique)
}

$preferences | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $preferencesPath -Encoding utf8

$localStatePath = Join-Path $ProfilePath 'Local State'
if (Test-Path -LiteralPath $localStatePath -PathType Leaf) {
    $localState = Get-Content -LiteralPath $localStatePath -Raw | ConvertFrom-Json -AsHashtable
} else {
    $localState = @{}
}
if (-not $localState.ContainsKey('omnibox_everywhere')) { $localState['omnibox_everywhere'] = @{} }
$localState['omnibox_everywhere']['enabled'] = $false
$localState['omnibox_everywhere']['hotkey_enabled'] = $false
$localState['omnibox_everywhere']['hotkey'] = ''
$localState['omnibox_everywhere']['background_mode'] = $false
$localState['omnibox_everywhere']['launch_on_startup'] = $false
foreach ($key in 'omnibox_everywhere.enabled','omnibox_everywhere.hotkey_enabled','omnibox_everywhere.hotkey','omnibox_everywhere.background_mode','omnibox_everywhere.launch_on_startup') { $localState.Remove($key) }

if ($Brave) {
    if (-not $localState.ContainsKey('brave')) { $localState['brave'] = @{} }
    if (-not $localState['brave'].ContainsKey('p3a')) { $localState['brave']['p3a'] = @{} }
    $localState['brave']['p3a']['enabled'] = $false
    if (-not $localState['brave'].ContainsKey('stats')) { $localState['brave']['stats'] = @{} }
    $localState['brave']['stats']['reporting_enabled'] = $false
}
$localState | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $localStatePath -Encoding utf8
