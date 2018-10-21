# TL;DR

This repo is supposed to help out the creation of a OpenVPN server's configuration file along with the clients configuration files and certs.

You would normaly do this with easy-rsa, but this is a little more direct and sinple. 

Downsides of this is that clients would be able to login into the server without usernames/passwords. It might get done in the future.



# Usage

```# ./easyOpenVPN.sh -h
Usage: ./easyOpenVPN.sh [-i|--init </etc/openvpn>] [-c|--client <client> </etc/openvpn>] [-r|--revoke </path/to/cert> ]

  -i|--init would create a CA and server certs along with a default config file for OpenVPN
  You may pass along the location were your files will be created. A folder within said directory will be created <path>/server

  -c|--client would create a folder with all the necessary to start the client
  clients require a name.

  -r|--revoke-client would revoke a client's cert given the common name of the cert```


This might not work for everyone else, but it might help others.


# Files

You can edit the script file directly, or you can add all required parameters in the vars.yaml file.


# Requirements

* openvpn
* openssl
* yq, which also requires jq


# Considerations 

This comes without any warraty, use at your own risk.
