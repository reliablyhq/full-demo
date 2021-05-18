# A project for demoing Reliably

## What does this repository contain?

* [x] A terraform set of resources to create a GCP infrastructure
* [-] A set of Kubernetes manifests to run applications in a Kubernetes environment
* [x] A dummy application
* [x] A set of reliably manifests per application services
* [] Chaos Toolkit experiments

## What should you use?

To enjoy the demo provided by this project, you do not need to run the entire
infrastructure avery time. In fact, that part should usually be run on-demand
to update the infrastructure in some capacity.

Instead, you should simply use the demo applications served by the
infrastructure.

## Demo applications

For now, this project only contains a single application.

### Noteboard

The noteboard application is a very simple web application which consists of a
single webpage with a form to add a note to the current list of notes, displayed
on the page as well.

The architecture is rather simple:

* The web page makes a GET call to the backend to retrieve the list of notes
* The web page makes a POST call to the backend to add a new note
* The backend sends either to an API service to actually perform the operation
* Data is persisted and retrieved from a PostgreSQL database

The infrastructure is as follows:

* Both the web application and its API are served as serverless services from
  Google Cloud Platform Cloud Run infrastructure
* The database is hosted by GCP too through their Cloud SQL offering

Access to the web application and its API can be done via:

https://demo.reliably.com/noteboard and https://demo.reliably.com/noteboard/api
respectively.

Give it a spin from your browser, or from the CLI.

View the raw HTML page:
```console
$ curl https://demo.reliably.com/noteboard
```

Retrieve the notes:
```console
$ curl https://demo.reliably.com/noteboard/notes | jq .
```

Post a new note:
```console
$ curl -d '{"text": "hello there", "completed": true}' https://demo.reliably.com/noteboard/notes
```

The `/notes` path talks to the backend which then makes a call to the API. This
is mostly so that we can introduce interestingly failure cases in the chain
of calls.

View the current enabled faults on the API endpoint:
```console
$ curl https://demo.reliably.com/noteboard/api/v1/fault
```

We support latency and error-based faults. The former makes the API respond
slower, which can make your SLO look bad. The latter simply returns an
error code from the API.

View active faults:
```console
$ curl https://demo.reliably.com/noteboard/api/v1/fault
```

Add 400ms latency to API calls:
```console
$ curl https://demo.reliably.com/noteboard/api/v1/fault/slowdown?latency=400
```

Remove latency to API calls:
```console
$ curl -X DELETE https://demo.reliably.com/noteboard/api/v1/fault/slowdown
```

Response with a 400 or 500 error:
```console
$ curl https://demo.reliably.com/noteboard/api/v1/fault/error
```

Remove error fault to API calls:
```console
$ curl -X DELETE https://demo.reliably.com/noteboard/api/v1/fault/error
```

Whenever you have a fault enabled, you can call the 
https://demo.reliably.com/noteboard application a few times and it will
eventually impact the SLO.

To generate SLO reports, using reliably:

```console
$ reliably slo report --manifest apps/noteboard-frontend/reliably.yaml
$ reliably slo report --manifest apps/noteboard-api/reliably.yaml
```

Remember that we cannot compute reports under a minute of interval. If you 
call the command twice in less than a minute, you'll get more or less the
same reports.