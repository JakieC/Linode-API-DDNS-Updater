# Linode API DDNS Updater
## _Update Domain IP via Linode API by PowerShell_

A PowerShell script to allow you run DDNS update on Windows via Linode API.

## Features

- A wizard help to get domainId, recordId and generate config.json file
- Compare whether the IP needs to be updated 
- Log supported
- Use Task Scheduler to implement auto update DDNS to Linode Domain Manager

## How to use

Before to use this script plese make sure Domain is added to lindoe.
> Linode DNS Manager 
> https://www.linode.com/docs/guides/dns-manager/

Than get an API access toker and **make sure you API access on domain is Read/Write**.
> Guides - Get An API Access Token
> https://www.linode.com/docs/products/tools/linode-api/guides/get-access-token/

Run **Linode-API-DDNS-Updater.ps1** and follow the steps on PowerShell.

After it done, add the **Linode-API-DDNS-Updater.ps1** to Task Scheduler and add a triggers by daily or any you like.

**Enjoy🤗**