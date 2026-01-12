# OpenVPN 

Provides flexible VPN solutions to secure your data communications, whether it's for Internet privacy, remote access for employees, securing IoT, or for networking Cloud data centers.
Our VPN Server software solution can be deployed on-premises using standard servers or virtual appliances, or on the cloud.

# TL;DR

This repo is supposed to help out the creation of a OpenVPN server's configuration file along with the clients configuration files and certs.

You would normaly do this with easy-rsa, but this is a little more direct and sinple. 

Downsides of this is that clients will be able to login into the server without usernames/passwords. It might get done in the future.



# Usage

```
# ./easyOpenVPN.sh -h
Usage: ./easyOpenVPN.sh [-i|--init </etc/openvpn>] [-c|--client <client> </etc/openvpn>] [-r|--revoke </path/to/cert> ]

  -i|--init create a CA and server certs along with a default config file for OpenVPN
  You may pass along the location were your files will be created. A folder within said directory will be created <path>/server

  -c|--client create a folder with all the necessary to start the client
  clients require a name.

  -r|--revoke-client revoke a client's cert given the common name of the cert
```


This might not work for everyone else, but it might help others.


# Files

You can edit the script file directly, or you can add all required parameters in the vars.yaml file.


# Requirements

* openvpn
* openssl
* yq, which also requires jq


# Considerations 

This comes without any warraty, use at your own risk.


---

## Quick VPN set up in AWS


### Launch an instance
```
aws ec2 run-instances --image-id $(aws ec2 describe-images --filters "Name=name,Values=al2023-ami-2023*" "Name=architecture,Values=x86_64" --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text) --instance-type t3.micro --key-name $(aws ec2 describe-key-pairs |jq '.KeyPairs[0].KeyName' -r) --security-group-ids $(aws ec2 describe-security-groups |jq '.SecurityGroups[] | select(.GroupName != "default").GroupId' -r) --subnet-id $(aws ec2 describe-subnets |jq '.Subnets[0].SubnetId' -r)
```


### SSH into the new hosts
```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -A $(aws ec2 describe-instances --query "Reservations[].Instances[].NetworkInterfaces[].Association.PublicDnsName[]" --output text) -l ec2-user
```

### Server side

#### Install a few dependencies
```
sudo yum install git python3-pip openvpn
sudo pip install yq          # Yes, this is no bueno, but no plans to keep this as a permanent server
```

#### Clone the repo
```
git clone git@github.com:fauzigo/easyOpenVPN.git
cd easyOpenVPN
```

#### Edit the variables files
```
vim vars.yaml
```

#### Init the configuration
```
sudo ./easyOpenVPN.sh -i
```

#### Enable ip forwarding
```
echo 1 |sudo tee /proc/sys/net/ipv4/ip_forward
```

#### Masquerade traffic going out VPN server
```
sudo iptables -t nat -I POSTROUTING -o ens5 -j MASQUERADE
```

#### Create a client
```
sudo ./easyOpenVPN.sh -c a1
```

#### Pack client files
```
sudo tar cvf a1.tar /etc/openvpn/a1/*
```

#### Start server
```
sudo openvpn --config /etc/openvpn/server.conf
```

#### Alternatively, run everything off a script

```
aws ec2 run-instances \
  --image-id $(aws ec2 describe-images --filters "Name=name,Values=al2023-ami-2023*" "Name=architecture,Values=x86_64" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text) \
  --instance-type t3.micro \
  --key-name $(aws ec2 describe-key-pairs |jq '.KeyPairs[0].KeyName' -r) \
  --security-group-ids $(aws ec2 describe-security-groups |jq '.SecurityGroups[] | select(.GroupName != "default").GroupId' -r) \
  --subnet-id $(aws ec2 describe-subnets |jq '.Subnets[0].SubnetId' -r) \
  --user-data file://user-data
```


#### Update dns record

```
tmp=$(mktemp)
domain="domain.com"
subdomain="vpn.${domain}"
jq  --arg a "${subdomain}" --arg val "$(aws ec2 describe-instances --query "Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp[]" --output text)" '.Changes[0].ResourceRecordSet |= (.Name = $a | .ResourceRecords[0].Value = $val)' resources/record-update.json > ${tmp}
aws route53 change-resource-record-sets --hosted-zone-id $(aws route53 list-hosted-zones |jq -r '.HostedZones[] |select(.Name == "'${domain}'.") | .Id' |cut -d/ -f3) --change-batch file://${tmp}
```

#### Update security group to grant vpn access
```
sec_group_id=$(aws ec2 describe-security-groups |jq '.SecurityGroups[] | select(.GroupName != "default").GroupId' -r)
aws ec2 modify-security-group-rules --group-id ${sec_group_id} --security-group-rules SecurityGroupRuleId=$(aws ec2 describe-security-group-rules | jq -r '.SecurityGroupRules[] |select(.GroupId == "'$(aws ec2 describe-security-groups |jq '.SecurityGroups[] | select(.GroupName != "default").GroupId' -r)'") |select(.Description == "VPNAcess") |.SecurityGroupRuleId'),SecurityGroupRule="{Description=VPNAcess,IpProtocol=-1,CidrIpv4=$(curl -s4 ifconfig.io)/32}"
```


&nbsp;

### Client side

#### Copy config to client
```
scp ec2-user@$(aws ec2 describe-instances --query "Reservations[].Instances[].NetworkInterfaces[].Association.PublicDnsName[]" --output text):/home/ec2-user/a1.tar ./
```

#### Unpack
```
tar xf a1.tar
```

#### Start Client
```
sed  -i.bck "s/example\.com/${subdomain}/g" etc/openvpn/a1/a1.ovpn
sudo /opt/homebrew/opt/openvpn/sbin/openvpn --config a1.ovpn
```


---

## When done with the instance
```
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId"  --output text)
```

### Additions

Consider running a DNS server with named for example:

```
options {
	listen-on port 53 { any; };
	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	secroots-file	"/var/named/data/named.secroots";
	recursing-file	"/var/named/data/named.recursing";
	allow-query     { localhost; 10.8.0.0/24; };

	/*
	 - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
	 - If you are building a RECURSIVE (caching) DNS server, you need to enable
	   recursion.
	 - If your recursive DNS server has a public IP address, you MUST enable access
	   control to limit queries to your legitimate users. Failing to do so will
	   cause your server to become part of large scale DNS amplification
	   attacks. Implementing BCP38 within your network would greatly
	   reduce such attack surface
	*/
	recursion yes;

	dnssec-validation yes;

	forwarders { 84.200.69.80; 84.200.70.40; };

	forward only;

	managed-keys-directory "/var/named/dynamic";
	geoip-directory "/usr/share/GeoIP";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";

	/* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
	include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
```
