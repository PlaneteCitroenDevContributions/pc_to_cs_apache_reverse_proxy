#! /bin/bash

HERE=$( dirname "$0" )
PGM_BASENAME=$( basename "$0" )
ENV_FILE="${HERE}/env-${PGM_BASENAME}"

if [[ -n "${FILTER_DEBUG}" ]]
then
    set -x
    if [[ "${FILTER_DEBUG}" == "file" ]]
    then
	: ${DEBUG_ROOT_DIR:="${HERE}/DEBUG"}
	_debug_dir_="${DEBUG_ROOT_DIR}/debug_request_$$"
	mkdir -m 777 -p "${_debug_dir_}"

	: ${STDERR:="${_debug_dir_}/stderr.txt"}
	: ${trace_file:="${_debug_dir_}/trace.txt"}

	exec 2>>"${STDERR}"
    fi
fi

if [[ -x "${ENV_FILE}" ]]
then
    source "${ENV_FILE}"
fi

in_file="/tmp/in.txt.$$"
corrected_in_file="/tmp/corrected_in.txt.$$"

: ${check_pc_user_pgm:="${HERE}/checkVBulletinUser.sh"}

#
# get cs credentials from credential file
#

credential_file_effective_content=$(
    sed -e '/^[ \t]*#/d' "${CREDENTIAL_FILE}"
)

: ${CREDENTIAL_FILE:="${HERE}/cs_credential.txt"}
cs_login=$(
    grep cs_login <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
)

cs_password=$(
    grep cs_password <<< "${credential_file_effective_content}" | cut -d '=' -f 2 | tr -d ' '
	   )

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

    case "${username}" in

	# FIXME: to remove
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
	*)
	    if "${check_pc_user_pgm}" "${username}" "${password}"
	    then
		return 0
	    else
		return 1
	    fi
	    ;;
    esac

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
	# user has selected a document
	#
	jvin_field_in_body=$( sed -e '/VIN_OK_BUTTON/s/.*jvin=\([^\&]*\).*/\1/' "${in_file}" )
	if [[ -n "${jvin_field_in_body}" ]]
	then
            generateStatisticEntry "vin" "${jvin_field_in_body}" "none"
	fi

	cp "${in_file}" "${corrected_in_file}"
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

cp "${in_file}" "${corrected_in_file}" "${_debug_dir_}"
rm -f "${in_file}" "${corrected_in_file}"
