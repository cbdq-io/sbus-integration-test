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

Initiate the traffic:

```shell
make initiate-traffic
```

Finally, to start the router, run:

```shell
docker compose up -d router
```

When finished, run the following to nuke everything from orbit:

```shell
make clean
```

## Results

| Version                                                           | Record Count | Duration  | TPS  |
| ----------------------------------------------------------------- | ------------ | --------- | ---- |
| [0.1.0](https://github.com/cbdq-io/sbus-integration-test/pull/2)  | 128,000      | PT47M37S  | 44.8 |
| [0.2.0](https://github.com/cbdq-io/sbus-integration-test/pull/8)  | 128,000      | PT47M9S   | 45.3 |
| [0.3.0](https://github.com/cbdq-io/sbus-integration-test/pull/10) | 128,000      | PT51M48S  | 41.2 |
| [0.4.0](https://github.com/cbdq-io/sbus-integration-test/pull/12) | 128,000      | PT46M12S  | 46.2 |
