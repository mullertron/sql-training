# sql-training


### SQL Set up

Copy the sql-training.bicep file to your laptop

Open up an Azure CLI session, navigate to the folder where the sql-training.bicep file is

Run the following commands

~~~~~
az login
~~~~~
Enter the credentials to your subscription

~~~~~
az group create --name [RGName] --location [Region]
~~~~~
A new resource group will then be created in the region you chose
~~~~~
az deployment group create --resource-group [RGName] --template-file sql-training.bicep
~~~~~
Enter an admin Name and also a password

Once completed, you will have the following resources

![image](https://github.com/mullertron/sql-training/assets/79084450/7a64b194-d19d-41f5-a742-86d8389c28c0)



Log on to the VM and then download the following files

~~~~~
https://muldowninstallfiles.blob.core.windows.net/sqltraining/enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso?sp=r&st=2024-02-21T11:28:28Z&se=2024-03-09T19:28:28Z&spr=https&sv=2022-11-02&sr=b&sig=kJUsPWKQzZKVNwWIyUUuI66mN5Ormo39xG5iUJw%2BM6k%3D
~~~~~

~~~~~
https://muldowninstallfiles.blob.core.windows.net/sqltraining/SQLIaaS.reg?sp=r&st=2024-02-21T11:32:37Z&se=2024-03-09T19:32:37Z&spr=https&sv=2022-11-02&sr=b&sig=rFcMciE1CpGE4MnxnmU6UUWZ3bOvzzLqTSON7mWGwCo%3D
~~~~~
