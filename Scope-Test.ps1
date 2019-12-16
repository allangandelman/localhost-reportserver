$test = "Ambito Script"
function MyFunction ()
{
    $test = "Ambito Local"
    Get-Variable -Name test -Scope 0
    Get-Variable -Name test -Scope 1
    Get-Variable -Name test -Scope 2
}
MyFunction