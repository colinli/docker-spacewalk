#!/bin/bash
#
# Copyright (c) 2010--2015 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#

if [ 0$UID -gt 0 ]; then
    echo "$0 has to be run as root."
    exit 1
fi

LOG=/var/log/rhn/rhn_hostname_rename.log
RHN_CONF_FILE=/etc/rhn/rhn.conf
SSL_BUILD_DIR=/root/ssl-build
ETC_JABBERD_DIR=/etc/jabberd
HTTP_PUB_DIR=/var/www/html/pub/
BOOTSTRAP_SH=/var/www/html/pub/bootstrap/bootstrap.sh
BOOTSTRAP_CCO=/var/www/html/pub/bootstrap/client-config-overrides.txt
SAT_LOCAL_RULES_CONF=/var/lib/rhn/rhn-satellite-prep/satellite-local-rules.conf
BACKUP_EXT=.rnmbck
CA_CERT_TRUST_DIR=/etc/pki/ca-trust/source/anchors
HOSTNAME=$1

DB_BACKEND="$(spacewalk-cfg-get db_backend)"
if [ "$DB_BACKEND" = "oracle" ]; then
    DBSHELL_QUIT="QUIT"
    DBSHELL_QUIET="
set feed off;
set pages 0;"

    if [ -x /etc/init.d/oracle ]; then
        DB_SERVICE="oracle"
    fi

elif [ "$DB_BACKEND" = "postgresql" ]; then
    DBSHELL_QUIT="\q"
    DBSHELL_QUIET="
\set QUIET on
\t"
    if [ -x /etc/init.d/postgresql -o -f /usr/lib/systemd/system/postgresql.service ]; then
        DB_SERVICE="postgresql"
    fi
    if [ -x /etc/init.d/postgresql92-postgresql ]; then
        DB_SERVICE="postgresql92-postgresql"
    fi
fi

ORACLE_XE_LISTENER_ORA_FILE=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/network/admin/listener.ora
ORACLE_XE_TNSNAMES_ORA_FILE=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/network/admin/tnsnames.ora

SPW_SETUP_JABBERD=/usr/bin/spacewalk-setup-jabberd

IPV4ADDR_REGEX="^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$"
IPV6ADDR_REGEX="^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$"
IPADDR_REGEX="($IPV4ADDR_REGEX)|($IPV6ADDR_REGEX)"

###############################################################################

function echo_usage {
    echo "Usage:"
    echo "   $(basename $0) <IP_ADDRESS> [ --ssl-country=<SSL_COUNTRY> --ssl-state=<SSL_STATE> --ssl-org=<SSL_ORG> --ssl-orgunit=<SSL_ORGUNIT> --ssl-email=<SSL_EMAIL> --ssl-ca-password=<SSL_CA_PASSWORD>]"
    echo "   $(basename $0) { -h | --help }"
    exit 1
}

function echo_err {
    echo "$*" >&2
    echo "$*" >> $LOG
}

function bye {
    echo_err "Fix the problem and run $0 again"
    exit 1
}

function print_status {
    # strip whitespace
    STATUS="${1#"${1%%[![:space:]]*}"}"
    if [ "$STATUS" == "0" ]
    then
        echo "OK" | tee -a $LOG
    else
        echo_err "FAILED"
        shift
        echo_err $*
        bye
    fi
}

function check_input_ip {
   return 0
}

function initial_system_hostname_check {
    return 0
}

function backup_file {
    if [ -e ${1} ]
    then
        cp ${1} ${1}${BACKUP_EXT}
    else
        echo "Backup of ${1} failed. File not found." >> $LOG
    fi
}

function update_rhn_conf {
    backup_file ${SAT_LOCAL_RULES_CONF}
    # store config to satellite-local-rules.conf
    /usr/bin/rhn-config-satellite.pl \
       --target=${SAT_LOCAL_RULES_CONF} \
       --option=jabberDOThostname=$HOSTNAME \
       --option=cobblerDOThost=$HOSTNAME \
       >> $LOG 2>&1
    # but do not deploy (we'd lose actual configuration)
    # /usr/bin/satcon-deploy-tree.pl \
    #    --source=/var/lib/rhn/rhn-satellite-prep/etc
    #    --dest=/etc
    #    --conf=$SAT_LOCAL_RULES_CONF
    #    >> $LOG 2>&1
    backup_file ${RHN_CONF_FILE}
    /usr/bin/rhn-config-satellite.pl \
        --target=${RHN_CONF_FILE} \
        --option=server.jabber_server=$HOSTNAME \
        --option=osa-dispatcher.jabber_server=$HOSTNAME \
        --option=cobbler.host=$HOSTNAME >> $LOG 2>&1
}

function re-generate_server_ssl_certificate {
    # default is to generate new SSL certificate
    GEN_NEW_SSL="y"

    ACTUAL_SSL_KEY_PAIR_PACKAGE=$(rpm -qa 'rhn-org-httpd-ssl-key-pair*')
    if [ -n "$ACTUAL_SSL_KEY_PAIR_PACKAGE" ]
    then
        echo "Actual SSL key pair package: $ACTUAL_SSL_KEY_PAIR_PACKAGE" | tee -a $LOG

        ACTUAL_CERT_FILES=$(rpm -ql $ACTUAL_SSL_KEY_PAIR_PACKAGE)
        for cert_file in $ACTUAL_CERT_FILES
        do
            if [[ "$cert_file" =~ \.crt ]]
            then
                CERT_FILE="$cert_file"
                # SUBJECT=`openssl x509 -in $CERT_FILE -noout -subject`
                SUBJECT=`grep "Subject:" $CERT_FILE`
            fi
            # [[ "$cert_file" =~ \.key ]] && CERT_KEY_FILE="$cert_file"
            # [[ "$cert_file" =~ \.scr ]] && CERT_REQ_FILE="$cert_file"
        done

        if [ ! -n "$CML_NEW_SSL_CERT_REQUEST" ]
        then
            # Common Name is prefilled by actuall HOSTNAME
            HOSTNAME_CERT=`awk "/Subject:/ && /, CN=$HOSTNAME\//" $CERT_FILE`
            if [ -n "$HOSTNAME_CERT" ]
            then
                echo " No need to re-generate SSL certificate." | tee -a $LOG
                GEN_NEW_SSL="n"
            fi
        fi
    fi

    # is there a need to re-generate SSL certificate?
    if [ -n "$CML_NEW_SSL_CERT_REQUEST" -o "$GEN_NEW_SSL" == "y" ]
    then
        if [ -n "$SUBJECT" ]
        then
            SUBJECT_PATTERN='[[:space:]]*Subject: C=\(..*\), ST=\(..*\), O=\(..*\), OU=\(..*\), CN=\(..*\)\/emailAddress=\(..*\)'
            SSL_COUNTRY_OLD=`echo $SUBJECT | sed "s/$SUBJECT_PATTERN/\1/"`
            SSL_STATE_OLD=`echo $SUBJECT | sed "s/$SUBJECT_PATTERN/\2/"`
            SSL_ORG_OLD=`echo $SUBJECT | sed "s/$SUBJECT_PATTERN/\3/"`
            SSL_ORGUNIT_OLD=`echo $SUBJECT | sed "s/$SUBJECT_PATTERN/\4/"`
            SSL_EMAIL_OLD=`echo $SUBJECT | sed "s/$SUBJECT_PATTERN/\6/"`
        fi

        echo "Starting generation of new SSL certificate:"
        # COUNTRY
        if [ -n "${CML_SSL_COUNTRY+x}" ]
        then
            SSL_COUNTRY=${CML_SSL_COUNTRY}
        else
            read -e -p " Enter Country [$SSL_COUNTRY_OLD] : "
            SSL_COUNTRY=${REPLY:-$SSL_COUNTRY_OLD}
        fi
        # STATE
        if [ -n "${CML_SSL_STATE+x}" ]
        then
            SSL_STATE=${CML_SSL_STATE}
        else
            read -e -p " Enter State [$SSL_STATE_OLD] : "
            SSL_STATE=${REPLY:-$SSL_STATE_OLD}
        fi
        # ORGANIZATION
        if [ -n "${CML_SSL_ORG+x}" ]
        then
            SSL_ORG=${CML_SSL_ORG}
        else
            read -e -p " Enter Organization [$SSL_ORG_OLD] : "
            SSL_ORG=${REPLY:-$SSL_ORG_OLD}
        fi
        # ORGANIZATION UNIT
        if [ -n "${CML_SSL_ORGUNIT+x}" ]
        then
            SSL_ORGUNIT=${CML_SSL_ORGUNIT}
        else
            # offer hostname as ORG UNIT everytime
            read -e -p " Enter Organization Unit [$HOSTNAME] : "
            SSL_ORGUNIT=${REPLY:-$HOSTNAME}
        fi
        # EMAIL ADDRESS
        if [ -n "${CML_SSL_EMAIL+x}" ]
        then
            SSL_EMAIL=${CML_SSL_EMAIL}
        else
            read -e -p " Enter Email Address [$SSL_EMAIL_OLD] : "
            SSL_EMAIL=${REPLY:-$SSL_EMAIL_OLD}
        fi
        # CA PASSWORD
        # ask explicitelly (different behaviour on sat and spw)
        if [ -n "${CML_SSL_CA_PASSWORD+x}" ]
        then
            SSL_CA_PASSWORD=${CML_SSL_CA_PASSWORD}
        else
            read -e -p " Enter CA password : " -s
            echo
            SSL_CA_PASSWORD=${REPLY}
        fi

        echo " Generating SSL certificates:" | tee -a $LOG
        # just log the SSL info ...
        echo "rhn-ssl-tool --gen-ca --force \
            --dir="$SSL_BUILD_DIR" \
            --set-country="$SSL_COUNTRY" \
            --set-state="$SSL_STATE" \
            --set-org="$SSL_ORG" \
            --set-org-unit="$SSL_ORGUNIT" \
            --set-common-name="${HOSTNAME}" \
        " >> $LOG
        rhn-ssl-tool --gen-ca --force \
            --dir="$SSL_BUILD_DIR" \
            --set-country="$SSL_COUNTRY" \
            --set-state="$SSL_STATE" \
            --set-org="$SSL_ORG" \
            --set-org-unit="$SSL_ORGUNIT" \
            --set-common-name="${HOSTNAME}" \
            --password="$SSL_CA_PASSWORD" \
            2>>$LOG
        echo "rhn-ssl-tool --gen-server \
            --dir="$SSL_BUILD_DIR" \
            --set-country="$SSL_COUNTRY" \
            --set-state="$SSL_STATE" \
            --set-org="$SSL_ORG" \
            --set-org-unit="$SSL_ORGUNIT" \
            --set-email="$SSL_EMAIL" \
            --set-hostname="${HOSTNAME}" \
        " >> $LOG
        SSL_KEY_PAIR_RPM=`rhn-ssl-tool --gen-server \
            --dir="$SSL_BUILD_DIR" \
            --set-country="$SSL_COUNTRY" \
            --set-state="$SSL_STATE" \
            --set-org="$SSL_ORG" \
            --set-org-unit="$SSL_ORGUNIT" \
            --set-email="$SSL_EMAIL" \
            --set-hostname="${HOSTNAME}" \
            --password="$SSL_CA_PASSWORD" \
            2>>$LOG | grep noarch.rpm`

        if [ ! -n "$SSL_KEY_PAIR_RPM" ]
        then
            echo_err "Wrong SSL information provided. Check $LOG for more information." | tee -a $LOG
            bye
        fi

        if [ -n "$ACTUAL_SSL_KEY_PAIR_PACKAGE" ]
        then
            echo -n "Removing old SSL certificate ($ACTUAL_SSL_KEY_PAIR_PACKAGE) ... " | tee -a $LOG
            rpm -e $ACTUAL_SSL_KEY_PAIR_PACKAGE
            print_status $?
        fi

        echo -n "Installing new SSL certificate ($(basename $SSL_KEY_PAIR_RPM)) ... " | tee -a $LOG
        rpm -Uh $SSL_KEY_PAIR_RPM >>$LOG
        print_status $?

        echo -n "Making new SSL certificate publicly available ... " | tee -a $LOG
        /usr/bin/rhn-deploy-ca-cert.pl --source-dir=$SSL_BUILD_DIR --target-dir=$HTTP_PUB_DIR --trust-dir=$CA_CERT_TRUST_DIR
        print_status $?

        # copy jabberd certificate, too
        echo -n "Deploying jabberd certificate ... " | tee -a $LOG
        NEW_SSL_KEY_PAIR_PACKAGE=$(rpm -qa 'rhn-org-httpd-ssl-key-pair*')
        JABBERD_CERTIFICATE=$(rpm -ql $NEW_SSL_KEY_PAIR_PACKAGE | grep jabberd)
        if [ -e "$JABBERD_CERTIFICATE" ]
        then
            \cp -f $JABBERD_CERTIFICATE $ETC_JABBERD_DIR/
            print_status $?
        else
            print_status 1
        fi
    fi
}

###############################################################################

echo "[$(date)]: $0 $*" >> $LOG

while [ $# -ge 1 ]; do
    if [[ "$1" =~ $IPADDR_REGEX ]]; then
        IP=$1
        shift
        continue
    fi

    case $1 in
            --help | -h)  echo_usage;;

            --ssl-country=*) CML_SSL_COUNTRY=$(echo $1 | cut -d= -f2-);;
            --ssl-state=*) CML_SSL_STATE=$(echo $1 | cut -d= -f2-);;
            --ssl-org=*) CML_SSL_ORG=$(echo $1 | cut -d= -f2-);;
            --ssl-orgunit=*) CML_SSL_ORGUNIT=$(echo $1 | cut -d= -f2-);;
            --ssl-email=*) CML_SSL_EMAIL=$(echo $1 | cut -d= -f2-);;

            --ssl-ca-password=*) CML_SSL_CA_PASSWORD=$(echo $1 | cut -d= -f2-);;
            *) echo_err "Error: Invalid option $1"
               echo_usage;;
    esac
    shift
done

if [ -n "${IP}" ]
then
    echo -n "Validating IP ... " | tee -a $LOG
    check_input_ip $IP
    print_status $? "IP $IP is not your valid IP address."
else
    echo_err "Missing <hostname> argument."
    echo_usage
fi

# if the user has set one of these params,
# he wants to re-generate SSL certificate
for ssl_var in ${CML_SSL_COUNTRY} ${CML_SSL_STATE} ${CML_SSL_ORG} ${CML_SSL_ORGUNIT} ${CML_SSL_EMAIL} ${CML_SSL_CA_PASSWORD}
do
    [ -n "${ssl_var}" ] && CML_NEW_SSL_CERT_REQUEST=1
done

echo "=============================================" | tee -a $LOG
echo "hostname: $HOSTNAME" | tee -a $LOG
echo "=============================================" | tee -a $LOG

initial_system_hostname_check || bye

# stop services
echo -n "Stopping spacewalk services ... " | tee -a $LOG
/usr/sbin/spacewalk-service stop >> $LOG 2>&1
if [ "$DB_SERVICE" != "" ]
then
    /sbin/service $DB_SERVICE start >> $LOG 2>&1
fi
print_status 0  # just simulate end

echo -n "Testing DB connection ... " | tee -a $LOG
# for spacewalk only:
if [ -e "$ORACLE_XE_LISTENER_ORA_FILE" ]
then
    sed -i$BACKUP_EXT "s/\(.*(HOST[[:space:]]*=[[:space:]]*\)[^)]*\().*$\)/\1$HOSTNAME\2/" $ORACLE_XE_LISTENER_ORA_FILE
fi
if [ -e $ORACLE_XE_TNSNAMES_ORA_FILE ]
then
    sed -i$BACKUP_EXT "s/\(.*(HOST[[:space:]]*=[[:space:]]*\)[^)]*\().*$\)/\1$HOSTNAME\2/" $ORACLE_XE_TNSNAMES_ORA_FILE
    if [ -x /etc/init.d/oracle-xe ]; then
        /sbin/service oracle-xe restart >> $LOG 2>&1
    fi
fi

/usr/sbin/spacewalk-startup-helper wait-for-database
print_status "${?}" "Your database isn't running."

echo -n "Updating /etc/rhn/rhn.conf ... " | tee -a $LOG
update_rhn_conf
print_status 0  # just simulate end

re-generate_server_ssl_certificate

echo -n "Regenerating new bootstrap client-config-overrides.txt ... " | tee -a $LOG
# it's easier to subst HOSTNAME with sed
# than to re-generate and keep current configuration
# rhn-bootstrap >> /dev/null 2>&1
if [ -e "$BOOTSTRAP_SH" ]
then
    backup_file ${BOOTSTRAP_SH}
    sed -i "s/\(HOSTNAME=\).*/\1$HOSTNAME/" ${BOOTSTRAP_SH}
fi
if [ -e "$BOOTSTRAP_CCO" ]
then
    backup_file ${BOOTSTRAP_CCO}
    sed -i "s/\(noSSLServerURL=https\?:\/\/\).*\(\/XMLRPC\)/\1$HOSTNAME\2/" ${BOOTSTRAP_CCO}
    sed -i "s/\(serverURL=https\?:\/\/\).*\(\/XMLRPC\)/\1$HOSTNAME\2/" ${BOOTSTRAP_CCO}
fi
print_status 0  # just simulate end

echo -n "Updating other DB entries ... " | tee -a $LOG
spacewalk-sql --select-mode - >>$LOG <<EOS
UPDATE rhntemplatestring SET value='$HOSTNAME' WHERE label='hostname';
COMMIT;
$DBSHELL_QUIT
EOS
print_status 0  # just simulate end

echo -n "Changing cobbler settings ... " | tee -a $LOG
/usr/bin/spacewalk-setup-cobbler >> $LOG 2>&1
print_status $?

echo -n "Changing jabberd settings ... " | tee -a $LOG
# delete old dispatcher(s)
spacewalk-sql --select-mode - >>$LOG <<EOS
DELETE FROM rhnPushDispatcher WHERE hostname != '$HOSTNAME';
COMMIT;
$DBSHELL_QUIT
EOS

for jabber_config_file in c2s.xml s2s.xml sm.xml
do
    backup_file ${ETC_JABBERD_DIR}/${jabber_config_file}
done

if [ -e $SPW_SETUP_JABBERD ]
then
    $SPW_SETUP_JABBERD
else
    /usr/bin/satcon-deploy-tree.pl \
        --source=/var/lib/rhn/rhn-satellite-prep/etc/jabberd \
        --dest=$ETC_JABBERD_DIR \
        --conf=$SAT_LOCAL_RULES_CONF \
       >> /dev/null 2>&1
fi
print_status $?

echo -n "Starting spacewalk services ... " | tee -a $LOG
if [ "$DB_SERVICE" != "" ]
then
    /sbin/service $DB_SERVICE stop >> $LOG 2>&1
fi
/usr/sbin/spacewalk-service start >> $LOG 2>&1
print_status 0  # just simulate end

echo "[$(date)]: $(basename $0) finished sucessfully." >> $LOG
