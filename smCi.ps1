param($GITHUB_TOKEN)
Invoke-Expression "& {$(Invoke-RestMethod https://github.com/vapoursynth/vapoursynth/releases/download/R70/Install-Portable-VapourSynth-R70.ps1)} -TargetFolder ./VapourSynth -Python38 -Unattended"
$timecube_release = "r3.1"
$ffms2_release = "5.0"

$Dependencies = [Ordered]@{
    # 'py.zip'        = 'https://www.python.org/ftp/python/3.8.10/python-3.8.10-embed-amd64.zip'
    # 'getpip.py'     = 'https://bootstrap.pypa.io/get-pip.py'
    'svp.7z'        = 'https://github.com/bjaan/smoothvideo/blob/main/SVPflow_LastGoodVersions.7z?raw=true'
    'akexpr.7z'     = "https://github.com/AkarinVS/vapoursynth-plugin/releases/download/v0.96/akarin-release-lexpr-amd64-v0.96b.7z"
    #'akexpr.zip' = @{ Repo = "AkarinVS/vapoursynth-plugin";                             Pattern = "akarin-release-lexpr-amd64-v*.7z"}
    'bestsource.7z' = "https://github.com/vapoursynth/bestsource/releases/download/R10/BestSource-R10.7z"
    'lsmash.zip'    = "https://github.com/AkarinVS/L-SMASH-Works/releases/download/vA.3k/release-x86_64-cachedir-tmp.zip"
    'mvtools.7z'    = @{ Repo = "dubhater/vapoursynth-mvtools"; Pattern = "vapoursynth-mvtools-v*-win64.7z" }
    'remap.zip'     = @{ Repo = "Irrational-Encoding-Wizardry/Vapoursynth-RemapFrames"; Pattern = "Vapoursynth-RemapFrames-v*-x64.zip" }
    # 'rife.7z'    = @{ Repo = "HomeOfVapourSynthEvolution/VapourSynth-RIFE-ncnn-Vulkan"; Pattern = "RIFE-r*-win64.7z"}
    'librife.dll'   = @{ Repo = "styler00dollar/VapourSynth-RIFE-ncnn-Vulkan"; Pattern = "librife_windows_x86-64.dll" }
    # 'vsA6.zip'   = @{ Repo = "AmusementClub/vapoursynth-classic";                       Pattern = "release-x64.zip"}
    # 'vsA6.zip'      = @{ Repo = "vapoursynth/vapoursynth"; Pattern = "*portable*.zip" }
    'fmtc.zip'      = @{ Repo = 'EleonoreMizo/fmtconv'; Pattern = 'fmtconv-r*.zip' }
    'timecube.7z'   = "https://github.com/sekrit-twc/timecube/releases/download/$timecube_release/timecube_$timecube_release.7z"
    'ffms2.7z'      = "https://github.com/FFMS/ffms2/releases/download/$ffms2_release/ffms2-$ffms2_release-msvc.7z"
    #'vsfbd.dll' = @{Repo = "couleurm/vs-frameblender";                                  Pattern = "vs-frameblender-*.dll"}
    'avisource.7z'  = "https://github.com/vapoursynth/vs-avisource-obsolete/releases/download/R1/avisource-r1.7z"
}

if (-not(Test-Path smdeps)){
    mkdir smdeps
}
if (-not(Test-Path smShip)){
    mkdir smShip
}

ForEach ($File in [Array]$Dependencies.Keys) {

    $smDeps = Convert-Path ./smDeps
    $BaseName = [IO.Path]::GetFileNameWithoutExtension($File)
    Set-Variable -Name $BaseName -Value (Join-Path $smDeps $File)
    
    if (-not(Test-Path "$smDeps/$File")) {


        Write-Host "Downloading to $(Join-Path $smDeps $File) from" $Dependencies.$File -ForegroundColor Cyan

        $URL = if ($Dependencies.$File -is [String]) {

            $Dependencies.$File
        }
        else {

            $Parameters = @{

                Uri         = "https://api.github.com/repos/$($Dependencies.$File.Repo)/releases/latest"
                ErrorAction = 'Stop'
            }

            if ($GITHUB_TOKEN) {

                $Parameters.Authentication = "Bearer"
                $Parameters.Token = ($GITHUB_TOKEN | ConvertTo-SecureString -AsPlainText)
            }

            $LastRelease = (Invoke-RestMethod @Parameters).assets.browser_download_url | Where-Object { $_ -Like "*$($Dependencies.$File.Pattern)" }

            if (!$LastRelease) {

                $Parameters.Token = "***"
                Write-Debug "$Repo failed with parameters $($Parameters | ConvertTo-Json -Depth 2 -Compress)" -Debug
                throw "Failed getting latest release from API"
            }

            if ($LastRelease.Count -gt 1) {

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

Push-Location VapourSynth/vs-plugins/

7z e -y $bestsource "bestsource.dll" . | Out-Null
7z e -y $avisource -r "win64\avisource.dll" . | Out-Null
7z e -y $ffms2 -r "ffms2-$ffms2_release-msvc\x64\ffms2.dll" . | Out-Null
7z e -y $svp -r svpflow1_vs.dll svpflow2_vs.dll . | Out-Null
7z e -y $fmtc -r 'win64\fmtconv.dll' . | Out-Null
7z e -y $timecube -r "timecube_$timecube_release\x64\vscube.dll" . | Out-Null

Copy-Item $librife .
$akexpr, $lsmash, $mvtools, $rife, $remap | ForEach-Object { 7z x $_ }

popd


7z a ".\smShip\VapourSynth.7z" .\VapourSynth\ -t7z -mx=8 -sae
