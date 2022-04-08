#! /bin/bash

#
# check args
#

usage ()
{
    echo "Usage: $0 <cloud login> <cloud password>" 1>&2
    exit 1
}


if [[ $# -ne 2 ]]
then
    usage
    # not reached
fi

username="$1"
password="$2"

if [[ -z "${username}" ]]
then
    echo "ERROR: missing username" 1>&2
    usage
    # not reached
fi

if [[ -z "${password}" ]]
then
    echo "ERROR: missing password" 1>&2
    usage
    # not reached
fi

#
# TMP management
#
: ${SKIP_CLEAN_TMP:=""}
if [[ -n "${SKIP_CLEAN_TMP}" ]]
then
    _skip_clean_tmp=true
else
    _skip_clean_tmp=false
fi

: ${TMP_PREFIX:=$( mktemp -u )}
trap "cleanup" 0


cleanup ()
{
    if ${_skip_clean_tmp}
    then
	return 0
    fi

    rm -rf \
       "${TMP_PREFIX}"
}

#
# check if user has access to a specific message
#

checkUserHasAccessToPC ()
{
    local pc_cloud_username="$1"
    local pc_cloud_password="$2"

    if [[ -z "${pc_cloud_username}" || -z "${pc_cloud_password}" ]]
    then
	echo "ERROR: missing username or password" 1>&2
	return 1
    fi

    local dn="uid=${pc_cloud_username},ou=people,dc=planetecitroen,dc=fr"
    ldapwhoami -H "ldap://ldap:3389" -D "${dn}" -w "${pc_cloud_password}"
    ldap_status=$?

    local access_granted=false
    if [[ "${ldap_status}" -eq 0 ]]
    then
	access_granted=true
    fi

    if ${access_granted}
    then
	return 0
    else
	return 1
    fi
}

checkUserHasAccessToPC "${username}" "${password}"
