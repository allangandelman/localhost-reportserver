Param
    (
    [parameter(Mandatory=$false)] [ValidatePattern("https?://.*")] [String]  $RSURL,
    [parameter(Mandatory=$false)] [ValidateSet("All", "Delta", "List")] [String]  $Mode,
    [parameter(Mandatory=$false)] [ValidatePattern("/.*")] [String[]]  $ItemList,
    [parameter(Mandatory=$false)] [String]  $RepositoryPath,
    [parameter(Mandatory=$false)] [String]  $GitHubRepository,
    [parameter(Mandatory=$false)] [String]  $GitHubToken
    ) 

#####
if($RSURL -like "") { $RSURL = "http://localhost/reportserver" }
if($RepositoryPath -like "") {$RepositoryPath = "C:\Users\administrator.ALGANDLAB\Desktop\Backup\localhost-reportserver"}
if($mode -like "") {$mode = "Delta"}
if($mode -eq "List") {Write-Host "Please make sure that the item path is like '/<Folder>/<Report Name>'"}
if($GitHubRepository -like "") {$GitHubRepository = "https://github.com/allangandelman/localhost-reportserver.git"}
if($GitHubToken -like "") {$GitHubToken = "b669e81c90708b2f41df37fc32bd889d881bac33"}

#$mode = "List"; $ItemList = "/MP dataset","/Alert"################

##################### Script Start #####################################

Add-Type -AssemblyName System.Runtime.Extensions

if(-not (Test-Path $RepositoryPath))
{
    New-Item -Path $RepositoryPath -ItemType Directory
    cd $RepositoryPath
}

if (-not (test-path "$RepositoryPath\.git"))
{
    ."C:\Program Files\Git\cmd\git.exe" init
}

if($mode -eq "Delta")
{
    if(Test-Path "$RepositoryPath\LastRun.txt")
    {
        $LastRun = Get-Date (Get-Content "$RepositoryPath\LastRun.txt")
    }
}

############################################

$SSRS = New-WebServiceProxy -Uri "$RSURL/ReportService2010.asmx?wsdl" -UseDefaultCredential

$items = $SSRS.ListChildren("/",$true)

for ($i=0;$i -lt $items.count;$i++)
{
    Write-Progress -Activity "Processing $($item.path)" -Status "$i/$($items.count)" -PercentComplete ($i/$items.count)
    $item = $items[$i]
    
    #If running in list mode, make sure the item is on the list
    if($mode -eq "List" -and $item.Path -notin $ItemList)
    {
        continue
    }


    if($mode -eq "Delta" -and $item.ModifiedDate -lt $LastRun)
    {
        # item hasn't been modified, so we skip
        continue
    }

    $itempath = $RepositoryPath + ($item.Path -replace "/","\")
    switch ($item.TypeName)
    {
        'Folder' 
        {
            if(-not (Test-Path $itempath))
            {
                New-Item -Path $itempath -ItemType Directory
            }
        }
        'Report' {$itempath += ".rdl"}
        'DataSet' {$itempath += ".rsd"}
        'DataSource' {$itempath += ".ds"} # Saving for documentation purposes. If there's credentials saved, won't restore completely
        'Resource' {}
        Default
        {
            Write-Host "File $itempath of type not backed up: $_"
            continue
        }
    }

    if($item.TypeName -eq "Folder")
    {
        # Folder ok, skip to the next item
        continue
    }

    if(Test-Path ($itempath))
    {
        Remove-Item $itempath -Force
    }
    $itemDefinition = $SSRS.GetItemDefinition($item.Path)
    $fs = New-Object System.IO.FileStream $itempath,([System.IO.FileMode]::OpenOrCreate)
    $fs.Write($itemDefinition,0,$itemDefinition.Length)
    $fs.flush()
    $fs.close()
}

if($mode -ne "List")
{
    Get-Date -Format "yyyy-MM-dd hh:mm:ss" | Out-File -FilePath "$RepositoryPath\LastRun.txt"
}

######################################################

[array]$s =  ."C:\Program Files\Git\cmd\git.exe" remote
if(($s|?{$_ -like "Powershell"}) -ne $null)
{
    ."C:\Program Files\Git\cmd\git.exe" remote remove Powershell
}

$repoUrl = 
."C:\Program Files\Git\cmd\git.exe" remote add -m master Powershell 