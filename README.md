<a name="readme-top"></a>
<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#context">Context</a></li>
    <li><a href="#usage">Usage</a>
        <ul><a href="#prerequisites">Prerequisites</a></ul>
    </li>
    <li><a href="#roadmap">Road Map</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#references">References</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- CONTEXT -->
## Context

We (ZOAK Solutions) have numerous clients and our own systems that require:

- Access with certain roles/groups/users to certain services only from appropriately hardened and monitored hosts
  - If Entra is used for authentication to these services, then this SAW can be a requirement in conditional access policies
- Inbound and outbound network security including the ability to ‘AllowList’ and ‘BlockList’ based on IPs/URLs/Hostnames/other ‘NGFW‘ methods… although this can be achieved with host-based only controls… does not seems like a very layered defence.
- Idempotent deployment solution (deployment code can be run regularly and if no changes to code, no changes to deployment)
  - PowerShell is not ideal for doing idempotency proper… but it can.
- See some blog post made during initial implementation:
  - <https://mwclearning.com/?tag=azurevirtualsaw>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Implmentation tools/dependencies

- [PowerShell](https://learn.microsoft.com/en-us/powershell/)
  - [Azure PowerShell Az module](https://learn.microsoft.com/en-us/powershell/azure): Azure PowerShell is a collection of modules for managing Azure resources from PowerShell
- [Azure](https://azure.microsoft.com/en-au/)
- [CloudShell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview)
  - Tested in CloudShell, but can be run in any PowerShell environment
- Whilst idempotency is a requirement, the scripts are not properly idempotent, they check for existing resources in the resource group and will not create if they exist (by name), do not check for changes to the code/config, so if you change the code, you will need to run with the `-Destroy` parameter to overwrite existing resources.
  - NOTE: This does not apply for outbound FW rules which are recreated on every run, regardless of changes to the code.
  - *WARNING:* The script does not hold state, if you change the `$SAWResourceGroupName` ensure you first complete a `DeploySAW.ps1 -Destroy -NoDeploy`

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Usage

### Prerequisites

- PowerShell/CloudShell environment configured and authenticated with appropriate permissions to create resources in Azure
  - See: <https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-virtual-desktop?tabs=powershell#prerequisites>
- <https://learn.microsoft.com/en-us/azure/firewall/deploy-ps#prerequisites>

#### Example PowerShell environment set up

```powershell
# Allow PowerShell to run scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
# Install Azure PowerShell Az module
Install-Module -Name Az -Repository PSGallery -Force
Update-Module -Name Az -Force
# Authenticate to Azure
Connect-AzAccount
```

### Deploy an Azure SAW env

1. Clone this repo
    - `git clone git@github.com:zoak-solutions/AzureVirtualSAW.git`
2. Review and update the `SAWDeployerConfigItems.ps1` file with your desired configuration

3. Run the `DeploySAW.ps1` script
    - Optional Parameters:
        - `-Destroy`: Destroy all resources in and the resource group itself before recreating (If you make changes to config and want them applied, excepting outbound FW rules which are recreated on every run).

#### Example

```powershell
Install-Module -Name Az -Repository PSGallery -Force
Update-Module -Name Az -Force
Connect-AzAccount
git clone git@github.com:zoak-solutions/AzureVirtualSAW.git
cd AzureVirtualSAW
vim SAWDeployerConfigItems.ps1
.\DeploySAW.ps1 -Destroy
```

<!-- ROADMAP -->
## Roadmap

- M365 Defender monitoring, logging, alerting
  - Email / JIRA / Teams / Slack / other notifications
- Alerting on changes to config / drift
- Solution for pre-hardended VM Template

See the [open issues](https://github.com/zoak-solutions/AzureVirtualSAW/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- REFERENCES -->
## References

<ul>
    <li><a href="https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-virtual-desktop?tabs=powershell">Deploy Azure Virtual Desktop – Azure Virtual Desktop | Microsoft Learn</a>
    <ul>
        <li><a href="https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/fundamental-concepts">Azure fundamental concepts – Cloud Adoption Framework | Microsoft Learn</a></li>
        <li><a href="https://learn.microsoft.com/en-us/azure/virtual-desktop/security-guide">Azure Virtual Desktop security best practices – Azure | Microsoft Learn</a></li>
        <li><a href="https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-deployment">Deploying a privileged access solution | Microsoft Learn</a></li>
        <li><a href="https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-intermediaries">Securing privileged access intermediaries | Microsoft Learn</a></li>
        <li><a href="https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-deployment">Deploying a privileged access solution | Microsoft Learn</a></li>
    </ul>
</li>
<li><a href="https://learn.microsoft.com/en-us/azure/firewall/protect-azure-virtual-desktop?tabs=azure">Use Azure Firewall to protect Azure Virtual Desktop | Microsoft Learn</a>
    <ul>
        <li><a href="https://learn.microsoft.com/en-us/azure/firewall/deploy-ps">Deploy and configure Azure Firewall using Azure PowerShell | Microsoft Learn</a></li>
        <li><a href="https://learn.microsoft.com/en-us/azure/virtual-desktop/network-connectivity">Understanding Azure Virtual Desktop network connectivity – Azure | Microsoft Learn</a></li>
    </ul>
</li>
<li><a href="https://learn.microsoft.com/en-us/azure/cloud-shell/features">Azure Cloud Shell features | Microsoft Learn</a></li>
</ul>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the GNU AGPLv3 License. See [LICENSE.txt](LICENSE.txt) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

ZOAK Solutions - [@contact@zoak.solutions](mailto:contact@zoak.solutions)
