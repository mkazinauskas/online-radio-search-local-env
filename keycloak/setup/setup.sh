#!/bin/sh

ADMIN_USER=importer

ADMIN_PASSWORD=Pa55w0rd

echo "Setting up default admin $ADMIN_USER"

./add-user-keycloak.sh -u $ADMIN_USER -p $ADMIN_PASSWORD

nohup ./standalone.sh > /dev/null 2>&1 &

until curl -s localhost:8080; do sleep 1; echo "Waiting for started server"; done

echo "Setting up users"

./kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user $ADMIN_USER --password $ADMIN_PASSWORD

./kcadm.sh create realms -s realm=online-radio-search -s enabled=true

CURL_ID=$(./kcadm.sh create clients -r online-radio-search -s clientId=curl -s enabled=true -s publicClient=true -s baseUrl=http://localhost:8080 -s adminUrl=http://localhost:8080 -s directAccessGrantsEnabled=true -i)

DEMO_APP_ID=$(./kcadm.sh create clients -r online-radio-search -s clientId=online-radio-search-app -s enabled=true -s baseUrl=http://localhost:8080 -s bearerOnly=true -i)

./kcadm.sh create clients/$DEMO_APP_ID/roles -r online-radio-search -s name=admin -s 'description=Admin role'

./kcadm.sh create clients/$DEMO_APP_ID/roles -r online-radio-search -s name=user -s 'description=User role'

./kcadm.sh  get clients/$DEMO_APP_ID/installation/providers/keycloak-oidc-keycloak-json -r online-radio-search

JOE_ADMIN_ID=$(./kcadm.sh create users -r online-radio-search -s username=joe_admin -s enabled=true -i)

./kcadm.sh update users/$JOE_ADMIN_ID/reset-password -r online-radio-search -s type=password -s value=admin -s temporary=false -n

./kcadm.sh add-roles -r online-radio-search --uusername=joe_admin --cclientid online-radio-search-app --rolename admin

JIM_USER_ID=$(./kcadm.sh create users -r online-radio-search -s username=jim_user -s enabled=true -i)

./kcadm.sh update users/$JIM_USER_ID/reset-password -r online-radio-search -s type=password -s value=admin -s temporary=false -n

./kcadm.sh add-roles -r online-radio-search --uusername=jim_user --cclientid online-radio-search-app --rolename user

./jboss-cli.sh --connect command=:shutdown

nohup ./standalone.sh \
    -Dkeycloak.migration.action=export \
    -Dkeycloak.migration.provider=singleFile \
    -Dkeycloak.migration.file=import.json \
> /dev/null 2>&1 &

until curl -s localhost:8080; do sleep 1; echo "Waiting for started server"; done

./jboss-cli.sh --connect command=:shutdown
