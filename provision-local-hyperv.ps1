# this has access to the following environment variables (this
# also shows example values):
#
#   PACKER_VERSION          1.6.0
#   PACKER_VM_NAME          packer-ubuntu-22.04-amd64-hyperv
#   PACKER_BUILD_NAME       ubuntu-22.04-amd64-hyperv
#   PACKER_BUILDER_TYPE     hyperv-iso
#   PACKER_HTTP_ADDR        10.0.0.123:1
#   PACKER_HTTP_IP          10.0.0.123
#   PACKER_HTTP_PORT        1

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

Import-Module Hyper-V

# NB Trim is needed because something is adding a
#    trailing space to the value.
$vmName = $env:PACKER_VM_NAME.Trim()

# update the vm notes.
$notes = (Get-VM $vmName).Notes
$notes += "---`n"
$notes += "packer_version: $env:PACKER_VERSION`n"
$notes += "git_url: $(git config --get remote.origin.url)`n"
$notes += "git_branch: $(git rev-parse --abbrev-ref HEAD)`n"
$notes += "git_revision: $(git rev-parse HEAD)`n"
Set-VM $vmName -Notes $notes
