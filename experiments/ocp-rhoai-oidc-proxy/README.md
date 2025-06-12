# Notes
How to set the audience correctly the jwts ...
https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/keycloak_oidc?_highlight=audience#usage

# Presteps
## IDP setup
Need to have the cluster-admins group AND the odh-admins group.
Need to have the groups key added to the token claims.
Need to have the audience key set correctly in the token claims.


## Build all the necessary docker images and push to the registry 
```
./BUILD_ALL.sh
```

# Getting the odh operator running

## Get all manifests [ONLY IF NOT ALREADY DONE!!!]
```
cd /src.odh/opendatahub-operator
./get_all_manifests.sh
```

## Install the odh operator
```
make install
```

## Start the operator
```
make run-nowebhook
```

## Set the dsci
```
oc apply -f src.odh/configs/dsci.yaml
```

## Set the dsc
```
src.odh/configs/dsc.yaml
```

# Setup the new http service for the dashboard
```
oc apply -f src.odh/configs/dashboard-svc-no-proxy.yaml
```

# Setup the oidc proxy
```
oc apply -f src.odh/configs/oidc-proxy-service.yaml
```
