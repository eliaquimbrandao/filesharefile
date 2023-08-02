$ExecutionTime = Measure-Command {
  
# Initialize a hashtable to store the total file count and length
$fileinfor =@{count=0;length=0}

# Specify the Subscription ID, storage account name and the file share name
$subID = Read-Host "`n Enter your Subscription ID: "
$ResourceGroupName = Read-Host "`n Enter your Resource Group Name: "
$Storageaccountname = Read-Host "`n Enter the name of your Storage Account: "
$filesharename = Read-Host "`n Enter the name of your Azure File Share: "

# Connect to Az  Account
Connect-AzAccount

# Choose subscription
Select-AzSubscription -SubscriptionId "$subID"

# Create a new storage context using the storage account name and key
$context = New-AzStorageContext -StorageAccountName $Storageaccountname -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $Storageaccountname).Value[0])

# Initialize an array to store the file information
$script:fileList = @()

function file_info {
    # Retrieve the files and directories in the root directory
    $filesAndDirs = Get-AzStorageFile -ShareName $filesharename -Context $context

    foreach($f in $filesAndDirs) {
        # If it's a file, create a new object with its name and length, and add it to the array
        if($f.gettype().name -eq "AzureStorageFile"){
            $script:fileList += New-Object PSObject -Property @{
                FilePath = ""
                FileName = $f.name
                FileLength = $f.FileProperties.ContentLength
            }

            # Update the total file count and length
            $script:fileinfor["count"]++
            $script:fileinfor["length"]=$script:fileinfor["length"]+$f.FileProperties.ContentLength
        }
        # If it's a directory, call the function to process subdirectories
        elseif($f.gettype().name -eq "AzureStorageFileDirectory"){
            list_subdir $f
        }
    }

    # Output the total file count and length
    Write-Output "File total count: $($script:fileinfor["count"])"
    Write-Output "File total length: $($script:fileinfor["length"])"

    # Export the array of file information to a CSV file
    $script:fileList | Export-Csv -Path 'C:\temp\fileInfo.csv' -NoTypeInformation
}

function list_subdir {
    param(
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageFileDirectory]$dirs
    )
    # Retrieve the path of the subdirectory
    $path = $dirs.CloudFileDirectory.Uri.PathAndQuery.Remove(0,($dirs.CloudFileDirectory.Uri.PathAndQuery.IndexOf('/',1)+1))

    # Retrieve the files and directories in the subdirectory
    $filesAndDirs = Get-AzStorageFile -ShareName $dirs.ShareDirectoryClient.ShareName -Path $path -Context $context | Get-AzStorageFile

    foreach($f in $filesAndDirs) {
        # If it's a file, create a new object with its path, name, and length, and add it to the array
        if($f.gettype().name -eq "AzureStorageFile"){
            $script:fileList += New-Object PSObject -Property @{
                FilePath = $path
                FileName = $f.name
                FileLengthBytes = $f.FileProperties.ContentLength
            }

            # Update the total file count and length
            $script:fileinfor["count"]++
            $script:fileinfor["length"]=$script:fileinfor["length"]+$f.FileProperties.ContentLength
        }
        # If it's a directory, recursively call this function
        elseif($f.gettype().name -eq "AzureStorageFileDirectory"){
            list_subdir $f
        }
    }
}

# Call the main function to start processing the file share
file_info
}

Write-Output "Total execution time: $($ExecutionTime.TotalSeconds) seconds"