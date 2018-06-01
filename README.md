# networkcheck.sh
Linux network check script (sh/bash) - to find configuration or network problems

Usage:

	### Program: networkcheck by peter@forret.com
	### Version: v1.0 - 2018-06-01 18:35
	### Usage: networkcheck [-h] [-q] [-v] [-f] [-r] [-t <tmpdir>] [-d <domain>] [-n <ns>] [-p <port>] <action>
	### Flags, options and parameters:
	    -h|--help      : [flag] show usage [default: off]
	    -q|--quiet     : [flag] no output [default: off]
	    -v|--verbose   : [flag] output more [default: off]
	    -f|--force     : [flag] do not ask for confirmation [default: off]
	    -r|--rx        : [flag] check for tx/rx traffic too [default: off]
	    -t|--tmpdir <val>: [optn] folder for temp files  [default: /tmp/networkcheck]
	    -d|--domain <val>: [optn] domain to check for  [default: www.google.com]
	    -n|--ns <val>: [optn] nameserver to use as fallback  [default: 8.8.8.8]
	    -p|--port <val>: [optn] portto check for  [default: 80]
	    <action>  : [parameter] action to perform: CHECK/...

Command:

	./networkcheck.sh  CHECK

Results:

	##### 1. check network cards
	 ___  This system has a default route, interface <eth0>
	 ___  Loopback interface is working properly
	##### 2. check network connections
	 ___  Interface <eth0>: IP address(es) <10.11.114.172/24 fe80::9999:9999:9999:9999/64>
	 ___  The router <10.11.114.50> is reachable
	##### 3. check DNS resolution
	 ___  DNS <8.8.8.8>: resolves <www.google.com> to <216.58.211.100>
	 ___  DNS <8.8.8.8>: resolves <www.google.com> to <2a00:1450:400e:804::2004>
	 ___  DNS <10.11.114.99>: resolves <www.google.com> to <172.217.20.68>
	 ___  DNS <10.11.114.99>: resolves <www.google.com> to <2a00:1450:400e:803::2004>
	##### 4. check HTTP traffic
	 ___  Host <www.google.com:80>: web server responds!
	##### Problems found: 0
