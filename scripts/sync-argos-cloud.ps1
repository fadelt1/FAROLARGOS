# Script de sincronización autónoma para GitHub Actions
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

$user = if ($env:ARGOS_USER) { $env:ARGOS_USER } else { "anika.solis@fadeltransportes.com.br" }
$pass = if ($env:ARGOS_PASS) { $env:ARGOS_PASS } else { "Anikafadel@358" }

Write-Host "Iniciando sesion en Argos Ambev con usuario: $user"

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0")
$wc.Headers.Add("Content-Type", "application/x-www-form-urlencoded")
$body = "client_id=ambev-argos&username=$user&password=$pass&grant_type=password"

try {
    $tokenJson = $wc.UploadString("https://auth.ambevdevs.com.br/realms/Third/protocol/openid-connect/token", $body) | ConvertFrom-Json
    $token = $tokenJson.access_token
    Write-Host "Autenticacion exitosa con Keycloak."
} catch {
    Write-Host "Error autenticando con Argos: $($_.Exception.Message)"
    exit 1
}

$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
$client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0")
$client.DefaultRequestHeaders.Add("Accept", "application/json")
$client.Timeout = [TimeSpan]::FromSeconds(90)

# 1. Obtener empleados activos autoritativos
Write-Host "Consultando lista oficial de empleados ACTIVOS..."
$empUrl = "https://apim.ambevdevs.com.br/argos-hired/v1/api/v1/employee/list?status=Active&pagination.currentPage=1&pagination.itemsPerPage=500"
$empReq = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $empUrl)
$empRes = $client.SendAsync($empReq).GetAwaiter().GetResult()
$empBytes = $empRes.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
$empJson = [System.Text.Encoding]::UTF8.GetString($empBytes) | ConvertFrom-Json

$activeMap = @{}
foreach ($emp in $empJson.data) {
    if ($emp.status -eq "Active" -and -not $emp.deleted) {
        $activeMap[[string]$emp.id] = $emp
    }
}
Write-Host "Total Empleados Activos confirmados: $($activeMap.Keys.Count)"

function Normalize-ArgosDate($str) {
    if (-not $str) { return "" }
    $s = $str.Trim()
    if ($s -match '^(\d{4}-\d{2}-\d{2})') { return $matches[1] }
    if ($s -match '^(\d{1,2})\/(\d{1,2})\/(\d{4})') {
        return "$($matches[3])-$($matches[2].PadLeft(2,'0'))-$($matches[1].PadLeft(2,'0'))"
    }
    return $s
}

# 2. Obtener documentos
Write-Host "Descargando documentos..."
$allDocs = @()
$page = 1
$pageSize = 1000

do {
    $url = "https://apim.ambevdevs.com.br/argos-hired/v1/api/v1/employee-document/list?pagination.currentPage=$page&pagination.itemsPerPage=$pageSize"
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $url)
    $res = $client.SendAsync($req).GetAwaiter().GetResult()
    $b = $res.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    $obj = [System.Text.Encoding]::UTF8.GetString($b) | ConvertFrom-Json
    $items = @($obj.data)

    Write-Host "Pagina $page : $($items.Count) documentos"
    foreach ($d in $items) {
        $empId = [string]$d.employeeId
        $empName = [string]$d.employee.fullName
        if (-not $empName.Trim()) { $empName = "$($d.employee.name) $($d.employee.surname)".Trim() }

        # Filtrar inactivos estrictamente
        if (-not $activeMap.ContainsKey($empId) -or [string]$d.employee.status -ne "Active" -or [bool]$d.employee.deleted -or [bool]$d.deleted) {
            continue
        }

        $unitDesc = [string]$d.unit.description
        if (-not $unitDesc -and $activeMap.ContainsKey($empId)) {
            $unitDesc = ($activeMap[$empId].units | ForEach-Object { $_.description }) -join ', '
        }

        $allDocs += @{
            id = [string]$d.id
            driver = $empName
            cpf = [string]$d.employee.documentIdentifierEmployee.value
            carrier = [string]$d.company.name
            unit = $unitDesc
            docType = [string]$d.documentModel.name
            uploadDate = Normalize-ArgosDate ([string]$d.createdDate)
            expDate = Normalize-ArgosDate ([string]$d.expirationDate)
            status = [string]$d.status
            isExpired = [bool]$d.isExpired
            employeeId = $empId
            employeeStatus = "Active"
        }
    }
    $page++
} while ($page -le 6 -and $items.Count -gt 0)

Write-Host "Total documentos activos recolectados: $($allDocs.Count)"

# 3. Guardar argos-cache.json
$jsonStr = $allDocs | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("argos-cache.json", $jsonStr, [System.Text.Encoding]::UTF8)

# 4. Actualizar index.html con los nuevos datos incrustados
if (Test-Path "index.html") {
    $html = [System.IO.File]::ReadAllText("index.html", [System.Text.Encoding]::UTF8)
    
    $replacement = "<script>`r`nwindow.ARGOS_INITIAL_DATA = " + $jsonStr + ";`r`n</script>"
    $pattern = '<script>\s*window\.ARGOS_INITIAL_DATA\s*=[\s\S]*?</script>'
    
    if ([regex]::IsMatch($html, $pattern)) {
        $newHtml = [regex]::Replace($html, $pattern, $replacement)
    } else {
        $newHtml = $html.Replace('<script src="argos-data.js"></script>', $replacement)
    }
    
    [System.IO.File]::WriteAllText("index.html", $newHtml, [System.Text.Encoding]::UTF8)
    Write-Host "index.html actualizado exitosamente en la nube."
}
