[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProfilePath,
    [Alias('InstallPath')] [string] $AppDir,
    [switch] $Waterfox,
    [switch] $CleanShortcuts,
    [switch] $Enforce
)

if (-not $Waterfox -and (($AppDir -and $AppDir -match 'waterfox') -or $ProfilePath -match 'waterfox')) {
    $Waterfox = $true
}

# 1. Initialize or update policies.json if $AppDir is provided
if ($AppDir) {
    $targetDir = if (Test-Path -LiteralPath $AppDir -PathType Leaf) {
        Split-Path -Parent $AppDir
    } else {
        $AppDir
    }

    $distDir = Join-Path $targetDir 'distribution'
    if (-not (Test-Path -LiteralPath $distDir -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $distDir | Out-Null
    }

    $policiesFile = Join-Path $distDir 'policies.json'
    $policy = @{
        policies = @{
            DisableAppUpdate = $true
            BackgroundAppUpdate = $false
            DisableDefaultBrowserAgent = $true
            DisableLaunchOnLogin = $true
            DisableTelemetry = $true
            DisableFirefoxStudies = $true
            DisablePocket = $true
            DisableFirefoxScreenshots = $true
            DisableFeedbackCommands = $true
            DisableAccounts = $true
            DontCheckDefaultBrowser = $true
            OverrideFirstRunPage = ''
            OverridePostUpdatePage = ''
            FirefoxHome = @{
                Search = $true
                TopSites = $true
                SponsoredTopSites = $false
                Highlights = $false
                Pocket = $false
                Stories = $false
                SponsoredPocket = $false
                SponsoredStories = $false
                Snippets = $false
                Locked = $true
            }
            UserMessaging = @{
                ExtensionRecommendations = $false
                FeatureRecommendations = $false
                UrlbarInterventions = $false
                SkipOnboarding = $true
                Locked = $true
            }
            Preferences = @{
                'browser.shell.checkDefaultBrowser' = @{ Value = $false; Status = 'locked' }
                'browser.aboutwelcome.enabled' = @{ Value = $false; Status = 'locked' }
                'browser.newtabpage.activity-stream.widgets.weather.enabled' = @{ Value = $false; Status = 'locked' }
                'browser.newtabpage.activity-stream.showSponsoredTopSites' = @{ Value = $false; Status = 'locked' }
                'browser.newtabpage.activity-stream.showSponsored' = @{ Value = $false; Status = 'locked' }
                'browser.privateWindowSeparation.enabled' = @{ Value = $false; Status = 'locked' }
                'browser.privacySegmentation.createdShortcut' = @{ Value = $true; Status = 'locked' }
                'browser.shell.customIcon.enabled' = @{ Value = $false; Status = 'locked' }
                'browser.shell.customIcon.perUserStartMenuShortcutCreated' = @{ Value = $true; Status = 'locked' }
            }
        }
    }
    $policy | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $policiesFile -Encoding utf8
}

# 2. Initialize or update user.js in profile directory
if (-not (Test-Path -LiteralPath $ProfilePath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $ProfilePath | Out-Null
}

$userJsPath = Join-Path $ProfilePath 'user.js'
$userPrefs = [ordered]@{
    'browser.privateWindowSeparation.enabled' = $false
    'browser.privacySegmentation.createdShortcut' = $true
    'browser.shell.checkDefaultBrowser' = $false
    'browser.shell.customIcon.enabled' = $false
    'browser.shell.customIcon.perUserStartMenuShortcutCreated' = $true
    'browser.aboutwelcome.enabled' = $false
    'browser.newtabpage.activity-stream.widgets.weather.enabled' = $false
    'browser.newtabpage.activity-stream.showSponsoredTopSites' = $false
    'browser.newtabpage.activity-stream.showSponsored' = $false
}

function Set-UserJsPref {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] $Value
    )
    $formattedVal = if ($Value -is [bool]) {
        if ($Value) { 'true' } else { 'false' }
    } elseif ($Value -is [int]) {
        "$Value"
    } else {
        '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
    }
    $prefLine = "user_pref(`"$Name`", $formattedVal);"

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Set-Content -LiteralPath $Path -Value "$prefLine`r`n" -NoNewline -Encoding utf8
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $escapedName = [regex]::Escape($Name)
    $regex = "(?m)^\s*user_pref\s*\(\s*`"$escapedName`"\s*,[^)]*\)\s*;\s*`r?`n?"

    if ($content -match $regex) {
        $content = [regex]::Replace($content, $regex, "$prefLine`r`n")
    } else {
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $content += "`r`n"
        }
        $content += "$prefLine`r`n"
    }
    Set-Content -LiteralPath $Path -Value $content -NoNewline -Encoding utf8
}

foreach ($prefKey in $userPrefs.Keys) {
    Set-UserJsPref -Path $userJsPath -Name $prefKey -Value $userPrefs[$prefKey]
}

# 3. Clean up rogue Start Menu shortcuts generated by Gecko browsers
$startFolders = @(
    (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'),
    (Join-Path ([Environment]::GetFolderPath('CommonStartMenu')) 'Programs')
) | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false -and (Test-Path -LiteralPath $_) }

foreach ($folder in $startFolders) {
    $shortcuts = @(
        (Join-Path $folder 'Firefox Private Browsing.lnk'),
        (Join-Path $folder 'Waterfox Private Browsing.lnk'),
        (Join-Path $folder 'Zen Private Browsing.lnk'),
        (Join-Path $folder 'Zen Browser Private Browsing.lnk'),
        (Join-Path $folder 'Firefox.lnk'),
        (Join-Path $folder 'Waterfox.lnk'),
        (Join-Path $folder 'Zen.lnk'),
        (Join-Path $folder 'Zen Browser.lnk'),
        (Join-Path $folder 'Scoop Apps\Waterfox Profile Manager.lnk'),
        (Join-Path $folder 'Waterfox Profile Manager.lnk'),
        (Join-Path $folder 'Scoop Apps\Zen Profile Manager.lnk'),
        (Join-Path $folder 'Scoop Apps\Zen Browser Profile Manager.lnk'),
        (Join-Path $folder 'Zen Profile Manager.lnk'),
        (Join-Path $folder 'Zen Browser Profile Manager.lnk')
    )
    foreach ($sc in $shortcuts) {
        Remove-Item -LiteralPath $sc -Force -ErrorAction SilentlyContinue
    }
}
