# aops-content-export
Automate the content export of Aria for Operations


Powershell script to export the content of Aria for Operations as there's no in-built way to 'backup' the configuration on a schedule...(whhhyyy??!) - Script requires a few command line arguments to acheive this task, arguments are below :

1. AriaOpsURL - URL for API calls
2. AuthSource - Auth Source for API login (vIDMAuthSource / 'AD' Domain etc)
3. Username - Whoareyou?
4. Password - Whyareyou?
5. ExportPassword - Password for the .zip file (saved as a .bak - edit code  as required) - note, not sure if there's a bug but the file didnt have a password when completed via the API - the UI one seems to work? (thanks?)
6. DownloadPath - Where to download the .bak file into
7. RetentionDays - how many days worth of .bak files to keep - the older files will be deleted by the script.
8. LogFile - Log the things...
