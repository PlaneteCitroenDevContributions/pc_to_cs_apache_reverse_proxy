#! /bin/bash

# $Id: filter-output.sh,v 1.4 2021/03/08 18:34:42 orba6563 Exp $

HERE=$( dirname "$0" )

#
# FIXME: the following code is a copy from filter-input
#         SHARE THE CODE
#
if [[ -n "${FILTER_DEBUG}" ]]
then
    set -x
    if [[ "${FILTER_DEBUG}" == "file" ]]
    then
	: ${DEBUG_ROOT_DIR:="${HERE}/DEBUG"}
	_debug_dir_="${DEBUG_ROOT_DIR}/debug_request_$( date '+%s' )"
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

response_file="/tmp/response.txt.$$"
corrected_response_file="/tmp/corrected_response.txt.$$"

cat - > "${response_file}"

if [[ -n "${trace_file}" ]]
then
    (
	echo '======================================================'
	date
	echo '------------------------------------------------------'
	export
	echo '======================================================'
	echo -n "ORIGINAL RESPONSE:"
	cat "${response_file}"
    ) >> "${trace_file}"
fi


case "${REQUEST_URI}" in
    "/elapseTime" )

	# force the response body
	echo -n '{"showCaptcha":false}' > "${corrected_response_file}"
	;;

    * )
	cp "${response_file}" "${corrected_response_file}"
	;;
esac

if [[ -n "${trace_file}" ]]
then
    (
	echo '++++++++++++++++++++++++++++++++++++>'
	echo -n "CORRECTED RESPONSE:"
	cat "${corrected_response_file}"
	echo '^^^^^^^^^^^^^^^^^^^^^^^^'
    ) >> "${trace_file}"
fi

cat "${corrected_response_file}"

if [[ -n "${_debug_dir_}" ]]
then
    cp "${response_file}" "${corrected_response_file}" "${_debug_dir_}"
fi

rm -f "${response_file}" "${corrected_response_file}"
