#!/bin/bash

## SETTINGS ##
NUMBER_OF_TIMES_TO_RUN_EACH_JOB=3
export TEST_SIZE="4096m"
export TEST_FILENAME="fio_test_file"
export IO_DEPTH="256"

# get time and create results folder
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
TIME=`date +%H%M`
RESULT_PATH="./results/${YEAR}${MONTH}${DAY}_${TIME}"
mkdir -p ${RESULT_PATH}

usage()
{
    echo "Usage: $0: [OPTIONS]"
    echo "  -u              : Directory/mountpoint to test"
    echo "  -s              : Test file size (default: 4G)"
    echo "  -i              : I/O depth (used by fio) (default: 256 - heavy)" 
    echo "  -n              : Test name (used for the comparaison)"
    echo ""
    echo "Example:"
    echo "  $0 -u /mnt/nfs/ -s 4G -i 256 -n nfs_raid10"
    exit 1
}

log()
{
    echo $1 | tee -a ${RESULT_PATH}/output.log
}

sysinfo()
{
  mkdir -p ${RESULT_PATH}/sysinfo

  for proc in cpuinfo meminfo mounts modules version
  do
    cat /proc/$proc > ${RESULT_PATH}/sysinfo/$proc
  done

  for cmd in dmesg env lscpu lsmod lspci dmidecode free
  do
    $cmd > ${RESULT_PATH}/sysinfo/$cmd
  done
}


launch_fio()
{
  log "===> FIO TESTS: START (`date +%H:%M:%S`)"
  COUNTER=1
  until [ $COUNTER -gt $NUMBER_OF_TIMES_TO_RUN_EACH_JOB ]; do
    for t in `ls -1 enabled-tests/`
    do
      log "===================="
        log "Running: ${t}"
        log "Pass Number: ${COUNTER}"
        log "Test Size: ${TEST_SIZE}"
        touch ${RESULT_PATH}/${TIME}-${t}-pass-${COUNTER}
        fio --output=${RESULT_PATH}/${TIME}-${t}-pass-${COUNTER} ./enabled-tests/${t}
      log ""
    done
    let COUNTER+=1
  done
  log "===> FIO TESTS: END (`date +%H:%M:%S`)"
}

launch_iozone()
{
  log "===> IOZONE TESTS: START (`date +%H:%M:%S`)"
  if [ `grep ${TEST_DIRECTORY} /etc/fstab` ]; then
    iozone -a -R -c -U ${TEST_DIRECTORY} -f ${TEST_DIRECTORY}/${TEST_FILENAME} -b ${RESULT_PATH}/iozone.xls
  else
    iozone -a -R -c -f ${TEST_DIRECTORY}/${TEST_FILENAME} -b ${RESULT_PATH}/iozone.xls
  fi
  log "===> IOZONE TESTS: END (`date +%H:%M:%S`)"

}

launch_bonnie()
{
  bonnie++ -q -u `whoami` -d ${TEST_DIRECTORY}/ -m ${NAME} -n 256 > ${RESULT_PATH}/bonnie.csv
}

check_apps()
{
  for app in iozone fio dmidecode bonnie++
  do
    if [ ! "`which $app`" ]; then
        echo "ERROR: '$app' application is required."
        EXIT=1
    fi
  done

  if [ "$EXIT" == "1" ]; then
    echo "Please install the above application(s) then re-run the script."
    exit $EXIT
  fi
}

results()
{
  tar cfz results.${YEAR}${MONTH}${DAY}_${TIME}.tar.gz ${RESULT_PATH}/
  log "Results: results.${YEAR}${MONTH}${DAY}_${TIME}.tar.gz"
}

while getopts 'u:s:i:n:' OPTION
do
    case ${OPTION} in
    u)
        export TEST_DIRECTORY="${OPTARG}"
        ;;
    s)
        export TEST_SIZE="${OPTARG}"
        ;;
    i)
        export IO_DEPTH="${OPTARG}"
        ;;
    n)
        export TEST_NAME="${OPTARG}"
        ;;
    ?)
        usage
        ;;
    esac
done

# mandatory parameters
if [ ! "${TEST_DIRECTORY}" ] || [ ! "${TEST_SIZE}" ] || [ ! "${IO_DEPTH}" ] || [ ! "${TEST_NAME}" ]; then
    usage
fi

# first, check that all applications are installed on the system
check_apps

# collect system information
sysinfo

# start the tests
log "Start: `date +%H:%M:%S`"
launch_fio
launch_iozone
launch_bonnie++
log "Done: `date +%H:%M:%S`"

# prepare the result tar.gz
results

exit 0
