#!/bin/sh
# Test whether the flies server is up.

function print_usage(){
    cat << END
Usage: $0 [-i interval] [-r retries] [-p up_pattern] [-v verboseLevel] <FLIES_SERVER_URL>
       $0 -h

FLIES_SERVER_URL: URL to flise server

Options:
    -h: Show usage
    -i: Interval between retries in seconds
    -r: Times of retries.
    -p: Grep-like patten to be captured.
    -v: VerboseLevel (Default is 1)
        0: Nothing is output
	1: Only the final results
	2: Print result for each check.
	3: wget message as well.

Return value:
    0: Flies server is up eventually.
    1: Flies server is still down after the retries.
END
}

function check_connection(){
    DOWNLOAD_FILE=index.html.tmp
    if [ $VERBOSE -lt 3 ]; then
	QUIET="-q"
    else
	QUIET=""
    fi
    wget ${QUIET} -O $DOWNLOAD_FILE $FLIES_SERVER_URL
    if grep $UP_PATTERN $DOWNLOAD_FILE; then
	UP=1
	if [ $VERBOSE -ge 1 ]; then
	    echo "Flies server on $FLIES_SERVER_URL is [UP]"
	fi
    else
	UP=0
	if [ $VERBOSE -ge 2 ]; then
	    echo "Flies server on $FLIES_SERVER_URL is [DOWN]"
	fi
    fi

    rm -f $DOWNLOAD_FILE

    if [ "$UP" = "0" ];then
	return 1
    fi
    return 0;
}

UP_PATTERN='<h1>Welcome'

# Retry interval: Default: 30 sec
INTERVAL=30
RETRIES=5
VERBOSE=1

while getopts "hi:r:p:v:" opt; do
    case $opt in
	h)
	    print_usage
	    exit 0
	    ;;
	i)
	    INTERVAL=$OPTARG
	    ;;
	r)
	    RETRIES=$OPTARG
	    ;;
	p)
	    UP_PATTERN=$OPTARG
	    ;;
	v)
	    VERBOSE=$OPTARG
	    ;;
	*)
	    ;;
    esac
done
shift $((OPTIND-1));

FLIES_SERVER_URL=$1

if [ -z $FLIES_SERVER_URL ]; then
    print_usage
    exit -1
fi

DOWNLOAD_FILE=index.html.tmp


if check_connection; then
    exit 0;
fi

retries=0
up=0
until [ "$retries" = "$RETRIES" ]; do
    let retries++
    echo "retries $retries in $INTERVAL seconds"
    sleep $INTERVAL
    if check_connection; then
	exit 0;
    fi
done
if [ $VERBOSE -ge 1 ]; then
    echo "Flies server on $FLIES_SERVER_URL is still [DOWN] after $retries retries"
fi
exit 1;
