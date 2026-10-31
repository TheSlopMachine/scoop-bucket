[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TargetPath,
    [Parameter(Mandatory)] [string] $ShortcutPath,
    [string] $Arguments = '',
    [string] $WorkingDirectory = '',
    [string] $IconLocation = '',
    [switch] $DiscoverAppUserModelId,
    [string] $AppUserModelId
)

if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    throw "Target executable was not found: $TargetPath"
}

if (-not ('Scoop.AppUserModelShortcut' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Scoop {
    [StructLayout(LayoutKind.Sequential)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public uint pid;
        public PROPERTYKEY(Guid fmtid, uint pid) { this.fmtid = fmtid; this.pid = pid; }
    }

    [StructLayout(LayoutKind.Explicit, Size = 24)]
    public struct PROPVARIANT {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pointer;
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore {
        int GetCount(out uint cProps);
        int GetAt(uint iProp, out PROPERTYKEY pkey);
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT value);
        int Commit();
    }

    public static class AppUserModelShortcut {
        const int S_OK = 0;
        static readonly Guid PropertyStoreIid = typeof(IPropertyStore).GUID;
        static readonly PROPERTYKEY AppUserModelIdKey = new PROPERTYKEY(
            new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        static extern int SHGetPropertyStoreFromParsingName(
            string path, IntPtr pbc, uint flags, ref Guid iid,
            [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

        [DllImport("shell32.dll")]
        static extern int SHGetPropertyStoreForWindow(
            IntPtr hwnd, ref Guid iid,
            [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

        delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

        [DllImport("user32.dll")]
        static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        static extern bool IsWindowVisible(IntPtr hwnd);

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

        public static object[] FindWindows(string executablePath, int[] excludedProcessIds) {
            string wanted = System.IO.Path.GetFullPath(executablePath);
            var excluded = new HashSet<int>(excludedProcessIds ?? new int[0]);
            var results = new List<object>();

            EnumWindows((hwnd, unused) => {
                if (!IsWindowVisible(hwnd)) return true;
                uint processId;
                GetWindowThreadProcessId(hwnd, out processId);
                if (excluded.Contains((int)processId)) return true;

                try {
                    using (var process = Process.GetProcessById((int)processId)) {
                        if (!String.Equals(process.MainModule.FileName, wanted, StringComparison.OrdinalIgnoreCase)) return true;
                    }
                } catch { return true; }

                IPropertyStore store;
                Guid propertyStoreIid = PropertyStoreIid;
                int result = SHGetPropertyStoreForWindow(hwnd, ref propertyStoreIid, out store);
                if (result < 0) return true;
                try {
                    PROPVARIANT value;
                    PROPERTYKEY appUserModelIdKey = AppUserModelIdKey;
                    result = store.GetValue(ref appUserModelIdKey, out value);
                    if (result == S_OK && value.vt == 31 && value.pointer != IntPtr.Zero) {
                        results.Add(new object[] { hwnd, (int)processId, Marshal.PtrToStringUni(value.pointer) });
                    }
                } finally { Marshal.ReleaseComObject(store); }
                return true;
            }, IntPtr.Zero);

            return results.ToArray();
        }

        public static void SetId(string shortcutPath, string appUserModelId) {
            IPropertyStore store;
            Guid propertyStoreIid = PropertyStoreIid;
            int result = SHGetPropertyStoreFromParsingName(shortcutPath, IntPtr.Zero, 0x2,
                ref propertyStoreIid, out store);
            if (result < 0) Marshal.ThrowExceptionForHR(result);

            IntPtr text = Marshal.StringToCoTaskMemUni(appUserModelId);
            var value = new PROPVARIANT { vt = 31, pointer = text };
            try {
                PROPERTYKEY appUserModelIdKey = AppUserModelIdKey;
                result = store.SetValue(ref appUserModelIdKey, ref value);
                if (result < 0) Marshal.ThrowExceptionForHR(result);
                result = store.Commit();
                if (result < 0) Marshal.ThrowExceptionForHR(result);
            } finally {
                Marshal.FreeCoTaskMem(text);
                Marshal.ReleaseComObject(store);
            }
        }
    }
}
'@
}

if ($DiscoverAppUserModelId) {
    $fullTargetPath = [IO.Path]::GetFullPath($TargetPath)
    $before = @(Get-Process | Where-Object {
        try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq $fullTargetPath) } catch { $false }
    } | Select-Object -ExpandProperty Id)

    $discovered = $null
    $started = $null
    $existingWindows = [Scoop.AppUserModelShortcut]::FindWindows($fullTargetPath, @())
    if ($existingWindows.Count -gt 0) {
        $discovered = $existingWindows[0]
    } else {
        $startParameters = @{ FilePath = $fullTargetPath; ArgumentList = $Arguments; PassThru = $true; WindowStyle = 'Minimized' }
        if ($WorkingDirectory) { $startParameters.WorkingDirectory = $WorkingDirectory }
        $started = Start-Process @startParameters

        $deadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $deadline -and -not $discovered) {
            $windows = [Scoop.AppUserModelShortcut]::FindWindows($fullTargetPath, $before)
            if ($windows.Count -gt 0) { $discovered = $windows[0] }
            if (-not $discovered) { Start-Sleep -Milliseconds 250 }
        }
    }

    if (-not $discovered) {
        if ($started) { try { Stop-Process -Id $started.Id -Force -ErrorAction SilentlyContinue } catch { } }
        throw "Could not discover the AppUserModelID for $fullTargetPath"
    }

    $AppUserModelId = [string]$discovered[2]
    if ($started) {
        $probeProcessId = [int]$discovered[1]
        try { Get-Process -Id $probeProcessId -ErrorAction Stop | ForEach-Object { $_.CloseMainWindow() | Out-Null } } catch { }
        Start-Sleep -Milliseconds 750
        try { Stop-Process -Id $probeProcessId -Force -ErrorAction SilentlyContinue } catch { }
    }
    Write-Verbose "Discovered AppUserModelID: $AppUserModelId"
}

if ([string]::IsNullOrWhiteSpace($AppUserModelId)) {
    throw 'Specify -AppUserModelId or use -DiscoverAppUserModelId.'
}

$shortcutDirectory = Split-Path -Parent $ShortcutPath
New-Item -ItemType Directory -Force -Path $shortcutDirectory | Out-Null

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $TargetPath
$shortcut.Arguments = $Arguments
$shortcut.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $TargetPath }
$shortcut.IconLocation = if ($IconLocation) { $IconLocation } else { "$TargetPath,0" }
$shortcut.Save()

[Scoop.AppUserModelShortcut]::SetId($ShortcutPath, $AppUserModelId)
