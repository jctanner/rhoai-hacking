# Dashboard URL Redirect

## Purpose

Starting with RHOAI 3.3 and ODH 2.x, the old dashboard routes (`rhods-dashboard` and `odh-dashboard`) are removed in favor of the new `data-science-gateway` route. This breaks bookmarks and existing links.

This tool creates a redirect route that preserves the old URL and redirects traffic to the new gateway URL.

## What it does

1. Detects whether you're running RHOAI or ODH by checking subscriptions and dashboard config
2. Discovers the new gateway URL from the cluster
3. Generates a YAML manifest that deploys an nginx-based redirect
4. Creates the correct route name (`rhods-dashboard` or `odh-dashboard`) in the correct namespace

## Requirements

- `oc` or `kubectl` in PATH
- Cluster admin or sufficient permissions to read cluster resources
- Python 3.6+ (uses only stdlib)

## Usage

```bash
cd url_redirects
./generate-dashboard-redirect.py
```

The script will auto-discover platform type, namespace, route name, and redirect URL from the cluster.

After generation, apply the manifest:

```bash
oc apply -f dashboard-redirect.yaml
```

## What gets deployed

- **ConfigMap**: nginx config with redirect rule
- **Pod**: nginx container serving the redirect
- **Service**: Routes traffic to the pod
- **Route**: Recreates the old dashboard route name

All resources are deployed in the platform's application namespace (`redhat-ods-applications` for RHOAI, `opendatahub` for ODH).

## How the redirect works

The nginx config returns HTTP 301 redirects:

```
Old URL: https://rhods-dashboard.apps.cluster.com/path
New URL: https://data-science-gateway.apps.cluster.com/path
```

The `$request_uri` is preserved, so deep links work correctly.

## Detection logic

The script checks in order:

1. OdhDashboardConfig CR - reads platform type annotation and namespace
2. Subscription CRs - looks for `rhods-operator` or `opendatahub-operator` package
3. Consolelink - extracts redirect URL from "Red Hat OpenShift AI" or "Open Data Hub" entry
4. Route - falls back to `data-science-gateway` route if consolelink is missing

## Template variables

The template uses Python's `string.Template` with three variables:

- `${NAMESPACE}` - Target namespace for resources
- `${ROUTE_NAME}` - Name of the route to create
- `${REDIRECT_URL}` - Full URL to redirect to

## Files

- `generate-dashboard-redirect.py` - Generator script
- `dashboard-redirect.yaml.template` - YAML template
- `dashboard-redirect.yaml` - Generated output (created by script)

## Removing the redirect

```bash
oc delete -f dashboard-redirect.yaml
```

Or delete resources individually:

```bash
oc delete route <route-name> -n <namespace>
oc delete pod nginx-redirect -n <namespace>
oc delete service nginx-redirect -n <namespace>
oc delete configmap nginx-redirect-config -n <namespace>
```
