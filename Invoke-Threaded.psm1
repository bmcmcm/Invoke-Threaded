$Scripts = Get-ChildItem "$PWD\public-functions\*.ps1" | Select-Object -ExpandProperty FullName
$Scripts += Get-ChildItem "$PWD\private-functions\*.ps1" | Select-Object -ExpandProperty FullName
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