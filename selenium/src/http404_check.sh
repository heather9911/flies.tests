#!/bin/sh
# http404_check.sh
if [ -z ${FLIES_URL} ];then
    source ./test.cfg
fi
export FLIES_URL
export PRIVILEGE_TEST_ROOT
export HTTP_404_CHECK_RESULT
perl http404_check.perl

