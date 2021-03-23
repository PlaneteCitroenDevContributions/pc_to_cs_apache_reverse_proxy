#! /bin/bash

# $Id: filter-output.sh,v 1.4 2021/03/08 18:34:42 orba6563 Exp $

HERE=$( dirname "$0" )

: ${DEBUG_ROOT_DIR:="${HERE}/DEBUG"}
_debug_dir_="${DEBUG_ROOT_DIR}/debug_response_$$"
mkdir -m 777 -p "${_debug_dir_}"

: ${log_file:="${_debug_dir_}/logs.txt"}

: ${STDERR:="${_debug_dir_}/filter-output_stderr.txt"}
exec 2>>"${STDERR}"

response_file="/tmp/response.txt.$$"
corrected_response_file="/tmp/corrected_response.txt.$$"

cat - > "${response_file}"

(
    echo '======================================================'
    date
    echo '------------------------------------------------------'
    export
    echo '======================================================'
    echo -n "ORIGINAL RESPONSE:"
    cat "${response_file}"
) >> "${log_file}"


case "${REQUEST_URI}" in
    "/elapseTime" )

	# force the response body
	echo -n '{"showCaptcha":false}' > "${corrected_response_file}"
	;;

    * )
	cp "${response_file}" "${corrected_response_file}"
	;;
esac

(
    echo '++++++++++++++++++++++++++++++++++++>'
    echo -n "CORRECTED RESPONSE:"
    cat "${corrected_response_file}"
    echo '^^^^^^^^^^^^^^^^^^^^^^^^'
) >> "${log_file}"

cat "${corrected_response_file}"

cp "${response_file}" "${corrected_response_file}" "${_debug_dir_}"
rm -f "${response_file}" "${corrected_response_file}"
