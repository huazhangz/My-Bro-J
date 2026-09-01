param(
	[Parameter(Mandatory = $true)]
	[string]$CmdPath
)

$ErrorActionPreference = "Stop"
$statusPath = [System.IO.Path]::ChangeExtension($CmdPath, ".status.json")
if ($CmdPath.EndsWith("web_movie_cmd.json")) {
	$statusPath = $CmdPath.Replace("web_movie_cmd.json", "web_movie_status.json")
}

function Write-Status([string]$State, [string]$Detail = "") {
	$session = 0
	$latest = Read-Cmd
	if ($null -ne $latest) {
		try { $session = [int]$latest.session } catch { $session = 0 }
	}
	$payload = @{ state = $State; detail = $Detail; session = $session } | ConvertTo-Json -Compress
	[System.IO.File]::WriteAllText($statusPath, $payload)
}

function Read-Cmd {
	if (-not (Test-Path -LiteralPath $CmdPath)) {
		return $null
	}
	try {
		return Get-Content -LiteralPath $CmdPath -Raw | ConvertFrom-Json
	} catch {
		return $null
	}
}

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class SteveWinEmbed {
	public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lp, int max);
	[DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr child, IntPtr parent);
	[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
	[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int idx);
	[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int idx, int val);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
	[DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int l, int t, int r, int b);
	[DllImport("gdi32.dll")] public static extern int CombineRgn(IntPtr dest, IntPtr a, IntPtr b, int mode);
	[DllImport("user32.dll")] public static extern int SetWindowRgn(IntPtr hWnd, IntPtr rgn, bool redraw);
	[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
	public const int GWL_STYLE = -16;
	public const int WS_CHILD = 0x40000000;
	public const int WS_VISIBLE = 0x10000000;
	public const int WS_CAPTION = 0x00C00000;
	public const int WS_THICKFRAME = 0x00040000;
	public const int WS_POPUP = unchecked((int)0x80000000);
	public const int SW_SHOW = 5;
	public const int RGN_DIFF = 4;
}
"@

function Find-Browser {
	$paths = @(
		"$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
		"${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
		"$env:LocalAppData\Microsoft\Edge\Application\msedge.exe",
		"$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
		"$env:LocalAppData\Google\Chrome\Application\chrome.exe"
	)
	foreach ($path in $paths) {
		if (Test-Path -LiteralPath $path) {
			return $path
		}
	}
	return $null
}

function Get-ProcessTree([int]$RootId) {
	$ids = New-Object "System.Collections.Generic.HashSet[int]"
	[void]$ids.Add($RootId)
	$changed = $true
	while ($changed) {
		$changed = $false
		foreach ($proc in Get-CimInstance Win32_Process) {
			if ($ids.Contains([int]$proc.ParentProcessId) -and -not $ids.Contains([int]$proc.ProcessId)) {
				[void]$ids.Add([int]$proc.ProcessId)
				$changed = $true
			}
		}
	}
	return $ids
}

function Find-AppWindow($PidSet) {
	foreach ($procInfo in Get-Process) {
		try {
			if (-not $PidSet.Contains($procInfo.Id)) {
				continue
			}
			if ($procInfo.MainWindowHandle -ne [IntPtr]::Zero) {
				return $procInfo.MainWindowHandle
			}
		} catch {
		}
	}
	return [IntPtr]::Zero
}

function Stop-Tree([int]$RootId) {
	try {
		Start-Process -FilePath "taskkill.exe" -ArgumentList @("/PID", "$RootId", "/T", "/F") -WindowStyle Hidden -Wait | Out-Null
	} catch {
	}
}

function Apply-SteveHole($hwnd, [int]$x, [int]$y, [int]$w, [int]$h, $cmdObj) {
	$full = [SteveWinEmbed]::CreateRectRgn(0, 0, $w, $h)
	if ($full -eq [IntPtr]::Zero) {
		return
	}
	$hx = 0
	$hy = 0
	$hw = 0
	$hh = 0
	if ($null -ne $cmdObj) {
		try { $hx = [int]$cmdObj.hole_x } catch { $hx = 0 }
		try { $hy = [int]$cmdObj.hole_y } catch { $hy = 0 }
		try { $hw = [int]$cmdObj.hole_w } catch { $hw = 0 }
		try { $hh = [int]$cmdObj.hole_h } catch { $hh = 0 }
	}
	if ($hw -gt 8 -and $hh -gt 8) {
		$left = [Math]::Max(0, $hx - $x)
		$top = [Math]::Max(0, $hy - $y)
		$right = [Math]::Min($w, $left + $hw)
		$bottom = [Math]::Min($h, $top + $hh)
		if (($right - $left) -gt 8 -and ($bottom - $top) -gt 8) {
			$hole = [SteveWinEmbed]::CreateRectRgn($left, $top, $right, $bottom)
			if ($hole -ne [IntPtr]::Zero) {
				[void][SteveWinEmbed]::CombineRgn($full, $full, $hole, [SteveWinEmbed]::RGN_DIFF)
				[void][SteveWinEmbed]::DeleteObject($hole)
			}
		}
	}
	[void][SteveWinEmbed]::SetWindowRgn($hwnd, $full, $true)
}

$cmd = Read-Cmd
if ($null -eq $cmd -or [string]::IsNullOrWhiteSpace([string]$cmd.url)) {
	Write-Status "failed" "no_cmd"
	exit 1
}
if ($cmd.close -eq $true) {
	Write-Status "failed" "closed"
	exit 0
}

$parentProbe = [IntPtr]::Zero
try {
	$parentProbe = [IntPtr][int64]([string]$cmd.parent)
} catch {
	$parentProbe = [IntPtr]::Zero
}
if ($parentProbe -eq [IntPtr]::Zero) {
	Write-Status "failed" "no_parent"
	exit 1
}

$browser = Find-Browser
if ([string]::IsNullOrWhiteSpace($browser)) {
	Write-Status "failed" "no_browser"
	exit 1
}

$profile = Join-Path $env:TEMP "steve-web-movie-profile"
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$argList = @(
	"--app=$($cmd.url)",
	"--user-data-dir=$profile",
	"--window-size=$($cmd.w),$($cmd.h)",
	"--window-position=0,0",
	"--disable-features=TranslateUI,MediaRouter",
	"--autoplay-policy=no-user-gesture-required",
	"--force-device-scale-factor=1",
	"--high-dpi-support=1",
	"--no-first-run",
	"--no-default-browser-check"
)
if ($cmd.mute -eq $true) {
	$argList += "--mute-audio"
}
$proc = Start-Process -FilePath $browser -ArgumentList $argList -PassThru
if ($null -eq $proc) {
	Write-Status "failed" "spawn"
	exit 1
}

$child = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(9)
while ((Get-Date) -lt $deadline) {
	$latest = Read-Cmd
	if ($null -ne $latest -and $latest.close -eq $true) {
		Stop-Tree $proc.Id
		Write-Status "failed" "closed"
		exit 0
	}
	$tree = Get-ProcessTree $proc.Id
	$child = Find-AppWindow $tree
	if ($child -ne [IntPtr]::Zero) {
		break
	}
	Start-Sleep -Milliseconds 120
}

if ($child -eq [IntPtr]::Zero) {
	Stop-Tree $proc.Id
	Write-Status "failed" "no_window"
	exit 1
}

$parent = [IntPtr]::Zero
try {
	$parent = [IntPtr][int64]([string]$cmd.parent)
} catch {
	$parent = [IntPtr]::Zero
}
if ($parent -eq [IntPtr]::Zero) {
	Stop-Tree $proc.Id
	Write-Status "failed" "no_parent"
	exit 1
}
$style = [SteveWinEmbed]::GetWindowLong($child, [SteveWinEmbed]::GWL_STYLE)
$style = $style -band (-bnot [SteveWinEmbed]::WS_POPUP)
$style = $style -band (-bnot [SteveWinEmbed]::WS_CAPTION)
$style = $style -band (-bnot [SteveWinEmbed]::WS_THICKFRAME)
$style = $style -bor [SteveWinEmbed]::WS_CHILD -bor [SteveWinEmbed]::WS_VISIBLE
[void][SteveWinEmbed]::SetWindowLong($child, [SteveWinEmbed]::GWL_STYLE, $style)
[void][SteveWinEmbed]::SetParent($child, $parent)
$firstX = [int]$cmd.x
$firstY = [int]$cmd.y
$firstW = [Math]::Max(64, [int]$cmd.w)
$firstH = [Math]::Max(64, [int]$cmd.h)
[void][SteveWinEmbed]::MoveWindow($child, $firstX, $firstY, $firstW, $firstH, $true)
Apply-SteveHole $child $firstX $firstY $firstW $firstH $cmd

Write-Status "ready" "embedded"

while ($true) {
	Start-Sleep -Milliseconds 80
	$latest = Read-Cmd
	if ($null -eq $latest -or $latest.close -eq $true) {
		break
	}
	try {
		if ($proc.HasExited) {
			Write-Status "failed" "exited"
			exit 1
		}
	} catch {
	}
	$x = [int]$latest.x
	$y = [int]$latest.y
	$w = [Math]::Max(64, [int]$latest.w)
	$h = [Math]::Max(64, [int]$latest.h)
	[void][SteveWinEmbed]::MoveWindow($child, $x, $y, $w, $h, $true)
	Apply-SteveHole $child $x $y $w $h $latest
	[void][SteveWinEmbed]::ShowWindow($child, [SteveWinEmbed]::SW_SHOW)
}

Stop-Tree $proc.Id
Write-Status "failed" "closed"
exit 0
