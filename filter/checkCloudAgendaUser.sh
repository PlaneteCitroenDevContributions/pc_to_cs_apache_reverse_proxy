#! /bin/bash

#
# configuration vars
#
_DEFAULT_LDAPSEARCH_EXPRESSION_FOR_GROUP_MEMBERSHIP_='(&(memberOf=cn=ServiceBoxUser,ou=groups,dc=planetecitroen,dc=fr)(memberOf=cn=ServiceBoxAllowed,ou=groups,dc=planetecitroen,dc=fr))'

: ${PC_LDAP_URL:="ldap://ldap:3389"}
group_membership_ldap_search_expression=${_DEFAULT_LDAPSEARCH_EXPRESSION_FOR_GROUP_MEMBERSHIP_}

#
# check args
#

usage ()
{
    echo "Usage: $0 <cloud login> <cloud password> [ldap group membership search expression]
	Default value for ldap group expression: ${_DEFAULT_LDAPSEARCH_EXPRESSION_FOR_GROUP_MEMBERSHIP_}" 1>&2
    exit 1
}


username="$1"
password="$2"
ldap_search_expression="$3"

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

if [[ -n "${ldap_search_expression}" ]]
then
    group_membership_ldap_search_expression=${ldap_search_expression}
fi

#
# check if user has access to a specific message
#

checkUserHasAccessToPC ()
{
    local pc_cloud_username="$1"
    local pc_cloud_password="$2"
    local ldap_filter_search_expression="$3"

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
	    ldapsearch -LLL -x -H "${PC_LDAP_URL}" -b "${dn}" "${ldap_filter_search_expression}" dn
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

checkUserHasAccessToPC "${username}" "${password}" "(${group_membership_ldap_search_expression})"
