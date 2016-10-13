param
(
    $keyfile
)

$Environment = "AzureChinaCloud"
$subscriptionId = "cc1624c7-3f1d-4ed3-a855-668a86e96ad8"
$location = 'chinaeast'
$ResourceGroupName = 'sshconnect'
$keyVaultName = 'sshconnectkv'
$keySecretName = [Environment]::UserName
$defaultkeyfile = 'C:\Users\andliu\OneDrive - Microsoft\SSHCert\certinuse\privatekey'
$tempKeyPath = ".\privatekey"

$existingSubscriptions = Get-AzureSubscription

$existingSubscription = $null
if ($existingSubscriptions -ne  $null){
    foreach ( $item in $existingSubscriptions)
    {
        if($item.SubscriptionId -eq $subscriptionId){
            $existingSubscription=$item
        }
    }
}

if($existingSubscription -eq $null)
{
    Add-AzureAccount -Environment $Environment
}

Write-Host "try to select subscription $subscriptionId"
Select-AzureSubscription -SubscriptionId $subscriptionId

Try
{
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
}
Catch [System.Exception]
{
    Write-Host "Couldn't select subscription: $subscriptionId";
    $EnvironmentToUse = Get-AzureRmEnvironment -Name $Environment
    Add-AzureRmAccount -Environment $EnvironmentToUse
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
}

#region Resource Group 
Function MakeSureResourceGroupExists
{
    param
    (
        $ResourceGroupName,
        $Location
    )

    $resourceGroup = $null
    $existedResourceGroups = Get-AzureRmResourceGroup
    foreach ($item in $existedResourceGroups)
    {
        if($item.ResourceGroupName -eq $ResourceGroupName){
            $resourceGroup = $item
        }
    }

    if($resourceGroup -eq $null)
    {
        Write-Output "resource group '$ResourceGroupName' in $Location not exist, create it..."
        New-AzureRmResourceGroup -ResourceGroupName  $ResourceGroupName -Location $Location
    }
    $resourceGroup = $null
}
#endregion

#region KeyVault
Function MakeSureRmKeyVaultExists
{
    param
    (
        $resourceGroupName,
        $keyVaultName,
        $location
    )
    Try
    {
        $keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue;
    }
    Catch [System.ArgumentException]
    {
        Write-Host "Couldn't find Key Vault: $keyVaultName";
        $keyVault = $null;
    }

    #Create a new vault if vault doesn't exist
    if (-not $keyVault)
    {
        Write-Host "Creating new key vault:  ($keyVaultName)";
        $keyVault = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Sku Standard -Location $location;
        Write-Host "Created a new KeyVault named $keyVaultName to store encryption keys";
    }
}

Function MakeSureAzureKeyVaultKeyExists
{
    param
    (
        $resourceGroupName,
        $keyVaultName,
        $keyVaultKeyName
    )
    $keyVaultKey = Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyVaultEncryptionKeyName -ErrorAction SilentlyContinue

    if($keyVaultKey -eq $null)
    {
        $KeyOperations = 'encrypt', 'decrypt', 'verify'
        Add-AzureKeyVaultKey -VaultName $keyVaultName -Name $keyVaultEncryptionKeyName -Destination Software -KeyOps $KeyOperations
    }
}
#endregion

if( $keyfile -eq $null)
{
    $keyfile = $defaultkeyfile
}
MakeSureResourceGroupExists  -ResourceGroupName $ResourceGroupName -Location $location      
MakeSureRmKeyVaultExists -resourceGroupName $ResourceGroupName -keyVaultName $keyVaultName -location $location
$keyContent = Get-Content -Encoding Ascii -Path $keyfile -Raw
Write-Host $keyContent
$secretvalue = ConvertTo-SecureString $keyContent -AsPlainText -Force
$secret = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name $keySecretName -SecretValue $secretvalue
$secretSaved = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $keySecretName
Write-Host $secretSaved.SecretValueText