# sbus-integration-test
An integration test of the Kafka Connect connector for Azure Service Bus and the Service Bus Router.

To run through the test, firstly login to Azure with:

```shell
az login
```

Then export the relevant subscription ID so that Terraform can use the variable:

```shell
export TF_VAR_subscription_id='00000000-0000-0000-0000-000000000000'
```

Run a basic connectivity test:

```shell
make
```

Deploy the infrastructure:

```shell
make deploy
```

Capture the connection string for the Service Bus namespace:

```shell
export SBNS_CONNECTION_STRING=$( terraform -chdir=terraform output -raw connection_string )
```

Start the Kafka Connect connector:

```shell
docker compose run --rm kccinit
```

Now generate some data to be injected into Kafka:

```shell
./data_gen.py
```

When finished, run the following to nuke everything from orbit:

```shell
make clean
```
