$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

flutter create --project-name iptv_pro --org com.iptvpro --platforms=android,windows .
if ($LASTEXITCODE -ne 0) {
    throw "flutter create failed with exit code $LASTEXITCODE"
}

$manifestPath = Join-Path 'android' 'app\src\main\AndroidManifest.xml'
[xml] $manifest = Get-Content -Raw $manifestPath
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$namespaces = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
$namespaces.AddNamespace('android', $androidNamespace)
$application = $manifest.SelectSingleNode('/manifest/application')

if ($null -eq $application) {
    throw "Android application element was not found in $manifestPath"
}

foreach ($permission in @('android.permission.INTERNET', 'android.permission.WAKE_LOCK')) {
    $xpath = "/manifest/uses-permission[@android:name='$permission']"
    if ($null -eq $manifest.SelectSingleNode($xpath, $namespaces)) {
        $element = $manifest.CreateElement('uses-permission')
        $element.SetAttribute('name', $androidNamespace, $permission)
        $manifest.DocumentElement.InsertBefore($element, $application) | Out-Null
    }
}

$application.SetAttribute('usesCleartextTraffic', $androidNamespace, 'true')
$application.SetAttribute('label', $androidNamespace, 'IPTV Pro')
$manifest.Save((Join-Path (Get-Location) $manifestPath))

Write-Host 'Android and Windows platform files are ready.'
