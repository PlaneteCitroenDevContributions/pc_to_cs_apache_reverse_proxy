#! /bin/bash

HERE=$( dirname "$0" )
PGM_BASENAME=$( basename "$0" )

#
# check arg = week number
#

Usage ()
{
    msg="$@"
    (
	echo "ERROR: ${msg}"
	echo "Usage ${PGM_BASENAME} <week number of current year>"
    ) 1>&2
}


if [[ $# != 1 ]]
then
    Usage "bad args"
    exit 1
fi

week_number="$1"

if expr "${week_number}" + 0 2>/dev/null
then
    :
else
    Usage "argument should be an integer"
    exit 1
fi

if [[ 1 -le ${week_number} && ${week_number} -le 53 ]]
then
    :
else
    Usage "argument should be a valide week number"
    exit 1
fi

: ${STATS_FOR_YEAR:=$( date '+%Y' )}

#
# add statistic entry
# ===================

: ${STAT_DATA_DIR:="/var/pc_stats"}

if [[ -d "${STAT_DATA_DIR}" && -d "${STAT_DATA_DIR}" ]]
then
    :
else
    Usage "ERROR: could not acces stat folder \"${STAT_DATA_DIR}\""
    exit 1
fi



generateStatisticEntry ()
{
    local reason="$1"
    local userid="$2"
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
        echo "\"${stat_date}\" \"${userid}\" \"${reason}\" \"${status}\" \"${HTTP_X_REAL_IP}\" \"${HTTP_USER_AGENT}\""
    ) > "${stat_file}"
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
