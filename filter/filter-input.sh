#! /bin/bash

# $Id: filter-input.sh,v 1.22 2021/03/08 18:35:05 orba6563 Exp $

HERE=$( dirname "$0" )
PGM_BASENAME=$( basename "$0" )
ENV_FILE="${HERE}/env-${PGM_BASENAME}"
CREDENTIAL_FILE="${HERE}/cs_credential.txt"

_debug_dir_="${HERE}/DEBUG/debug_request_$$"
mkdir -p "${_debug_dir_}"

_log_dir_="${HERE}/logs/log_$$"
mkdir -p "${_log_dir_}"

: ${STDERR:="${_debug_dir_}/filter-input_stderr.txt"}
exec 2>>"${STDERR}"

if [[ -x "${ENV_FILE}" ]]
then
    source "${ENV_FILE}"
fi

in_file="/tmp/in.txt.$$"
corrected_in_file="/tmp/corrected_in.txt.$$"

: ${trace_file:="${_debug_dir_}/trace.txt"}

: ${check_pc_user_pgm:="${HERE}/checkVBulletinUser.sh"}

#
# get cs credentials from credential file
#

cs_login=$(
    grep cs_login "${CREDENTIAL_FILE}" | cut -d '=' -f 2 | tr -d ' '
)

cs_password=$(
    grep cs_password "${CREDENTIAL_FILE}" | cut -d '=' -f 2 | tr -d ' '
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

    case "${username}" in

	"pc1" )
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

generateStatisticEntry ()
{
    local reason="$1"
    local userid="$2"
    local status="$3"

    (
        echo "Date;login PC;Action;Status;Adresse IP;Navigateur"

        local csv_date=$( date '+%x %T' )
        echo "${csv_date};\"${userid}\";${reason};${status};\"${HTTP_X_REAL_IP}\
\";\"${HTTP_USER_AGENT}\""
    ) > "${_log_dir_}/stat_$$.csv"
}

#
# DEBUG
# =====
#

(
    echo 'vvvvvvvvvvvvvvvvvvvvvvv'
    date
    export
    echo -n '===========================================>'
    cat "${in_file}"
    echo '<==========================================='
    echo '-----------------------'
) >> "${trace_file}"

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
	    generateStatisticEntry login "${userid}" success
	else
	    generateStatisticEntry login "${userid}" fail
	fi

	;;

    * )
	cp "${in_file}" "${corrected_in_file}"
	;;
esac

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

cat "${corrected_in_file}"

cp "${in_file}" "${corrected_in_file}" "${_debug_dir_}"
rm -f "${in_file}" "${corrected_in_file}"
