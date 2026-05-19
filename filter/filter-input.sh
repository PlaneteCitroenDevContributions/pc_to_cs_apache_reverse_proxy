#! /bin/bash

HERE=$( dirname "$0" )
PGM_BASENAME=$( basename "$0" )
ENV_FILE="${HERE}/env-${PGM_BASENAME}"

if [[ -n "${SHELL_DEBUG}" ]]
then
    set -x
fi

# Utilities
# =========
urlencode() {
    # urlencode <string>

    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-])
		printf '%s' "$c"
		;;
            *)
		printf '%%%02X' "'$c"
		;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

getHeaderValueFor ()
{
    header_regexpr_pattern="$1"

    line_containing_header=$(
	grep \
	    --ignore-case \
	    --regexp="${header_regexpr_pattern}:"
			 )

    header_value=$(
	echo "${line_containing_header}" | \
	    sed -n -e 's/[^:]*:[ \t]*\(.*\)$/\1/p'
		)

    echo "${header_value}"
}

# =========

if [[ "${FILTER_DEBUG}" == "file" ]]
then
    : ${DEBUG_ROOT_DIR:="${HERE}/DEBUG"}
    _document_uri_to_system_path_=$( urlencode "${REQUEST_URI}" )
    _debug_dir_="${DEBUG_ROOT_DIR}/$( date '+%Y/%m/%d/%s' )-${_document_uri_to_system_path_}-request"
    _log_files_dir_="${_debug_dir_}"

    mkdir -m 777 -p "${_debug_dir_}" 2>/dev/null

    # test if all the folders are OK

    # 1. stderr redirection
    : ${STDERR:="${_debug_dir_}/stderr.txt"}
    if ( echo '' >> "${STDERR}" ) 2>/dev/null
    then
	# OK
	:
    else
	# invalidate _debug_dir_
	_debug_dir_='/tmp'
	STDERR=/dev/stderr
    fi
    echo "Redirect stderr to ${STDERR}" 1>&2
    exec 2>>"${STDERR}"

    # 2. _log_files_dir_
    : ${_log_file_:="${_log_files_dir_}/log.txt"}
    if ( echo '' >> "${_log_file_}" ) 2>/dev/null
    then
	# OK
	:
    else
	# invalidate _debug_file_
	_log_file_="/dev/stderr"
	# _log_files_dir_ may by wrong too
	_trace_dir='/tmp'
    fi
else
    STDERR='/dev/stderr'
    _debug_dir_='/tmp'
    _log_files_dir_='/tmp'
    _log_file_='/dev/stderr'
fi
    
logInfo ()
{
    echo "$@" | while read -r line
    do
       echo '===>[INFO] '"${line}"
    done >> "${_log_file_}"
}

# default values if not previously set
logTrace ()
{
    echo "$@" | while read -r line
    do
       echo '===>[TRACE] '"${line}"
    done >> "${_log_file_}"
}


if [[ -x "${ENV_FILE}" ]]
then
    source "${ENV_FILE}"
fi

in_file="/tmp/in.txt.$$"
corrected_in_file="/tmp/corrected_in.txt.$$"

#
# save stdin to file
#

cat - > "${in_file}"

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
) > "${_debug_dir_}/in_file.txt"


#
# stat utilities
# ==============

: ${STAT_DATA_DIR:="/var/pc_stats"}
# TODO: better test of the directory
mkdir -p "${STAT_DATA_DIR}"

escapedString ()
{
    unescaped_string="$1"

    escaped_string=$( printf '%q' "${unescaped_string}" )

    echo -e "${escaped_string}"
}

generateStatisticEntry ()
{
    local user="$1"

    local action="$2"
    local param="$3"
    local status="$4"

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
        echo -e \"${stat_date}\" \"$( escapedString "${user}")\" \"${action}\" \"$( escapedString "${param}")\" \"$( escapedString "${status}")\" \"$( escapedString "${HTTP_X_REAL_IP}")\" \"$( escapedString "${HTTP_USER_AGENT}")\"
    ) > "${stat_file}"
}

#
# MAIN
# ====
#
# select behavior depending on URL
#

case "${REQUEST_URI}" in

    /do/login* ) # same as <Location "/do/login"> in http.conf

	if [[ -n "${AUTHENTICATE_UID}" ]]
	then
	    generateStatisticEntry "${AUTHENTICATE_UID}" 'login' "${REMOTE_USER}" 'success'
	else
	    generateStatisticEntry '_unknown_user_' 'login' 'Internal error: missing AUTHENTICATE_UID' 'fail'
	fi

	cp "${in_file}" "${corrected_in_file}"
	;;

    /docapvAC/affiche.do* )
	#
	# user has selected a document
	#
	document_reference_query_field=$( echo "${QUERY_STRING}" | cut -d \& -f 1 )
	document_reference="${document_reference_query_field#ref=}"
        generateStatisticEntry "${AUTHENTICATE_UID}" 'documentation' "${document_reference}"

	cp "${in_file}" "${corrected_in_file}"
	;;

    "/do/ok" )
	#
	# user has selected a document
	#
	jvin_field_in_body=$( sed -e '/VIN_OK_BUTTON/s/.*jvin=\([^\&]*\).*/\1/' "${in_file}" )
	if [[ -n "${jvin_field_in_body}" ]]
	then
            generateStatisticEntry "${AUTHENTICATE_UID}" 'vin' "${jvin_field_in_body}"
	fi

	cp "${in_file}" "${corrected_in_file}"
	;;

    * )
	cp "${in_file}" "${corrected_in_file}"
	;;
esac

#
# DEBUG
# =====
#

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
) > "${_debug_dir_}/corrected_in_file.txt"

cat "${corrected_in_file}"

rm -f "${in_file}" "${corrected_in_file}"
