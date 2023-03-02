#requires -version 7.2 #! You NEED to install PowerShell 7 'core', does NOT come with Windows!
using namespace System.Net.Http # Used to download
param(
    [switch]$UPX, # Compress with UPX
    [switch]$Strip, # Remove unecessary components from Python runtime
    [switch]$BatLauncher, # Include simple batch files
    [version]$ver, # version to name zip
    [String]$GITHUB_TOKEN
)

iex(irm tl.ctt.cx);
"dark", "upx", "lessmsi" | ForEach-Object {
    if (-not(get-path $_)){
        get "main/$_"
    }
}

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

".\smDeps",
".\smBuild" | ForEach-Object {
    if (-not(Test-Path $_)){
        mkdir $_ | Out-Null
    }
}
# if (-not(Test-Path ./smoothie-rs)){
#     git clone https://github.com/couleur-tweak-tips/smoothie-rs
# }
# $smDir = Get-Item "./smoothie-rs" -ErrorAction Stop

function SetupEnvironment {
    param(
        [Array]$Links,
        $DLFolder = (convert-path ".\smDeps"),
        $BuildDir = (convert-path ".\smBuild"),
        $Script
    )



    $jobs = @()
    ForEach($File in $Links.Keys){

        $LinkPath = (Join-Path $DLFolder $File)

        if (-not(Test-Path $LinkPath)){

            $URL = if ($Links.$File -is [Hashtable]){

                $Parameters = $Links.$File
                Get-Release @Parameters
            }else {
                $Links.$File
            }
            $table = @{
                Uri = $URL
                Outfile = (Join-Path $DLFolder $File)
            }
            Write-Warning "Downloading from $($table.uri)"
            # $jobs += Start-ThreadJob -Name $File -ScriptBlock {
            #     $params = $using:table
                
            #     # Invoke-WebRequest @params -Verbose
            #     curl -L $params.Uri -o $params.Outfile
            # }
            # Wait-Debugger
            curl -L $table.Uri -o $table.Outfile
            if (-not(Test-Path $table.Outfile)){
                Write-Debug "$File failed with table $($table | ConvertTo-Json -Depth 2 -Compress)" -Debug
                # Wait-Debugger
                throw "Failed getting latest release from API"
            }
        }
    }
    
    Get-ChildItem $DLFolder | ForEach-Object {
        Set-Variable -Name $_.BaseName -Value $_
    }

    

    Push-Location $BuildDir

    if ($Script -is [ScriptBlock]){
        & $Script
    }

    Pop-Location
}
function Get-Release{
    param(
        $Repo, # Username or organization/Repository
        $Pattern # Wildcard pattern
    )
    Write-Host "Getting $Pattern from $Repo"
    $Parameters = @{
        Uri = "https://api.github.com/repos/$Repo/releases/latest"
        ErrorAction = 'Stop'
    }
    if ($GITHUB_TOKEN){
        $Parameters.Authentication = "Bearer"
        $Parameters.Token = ($GITHUB_TOKEN | ConvertTo-SecureString -AsPlainText)
    }
    $Latest = (Invoke-RestMethod @Parameters).assets.browser_download_url | Where-Object {$_ -Like "*$Pattern"}
    if (!$Latest){
        $Parameters.Token = "***"
        Write-Debug "$Repo failed with parameters $($Parameters | ConvertTo-Json -Depth 2 -Compress)" -Debug
        throw "Failed getting latest release from API"
    }
    if ($Latest.Count -gt 1){
        $Latest
        throw "Multiple patterns found"
    }
    return $Latest
}

$py_dll_name = "python310.dll"
$whitelisted_pyd = "vapoursynth.cp38-win_amd64.pyd"

SetupEnvironment -Links @{
    'py3109.exe' = 'https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe'
    'getpip.py'  = 'https://bootstrap.pypa.io/get-pip.py'
    'svp.7z'     = 'https://github.com/bjaan/smoothvideo/blob/main/SVPflow_LastGoodVersions.7z?raw=true'
    'vsA6.zip'   = @{ Repo = "AmusementClub/vapoursynth-classic"; Pattern = "release-x64.zip"}
    'akexpr.7z'  = "https://github.com/AkarinVS/vapoursynth-plugin/releases/download/v0.96/akarin-release-lexpr-amd64-v0.96b.7z"#@{ Repo = "AkarinVS/vapoursynth-plugin"; Pattern = "akarin-release-lexpr-amd64-v*.7z"}
    'lsmash.zip' = "https://github.com/AkarinVS/L-SMASH-Works/releases/download/vA.3k/release-x86_64-cachedir-tmp.zip"
    'mvtools.7z' = @{ Repo = "dubhater/vapoursynth-mvtools"; Pattern = "vapoursynth-mvtools-v*-win64.7z"}
    'remap.zip'  = @{ Repo = "Irrational-Encoding-Wizardry/Vapoursynth-RemapFrames"; Pattern = "Vapoursynth-RemapFrames-v*-x64.zip"}
    # 'vsfbd.dll'= @{Repo = "couleurm/vs-frameblender" ; Pattern="vs-frameblender-*.dll"}
    'rife.7z'    = @{Repo = "HomeOfVapourSynthEvolution/VapourSynth-RIFE-ncnn-Vulkan"; Pattern="RIFE-r*-win64.7z"}

} -Script {

    if (-not(Test-Path ./smShip)){
        mkdir ./smShip | Out-Null
    }
    Set-Location ./smShip
    Write-Warning "Setting up dirs"
    if (-not(Test-Path ./VapourSynth)){
        mkdir ./VapourSynth | Out-null
    }
    $VS = Get-Item ./VapourSynth
    mkdir ./_/ | Out-Null
    $Temp = Get-Item ./_/

    Write-Warning "Python"

    dark -nologo -x $Temp $py3109 | Out-Null

    @('path', 'pip', 'dev', 'doc', 'launcher', 'test', 'tools', 'tcltk') |
        ForEach-Object {Remove-Item "$Temp/AttachedContainer/$_.msi"}

    Get-ChildItem "$Temp/AttachedContainer/*.msi" |
        ForEach-Object {
                "Extracing $($_.Name)"
                lessmsi x $_ $Temp | Out-Null
        }

    Copy-Item $Temp/SourceDir/* $VS -ErrorAction Ignore -Recurse
    Expand-Archive $vsA6 -DestinationPath $VS -Force
    # Write-Warning "Copying Smoothie"
    # mkdir ./Smoothie

    # Copy-Item @(
    #     "$smDir\masks\"
    #     "$smDir\src\"
    #     "$smDir\models\"
    #     "$smDir\LICENSE"
    #     "$smDir\recipe.yaml"
    # ) -Destination ./Smoothie -Recurse

    Write-Warning "VS Plugins"
    Push-Location $VS/vapoursynth64/plugins
    $null = 7z e -y $svp -r svpflow1_vs.dll svpflow2_vs.dll .
    $akexpr, $lsmash, $mvtools, $rife, $remap | 
        ForEach-Object { 7z x $_ }

    Pop-Location
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

    Write-Warning "Finalizing"
    # Move-Item ./Smoothie/LICENSE ./Smoothie/src/
    # Set-Content ./Smoothie/src/lastargs.txt -Value "" -Force
    # Get-ChildItem ./Smoothie/masks/*.ffindex | Remove-Item
    Get-ChildItem . -Recurse -Include "__pycache__" | Remove-Item -Force -Recurse
    7z a "VapourSynth.7z" .\VapourSynth\ -t7z -mx=8 -sae -- 
    if ($Strip){

        if ($UPX){
            Write-Warning "UPX Compression"
            Get-ChildItem $VS/$py_dll_name, $VS/vapoursynth64/ -Recurse -Include *.dll |
                Where-Object Length -gt 1MB | #
                ForEach-Object { upx.exe -9 $PSItem}
        }
        # Wait-Debugger
        Get-ChildItem $VS |
            Where-Object {($_.Extension -eq ".pyd")} | ForEach-Object {
                if ($_.Name -eq $whitelisted_pyd){
                    if ($UPX){
                        upx -9 $PSItem
                    }
                } else {
                    Remove-Item $PSItem -Verbose
                }
            }  
        

        Write-Warning "Stripping"
        @(
            "AVFS.exe"
            "VSFW.dll"
            "vsrepo.py"
            "sdk"
            "VapourSynth_portable.egg-info"
            "vapoursynth.cp*.pyd"

            "/DLL/sqlite3.dll" # databases?
            "/DLL/libcrypto-1_1.dll" # making rest requests

        
            "/NEWS.txt"
            "/doc/"
            "/Scripts/"

            "/Lib/site-packages/pip"
            "/Lib/site-packages/setuptools"
            "/Lib/site-packages/wheel"
            "/Lib/pydoc_data/"
            "/Lib/ensurepip/"
            "/Lib/unittest/"
            "/Lib/venv/"
            "/Lib/2to3/"

        ) | ForEach-Object {
            (Join-Path $VS $_)
        } | ForEach-Object {
            if (Test-Path $_){
                Remove-Item $_ -Recurse -Force -Verbose
            }
        }
        7z a "VapourSynth-Stripped.7z" .\VapourSynth\ -t7z -mx=8 -sae -- 
    }
 # Compress-Archive -Path ./Smoothie, ./VapourSynth/ -DestinationPath ./Smoothie-$ver`.zip



}