#!/bin/bash

THECMD=$0
APPNAME=$1
APPPWD=$2

if [[ "" == ${APPNAME} ]]; then
  echo "You need to specify an app name after your docker command, ex : ${THECMD} 'AppName'"
  exit 1
fi

if [[ "" == ${APPPWD} ]]; then
  echo "*** No password specified, generating one using urandom"
  echo
  PASSWORD=$(env LC_CTYPE=C tr -dc "a-zA-Z0-9" < /dev/urandom | head -c 15)
fi
if [[ "" != ${APPPWD} ]]; then
  PASSWORD=$APPPWD
fi

az login > logAccount.json

if [ -z "$SUBSCRIPTIONNAME" ]; then
  echo "Successfully logged"
  echo " -------- > Pick your subscription : "
  options=($(az account list | jq -r 'map(select(.state == "Enabled"))|.[]|.name + ":" + .id' | sed -e 's/ /_/g'))
  select opt in "${options[@]}"
  do
          SUBSCRIPTIONNAME=`echo $opt | awk -F ':' '{print $1}'`
          break
  done
fi

echo "**** Using subscription : ${SUBSCRIPTIONNAME}"

TENANTID=$(az account list | jq ".[$((REPLY-1))].tenantId" | sed -e 's/\"//g')
SUBSCRIPTIONID=$(az account list | jq ".[$((REPLY-1))].id" | sed -e 's/\"//g')

if [[ "" == ${TENANTID} ]]; then
    echo "!!! Error - Tenant id. !!!"
    exit 1
fi
echo "*** Validating if this application is not already there... You can ignore the parse error message..."
APPALREDAYTHERE=$(az ad app list --display-name ${APPNAME})

if [[ "[]" != ${APPALREDAYTHERE} ]]; then
    echo "!!! This application name is already taken !!!"
    exit 1
fi

echo "**** Creating AD application ${APPNAME}"

az ad app create --display-name ${APPNAME} --identifier-uris http://${APPNAME} --homepage http://${APPNAME} --password ${PASSWORD} > logApp.json

APPID=$(jq .appId logApp.json | sed -e s/\"//g)

echo "**** Application created with ID=${APPID}"
if [[ "" == ${APPID} ]]; then
    echo "!!! Error - APP ID !!!"
    exit 1
fi

echo "**** Creating SPN"
az ad sp create --id ${APPID} > logAppSP.json

SPOBJECTID=$(jq .objectId logAppSP.json | sed -e 's/\"//g')

echo "SPN created with ID=${SPOBJECTID}"
if [[ "" == ${SPOBJECTID} ]]; then
    echo "!!! Error - SP Object !!!"
    exit 1
fi

echo "*** Waiting 15 sec to applying for parameters"
sleep 15

echo "Attributing contributor role for ${SPOBJECTID} in subscription ${SUBSCRIPTIONNAME}"
az role assignment create --assignee ${SPOBJECTID} --role Contributor > logRole.json

echo

echo "================== Informations about your new App =============================="
echo "Subscription ID                    ${SUBSCRIPTIONID}"
echo "Subscription Name                  ${SUBSCRIPTIONNAME}"
echo "Service Principal Client ID:       ${APPID}"
echo "Service Principal Key:             ${PASSWORD}"
echo "Tenant ID:                         ${TENANTID}"
echo "================================================================================="
echo
echo "Thanks for using this container, if you have questions or issues : https://github.com/julienstroheker/DockerAzureSPN"