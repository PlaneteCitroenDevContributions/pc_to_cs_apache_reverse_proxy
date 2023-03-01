#! /bin/bash

HERE=$( dirname "$0" )
PGM_BASENAME=$( basename "$0" )
ENV_FILE="${HERE}/env-${PGM_BASENAME}"

: ${SIMPLE_VIN_DECODER_PORT_URL:="http://simple-vindecoder-server:80/vindecode-cgi-bin/cached-simple-vindecoder.cgi"}

# TMP
FILTER_DEBUG=yes

if [[ -n "${FILTER_DEBUG}" ]]
then
    set -x
    if [[ "${FILTER_DEBUG}" == "file" ]]
    then
	: ${DEBUG_ROOT_DIR:="${HERE}/DEBUG"}
	_debug_dir_="${DEBUG_ROOT_DIR}/$( date '+%Y/%m/%d' )/debug_request_$( date '+%s' )"
	mkdir -m 777 -p "${_debug_dir_}"

	: ${STDERR:="${_debug_dir_}/stderr.txt"}
	if echo '' >> "${STDERR}"
	then
	    :
	else
	    # invalidate _debug_dir_
	    _debug_dir_=''
	    STDERR=/dev/stderr
	fi
	echo "Redirect stderr to ${STDERR}" 1>&2
	exec 2>>"${STDERR}"
	
	: ${trace_file:="${_debug_dir_}/trace.txt"}
	if echo '' >> "${trace_file}"
	then
	    :
	else
	    # invalidate _debug_dir_
	    _debug_dir_=''
	    trace_file="/dev/stderr"
	fi
    fi
fi

if [[ -x "${ENV_FILE}" ]]
then
    source "${ENV_FILE}"
fi

in_file="/tmp/in.txt.$$"
corrected_in_file="/tmp/corrected_in.txt.$$"

: ${check_pc_user_pgm:="${HERE}/checkCloudAgendaUser.sh"}

#
# get cs credentials from credential file
#

credential_file_effective_content=$(
    sed -e '/^[ \t]*#/d' "${CREDENTIAL_FILE}"
)

: ${CREDENTIAL_FILE:="${HERE}/cs_credential.txt"}

# get login credential
cs_login=$(
    grep 'cs_login' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
)

cs_password=$(
    grep 'cs_password' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
	   )

# get ldap filtering information
cs_ldap_filter_group1=$(
    grep 'filter_group1' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
	   )

cs_ldap_filter_group2=$(
    grep 'filter_group2' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
	   )

cs_ldap_filter_group3=$(
    grep 'filter_group3' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
	   )

cs_ldap_filter_group4=$(
    grep 'filter_group4' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
		     )

# get allowed vin make ids
allowed_vin_make_id1=$(
    grep 'allowed_vin_make_id1' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
		     )

allowed_vin_make_id2=$(
    grep 'allowed_vin_make_id2' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
		    )

allowed_vin_make_id3=$(
    grep 'allowed_vin_make_id3' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
		     )

allowed_vin_make_id4=$(
    grep 'allowed_vin_make_id4' <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
		     )
#
# test collected values
#

if [[ -z "${cs_login}" ]]
then
    #TODO: test it
    cs_login='unintialized'
fi
if [[ -z "${cs_password}" ]]
then
    cs_password='unintialized'
fi

#
# save stdin to file
#

cat - > "${in_file}"

url_decode ()
{
    url_encoded_string="$1"
    url_decoded_string=$( urlencode -d "${url_encoded_string}" )

    echo -n "${url_decoded_string}"
}

checkUsername ()
{
    username=$1

    # bypass
    return 0
    # NOT REACHED

    case "${username}" in

	"pc1" )
	    # FIXME: to remove
	    : # nop
	    ;;
	"pc2")
	    return 0
	    ;;
	*)
	    return 1
	    ;;
    esac

}
	
checkUserpassword ()
{
    username="$1"
    password="$2"

    check_result=false

    if [[ -n "${_CREDENTIONAL_DEBUG_}" ]]
    then
	case "${username}" in

	    "pc1" )
		if [[ "${password}" == "pc1pass" ]]
		then
		    return 0
		fi
		;;
	    "pc2")
		if [[ "${password}" == "pc2pass" ]]
		then
		    return 0
		fi
		;;
	esac
    fi

    if "${check_pc_user_pgm}" "${username}" "${password}" "${cs_ldap_filter_group1}" "${cs_ldap_filter_group2}" "${cs_ldap_filter_group3}" "${cs_ldap_filter_group4}"
    then
	return 0
    else
	return 1
    fi

}

#
# compute car make ID based on VIN with Vindecoder
#

getVinCarMakeId ()
{
    vin="$1"

    curl_out=$( curl --silent --connect-timeout 3 --data "${vin}" "${SIMPLE_VIN_DECODER_PORT_URL}" )

    simple_vin_decoder_status=$( echo "${curl_out}" | grep 'service_error_status:' | cut -d ':' -f 2 | tr --delete '[:space:]' )

    case "${simple_vin_decoder_status}" in
	'0')
	    # ok
	    make_id=$( echo "${curl_out}" | sed -n '/^{"label":"Make"/s/.*,"id":\([1-9][0-9]*\).*/\1/p')
	    result_string="${make_id}"
	    return_status=0
	    ;;
	[1-9][0-9]*)
	    # got an error code
	    result_string=''
	    return_status=${simple_vin_decoder_status}
	    ;;	    
	* )
	    # curl failed
	    result_string=''
	    return_status=99
	    ;;
    esac
	    
    echo "${result_string}"
    return ${return_status}
}

#
# add statistic entry
# ===================

: ${STAT_DATA_DIR:="/var/pc_stats"}
# TODO: better test of the directory
mkdir -p "${STAT_DATA_DIR}"

generateStatisticEntry ()
{
    local action="$1"
    local param="$2"
    local status="$3"

    local current_year=$( date '+%Y' )
    local current_month=$( date '+%m' )
    local current_day_number=$( date '+%d' )
    local current_weekday=$( date '+%u' )
    local current_week_number=$( date '+%V' )

    local date_filename_part=""
    date_filename_part="${date_filename_part}_Y=${current_year}=Y"
    date_filename_part="${date_filename_part}_M=${current_month}=M"
    date_filename_part="${date_filename_part}_D=${current_day_number}=D"
    date_filename_part="${date_filename_part}_d=${current_weekday}=d"
    date_filename_part="${date_filename_part}_W=${current_week_number}=W"
    
    local stat_file="${STAT_DATA_DIR}/stat${date_filename_part}_$$.txt"
    (
	# use date since epoch to easy line sorting later
        local stat_date=$( date '+%s' )
        echo "\"${stat_date}\" \"${action}\" \"${param}\" \"${status}\" \"${HTTP_X_REAL_IP}\" \"${HTTP_USER_AGENT}\""
    ) > "${stat_file}"
}


#
# DEBUG
# =====
#

if [[ -n "${trace_file}" ]]
then

    (
	echo 'vvvvvvvvvvvvvvvvvvvvvvv'
	date
	export
	echo -n '===========================================>'
	cat "${in_file}"
	echo '<==========================================='
	echo '-----------------------'
    ) >> "${trace_file}"
fi

#
# MAIN
# ====
#
# select behavior depending on URL
#


case "${REQUEST_URI}" in
    "/elapseTime" )
	body=$( cat "${in_file}" )
	#content = username=XXXXX
	username=${body#username=}

	if checkUsername "${username}"
	then
	    elapseTimeUserName="${cs_login}"
	else
	    elapseTimeUserName="bad_planete_citroen_assosiation_login_${username}"
	fi

	sed -e 's/username=.*$/username='${elapseTimeUserName}'/' "${in_file}" > "${corrected_in_file}"
	;;

    "/do/login" )
	#
	# get provided credential
	#
	userid=$(
	    sed -e 's/.*&userid=\([^&]*\)&.*/\1/' "${in_file}"
	      )
	password=$(
	    sed -e 's/.*&password=\([^&]*\)&.*/\1/' "${in_file}"
	      )

	pc_login_success=false
	loginUserid="bad_planete_citroen_association_login_${username}"
	loginPassword="bad_planete_citroen_association_password_${password}"
	if checkUsername "${userid}"
	then
	    url_decoded_user_id=$( url_decode "${userid}" )
	    url_decoded_password=$( url_decode "${password}" )
	    if checkUserpassword "${url_decoded_user_id}" "${url_decoded_password}"
	    then
		loginUserid="${cs_login}"
		loginPassword="${cs_password}"
		pc_login_success=true
	    fi
	fi

	sed -e 's/&userid=[^&]*&password=[^&]*&/\&userid='${loginUserid}'\&password='${loginPassword}'\&/' "${in_file}" > "${corrected_in_file}"

	if ${pc_login_success}
	then
	    generateStatisticEntry "login" "${userid}" success
	else
	    generateStatisticEntry "login" "${userid}" fail
	fi

	;;

    /docapvAC/affiche.do* )
	#
	# user has selected a document
	#
	document_reference_query_field=$( echo "${QUERY_STRING}" | cut -d \& -f 1 )
	document_reference="${document_reference_query_field#ref=}"
        generateStatisticEntry "documentation" "${document_reference}" "none"

	cp "${in_file}" "${corrected_in_file}"
	;;

    "/do/ok" )
	#
	# user has entered a VIN
	#
	jvin_field_in_body=$( sed -n -e '/VIN_OK_BUTTON/s/.*\&jvin=\([^\&]*\)\&.*/\1/p' "${in_file}" )
	if [[ -n "${jvin_field_in_body}" ]]
	then

	    #
	    # check if car make is allowed
	    #

	    # build array from configuration params

	    declare -a allowed_car_make_id_array
	    for id in "${allowed_vin_make_id1}" "${allowed_vin_make_id2}" "${allowed_vin_make_id3}" "${allowed_vin_make_id4}"
	    do
		if [[ -n "${id}" ]]
		then
		    allowed_car_make_id_array+=( "${id}" )
		fi
	    done

	    if [[ ${#allowed_car_make_id_array[@]} -eq 0 ]]
	    then
		# no car make filtering configuration provided => no filtering
		vin_entry_is_allowed=true
	    else
		# check if car make for to the typed vin is allowed

		car_make_id=$( getVinCarMakeId "${jvin_field_in_body}" )

		vin_entry_is_allowed=false
		for id in "${allowed_car_make_id_array[@]}"
		do
		    if [[ "${car_make_id}" == "${id}" ]]
		    then
			vin_entry_is_allowed=true
		    break
		    fi
		done
	    fi

	    if ${vin_entry_is_allowed}
	    then
		# transmit input as it
		cp "${in_file}" "${corrected_in_file}"

		generateStatisticEntry "vin" "${jvin_field_in_body}" "{\"status\": \"OK\"; \"make\": \"no make filtering\"}"

	    else
		# alter stream so that the server generates an error
		#
		# generate a BAD VIN and replacing the first character by 'X'
		bad_vin="X${jvin_field_in_body:1}"
		sed -e '/VIN_OK_BUTTON/s/\&jvin=[^\&]*\&/\&jvin='"${bad_vin}"'\&/' "${in_file}" > "${corrected_in_file}"

		generateStatisticEntry "vin" "${jvin_field_in_body}" "{\"status\": \"NOK\"; \"make\": \"${car_make_id}\"}"
		
	    fi
	fi

	;;

    * )
	cp "${in_file}" "${corrected_in_file}"
	;;
esac

if [[ -n "${trace_file}" ]]
then
    (
	echo -n '++++++++++++++++++++++++++++++++++++>'
	cat "${corrected_in_file}"
	echo '<++++++++++++++++++++++++++++++++++++'
	echo "Got username: ${username}"
	echo "Used elapseTimeUserName: ${elapseTimeUserName}"
	echo "Got userid: ${userid}"
	echo "Used loginUserid: ${loginUserid}"
	echo "Got password: ${password}"
	echo "Used loginPassword: ${loginPassword}"
	echo '^^^^^^^^^^^^^^^^^^^^^^^^'
    ) >> "${trace_file}"
fi

cat "${corrected_in_file}"

if [[ -n "${_debug_dir_}" ]]
then
    cp "${in_file}" "${corrected_in_file}" "${_debug_dir_}"
fi

rm -f "${in_file}" "${corrected_in_file}"
