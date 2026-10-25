#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# Keep Windows Firewall enabled and limit access to the local subnet.
$ruleName = 'SeseWedding-LocalNetwork'

if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) {
  Set-NetFirewallRule -Name $ruleName -Direction Inbound -Action Allow -Profile Any -Enabled True
  Get-NetFirewallRule -Name $ruleName | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol TCP -LocalPort 5173,4173 | Out-Null
  Get-NetFirewallRule -Name $ruleName | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress LocalSubnet | Out-Null
} else {
  New-NetFirewallRule -Name $ruleName -DisplayName 'Sese Wedding - Local network' -Description 'Allow Vite dev and preview from the local subnet only.' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5173,4173 -RemoteAddress LocalSubnet -Profile Any -Enabled True | Out-Null
}
