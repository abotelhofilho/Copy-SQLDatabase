function Copy-SQLDatabase {
    Param
    (
        [Parameter(Mandatory = $True, Position = 0)]
        [string] $Source_Instance,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Source_Database,
        [Parameter(Mandatory = $True, Position = 2)]
        [string] $Destination_Instance,
        [Parameter(Mandatory = $true, Position = 3)]
        [string] $Destination_Database
    )

    ##Import SQL powershell module
    Import-Module SQLPS

    ## Extract Server names from Instance parameters
    $Source_Server = ($Source_Instance -split "\\")[0]
    $Destination_Server = ($Destination_Instance -split "\\")[0]
    $Source_Server_Instance = ($Source_Instance -split "\\")[1]
    $Destination_Server_Instance = ($Destination_Instance -split "\\")[1]
    
    ## Set naming convention for the new folders
    $Foldername = "\DB-Backup_" + $(Get-Date).tostring("MM-dd-yyyy")
    ## Set naming convention for the backup files
    $Filename = "$Source_Database" + "_" + $(Get-Date).tostring("MM-dd-yyyy_hh-mm-ss") + ".bak"
    $Destination_Server_Rollback_Filename = "$Destination_Database" + "_" + $(Get-Date).tostring("MM-dd-yyyy_hh-mm-ss") + ".bak"
    
    ## Set path for folders for both source and destination servers
    $Source_Server_Folder = "\\" + "$Source_Server" + "\c$" + "$Foldername"
    $Source_Server_File_Local = "c:" + "$Foldername" + "\" + "$Filename"
    $Source_Server_File_UNC = "\\" + "$Source_Server" + "\c$" + "$Foldername" + "\" + "$Filename"

    $Destination_Server_Folder = "\\" + "$Destination_Server" + "\c$" + "$Foldername"
    $Destination_Server_File_Local = "c:" + "$Foldername" + "\" + "$Filename"
    $Destination_Server_File_UNC = "\\" + "$Destination_Server" + "\c$" + "$Foldername" + "\" + "$Filename"
    $Destination_Server_Rollback_File_Local = "c:" + "$Foldername" + "\" + "$Destination_Server_Rollback_Filename"

    ## Create new directories
    New-Item -Path $Source_Server_Folder, $Destination_Server_Folder -Type Directory -ErrorAction SilentlyContinue  | Out-Null
    
    ## Get service account that is running the SQL server services
    $Source_Server_Service = "SQL Server (" + "$Source_Server_Instance" + ")"
    $Destination_Server_Service = "SQL Server (" + "$Destination_Server_Instance" + ")"
    $Source_Server_ServiceAccount = (Get-WmiObject Win32_Service -ComputerName $Source_Server | Where-Object { $_.displayName -eq "$Source_Server_Service"}).startname
    $Destination_Server_ServiceAccount = (Get-WmiObject Win32_Service -ComputerName $Destination_Server | Where-Object { $_.displayName -eq "$Destination_Server_Service"}).startname

    ## Grant the SQL server Service Accounts access to the new directories
    $acl = get-acl $Source_Server_Folder, $Destination_Server_Folder
    
    ## These are ran twice because you are building the desired ACLs prior to setting with the proceeding commands
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$Source_Server_ServiceAccount", "Modify", "Allow")
    $acl.SetAccessRule($AccessRule)
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$Destination_Server_ServiceAccount", "Modify", "Allow")
    $acl.SetAccessRule($AccessRule)
    ## Set ACLs to new folders on both servers
    $acl | Set-Acl $Source_Server_Folder, $Destination_Server_Folder
    

    ## Backup file needs to be set to a local path on source database server, I kept getting Access Denied error when using UNC path
    ## Backups Source Database
    Backup-SqlDatabase -ServerInstance "$Source_Instance" -Database "$Source_Database" -BackupFile "$Source_Server_File_Local"
    ## Backups up the Destination Database JUST IN CASE.  Still goes into the same folder, so it will get cleaned up the same way as the other files.
    Backup-SqlDatabase -ServerInstance "$Destination_Instance" -Database "$Destination_Database" -BackupFile "$Destination_Server_Rollback_File_Local"
    ## Copy backup file to Destination Server
    Copy-Item -Path $Source_Server_File_UNC -Destination $Destination_Server_File_UNC

    ## Kill All SQL Processes on Destination Server to be able to restore
    $Destination_Server_KillSQLProcesses = New-Object ("Microsoft.SqlServer.Management.Smo.Server") "$Destination_Server"
    $Destination_Server_KillSQLProcesses.KillAllProcesses("$Destination_Database")

    ## Restore Source database on Destination server
    Restore-SqlDatabase -ServerInstance "$Destination_Instance" -Database "$Destination_Database" -BackupFile "$Destination_Server_File_Local" -ReplaceDatabase

    
    ## Clean up older backups, keeps last two backups removes older ones
    $Source_Server_OlderFolders = Get-ChildItem -Path $("\\" + "$Source_Server" + "\c$\DB-Backup_*")
    $Destination_Server_OlderFolders = Get-ChildItem -Path $("\\" + "$Destination_Server" + "\c$\DB-Backup_*")
    
    if ($Source_Server_OlderFolders.count -gt '2') { 
        
        Remove-Item -Path $($Source_Server_OlderFolders | Sort-Object LastWriteTime | Select-Object -First $($Source_Server_OlderFolders.Count - 2)) -Recurse
        
    }

    if ($Destination_Server_OlderFolders.count -gt '2') { 
        
        Remove-Item -Path $($Destination_Server_OlderFolders | Sort-Object LastWriteTime | Select-Object -First $($Destination_Server_OlderFolders.Count - 2)) -Recurse
        
    }

}
