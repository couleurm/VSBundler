param(
    [String]$GITHUB_TOKEN,
    [Switch]$Strip,
    [Switch]$UPX, # use -9 on files greater than 1MB
    [Switch]$UPXBrute, # use --best --ultra-brute on all compressible files

    [Switch]$DontZip, # skips zipping, for debugging
    [Switch]$EnsureVSScript # Executes vspipe.exe after each component is stripped/compressed and fails if $LASTEXITCODE
)
if ($UPXBrute -and $UPX){
    return "Can't pass both -UPXBrute and -UPX"
}

if (-not(Get-Command Get -ErrorAction Ignore)){
    Invoke-Expression (Invoke-RestMethod tl.ctt.cx);
}

'dark', 'upx', 'lessmsi' | ForEach-Object {
    if (-not(get-path $_)){
        get "main/$_"
    }
}
$whitelisted_pyd = 'vapoursynth.cp310-win_amd64.pyd'
$Dependencies = [Ordered]@{
    'py3109.exe' = 'https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe'
    'getpip.py'  = 'https://bootstrap.pypa.io/get-pip.py'
    'svp.7z'     = 'https://github.com/bjaan/smoothvideo/blob/main/SVPflow_LastGoodVersions.7z?raw=true'
    'akexpr.7z'  = "https://github.com/AkarinVS/vapoursynth-plugin/releases/download/v0.96/akarin-release-lexpr-amd64-v0.96b.7z"
   #'akexpr.zip' = @{ Repo = "AkarinVS/vapoursynth-plugin";                             Pattern = "akarin-release-lexpr-amd64-v*.7z"}
    'lsmash.zip' = "https://github.com/AkarinVS/L-SMASH-Works/releases/download/vA.3k/release-x86_64-cachedir-tmp.zip"
    'mvtools.7z' = @{ Repo = "dubhater/vapoursynth-mvtools";                            Pattern = "vapoursynth-mvtools-v*-win64.7z"}
    'remap.zip'  = @{ Repo = "Irrational-Encoding-Wizardry/Vapoursynth-RemapFrames";    Pattern = "Vapoursynth-RemapFrames-v*-x64.zip"}
    'rife.7z'    = @{ Repo = "HomeOfVapourSynthEvolution/VapourSynth-RIFE-ncnn-Vulkan"; Pattern = "RIFE-r*-win64.7z"}
    'vsA6.zip'   = @{ Repo = "AmusementClub/vapoursynth-classic";                       Pattern = "release-x64.zip"}
   #'vsfbd.dll' = @{Repo = "couleurm/vs-frameblender";                                  Pattern = "vs-frameblender-*.dll"}
}

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Where downloads are downloaded to
if (-not(test-path ./smDeps)){
    mkdir smDeps
}
# Where downloads are extracted to
if (-not(test-path ./smBuild)){
    mkdir smBuild
}
# Where output zips are built before passing them to create-release
if (-not(test-path ./smShip)){
    mkdir smShip
}

# Redundance if a user runs the script twice
if (Test-Path ./smBuild/*){
    Remove-Item ./smBuild/* -Recurse -Confirm
}
if (Test-Path ./smShip/*){
    Remove-Item ./smShip/* -Recurse -Confirm
}

# Gets dependencies
ForEach($File in [Array]$Dependencies.Keys) {

    $smDeps = Convert-Path ./smDeps
    $BaseName = [IO.Path]::GetFileNameWithoutExtension($File)
    Set-Variable -Name $BaseName -Value (Join-Path $smDeps $File)
    
    if (-not(Test-Path "$smDeps/$File")){


        Write-Host "Downloading to $(Join-Path $smDeps $File) from" $Dependencies.$File -ForegroundColor Cyan

        $URL = if ($Dependencies.$File -is [String]){

            $Dependencies.$File
        } else {

            $Parameters = @{

                Uri = "https://api.github.com/repos/$($Dependencies.$File.Repo)/releases/latest"
                ErrorAction = 'Stop'
            }

            if ($GITHUB_TOKEN){

                $Parameters.Authentication = "Bearer"
                $Parameters.Token = ($GITHUB_TOKEN | ConvertTo-SecureString -AsPlainText)
            }

            $LastRelease = (Invoke-RestMethod @Parameters).assets.browser_download_url | Where-Object {$_ -Like "*$($Dependencies.$File.Pattern)"}

            if (!$LastRelease){

                $Parameters.Token = "***"
                Write-Debug "$Repo failed with parameters $($Parameters | ConvertTo-Json -Depth 2 -Compress)" -Debug
                throw "Failed getting latest release from API"
            }

            if ($LastRelease.Count -gt 1){

                Write-Debug $Latest -Debug
                throw "Multiple patterns found"
            }
            
            $LastRelease
        }

        # Bypass Invoke-WebRequest alias
        $curl = Get-Command -Name curl -CommandType Application | Select-Object -First 1
        
        & $curl -L $URL -o $((Get-Variable -Name $BaseName).Value)
    }

    Set-Variable -Name $BaseName -Value (Get-Item (Join-Path $smDeps $File))
}

Write-Warning "Setting up dirs"

mkdir ./smBuild/_/
$Temp = Get-Item ./smBuild/_/

mkdir ./smBuild/VapourSynth/
$VS = Get-Item ./smBuild/VapourSynth/

Write-Warning "Extracting Python"

dark -nologo -x $Temp $py3109 | Out-Null

@(
'path'
'pip'
'dev'
'doc'
'launcher'
'test'
'tools'
'tcltk'
) | ForEach-Object {
    Remove-Item "$Temp/AttachedContainer/$PSItem.msi"
}

Push-Location $Temp

    Get-ChildItem "$Temp/AttachedContainer/*.msi" |
        ForEach-Object {

                Write-Host "- $($PSItem.BaseName)"
                lessmsi x $PSItem | Out-Null
                # Wait-Debugger
                Copy-Item $Temp/$($PSItem.BaseName)/SourceDir/* $VS -Force -Recurse
        }
Pop-Location

# Copy-Item $Temp/SourceDir/* $VS -ErrorAction Ignore -Recurse -Verbose
Expand-Archive $vsA6 -DestinationPath $VS -Force



    # Write-Warning "Pip"
    # $py = Get-Item "$VS/python.exe"

    # & $py $getpip --no-warn-script-location

    # @(
    #     'yaspin'
    #     'pyyaml'
    #     "https://github.com/SubNerd/PyTaskbar/releases/download/0.0.8/PyTaskbarProgress-0.0.8-py3-none-any.whl"#(Get-Release SubNerd/PyTaskbar PyTaskbarProgress-*-py3-none-any.whl)
    # ) | ForEach-Object {
    #     & $py -m pip install $_
    # }
    # & $py -m pip install vsutil --no-dependencies




Write-Warning "VS Plugins"

Push-Location $VS/vapoursynth64/plugins
if (!$DontZip){
    7z e -y $svp -r svpflow1_vs.dll svpflow2_vs.dll . | Out-Null
}

$akexpr, $lsmash, $mvtools, $rife, $remap | ForEach-Object { 7z x $_ }

Pop-Location


if (!$DontZip){
    Write-Warning "Zipping non-stripped"
    7z a ".\smShip\VapourSynth.7z" .\smBuild\VapourSynth\ -t7z -mx=8 -sae
}

if ($Strip){
    Wait-Debugger
    Remove-Item (Get-ChildItem $VS/*.pyd | Where-Object {$_.Name -ne $whitelisted_pyd}) -Verbose


    Write-Warning "Stripping"
    @(
        "pythonw.exe"
        "AVFS.exe"
        "VSVFW.dll"
        "vsrepo.py"
        "VapourSynth_portable.egg-info"
        "/sdk/"

        "/DLLs/sqlite3.dll" # databases yeah i aint using that?
        "/DLLs/libssl-1_1.dll"
        "/DLLs/libcrypto-1_1.dll" # http stuff

        "/NEWS.txt"
        "/doc/"
        "/Scripts/"

        "/Lib/site-packages/pip"
        "/Lib/site-packages/setuptools"
        "/Lib/site-packages/wheel"
        "/Lib/pydoc_data/"
        "/Lib/sqlite3/"
        "/Lib/ensurepip/"
        "/Lib/unittest/"
        "/Lib/venv/"
        "/Lib/lib2to3/"
        # "/DLLs/libffi-7.dll"  # used by VSPipe internally

    ) | ForEach-Object {
        (Join-Path $VS $PSItem)
    } | ForEach-Object {
        if (Test-Path $PSItem){
            
            Remove-Item $PSItem -Recurse -Force -Verbose
            
            if ($EnsureVSScript){
                & $VS/vspipe.exe
                if ($LASTEXITCODE){
                    Write-Warning "Failed after $PSItem"
                    exit 1
                }
            }

        } else {
            Write-Host "$PSItem did not exist"
        }
    }

    $Binaries = Get-ChildItem $VS -Recurse -Include *.exe, *.dll, *.lib, *.pyd -Exclude VapourSynth.dll

    if ($UPX){
        
        Write-Warning "Compressing with UPX"

        upx -9 ($Binaries | Where-Object Length -gt 1MB)
    }elseif($UPXBrute){
        upx --best --ultra-brute $Binaries
    }

    if (!$DontZip){
        Write-Warning "Zipping stripped"
        7z a ".\smShip\VapourSynth-Stripped.7z" .\smBuild\VapourSynth\ -t7z -mx=8 -sae

    }

}
