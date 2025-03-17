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

## Results

| Version | Record Count | First Record | Last Record | Time (Minutes) | TPM (TPS) |
| ------- | ------------ | ------------ | ----------- | -------------- | --------- |
| [0.1.0](https://github.com/cbdq-io/sbus-integration-test/pull/2) | 128,000 | 18:13:54 | 19:01:31 | 48 | 2.6K (44.5) |
| [0.2.0](https://github.com/cbdq-io/sbus-integration-test/pull/8) | 128,000 | 08:04:13 | 08:51:22 | 47 | 2.7K (45.4) |
