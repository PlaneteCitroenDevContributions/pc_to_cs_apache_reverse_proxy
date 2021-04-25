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

if expr "${week_number}" + 0 1>/dev/null 2>/dev/null
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
    Usage "could not acces stat folder \"${STAT_DATA_DIR}\""
    exit 1
fi

#
# Get all files of the week
#

# example file name: stat_Y=2021=Y_M=03=M_D=24=D_d=3=d_W=12=W_156.txt
all_stat_files=$(
    ls -1 "${STAT_DATA_DIR}/"stat_Y=${STATS_FOR_YEAR}=Y*W=${week_number}=W*.txt 2>/dev/null
)

generateCSVStatLine ()
{
    # sample line:
    # "1616779865" "bernhara" "login" "success" "90.8.128.173" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36"
    
    line="$@"
    # echo ">>>>>>>>>>>>>>>>>>>>>${line}<<<<<<<<<<<<<<<<<<<<<"

    protected_line=$(
	echo "${line}" | \
	    sed \
		-e "s/^\"/'/" \
		-e "s/\" \"/' '/g" \
		-e "s/\"$/'/"
   )
    
    # echo ">>>>>>>>>>>>>>>>>>>>>${protected_line}<<<<<<<<<<<<<<<<<<<<<"

    # FIXME: eval should ne be required
    eval declare -a tab=( "${protected_line}" )

    epoch_time=${tab[0]}
    action=${tab[1]}
    param=${tab[1]}
    status=${tab[3]}
    real_ip=${tab[4]}
    user_agent=${tab[5]}

    case "${action}" in

	"login" )
	    pc_login="${param}"
	    ;;

	"documentation" )
	    doc_ref="${param}"
	    ;;

	"vin_select" )
	    vin="${param}"
	    ;;

	*)
	    echo "ERROR: bas action ${action}" 1>&2
	    ;;
    esac
      

    csv_date=$( date --date "@${epoch_time}" '+%x %T' )
    echo "\"${csv_date}\";\"${action}\";\"${status}\";\"${pc_login}\";\"${doc_ref}\";\"${VIN}\";\"${real_ip}\";\"${user_agent}\""

}

#
# generate CSV file
#

echo '"Date";"Action";"Status";"login PC";"Reference Document";"VIN";"Adresse IP";"Navigateur"'

sort \
    --numeric-sort \
    --key=1 \
    -o /tmp/starts_sorted.txt \
    ${all_stat_files}

cat /tmp/starts_sorted.txt | \
    while read -r line
    do
	generateCSVStatLine "${line}"
    done
