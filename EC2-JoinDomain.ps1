################################################################
#
#Script to join EC2 instance to Windows Active Directory Domain
#Modify this script and then create an EXE using ps2exe
# https://gallery.technet.microsoft.com/PS2EXE-Convert-PowerShell-9e4e07f1
# Finally call the Exe using the EC2 UserData
#
# <powershell>
#  Set-ExecutionPolicy unrestricted -Force
#  New-Item c:/temp -ItemType Directory -Force
#  set-location c:/temp
#  read-s3object -bucketname examplebucket -key JoinDomain.exe -file JoinDomain.exe
#  Invoke-Item C:/temp/JoinDomain.exe
# </powershell>
#
################################################################

#Retrieve the AWS instance ID, keep trying until the metadata is available
$instanceID = "null"
while ($instanceID -NotLike "i-*") {
 Start-Sleep -s 3
 $instanceID = invoke-restmethod -uri http://169.254.169.254/latest/meta-data/instance-id
}

#Set Username and password using account with permissions to join to domain
$username = "domain\username"
$password = "password12345" | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -typename System.Management.Automation.PSCredential($username, $password)

#Join instance to the domain and restart
Try {
Rename-Computer -NewName $instanceID -Force
Start-Sleep -s 5
Add-Computer -DomainName domain.local -OUPath "OU=YourOU,DC=domain,DC=local" -Options JoinWithNewName,AccountCreate -Credential $cred -Force -Restart -erroraction 'stop'
}
Catch{
echo $_.Exception | Out-File c:\temp\error-joindomain.txt -Append
}
