$pub = (Join-Path $PSScriptRoot -ChildPath "public-functions")
$priv = = (Join-Path $PSScriptRoot -ChildPath "private-functions")

[string[]]$Scripts = Get-ChildItem -File -Recurse -LiteralPath $pub -Filter *.ps1 | Select-Object -ExpandProperty FullName
$Scripts += Get-ChildItem -File -Recurse -LiteralPath $priv -Filter *.ps1 | Select-Object -ExpandProperty FullName

foreach ($script in $Scripts)
{
    try 
    {
        Write-Host $script
        . $script
    }
    catch 
    {
        Write-Host ("{0}: {1}" -f $script,$_.Exception.Message) 
    }
}
