# CenturyKnights v8.7 farm driver (runs on the m173 relay).
# Binds the physical LAN NIC and disables proxies so requests to the GeneRanch farm
# bypass the FlClash TUN (198.18.0.1) without touching any proxy/network config.
#   farm.ps1 submit <batchDir>   -> uploads <batchDir>\inputs\*, POSTs <batchDir>\jobs\*.json, appends submitted.tsv
#   farm.ps1 fetch  <batchDir>   -> downloads finished outputs into <batchDir>\out, writes status.tsv, zips out.zip
#   farm.ps1 watch  <batchDir>   -> fetch every 60s until every job is done (max 6h)
param([string]$Cmd, [string]$Batch, [string]$Farm = "192.168.9.244", [string]$Nic = "192.168.20.2")
$ErrorActionPreference = "Continue"
$C = @('-s', '--noproxy', '*', '--interface', $Nic)
function Url($port, $path) { "http://$Farm`:$port$path" }
function Submit {
  $sub = Join-Path $Batch "submitted.tsv"
  $done = @{}
  if (Test-Path $sub) { Get-Content $sub | ForEach-Object { $done[($_ -split "`t")[0]] = 1 } }
  $inp = Join-Path $Batch "inputs"
  if (Test-Path $inp) {
    $ports = (Get-ChildItem (Join-Path $Batch "jobs") -Filter *.json | ForEach-Object { ($_.BaseName -split "__")[0] } | Sort-Object -Unique)
    foreach ($f in Get-ChildItem $inp -File) {
      foreach ($p in $ports) {
        $r = & curl.exe @C -m 60 -F "image=@$($f.FullName)" -F "overwrite=true" (Url $p "/upload/image")
        "upload $($f.Name) -> $p : $r"
      }
    }
  }
  foreach ($j in Get-ChildItem (Join-Path $Batch "jobs") -Filter *.json | Sort-Object Name) {
    $name = $j.BaseName
    if ($done.ContainsKey($name)) { continue }
    $port = ($name -split "__")[0]
    $r = & curl.exe @C -m 30 -H "Content-Type: application/json" --data-binary "@$($j.FullName)" (Url $port "/prompt")
    try { $pid2 = ($r | ConvertFrom-Json).prompt_id } catch { $pid2 = $null }
    if ($pid2) { "$name`t$port`t$pid2" | Add-Content $sub; "ok  $name $pid2" } else { "ERR $name $r" | Tee-Object -Append -FilePath (Join-Path $Batch "errors.log") }
  }
}
function Fetch {
  $sub = Join-Path $Batch "submitted.tsv"; $out = Join-Path $Batch "out"
  New-Item -ItemType Directory -Force $out | Out-Null
  $pending = 0; $lines = @()
  foreach ($l in Get-Content $sub) {
    $name, $port, $id = $l -split "`t"
    $h = & curl.exe @C -m 30 (Url $port "/history/$id")
    $st = "pending"
    try { $o = ($h | ConvertFrom-Json).$id } catch { $o = $null }
    if ($o) {
      $st = $o.status.status_str
      foreach ($node in $o.outputs.PSObject.Properties) {
        foreach ($kind in 'images', '3d', 'gifs') {
          foreach ($f in $node.Value.$kind) {
            $dst = Join-Path $out ("$name" + "__" + $f.filename)
            if (-not (Test-Path $dst)) {
              $q = "/view?filename=$([uri]::EscapeDataString($f.filename))&subfolder=$([uri]::EscapeDataString($f.subfolder))&type=$($f.type)"
              & curl.exe @C -m 300 -o $dst (Url $port $q)
            }
          }
        }
      }
      if ($st -eq "error") { ($o.status.messages | ConvertTo-Json -Depth 6 -Compress) | Add-Content (Join-Path $Batch "errors.log") }
    } else { $pending++ }
    $lines += "$name`t$st"
  }
  $lines | Set-Content (Join-Path $Batch "status.tsv")
  $q = & curl.exe @C -m 20 (Url 8322 "/queue")
  "pending=$pending queue8322=$($q.Length)" | Set-Content (Join-Path $Batch "progress.txt")
  if (Test-Path (Join-Path $Batch "out.zip")) { Remove-Item (Join-Path $Batch "out.zip") }
  if ((Get-ChildItem $out -File).Count -gt 0) { Compress-Archive -Path "$out\*" -DestinationPath (Join-Path $Batch "out.zip") -Force }
  return $pending
}
switch ($Cmd) {
  "submit" { Submit }
  "fetch" { $n = Fetch; "pending=$n" }
  "watch" { for ($i = 0; $i -lt 360; $i++) { $n = Fetch; if ($n -eq 0) { "all done"; break }; Start-Sleep 60 } }
}
