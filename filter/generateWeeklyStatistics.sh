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
	echo "Usage ${PGM_BASENAME} [-w|--week <week number>]"
	echo "	If week number is a negative integer, specifies a relative week number to current week number"
    ) 1>&2
    exit 1
}


while [[ -n "$1" ]]
do
     case "$1" in
	-w | --week )
	    shift
	    week_number_arg="$1"
	    ;;
	* )
	    Usage "bad arg: $1"
	    exit 1
	    ;;
     esac
     shift
done

#
# check if any mandatory arg has been provided
#
if [[ -z "${week_number_arg}" ]]
then
    Usage "missing args"
    exit 1
fi

#
# check arg consistency
#

if expr "${week_number_arg}" + 0 1>/dev/null 2>/dev/null
then
    :
else
    Usage "week number argument should be an integer"
    #NOT REACHED
fi

# TODO: if week number is negative, compute real week number

if [[ ${week_number_arg} -lt 0 ]]
then
    # compute a relative week number
    current_week_number=$( date '+%U' )
    abs_week_number=$(( ${current_week_number} + ${week_number_arg} ))
    if [[ ${abs_week_number} -lt 0 ]]
    then
	Usage "relative week number ${week_number_arg} is too large"
	#NOT REACHED
    else
	week_number=${abs_week_number}
    fi
else
    # its an absolute week number in [0..52]
    if [[ ${week_number_arg} -le 52 ]]
    then
	week_number=${week_number_arg}
    else
	Usage "week number should be in range [0..52]"
	#NOT REACHED
    fi
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
    #NOT REACHED
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
    param=${tab[2]}
    status=${tab[3]}
    real_ip=${tab[4]}
    user_agent=${tab[5]}

    pc_login=''
    doc_ref=''
    vin=''

    case "${action}" in

	"login" )
	    pc_login="${param}"
	    ;;

	"documentation" )
	    doc_ref="${param}"
	    ;;

	"vin" )
	    vin="${param}"
	    ;;

	*)
	    echo "ERROR: bas action ${action}" 1>&2
	    echo ">>>>> ${line}" 1>&2
	    ;;
    esac
      

    csv_date=$( date --date "@${epoch_time}" '+%d/%m/%Y %T' )
    echo "\"${csv_date}\";\"${action}\";\"${status}\";\"${pc_login}\";\"${doc_ref}\";\"${vin}\";\"${real_ip}\";\"${user_agent}\""

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
