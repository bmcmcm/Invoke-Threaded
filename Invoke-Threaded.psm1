
$Scripts = Get-ChildItem "$($PWD.Path)\public-functions\*.ps1" | Select-Object -ExpandProperty FullName
$Scripts += Get-ChildItem "$($PWD.Path)\private-functions\*.ps1" | Select-Object -ExpandProperty FullName

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
