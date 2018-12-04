#!/bin/bash

getopt ()
{

while [ $# -gt 0 ]
do

      case $1 in
                  [-][Jj][Pp][Gg]|[Jj][Pp][Gg] ) OTYPE=JPG    ; PASSED_PARMS="${PASSED_PARMS} -jpg" ;;
                  [-][Pp][Dd][Ff]|[Pp][Dd][Ff] ) OTYPE=PDF    ; PASSED_PARMS="${PASSED_PARMS} -pdf" ;;
                                  [-][Pp]|[Pp] ) MODE=PROCESS ; PASSED_PARMS="${PASSED_PARMS} -p" ;;
                                  [-][Cc]|[Cc] ) MODE=COLLECT ; PASSED_PARMS="${PASSED_PARMS} -c" ;;
         20[0-9][0-9]0[1-9]|20[0-9][0-9]1[012] ) YEARMONTH=$1 ; PASSED_PARMS="${PASSED_PARMS} $1" ;;
                            [012][0-9]|[3][01] ) DAY=$1       ; PASSED_PARMS="${PASSED_PARMS} $1" ;;
                          [-][Ll][Cc]|[Ll][Cc] ) HOST=LIST ; set_customer ; exit  ;;
                                     [A-Za-z]* )
                                                MATCH=`grep -c -i -e $1 /etc/hosts` ; MATCH=${MATCH:-0}
                                                if [ ${MATCH} -eq 0 ]
                                                   then
                                                        echo -e "\n\tCannot find $1 in /etc/hosts\n" ; Print_Usage
                                                   else
                                                        HOST=$1 ; PASSED_PARMS="${PASSED_PARMS} $1" 
                                                fi ;;
                      [-][Hh]|[Hh]|[Hh][Ee][Ll][Pp]|[?]|[-][Hh][Ee][Ll][Pp] ) Print_Usage ;;
                                                                          * ) Print_Usage ;;
      esac
shift

done
YEARMONTH=${YEARMONTH:-None}
DAY=${DAY:-None}
case ${YEARMONTH} in
        None ) echo -e "\n\tYou must pass a valid Year Month <yyyymm>" ; Print_Usage ;;
esac
case ${DAY} in
        None ) echo -e "\n\tYou must pass a valid Day <dd>" ; Print_Usage ;;
esac 
MODE=${MODE:-ALL}
OTYPE=${OTYPE:-JPG}
}
Print_Usage ()
{
echo "
  Process a sar file from a given host using Ksar

Usage: ${filename} <host> <yyyymm> <dd> <c|p|lc|pdf|jpg>

          <host> = Process on this host a valid host found in /etc/hosts
        <yyyymm> = Sar file for this year and month
            <dd> = Sar file for this day for above year and month
            <lc> = List Valid customer strings found in /etc/hosts
             <c> = Collect sar file only.
             <p> = Process collected sar file only.
                   Default = collect and process
           <pdf> = Process output as a pdf file. 
           <jpg> = Process output as a jpg file. (Default)

"
exit
}
set_customer ()
{
HOST=${HOST:-None}

DEFAULT_CUST_STRING=`cat $SNODES|grep -v -e '#'|awk '{print $4}'|grep -v '#'|sort|uniq|tr -s "\012" "\040"`
case ${HOST} in

                     LIST ) echo -e "\n\tValid Customer Labels: ${DEFAULT_CUST_STRING}\n" ; return ;;
                     None ) echo -e "\nYou have to pass a valid host to be able to assign a Customer Name." ; exit ;;
                        * ) CUST=`grep -iw -e ${HOST} $SNODES|awk '{print $4}'` ; CUST=${CUST:-none}
                            case ${CUST} in
                                    none ) echo -e "\nCannot determine the 3 Character Customer Name for: ${HOST}"         ; exit ;;
                            esac ;;
esac 
echo -e "\n\tCustomer Name for: ${HOST} is: ${CUST}" 
}
collect ()
{
#
# Run sar -A -f on the sar file on the server redirect text ouptut to jmp server
echo -e "\nCreating SAR Text file: ${TEXTFILE}"
case ${CUST} in
     SOT )  set -x ; ssh runner@${HOST} -n "sudo LC_ALL=C sar -A -f /var/log/sa/sa${DAY} > /tmp/sarsa${DAY}.txt"
            scp runner@${HOST}:/tmp/sarsa${DAY}.txt ${TEXTFILE} ; chmod 744 ${TEXTFILE} ; set +x ;;
       * )  set -x ; ${sshnh} ${HOST} -n "LC_ALL=C sar -A -f /var/log/sa/sa${DAY} > /tmp/sarsa${DAY}.txt"
            ${scpnh} @${HOST}:/tmp/sarsa${DAY}.txt ${TEXTFILE} ; chmod 744 ${TEXTFILE} ; set +x ;;
esac
if [ ! -s ${TEXTFILE} ] || [ ! -f ${TEXTFILE} ]
   then
       echo "No return from ${HOST} for: ${YEARMONTH}${DAY}" >> ${RETURNLOG}
       echo -e "\n\tInput sar text file zero lenght or does not exist, removing." 
       rm ${TEXTFILE} 2>/dev/null ; rm -r ${WEBDIR} 2>/dev/null
fi

}
process ()
{
#
if [ ! -s ${TEXTFILE} ] || [ ! -f ${TEXTFILE} ]
   then
       echo "No return from ${HOST} for: ${YEARMONTH}${DAY}" >> ${RETURNLOG}
       echo -e "\n\tInput sar text file zero lenght or does not exist. Cannot process." ; return
fi
case ${OTYPE} in
       JPG )
             set -x ; java -jar ${KSARDIR}/kSar.jar -showCPUstacked -showMEMstacked -graph "all-cpu LinuxioSar LinuxswapSar LinuxloadSar LinuxpgpSar LinuxkbmemSar eth0-if1 eth0-if2" -input ${TEXTFILE} -outputJPG ${WEBDIR}/${HOST} -addHTML ; set +x
             mv ${WEBDIR}/${HOST}_index.html ${WEBDIR}/${HOST}-SAR-Report.html
             sed -i -e "/<\/HEAD>/i  <H2 style=\"text-align: center;\">${HOST} ${PRETTYDATE}<\/H2>" ${WEBDIR}/${HOST}-SAR-Report.html
             ;;
       PDF )
             set -x ; java -jar ${KSARDIR}/kSar.jar -showCPUstacked -showMEMstacked -graph "all-cpu LinuxioSar LinuxswapSar LinuxloadSar LinuxpgpSar LinuxkbmemSar eth0-if1 eth0-if2" -input ${TEXTFILE} -outputPDF ${PDFFILE}  ; set +x ;;

esac
}
################################################################
# MAIN
################################################################
filename=$0
getopt $*
SNODES=/var/www/html/supported_nodes.txt
set_customer
export KSARDIR=/root/ksar/kSar-5.0.6
export JAVA_HOME="/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0/jre"
NOTIFY='timothy.dorian@capgemini.com,ernie.viens@capgemini.com'
PRETTYDATE=`date -d ${YEARMONTH}${DAY} "+%A, %B %d, %Y"`

RETURNLOG="/tmp/no_sar_returns" 

rssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o ConnectionAttempts=2 -l root'
scpnh='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
sshnh='ssh -x -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o ConnectionAttempts=2'

DIRPDATE=`date -d ${YEARMONTH}${DAY} "+%B-%d-%Y"`

WEBDIR="/var/www/html/SAR/${CUST}/${HOST}/${YEARMONTH}${DAY}-${DIRPDATE}"
TEXTFILE="${WEBDIR}/sar-${HOST}-${YEARMONTH}${DAY}.txt"
PDFFILE=${WEBDIR}/System-Activity-Report-${HOST}-`date -d ${YEARMONTH}${DAY} "+%A-%B-%d-%Y"`.pdf
if [ ! -d ${WEBDIR} ];then mkdir -p ${WEBDIR};fi

case ${MODE} in
      COLLECT ) collect ;;
      PROCESS ) process ;;
          ALL ) collect ; process ;;
esac
