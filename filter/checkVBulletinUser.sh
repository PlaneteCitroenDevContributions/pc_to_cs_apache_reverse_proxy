#! /bin/bash

# $Id: checkVBulletinUser.sh,v 1.24 2021/03/03 12:00:28 orba6563 Exp $

#
# check args
#

usage ()
{
    echo "Usage: $0 <pc username> <pc password for username>" 1>&2
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


cookie_file="${TMP_PREFIX}_cookie.txt"
do_login_reponse_file="${TMP_PREFIX}_do_login_response.txt"
showthead_response_file="${TMP_PREFIX}_showthread_response.txt"

cleanup ()
{
    if ${_skip_clean_tmp}
    then
	return 0
    fi

    rm -f \
       "${TMP_PREFIX}_cookie.txt" \
       "${TMP_PREFIX}_do_login_response.txt" \
       "${TMP_PREFIX}_showthread_response.txt"
}

#
# check if user has access to a specific message
#

# curl global configuration

_curl_common_options=''
#_curl_common_options="${_curl_common_options} --verbose"
_curl_common_options="${_curl_common_options} --silent"
_curl_common_options="${_curl_common_options} --max-time 3"
_curl_common_options="${_curl_common_options} --insecure"
_curl_common_options="${_curl_common_options} --header 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'"
_curl_common_options="${_curl_common_options} --header 'Accept-Encoding: gzip, deflate, br'"
_curl_common_options="${_curl_common_options} --header 'Upgrade-Insecure-Requests: 1'"


checkUserHasAccessToPC ()
{
    local pc_username="$1"
    local pc_password="$2"

    if [[ -z "${pc_username}" || -z "${pc_password}" ]]
    then
	echo "ERROR: missing username or password" 1>&2
	return 1
    fi

    local md5password=$(
	echo -n "${pc_password}" | \
	    md5sum | \
	    cut -d ' ' -f 1 \
	       )

    local login_request_body="vb_login_username=${pc_username}&vb_login_password=&securitytoken=guest&do=login&vb_login_md5password=${md5password}&vb_login_md5password_utf=${md5password}"

    #
    # get login cookie
    #
    rm -f "${cookie_file}" # if one with the same name remains
    echo "${_curl_common_options}" \
	| xargs curl \
		--header 'Content-Type: application/x-www-form-urlencoded' \
		--data "${login_request_body}" \
		--cookie-jar "${cookie_file}" \
		--output "${do_login_reponse_file}" \
		--url 'https://www.planete-citroen.com/forum/login.php?do=login'
    if [[ ! -f "${cookie_file}" ]]
    then
	# could not get a cookie file with session creds
	return 1
    fi
    
    #
    # fetch message
    #
    echo "${_curl_common_options}" \
	| xargs curl \
		--cookie "${cookie_file}" \
		--header 'Accept-Language: fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3' \
		--compressed \
		--output "${showthead_response_file}" \
		'https://www.planete-citroen.com/forum/showthread.php?207549-Acc%C3%A8s-CITROEN-SERVICE-2021&p=2017903672&viewfull=1#post2017903672'


    # check for each word, preventing htlm encoded separators
    local found_mandatory_keywords=$(
	cat "${showthead_response_file}" | \
	    grep --text 'ACCES' | \
	    grep --text 'STRICTEMENT' | \
	    grep --text 'CONFIDENTIEL'
			    )

    local access_granted=false
    if [[ -n "${found_mandatory_keywords}" ]]
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
