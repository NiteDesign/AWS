Initialize-awsdefaults

Import-Module AWSPowerShell

#Create arrays
$instanceStart = @()
$instanceStop = @()

$fromEmail = "youremail@domain.com"
$Recipients  = "toemail@domain.com"
$emailserver = "emailserver"

#create filter to limit search on instances only
$filter = New-Object amazon.EC2.Model.Filter
$filter.Name = "resource-type"
$filter.Value = "instance"

#create filter based on tag=RunningSchedule
$filterType = New-Object amazon.EC2.Model.Filter
$filterType.Name = "tag:RunningSchedule"
$filterType.Value = "*"

#join the two filters together
$filter = @($filter,$filterType)

#retrieve the instances based on the filter parameters
$instances = Get-EC2Tag -Filter $filter

#set now date and day of week
$now = Get-Date
$dow = Get-Date -UFormat %u

#cycle through each instance found
foreach($instance in $instances){
    #reset variable to false for each instance through loop
    $startstopInstance = $false

    #Get current instance state,  either Running or Stopped
    $state = Get-EC2InstanceStatus -InstanceIds $instance.ResourceId
    $state = $state.InstanceState.Name

   #get schedule value
    $schedule = $instance.Value
    $schedule = $schedule.ToLower()
    if ($schedule -eq "disabled"){
    #if disabled then do nothing!
    Write-Host "Disabled schedule"
    }else{


    #Get Schedule from instance Tag Value, parse the values
    $schedule = $instance.Value -split ':'
    $start = [INT]$schedule[0]
    $stop = [INT]$schedule[1]
    $days = $schedule[2]

    #check if multiple days are set to run machine
    if ($days.Length -gt 1){
        $days = $days -split '-'
            #check if current day is between scheduled days, if so set variable to True
            if($dow -ge $days[0] -and $dow -le $days[1]){
            $startstopInstance = $true
            }
    }else{
        #check if current day is equal to scheduled day, if so set variable to True
        if($dow -eq $days){
        $startstopInstance = $true
        }
    }

    if ($startstopInstance -eq $true){
       #check start/stop times, if Start is less than Stop, machine running normal hours, ie; 3am-10pm
      if ($start -lt $stop){
            if ($now.Hour -ge $start -and $now.Hour -le $stop -and $state -ne "running"){
                Start-EC2Instance -InstanceIds $instance.ResourceId
                $instanceStart += $instance.ResourceId
            }elseif(($now.Hour -le $start -or $now.Hour -ge $stop) -and $state -eq "running"){
                Stop-EC2Instance -Instance $instance.ResourceId
                $instanceStop += $instance.ResourceId
            }

        #If Start is greater than Stop, therefore machine is running middle of night,ie: 10pm-3am
        }else{
            if ($now.Hour -in $stop..$start -and $state -eq "running"){
                Stop-EC2Instance -Instance $instance.ResourceId
                $instanceStop += $instance.ResourceId
            }elseif($now.Hour -notin $stop..$start -and $state -ne "running"){
                Start-EC2Instance -InstanceIds $instance.ResourceId
                $instanceStart += $instance.ResourceId
            }
        }
    }
    }
}

#Email list of instances Started and Stopped
#this will list the instances by instance ID that were started or stopped on this run
if ($instanceStart.Count -gt 0 -or $instanceStop.Count -gt 0){

$body = "
The following servers at Amazon have been affected by the automated schedule:
"
if ($instanceStart.Count -gt 0){
$body = $body + "
Servers Started"
 foreach($instance in $instanceStart){
      $filterNameTag = New-Object amazon.EC2.Model.Filter
    $filterNameTag.Name = "tag:Name"
    $filterNameTag.Value = "*"

    $filterNameID = New-Object amazon.EC2.Model.Filter
    $filterNameID.Name = "resource-id"
    $filterNameID.Value = $instance


    $filterNameType = New-Object amazon.EC2.Model.Filter
    $filterNameType.Name = "resource-type"
    $filterNameType.Value = "instance"

    $filterName = @($filterNameTag,$filterNameID,$filterNameType)

    $name = Get-EC2Tag -Filters $filterName

 $body = $body +
"
    " + $name.Value + "(" + $instance +")"
}
}

if ($instanceStop.Count -gt 0){
$body = $body + "

Servers Stopped"
foreach($instance in $instanceStop){
     $filterNameTag = New-Object amazon.EC2.Model.Filter
    $filterNameTag.Name = "tag:Name"
    $filterNameTag.Value = "*"

    $filterNameID = New-Object amazon.EC2.Model.Filter
    $filterNameID.Name = "resource-id"
    $filterNameID.Value = $instance

    $filterNameType = New-Object amazon.EC2.Model.Filter
    $filterNameType.Name = "resource-type"
    $filterNameType.Value = "instance"

    $filterName = @($filterNameTag,$filterNameID,$filterNameType)

    $name = Get-EC2Tag -Filters $filterName

 $body = $body +
"
    " + $name.Value + "(" + $instance +")"

}
}


$subject = "AWS - server start/stop"

send-mailmessage -from $fromEmail -to $Recipients -Subject $subject -body $body  -smtpserver $mailserver

}
