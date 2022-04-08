#! /bin/bash

#
# configuration vars
#
: ${PC_LDAP_URL:="ldap://ldap:3389"}

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
    ldapwhoami -H "${PC_LDAP_URL}" -D "${dn}" -w "${pc_cloud_password}"
    ldap_status=$?

    local access_granted=false
    if [[ "${ldap_status}" -eq 0 ]]
    then

	ldap_search_result=$(
	    ldapsearch -LLL -x -H "${PC_LDAP_URL}" -b "${dn}" \
		   '(&(memberOf=cn=ServiceBoxUser,ou=groups,dc=planetecitroen,dc=fr)(memberOf=cn=ServiceBoxAllowed,ou=groups,dc=planetecitroen,dc=fr))' \
		   dn
	    )

	if [[ -n "${ldap_search_result}" ]]
	then
	    access_granted=true
	fi
    fi

    if ${access_granted}
    then
	return 0
    else
	return 1
    fi
}

checkUserHasAccessToPC "${username}" "${password}"
