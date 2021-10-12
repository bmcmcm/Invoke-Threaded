
$Scripts = Get-ChildItem "$($PSScriptRoot)\public-functions" | Select-Object -ExpandProperty FullName
$Scripts += Get-ChildItem "$($PSScriptRoot)\private-functions" | Select-Object -ExpandProperty FullName

foreach ($script in $Scripts)
{
    try 
    {
        Write-Verbose $script
        . $($script)
    }
    catch 
    {
        Write-Verbose ("{0}: {1}" -f $script,$_.Exception.Message) 
    }
}
