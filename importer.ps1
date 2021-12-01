
Function ImportVariables {
    Param (
        [Parameter(Mandatory)]
        $ProjectOrigin,

        [Parameter(Mandatory)]
        $ProjectDestination,

        [Parameter(Mandatory)]
        $VariableGroupName,

        [Parameter(Mandatory)]
        $Organization
    ) 

    az devops configure --defaults project=$ProjectOrigin organization=$Organization

    # get the list of all variables for the origin project 
    $content = az pipelines variable-group list | ConvertFrom-Json

    foreach ($item in $content) {
        Write-Host "INFO: Processing Item - $($item.id) name $($item.name)"

        if ($item.name -eq $VariableGroupName) {
            Write-Host "INFO: Found Variable groupe - $($item.id) name $($item.name)"
            
            # get the list of all variables for the origin project 
            $variables = az pipelines variable-group show --group-id $item.id | ConvertFrom-Json

            Write-Host "INFO: Connecting on the project name: $($ProjectDestination)"
            az devops configure --defaults project=$ProjectDestination organization=$Organization

            $groupsInDestination = az pipelines variable-group list | ConvertFrom-Json

            $idGroupDest = $null

            #check if the group exists on the destination
            foreach ($itemDest in $groupsInDestination) {
        
                if ($itemDest.name -eq $VariableGroupName) {
                    Write-Host "INFO: The group already exists on the destination - $($item.id) name $($item.name)"
                    $idGroupDest = $itemDest.id
                    break
                }
            }
            
            if ($null -eq $idGroupDest) {
                Write-Host "INFO: Creating variable group on the destination $($item.name)"
                $temp = az pipelines variable-group create --name $VariableGroupName --variables projectOrigin=$ProjectOrigin  | ConvertFrom-Json
                $idGroupDest = $temp.id
            }

            foreach ($var in $variables.variables.PSobject.Properties) {
               
                Write-Host "INFO: working on the variable $($var.Name)"
               
                if ($var.Value.isSecret -eq $false -or $null -eq $var.Value.isSecret) {

                    #Check to see if is needed to update or create a variable
                    $existsVar = az pipelines variable-group variable list --group-id $idGroupDest | ConvertFrom-Json
                    $createVar = $true
                    foreach ($exists in $existsVar) {
                        if ($exists.PSobject.Properties.Name -eq $var.Name) {
                            $createVar = $false
                            break
                        }
                    }
                                        
                    if ($true -eq $createVar) {
                        Write-Host "INFO: Creating variable on the destination $($var.Name)"
                        az pipelines variable-group variable create --group-id $idGroupDest --name `"$($var.Name)`" --value `"$($var.Value.value)`"
                    }
                    else {
                        Write-Host "INFO: Updating variable on the destination $($var.Name)"
                        az pipelines variable-group variable update --group-id $idGroupDest --name `"$($var.Name)`" --value `"$($var.Value.value)`"
                    }                    
                    
                }
                else {
                    Write-Host "INFO: Can't create variable on the destination $($var.Name) because it's a Secret Variable"
                }
            }
            break
        }
    }
}

ImportVariables -ProjectOrigin "demo" -ProjectDestination "Demo03" -VariableGroupName "ExternalVars-Prod" -Organization "https://dev.azure.com/myorg"