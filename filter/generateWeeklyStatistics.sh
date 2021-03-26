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
# Check the folder containing the stats
# =====================================

: ${STAT_DATA_DIR:="/var/pc_stats"}

if [[ -d "${STAT_DATA_DIR}" && -d "${STAT_DATA_DIR}" ]]
then
    :
else
    Usage "ERROR: could not acces stat folder \"${STAT_DATA_DIR}\""
    exit 1
fi

#
# Get all files of the week
#

# example file name: stat_Y=2021=Y_M=03=M_D=24=D_d=3=d_W=12=W_156.txt
all_stat_files=$(
    ls -1 "${STAT_DATA_DIR}/stat_Y=${STATS_FOR_YEAR}=Y*W=${week_number}=W*.txt"
)


exit 1

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

