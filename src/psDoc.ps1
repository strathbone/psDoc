param(
    [parameter(Mandatory=$true, Position=0)] [string] $moduleName,
    [parameter(Mandatory=$false, Position=1)] [string] $template = "./out-html-template.ps1",
    [parameter(Mandatory=$false, Position=2)] [string] $outputDir = './help',
    [parameter(Mandatory=$false, Position=3)] [string] $fileName = 'index.html'
)

function Get-ModuleCount($modName){
	return (Get-Module -ListAvailable -Name $modName).Count
}

function FixString ($in = '', [bool]$includeBreaks = $false){
    if ($in -eq $null) { return }

    $rtn = $in.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Trim()

    if($includeBreaks){
        $rtn = $rtn.Replace([Environment]::NewLine, '<br>')
    }
    return $rtn
}

function Update-Progress($name, $action){
    Write-Progress -Activity "Rendering $action for $name" -CurrentOperation "Completed $progress of $totalCommands." -PercentComplete $(($progress/$totalCommands)*100)
}
$i = 0
$commandsHelp = (Get-Command -module $moduleName) | get-help -full | Where-Object {! $_.name.EndsWith('.ps1')}

if(Get-ModuleCount $moduleName -eq 1) {

	Import-Module $moduleName -DisableNameChecking

	foreach ($h in $commandsHelp){
		$cmdHelp = (Get-Command $h.Name)

		# Get any aliases associated with the method
		$alias = get-alias -definition $h.Name -ErrorAction SilentlyContinue
		if($alias){
			$h | Add-Member Alias $alias
		}

		# Parse the related links and assign them to a links hashtable.
		if(($h.relatedLinks | Out-String).Trim().Length -gt 0) {
			$links = $h.relatedLinks.navigationLink | % {
				if($_.uri){ @{name = $_.uri; link = $_.uri; target='_blank'} }
				if($_.linkText){ @{name = $_.linkText; link = "#$($_.linkText)"; cssClass = 'psLink'; target='_top'} }
			}
			$h | Add-Member Links $links
		}

		# Add parameter aliases to the object.
		foreach($p in $h.parameters.parameter ){
			$paramAliases = ($cmdHelp.parameters.values | where name -like $p.name | select aliases).Aliases
			if($paramAliases){
				$p | Add-Member Aliases "$($paramAliases -join ', ')" -Force
			}
		}
	}

	# Create the output directory if it does not exist
	if (-Not (Test-Path $outputDir)) {
		New-Item -Path $outputDir -ItemType Directory | Out-Null
	}

	$totalCommands = $commandsHelp.Count
	$template = Get-Content $template -raw -force
	Invoke-Expression $template > "$outputDir\$fileName"
}
elseif(Get-ModuleCount $moduleName -eq 0) {
	throw "The given module '$moduleName' was not found on this system... now exiting psDoc."
}
else {
	throw "The given module '$moduleName' was found more than once on this system, or some other error occured... now exiting psDoc."
}