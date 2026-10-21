param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Plan", "Apply")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$PlanFile,

    [int]$NodeCount
)

$ErrorActionPreference = "Stop"

try {
    . ./scripts/ensure-secrets.ps1
    $ErrorActionPreference = "Continue"

    if ($Mode -eq "Plan") {
        if (-not $PSBoundParameters.ContainsKey("NodeCount")) {
            throw "NodeCount is required when creating a toggle plan."
        }

        terraform plan "-out=$PlanFile" -detailed-exitcode
        $planExitCode = $LASTEXITCODE
        if ($planExitCode -ne 2) {
            if ($planExitCode -eq 0) {
                throw "Terraform reported no changes for the requested node_count update."
            }
            throw "terraform plan failed with exit code $planExitCode."
        }

        $planOutput = & terraform show -json $PlanFile 2>&1
        $showExitCode = $LASTEXITCODE
        if ($showExitCode -ne 0) {
            throw "terraform show -json failed with exit code $showExitCode."
        }

        $plan = ($planOutput -join [Environment]::NewLine) | ConvertFrom-Json
        $managedChanges = @(
            $plan.resource_changes | Where-Object {
                $_.mode -eq "managed" -and ($_.change.actions -join ",") -ne "no-op"
            }
        )

        if ($managedChanges.Count -ne 1) {
            throw "Expected only the GKE node pool to change; Terraform planned $($managedChanges.Count) managed resource changes."
        }

        $change = $managedChanges[0]
        if ($change.address -ne "google_container_node_pool.primary_nodes") {
            throw "Unexpected resource in toggle plan: $($change.address)."
        }

        if (($change.change.actions -join ",") -ne "update") {
            throw "The node pool toggle must be an in-place update; Terraform planned '$($change.change.actions -join ',')'."
        }

        if ($null -eq $change.change.before.node_count -or [int]$change.change.before.node_count -eq $NodeCount) {
            throw "The plan does not show a node_count change to $NodeCount."
        }

        if ($null -eq $change.change.after.node_count -or [int]$change.change.after.node_count -ne $NodeCount) {
            throw "The plan does not set node_count to the requested value $NodeCount."
        }

        $allProperties = @(
            $change.change.before.PSObject.Properties.Name
            $change.change.after.PSObject.Properties.Name
        )
        $otherProperties = @($allProperties | Sort-Object -Unique | Where-Object { $_ -ne "node_count" })

        foreach ($propertyName in $otherProperties) {
            $beforeProperty = $change.change.before.PSObject.Properties[$propertyName]
            $afterProperty = $change.change.after.PSObject.Properties[$propertyName]
            $beforeJson = if ($null -eq $beforeProperty) { "<missing>" } else { ConvertTo-Json -InputObject $beforeProperty.Value -Depth 100 -Compress }
            $afterJson = if ($null -eq $afterProperty) { "<missing>" } else { ConvertTo-Json -InputObject $afterProperty.Value -Depth 100 -Compress }

            if ($beforeJson -cne $afterJson) {
                throw "The plan also changes node pool attribute '$propertyName'."
            }
        }

        Write-Host "Plano validado: somente node_count muda para $NodeCount."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $PlanFile -PathType Leaf)) {
        throw "Saved Terraform plan not found: $PlanFile"
    }

    terraform apply $PlanFile
    $applyExitCode = $LASTEXITCODE
    if ($applyExitCode -ne 0) {
        throw "terraform apply failed with exit code $applyExitCode."
    }
}
catch {
    [Console]::Error.WriteLine($_)
    exit 1
}
