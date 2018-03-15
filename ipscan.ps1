$Threads = 50

$PingFunc = {
    param($ip, $count)
    ping -n $count $ip
}

$jobs = New-Object System.Collections.ArrayList

$pool = [runspacefactory]::CreateRunspacePool(1, $Threads)
$pool.Open()

foreach ($i in 2..254)
{
    $ip = "192.168.1.$i"
    $ps = [powershell]::Create()
    $ps.RunspacePool=$pool
    [void]$ps.AddScript($PingFunc)
    [void]$ps.AddArgument($ip)
    [void]$ps.AddArgument(1)
    $handle = $ps.BeginInvoke()
    $temp = '' | Select-Object PowerShell,Handle,IP
    $temp.PowerShell = $ps
    $temp.Handle = $handle
    $temp.IP = $ip
    [void]$jobs.Add($temp)
} 

$Jobs_Total = $jobs.Count
$onlineHostCouont = 0
Do {
    $Jobs_ToProcess = $jobs | Where-Object {$_.Handle.IsCompleted}

    if($Jobs_ToProcess -eq $null)
    {
        # Write-Host "No jobs completed, wait 500ms..."
        # Start-Sleep -Milliseconds 500
        continue
    }
    
    $Jobs_Remaining = ($jobs | Where-Object {$_.Handle.IsCompleted -eq $false}).Count

    try {            
        $Progress_Percent = 100 - (($Jobs_Remaining / $Jobs_Total) * 100) 
    }
    catch {
        $Progress_Percent = 100
    }

    # Processing completed jobs
    foreach($Job in $Jobs_ToProcess)
    {         
        $Job_Result = $Job.PowerShell.EndInvoke($Job.Handle)
        $resultStr = [string]::Join('', $Job_Result)
        if($Job_Result -ne $null -and $resultStr.Contains("ms") -and $resultStr.Contains("="))
        {       
            Write-Host $Job.IP,True
            $onlineHostCouont++
        }
        $Job.PowerShell.Dispose()
        $Jobs.Remove($Job)
    } 

} While ($jobs.Count -gt 0)

Write-Host "Total host online: $onlineHostCouont"

Write-Host "Closing RunspacePool and free resources..."

# Close the RunspacePool and free resources
$pool.Close()
$pool.Dispose()
