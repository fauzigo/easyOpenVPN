#
# OpenSSL configuration based on sample configuration shipped
# with OpenVPN.
#

#############################################################
# modify according to your needs

KEY_SIZE               = 2048
KEY_COUNTRY            = CONF_COUNTRY
KEY_PROVINCE           = CONF_STATE
KEY_CITY               = CONF_CITY
KEY_ORG                = CONF_ORG
KEY_ORGUNIT            = CONF_UNIT
KEY_EMAIL              = CONF_EMAIL
HOME                   = WORKS_PATH
KEY_DIR                = $HOME/server
RANDFILE               = $HOME/.rnd

#############################################################

openssl_conf           = openssl_init

[ openssl_init ]

oid_section            = new_oids
engines                = engine_section

[ new_oids ]

[ engine_section ]

[ ca ]

default_ca             = CA_default

[ CA_default ]

dir                    = $KEY_DIR
certs                  = $dir
crl_dir                = $dir
database               = $dir/index.txt
new_certs_dir          = $dir
certificate            = $dir/ca.crt
serial                 = $dir/serial
crl                    = $dir/crl.pem
private_key            = $dir/ca.key
RANDFILE               = $HOME/.rand
x509_extensions        = usr_cert
default_days           = 3650
default_crl_days       = 30
# IMPORTANT: The next must no longer be md5, if used with
# Debian's OpenLDAP package being compiled against libgnutls.
default_md             = sha1
preserve               = no
policy                 = policy_match

[ policy_match ]

countryName            = match
stateOrProvinceName    = match
organizationName       = match
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[ policy_anything ]

countryName            = optional
stateOrProvinceName    = optional
localityName           = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[ req ]

default_bits           = $KEY_SIZE
default_keyfile        = privkey.pem
distinguished_name     = req_distinguished_name
attributes             = req_attributes
x509_extensions        = v3_ca
string_mask            = nombstr

[ req_distinguished_name ]

countryName            = Country Name (2 letter code)
countryName_default    = $KEY_COUNTRY
countryName_min        = 2
countryName_max        = 2

stateOrProvinceName    = State or Province Name (full name)
stateOrProvinceName_default = $KEY_PROVINCE

localityName           = Locality Name (eg, city)
localityName_default   = $KEY_CITY

0.organizationName     = Organization Name (eg, company)
0.organizationName_default = $KEY_ORG

organizationalUnitName = Organizational Unit Name (eg, section)
organizationalUnitName_default = $KEY_ORGUNIT

commonName             = Common Name (eg, your name or your server\'s hostname)
commonName_max         = 64

emailAddress           = Email Address
emailAddress_default   = $KEY_EMAIL
emailAddress_max       = 40

[ req_attributes ]

challengePassword      = A challenge password
challengePassword_min  = 4
challengePassword_max  = 20
unstructuredName       = An optional company name

[ usr_cert ]

basicConstraints       = CA:FALSE
nsComment              = "OpenSSL Generated Certificate"
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage       = clientAuth
keyUsage               = digitalSignature

[ server ]

basicConstraints       = CA:FALSE
nsCertType             = server
nsComment              = "OpenSSL Generated Server Certificate"
# subjectKeyIdentifier   = hash
# authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage       = serverAuth
keyUsage               = digitalSignature, keyEncipherment

[ v3_req ]

basicConstraints       = CA:FALSE
keyUsage               = nonRepudiation,digitalSignature,keyEncipherment

[ v3_ca ]

subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints       = CA:true

[ v3_ext ]
keyUsage		= critical,digitalSignature,keyEncipherment
extendedKeyUsage	= serverAuth,clientAuth
basicConstraints	= critical,CA:FALSE
subjectKeyIdentifier	= hash
authorityKeyIdentifier	= keyid:always,issuer

[ crl_ext ]

authorityKeyIdentifier = keyid:always,issuer:always

