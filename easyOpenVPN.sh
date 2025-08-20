#!/usr/bin/env bash

###
#
#  This script is intended to make easy to deploy a new openVPN server along with the creation of clients config file
#
# This is for personal use, but it might help others to deploy this thing in an easy way. 
# Additional there is no warranty that this will work for anyone and on all environments, haven't tested it on anything other than
#
# Ubuntu 16.04
# 
#set -v

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

# VARs

#WORKS_PATH="/etc/openvpn"
#CERTS_PATH="${WORKS_PATH}/server"
#LOGS_LOCATION="/var/log"

## Net vars
#REMOTE="example.com"
#LISTEN_PORT="1194"
#SERVICE_PROTO="udp"
#DEV_TYPE="tun"
#SUBNET="10.8.0.0"
#SUBNET_MASK="255.255.255.0"
#DNS1="37.235.1.174"
#DNS2="37.235.1.177"



CERT_COMMON_NAME="example.com"
CERT_COUNTRY="US"
CERT_STATE="Illinois"
CERT_CITY="Chicago"
CERT_ORGANIZATION="Example INC."
CERT_ORGANIZATION_UNIT="IT Dept"
EMAIL="noreply@${CERT_COMMON_NAME}"


# Configuration files
CONF_LOCATION="/etc/openvpn"
CA_CRT_LOCATION="/etc/openvpn/server"
CA_KEY_LOCATION="${CA_CRT_LOCATION}"
SERVER_CRT="${CA_CRT_LOCATION}"
SERVER_KEY="${SERVER_CRT}"
SERVER_DH="${SERVER_CRT}"
SERVER_TLS="${SERVER_CRT}"

# Networking Configuration
SERVICE_PROTO="udp"
SERVICE_DEV_TYPE="tun"
SERVICE_PORT=1194
SERVICE_SUBNET="10.8.0.0"
SERVICE_SMASK="255.255.255.0"
SERVICE_DNS1="37.235.1.174"
SERVICE_DNS2="37.235.1.177"

# Other vars
LOGS="/var/log"

## Other vars
CLIENTS_CERT_DURATION=365


#export HOME=${WORKS_PATH}
#export 
###


#yum -y install openvpn
#apt -y install openvpn


function initialize
{

	if [ -d "${CA_CRT_LOCATION}" ] && [ -f "${CA_CRT_LOCATION}/ca.crt" ];
	then
		echo "Are you sure you want to initialize this? We already found a CA in the given path \"${CA_CRT_LOCATION}\""
		echo "Exiting"
		exit 1
	fi
	#echo ${CA_CRT_LOCATION}
	mkdir -p -m 700 ${CA_CRT_LOCATION}
	touch ${CA_CRT_LOCATION}/index.txt
	touch ${CA_CRT_LOCATION}/index.txt.attr
	echo "01" > ${CA_CRT_LOCATION}/serial
	local BASE_DN="/CN=${CERT_COMMON_NAME}/C=${CERT_COUNTRY}/L=${CERT_CITY}/O=${CERT_ORGANIZATION}/OU=${CERT_ORGANIZATION_UNIT}/ST=${CERT_STATE}"


	sed -e "s#WORKS_PATH#${CONF_LOCATION}#g" -e "s#CONF_COUNTRY#${CERT_COUNTRY}#g" -e "s#CONF_STATE#${CERT_STATE}#g" \
	    -e "s#CONF_CITY#${CERT_CITY}#g" -e "s#CONF_ORG#${CERT_ORGANIZATION}#g" -e "s#CONF_UNIT#${CERT_ORGANIZATION_UNIT}#g" \
	    -e "s#CONF_EMAIL#${EMAIL}#g"  openssl.conf.tpl > ${CONF_LOCATION}/openssl.conf

	# this is the ca creation
	echo "Generating the CA, certificate and key"
	echo "$BASE_DN"
	echo "CA key: ${CA_KEY_LOCATION},  CA crt: ${CA_CRT_LOCATION},  Conf Location: ${CONF_LOCATION}"
	#exit 1
	local TORUN="openssl req -nodes -new -x509 -keyout ${CA_KEY_LOCATION}/ca.key -out ${CA_CRT_LOCATION}/ca.crt -config ${CONF_LOCATION}/openssl.conf -subj \"${BASE_DN}\""
	#exit 0
	echo ${TORUN}
	eval ${TORUN}
	#openssl req -nodes -new -x509 -keyout ${CA_KEY_LOCATION}/ca.key -out ${CA_CRT_LOCATION}/ca.crt -config ${CONF_LOCATION}/openssl.conf -subj "${BASE_DN}"

	if [ $? -gt 0 ];
	then
		echo "Something went wrong generating the CA"
		exit 2
	fi

	echo "Generating the server certificate"
	# Now, let's create the server cert
	TORUN="openssl req -nodes -new -extensions server -keyout ${SERVER_KEY}/server.key -out ${SERVER_CRT}/server.csr -config ${CONF_LOCATION}/openssl.conf -subj \"${BASE_DN}\""
	echo ${TORUN}
	eval ${TORUN}
	#openssl req -nodes -new -extensions server -keyout ${SERVER_KEY}/server.key -out ${SERVER_CRT}/server.csr -config ${CONF_LOCATION}/openssl.conf -subj "${BASE_DN}"
	echo "Generating the cert itself"
	TORUN="openssl ca -batch -extensions server -out ${SERVER_CRT}/server.crt -in ${SERVER_CRT}/server.csr -config ${CONF_LOCATION}/openssl.conf"
	echo ${TORUN}
	eval ${TORUN}
	#openssl ca -batch -extensions server -out ${SERVER_CRT}/server.crt -in ${SERVER_CRT}/server.csr -config ${CONF_LOCATION}/openssl.conf

	if [ $? -gt 0 ];
	then
		echo "Something went wrong generating the server certificate"
		exit 2
	fi

	# Let's generate a Diffie-Hellman key exchange file.
	echo "Generating a Diffie-Hellman key echange file"
	TORUN="openssl genpkey -genparam -algorithm DH -out ${SERVER_DH}/dhp.pem"
	echo ${TORUN}
	eval ${TORUN}
	#openssl genpkey -genparam -algorithm DH -out ${SERVER_DH}/dhp.pem

	if [ $? -gt 0 ];
	then
		echo "Something went wrong generating the Diffie-Hellman key"
		exit 2
	fi

	# This is for tls authentication
	echo "Generating a tlsauth file"
	# TORUN="openvpn --genkey --secret ${SERVER_TLS}/myvpn.tlsauth"
	# TORUN="openvpn --genkey --tls-auth |tee ${SERVER_TLS}/myvpn.tlsauth"
	TORUN="openvpn --genkey |tee ${SERVER_TLS}/myvpn.tlsauth"
	echo ${TORUN}
	eval ${TORUN}

	if [ $? -gt 0 ];
	then
		echo "Something went wrong generating the tlsauth file"
		exit 2
	fi
}


function create_server_conf
{

	echo "${CONF_LOCATION}"
	cat > ${CONF_LOCATION}/server.conf <<EOF
port ${SERVICE_PORT}
proto ${SERVICE_PROTO}
dev ${SERVICE_DEV_TYPE}
ca ${CA_CRT_LOCATION}/ca.crt
cert ${SERVER_CRT}/server.crt
key ${SERVER_KEY}/server.key  # This file should be kept secret
dh ${SERVER_DH}/dhp.pem
topology subnet
server ${SERVICE_SUBNET} ${SERVICE_SMASK}
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS ${SERVICE_DNS1}"
push "dhcp-option DNS ${SERVICE_DNS2}"
keepalive 10 120
tls-crypt ${SERVER_TLS}/myvpn.tlsauth
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status      ${LOGS}/openvpn-status.log
log         ${LOGS}/openvpn.log
log-append  ${LOGS}/openvpn.log
verb 6
explicit-exit-notify 1
remote-cert-eku "TLS Web Client Authentication"
EOF

}


function create_client
{

	CERTNAME="${FOLDER}"

	if ! [ -d "${CERT_BASE_PATH}/${FOLDER}" ];
	then
		echo "Creating dir ${CERT_BASE_PATH}/${FOLDER}"
		mkdir -p "${CERT_BASE_PATH}/${FOLDER}"
	fi

	CPATH="${CERT_BASE_PATH}/${FOLDER}/"
	#echo $CAPTH
	#echo ${CERT_BASE_PATH}
	#echo ${FOLDER}
	#exit 0

	if [ -d "${CA_CRT_LOCATION}" ] && [ -d "${CA_KEY_LOCATION}" ] && [ -d "${SERVER_TLS}" ];
	then
		#CAPATH="${CA_CRT_LOCATION}server"
		if ! [ -f "${CA_CRT_LOCATION}/ca.crt" ] && [ -f "${CA_KEY_LOCATION}/ca.key" ] && [ -f "${SERVER_TLS}/myvpn.tlsauth" ];
		then
			echo "Can't find ca cert or key, or tlsauth"
			exit 2
		fi
	#elif ! [ -f "${SCRIPTPATH}/ca.crt" && -f "${SCRIPTPATH}/ca.key" && -f "${SCRIPTPATH}/myvpn.tlsauth" ];
	#then
	#	echo "Can't find ca path"
	#	exit 2
	elif [ -f "${CPATH}${CERTNAME}.crt" ] && [ -f "${CPATH}${CERTNAME}.key" ];
	then
		echo "The cert and key already exist for the provided name, at ${CPATH}."
		echo "If you want a new cert with the same name, delete or move the ${CPATH} folder"
		echo
		echo "It worth noting that openssl records may already have a cert on the same name. Unless you revoke it,"
		echo "you may not be able to create a cert with the same name"
		exit 2
	elif ! [ -f ${CONF_LOCATION}/openssl.conf ];
	then
		echo "${CONF_LOCATION}/openssl.conf was not found, if you want to proceed with the default openssl.conf file, make sure it is same one used to create the CA"
		read -p "Continue (y/N)? (default N)" choice
		case "$choice" in 
		  y|Y ) echo "yes";;
		  n|N ) exit 1;;
		  * ) echo "invalid"
			exit 2;;
		esac
	fi

	#CERT_DURATION=${CLIENT_CERT_DURATION}

	BASE_DN="/CN=${CERTNAME}.${CERT_COMMON_NAME}/C=${CERT_COUNTRY}/L=${CERT_CITY}/O=${CERT_ORGANIZATION}/OU=${CERT_ORGANIZATION_UNIT}/ST=${CERT_STATE}"

	local TORUN="openssl req -nodes -new -newkey rsa:2048 -keyout ${CPATH}${CERTNAME}.key -out ${CPATH}${CERTNAME}.csr -subj \"${BASE_DN}\""
	echo ${TORUN}
	eval ${TORUN}

	TORUN="openssl x509 -req -in ${CPATH}${CERTNAME}.csr -CA ${CA_CRT_LOCATION}/ca.crt -CAkey ${CA_KEY_LOCATION}/ca.key -CAcreateserial \
	    -out ${CPATH}${CERTNAME}.crt -days ${CLIENTS_CERT_DURATION} -extensions v3_ext -extfile ${CONF_LOCATION}/openssl.conf"
	echo ${TORUN}
	eval ${TORUN}

	cp ${SERVER_TLS}/myvpn.tlsauth ${CA_CRT_LOCATION}/ca.crt ${CPATH}

	cat > ${CPATH}/${CERTNAME}.ovpn <<EOF
proto ${SERVICE_PROTO}
remote ${CERT_COMMON_NAME} ${SERVICE_PORT} ${SERVICE_PROTO}
dev ${SERVICE_DEV_TYPE}
topology subnet
pull
persist-key
persist-tun
cipher AES-256-CBC
tls-client

<ca>
$(cat ${CPATH}ca.crt)
</ca>
<cert>
$(cat ${CPATH}${CERTNAME}.crt)
</cert>
<key>
$(cat ${CPATH}${CERTNAME}.key)
</key>
<tls-crypt>
$(cat ${CPATH}myvpn.tlsauth)
</tls-crypt>
EOF


}

function get_vars
{
	if ! [ -f "${SCRIPTPATH}/vars.yaml" ];
	then
		echo "vars file does not exist, using local vars within this script"
	else
		which yq > /dev/null 2>&1
		if [ $? -gt 0 ];
		then
			echo "yq is not installed, can't read the variables file, Would you like to use the local vars?"
			read -p "Continue (y/N)? (default N)" choice
			case "$choice" in 
			  y|Y ) echo "yes";;
			  n|N ) exit 1;;
			  * ) echo "invalid"
				exit 2;;
			esac

		else

			CONFIGS=$(yq . ${SCRIPTPATH}/vars.yaml)
			# Certificate information
			CERT_COMMON_NAME=$(yq -r .server.cert_subject.common_name ${SCRIPTPATH}/vars.yaml)
			CERT_COUNTRY=$(yq -r .server.cert_subject.country ${SCRIPTPATH}/vars.yaml)
			CERT_STATE=$(yq -r .server.cert_subject.state ${SCRIPTPATH}/vars.yaml)
			CERT_CITY=$(yq -r .server.cert_subject.city ${SCRIPTPATH}/vars.yaml)
			CERT_ORGANIZATION=$(yq -r .server.cert_subject.organization ${SCRIPTPATH}/vars.yaml)
			CERT_ORGANIZATION_UNIT=$(yq -r .server.cert_subject.organization_unit ${SCRIPTPATH}/vars.yaml)
			EMAIL=$(yq -r .server.cert_subject.email ${SCRIPTPATH}/vars.yaml)

			# Configuration files
			CONF_LOCATION=$(yq -r .server.conf_location ${SCRIPTPATH}/vars.yaml)
			CA_CRT_LOCATION=$(yq -r .server.cert_location.ca.cert ${SCRIPTPATH}/vars.yaml)
			CA_KEY_LOCATION=$(yq -r .server.cert_location.ca.key ${SCRIPTPATH}/vars.yaml)
			SERVER_CRT=$(yq -r .server.cert_location.server.cert ${SCRIPTPATH}/vars.yaml)
			SERVER_KEY=$(yq -r .server.cert_location.server.key ${SCRIPTPATH}/vars.yaml)
			SERVER_DH=$(yq -r .server.cert_location.dh ${SCRIPTPATH}/vars.yaml)
			SERVER_TLS=$(yq -r .server.cert_location.tls ${SCRIPTPATH}/vars.yaml)

			# Networking Configuration
			SERVICE_PROTO=$(yq -r .server.service.proto ${SCRIPTPATH}/vars.yaml)
			SERVICE_DEV_TYPE=$(yq -r .server.service.dev_type ${SCRIPTPATH}/vars.yaml)
			SERVICE_PORT=$(yq -r .server.service.port ${SCRIPTPATH}/vars.yaml)
			SERVICE_SUBNET=$(yq -r .server.service.subnet ${SCRIPTPATH}/vars.yaml)
			SERVICE_SMASK=$(yq -r .server.service.subnet_mask ${SCRIPTPATH}/vars.yaml)
			SERVICE_DNS1=$(yq -r .server.service.dns1 ${SCRIPTPATH}/vars.yaml)
			SERVICE_DNS2=$(yq -r .server.service.dns2 ${SCRIPTPATH}/vars.yaml)

			# Other vars
			LOGS=$(yq -r .server.logs_location ${SCRIPTPATH}/vars.yaml)

			# Clients
			CLIENTS_CERT_DURATION=$(yq -r .clients.certs_duration ${SCRIPTPATH}/vars.yaml)
			
		fi
	fi
}

function revoke_client
{
	openssl ca -revoke ${CERT_BASE_PATH} -config ${CONF_LOCATION}/openssl.conf
}

function check_requirements
{

	# openssl
	which openssl > /dev/null 2>&1
	if [ $? -gt 0 ];
	then
		echo "Please install openSSL"
		exit 2
	fi
	
	# yq
	which yq > /dev/null 2>&1
	if [ $? -gt 0 ];
	then
		echo "Please install yq"
		exit 2
	fi

	# openvpn
	which openvpn > /dev/null 2>&1
	if [ $? -gt 0 ];
	then
		echo "Well if you are going to use openVPN, please at least install it"
		exit 2
	fi
}

function usage
{
	echo "Usage: $0 [-i|--init </etc/openvpn>] [-c|--client <client> </etc/openvpn>] [-r|--revoke </path/to/cert> ]" 1>&2
	echo 
	echo "  -i|--init create a CA and server certs along with a default config file for OpenVPN"
	echo "  You may pass along the location were your files will be created. A folder within said directory will be created <path>/server"
	echo
	echo "  -c|--client create a folder with all the necessary to start a client"
	echo "  clients require a name and a path where the ca{.key,.crt} are"
	echo
	echo "  -r|--revoke-client revoke a client's cert given the common name of the cert"
	echo "  the client's name is required"
}

if [ $# -lt 1 ]
then
	usage
	exit 1
else
	check_requirements
	if [ -f "${SCRIPTPATH}/vars.yaml" ];
        then
		get_vars
	fi
fi

#if [ $1 == "init" ]
#then
#	# Initialize openVPN
#	echo "We are going to try initializing openVPN with the certain default configuration"
#	initialize > /dev/null 1>&2
#	exit 0
#fi

# read the options
params="$(getopt -o i::c:r:h --long init::,create-client:,revoke:,help -n "$0" -- "$@")"
eval set -- "$params"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -i|--init)
	    #echo "$2 pluss"
            case "$2" in
                "") WORKS_PATH='/etc/openvpn' 
			#create_server_conf
			#initialize
			echo "No path given, using ${CONF_LOCATION}"
			shift 2 ;;
                *) CONF_LOCATION="$2" #; shift 2 ;;
			echo "${CONF_LOCATION}"
			#create_server_conf #> /dev/null 1>&2
			#initialize #> /dev/null 1>&2
			#systemctl -f enable openvpn@server.service
			#systemctl start openvpn@server.service
			#exit 0;;
			shift 2 ;;
            esac 
		create_server_conf
		initialize
	    ;;
        #-b|--argb) ARG_B=1 ; shift ;;
        -c|--create-client)
		FOLDER=$2
		#CLIENT_NAME=$2
		#echo $3
		if [ $3 ] && [ "$3" != "--" ] && [ -d "${3}../" ];
		then
			CERT_BASE_PATH="$3"
		#	create_client
		#	exit 0;
		else
			echo "No destination path provided, using /etc/openvpn"
			CERT_BASE_PATH="/etc/openvpn"
		#	echo -n "Please provide the path of the CA cert and key, which should also have the location of \n the tlsfile"
		#	exit 1
		fi
		create_client
		exit 0
		shift 3;;
	-r|--revoke)
		#FOLDER=$2
		if [ -f $2 ];
		then
			CERT_BASE_PATH="$2"
			revoke_client
			exit 0;
		else
			echo "can't find the cert to revoke, please verify the rpovided path"
			exit 2;
		fi
		shift 3;;
	-h|--help)
		usage
		exit 0
		;;
        --) shift ; break ;;
        *) echo "run ${0} -h for help" ; exit 1 ;;
    esac
done


