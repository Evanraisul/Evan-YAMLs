#!/usr/bin/env bash
if [ ! -z "${IGNITE_SCRIPT_STRICT_MODE:-}" ]
then
    set -o nounset
    set -o errexit
    set -o pipefail
    set -o errtrace
    set -o functrace
fi

#
# Copyright (C) GridGain Systems. All Rights Reserved.
#  _________        _____ __________________        _____
#  __  ____/___________(_)______  /__  ____/______ ____(_)_______
#  _  / __  __  ___/__  / _  __  / _  / __  _  __ `/__  / __  __ \
#  / /_/ /  _  /    _  /  / /_/ /  / /_/ /  / /_/ / _  /  _  / / /
#  \____/   /_/     /_/   \_,__/   \____/   \__,_/  /_/   /_/ /_/
#

#
# GridGain Control Center agent configuration utility.
#

#
# Import common functions.
#
if [ "${IGNITE_HOME:-}" = "" ];
    then IGNITE_HOME_TMP="$(dirname "$(cd "$(dirname "$0")"; "pwd")")";
    else IGNITE_HOME_TMP=${IGNITE_HOME};
fi

#
# Set SCRIPTS_HOME - base path to scripts.
#
SCRIPTS_HOME="${IGNITE_HOME_TMP}/bin"

source "${SCRIPTS_HOME}"/include/functions.sh

#
# Discover path to Java executable and check it's version.
#
checkJava

#
# Discover IGNITE_HOME environment variable.
#
setIgniteHome

if [ "${DEFAULT_CONFIG:-}" == "" ]; then
    DEFAULT_CONFIG=config/default-config.xml
fi

#
# Set IGNITE_LIBS.
#
. "${SCRIPTS_HOME}"/include/setenv.sh
CP="${IGNITE_LIBS}:${IGNITE_HOME}/libs/optional/control-center-agent/*"

RANDOM_NUMBER=$("$JAVA" -cp "${CP}" org.apache.ignite.startup.cmdline.CommandLineRandomNumberGenerator)

RESTART_SUCCESS_FILE="${IGNITE_HOME}/work/ignite_success_${RANDOM_NUMBER}"
RESTART_SUCCESS_OPT="-DIGNITE_SUCCESS_FILE=${RESTART_SUCCESS_FILE}"

# Mac OS specific support to display correct name in the dock.
osname=`uname`

if [ "${DOCK_OPTS:-}" == "" ]; then
    DOCK_OPTS="-Xdock:name=Ignite Node"
fi

#
# JVM options. See http://java.sun.com/javase/technologies/hotspot/vmoptions.jsp for more details.
#
# ADD YOUR/CHANGE ADDITIONAL OPTIONS HERE
#
if [ -z "${MANAGEMENT_JVM_OPTS:-}" ] ; then
    if [[ `"$JAVA" -version 2>&1 | egrep "1\.[7]\."` ]]; then
        MANAGEMENT_JVM_OPTS="-Xms256m -Xmx1g"
    else
        MANAGEMENT_JVM_OPTS="-Xms256m -Xmx1g"
    fi
fi

#
# Uncomment to enable experimental commands [--wal]
#
# MANAGEMENT_JVM_OPTS="${MANAGEMENT_JVM_OPTS} -DIGNITE_ENABLE_EXPERIMENTAL_COMMAND=true"

#
# Uncomment the following GC settings if you see spikes in your throughput due to Garbage Collection.
#
# MANAGEMENT_JVM_OPTS="$MANAGEMENT_JVM_OPTS -XX:+UseG1GC"

#
# Uncomment if you get StackOverflowError.
# On 64 bit systems this value can be larger, e.g. -Xss16m
#
# MANAGEMENT_JVM_OPTS="${MANAGEMENT_JVM_OPTS} -Xss4m"

#
# Uncomment to set preference for IPv4 stack.
#
# MANAGEMENT_JVM_OPTS="${MANAGEMENT_JVM_OPTS} -Djava.net.preferIPv4Stack=true"

#
# Assertions are disabled by default since version 3.5.
# If you want to enable them - set 'ENABLE_ASSERTIONS' flag to '1'.
#
ENABLE_ASSERTIONS="0"

#
# Set '-ea' options if assertions are enabled.
#
if [ "${ENABLE_ASSERTIONS:-}" = "1" ]; then
    MANAGEMENT_JVM_OPTS="${MANAGEMENT_JVM_OPTS} -ea"
fi

#
# Set main class to start service (grid node by default).
#
if [ "${MAIN_CLASS:-}" = "" ]; then
    MAIN_CLASS=org.gridgain.control.agent.commandline.ManagementCommandHandler
fi

#
# Remote debugging (JPDA).
# Uncomment and change if remote debugging is required.
#
# MANAGEMENT_JVM_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8787 ${MANAGEMENT_JVM_OPTS}"

#
# Final MANAGEMENT_JVM_OPTS for Java 9+ compatibility
#
if [ $version -eq 8 ] ; then
    MANAGEMENT_JVM_OPTS="\
        -XX:+AggressiveOpts \
         ${MANAGEMENT_JVM_OPTS}"

elif [ $version -gt 8 ] && [ $version -lt 11 ]; then
    MANAGEMENT_JVM_OPTS="\
        -XX:+AggressiveOpts \
        --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \
        --add-exports=java.base/sun.nio.ch=ALL-UNNAMED \
        --add-exports=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
        --add-exports=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED \
        --add-exports=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED \
        --add-modules=java.xml.bind \
        ${MANAGEMENT_JVM_OPTS}"

elif [ $version -ge 11 ] ; then
     MANAGEMENT_JVM_OPTS="\
         --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
         --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
         --add-opens=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
         --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED \
         --add-opens=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED \
         --add-opens=java.base/java.nio=ALL-UNNAMED \
         --add-opens=jdk.management/com.sun.management.internal=ALL-UNNAMED \
         --add-opens=java.base/java.io=ALL-UNNAMED \
         --add-opens=java.base/java.util=ALL-UNNAMED \
         --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
         --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED \
         --add-opens=java.base/java.lang=ALL-UNNAMED \
         --add-opens=java.base/java.time=ALL-UNNAMED \
        ${MANAGEMENT_JVM_OPTS}"
fi

if [ $version -gt 8 ] && [ $version -lt 17 ]; then
    MANAGEMENT_JVM_OPTS="\
         --illegal-access=permit \
         ${MANAGEMENT_JVM_OPTS}"
fi

ERRORCODE="-1"

while [ "${ERRORCODE}" -ne "130" ]
do
    if [ "${INTERACTIVE:-}" == "1" ] ; then
        case $osname in
            Darwin*)
                "$JAVA" ${MANAGEMENT_JVM_OPTS} ${QUIET:-} "${DOCK_OPTS}" "${RESTART_SUCCESS_OPT}" \
                -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="${IGNITE_HOME}" \
                -DIGNITE_PROG_NAME="$0" ${JVM_XOPTS:-} -cp "${CP}" ${MAIN_CLASS} $@
            ;;
            *)
                "$JAVA" ${MANAGEMENT_JVM_OPTS} ${QUIET:-} "${RESTART_SUCCESS_OPT}" \
                -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="${IGNITE_HOME}" \
                -DIGNITE_PROG_NAME="$0" ${JVM_XOPTS:-} -cp "${CP}" ${MAIN_CLASS} $@
            ;;
        esac
    else
        case $osname in
            Darwin*)
                "$JAVA" ${MANAGEMENT_JVM_OPTS} ${QUIET:-} "${DOCK_OPTS}" "${RESTART_SUCCESS_OPT}" \
                 -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="${IGNITE_HOME}" \
                 -DIGNITE_PROG_NAME="$0" ${JVM_XOPTS:-} -cp "${CP}" ${MAIN_CLASS} $@
            ;;
            *)
                "$JAVA" ${MANAGEMENT_JVM_OPTS} ${QUIET:-} "${RESTART_SUCCESS_OPT}" \
                 -DIGNITE_UPDATE_NOTIFIER=false -DIGNITE_HOME="${IGNITE_HOME}" \
                 -DIGNITE_PROG_NAME="$0" ${JVM_XOPTS:-} -cp "${CP}" ${MAIN_CLASS} $@
            ;;
        esac
    fi

    ERRORCODE="$?"

    if [ ! -f "${RESTART_SUCCESS_FILE}" ] ; then
        break
    else
        rm -f "${RESTART_SUCCESS_FILE}"
    fi
done

if [ -f "${RESTART_SUCCESS_FILE}" ] ; then
    rm -f "${RESTART_SUCCESS_FILE}"
fi
