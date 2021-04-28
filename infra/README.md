This directory contains terrafomr resources to create a GCP project with the
following capabilities:

* A GKE cluster with at least 3 nodes
* A cloud run service serving one of the application's services
* A load balancer fronting both
* A PostgreSQL Cloud SQL database
* A dedicated VPC
* A basic set of GCP SLOs

## Setup your environment

### GCP

To create this infrastructure, you need to ensure you have a GCP credentials
set:

```
$ gcloud auth application-default login
```

Read: https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login

### Terraform

Make sure you have [Terraform 0.13+](https://www.terraform.io/downloads.html)
in your `PATH`.

Now run:

```
$ terraform init
```

## Check the terraform plan

Run:

```
$ terraform plan -out demo-infra.json
```

It will ask a few questions:

* The name of the GCP organization to create this project in
* The billing account name to associate to the GCP project
* The GCP project name to create
* The domain which will respond to requests

## Apply the plan to create the infrastructure

Run:

```
$ terraform apply "infra.plan"
```

This will likely fail a first time because GCP takes a bit of time to enable
some of its services and the GCP terraform providers isn't smart enough to wait
for some reason. When that happens, you'll see a message similar to:

```
│ Error: Error creating Network: googleapi: Error 403: Compute Engine API has not been used in project XYZ before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/compute.googleapis.com/overview?project=XYZ then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry., accessNotConfigured
│ 
│   on main.tf line 64, in resource "google_compute_network" "vpc":
│   64: resource "google_compute_network" "vpc" {
│ 
```

In that case, just wait for 5 mn or so and run the command again. It should go
through this time around.

## Configure the domain

While you have passed a domain to the terraform plan, the domain isn't actually
linked to the global IP address the project creates.

This must be done manually from your DNS zone.

Once your project finishes, it outputs the IP address to set a DNS A record for.

Once this is done, and your DNS has been populated, you can start reaching out
the domain over HTTPS.

## Cleaning up!

The demo poject isn't big but has a cost induced, once you have finished with
your demo, we suggest you destroy the resources to prevent costs.

```
$ terraform destroy
```

Again, the command will likely fail because the GCP provider doesn't seem to
be aware of the right ordering of things (could be we need to be explicit?).

When that happens, run the following command:

```
$ gcloud projects delete PROJECT_NAME
```

Of ocurse, replace `PROJECT_NAME` with the name you gave to terraform initially.
