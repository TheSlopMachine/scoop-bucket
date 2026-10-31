[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [Parameter(Mandatory)] [string] $DefaultBookmarksPath
)

$preferencesPath = Join-Path $ProfilePath 'Default\Preferences'
$bookmarksPath = Join-Path $ProfilePath 'Default\Bookmarks'

if (-not (Test-Path -LiteralPath $preferencesPath -PathType Leaf)) {
    return
}

$preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json -AsHashtable
if (-not $preferences.ContainsKey('vivaldi')) { $preferences['vivaldi'] = @{} }
if (-not $preferences['vivaldi'].ContainsKey('startup')) { $preferences['vivaldi']['startup'] = @{} }
if (-not $preferences['vivaldi'].ContainsKey('dashboard')) { $preferences['vivaldi']['dashboard'] = @{} }
if (-not $preferences['vivaldi'].ContainsKey('system')) { $preferences['vivaldi']['system'] = @{} }
if (-not $preferences['vivaldi'].ContainsKey('bookmarks')) { $preferences['vivaldi']['bookmarks'] = @{} }

$preferences['vivaldi']['startup']['has_seen_welcome_page'] = $true
$preferences['vivaldi']['startup']['check_is_default'] = $false
$preferences['vivaldi']['dashboard']['widgets'] = @()
$preferences['vivaldi']['system']['show_exit_confirmation_dialog'] = $false

$partnerNames = @()
if (Test-Path -LiteralPath $DefaultBookmarksPath -PathType Leaf) {
    $defaultBookmarks = Get-Content -LiteralPath $DefaultBookmarksPath -Raw | ConvertFrom-Json
    function Get-VivaldiPartnerNames($node) {
        if ($null -eq $node) { return }
        if (($node.PSObject.Properties.Name -contains 'name') -and ($node.PSObject.Properties.Name -contains 'url')) {
            Write-Output ([string] $node.name)
        }
        if ($node.PSObject.Properties.Name -contains 'children') {
            foreach ($child in $node.children) { Get-VivaldiPartnerNames $child }
        }
    }
    foreach ($root in $defaultBookmarks.children) { $partnerNames += @(Get-VivaldiPartnerNames $root) }
}

$deletedPartners = @($preferences['vivaldi']['bookmarks']['deleted_partners'])
foreach ($partnerName in $partnerNames) {
    if ($deletedPartners -notcontains $partnerName) { $deletedPartners += $partnerName }
}
$preferences['vivaldi']['bookmarks']['deleted_partners'] = @($deletedPartners | Select-Object -Unique)
$preferences | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $preferencesPath -Encoding utf8

if (Test-Path -LiteralPath $bookmarksPath -PathType Leaf) {
    $bookmarks = Get-Content -LiteralPath $bookmarksPath -Raw | ConvertFrom-Json -AsHashtable
    function Remove-VivaldiPartnerNodes($node) {
        if ($null -eq $node) { return $null }
        if ($node.ContainsKey('children')) {
            $kept = @()
            foreach ($child in @($node['children'])) {
                if ($child.ContainsKey('meta_info') -and $child['meta_info'].ContainsKey('Partner')) { continue }
                $cleanChild = Remove-VivaldiPartnerNodes $child
                if ($null -ne $cleanChild) { $kept += $cleanChild }
            }
            $node['children'] = @($kept)
        }
        return $node
    }
    $cleanRoots = @{}
    foreach ($rootName in $bookmarks['roots'].Keys) {
        $cleanRoots[$rootName] = Remove-VivaldiPartnerNodes $bookmarks['roots'][$rootName]
    }
    $bookmarks['roots'] = $cleanRoots
    $bookmarks | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $bookmarksPath -Encoding utf8
}
