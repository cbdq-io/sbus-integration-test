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

Now generate some data to be injected into Kafka:

```shell
./data_gen.py -d
```
