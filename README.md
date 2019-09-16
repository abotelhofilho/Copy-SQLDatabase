# Copy-SQLDatabase

<# 

!!!READ ME!!!

This is used to refresh a test MS SQL database with production MS SQL database, by taking a backup of the production database and restore it !!!OVER-WRITING!!! the test database.

Account running this needs to have sysadmin access to both databases.

Source_Instance -   The MS SQL server instance where the desired database to be copied is located.
                    Ex: ProdDB01\Prod

Source_Database -   The MS SQL database that needs to be copied.
                    Usually a production database.
                    Ex: Database_Prod

Destination_Instance -  The MS SQL server instance that the desired database that needs to be refreshed is located.
                        Ex: TestDB01\Test

Destination_Database -  The MS SQL database the needs to be refreshed\replaced\over-written with production(Source_Database) data
                        Ex: Database_Test

#>
