#!/bin/bash
# first set some execution parameters
prefix_fmt=""
# uncomment next line to have date/time prefix for every output line
#prefix_fmt='+%Y-%m-%d %H:%M:%S :: '

runasroot=0
# runasroot = 0 :: don't check anything
# runasroot = 1 :: script MUST run as root
# runasroot = -1 :: script MAY NOT run as root

### Change the next lines to reflect which flags/options/parameters you need
### flag:   switch a flag 'on' / no extra parameter / e.g. "-v" for verbose
# flag|<short>|<long>|<description>|<default>

# change program version to your own release logic
readonly PROGNAME=$(basename $0 .sh)
readonly PROGDIR=$(cd $(dirname $0); pwd)
readonly PROGVERS="v1.0"
readonly PROGAUTH="peter@forret.com"

### option: set an option value / 1 extra parameter / e.g. "-l error.log" for logging to file
# option|<short>|<long>|<description>|<default>
[[ -z "$TEMP" ]] && TEMP=/tmp

### param:  comes after the options
#param|<type>|<long>|<description>
# where <type> = 1 for single parameters or <type> = n for (last) parameter that can be a list
list_options() {
echo -n "
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|r|rx|check for tx/rx traffic too
option|d|domain|domain to check for|www.google.com
option|n|ns|nameserver to use as fallback|8.8.8.8
option|p|port|portto check for|80
param|1|action|action to perform: CHECK/...
"
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

PROGDATE=$(stat -c %y "$0" 2>/dev/null | cut -c1-16) # generic linux
if [[ -z $PROGDATE ]] ; then
  PROGDATE=$(stat -f "%Sm" "$0" 2>/dev/null) # for MacOS
fi

readonly ARGS="$@"
#set -e                                  # Exit immediately on error
verbose=0
quiet=0
piped=0
force=0
[[ -t 1 ]] && piped=0 || piped=1        # detect if out put is piped

# Defaults
args=()

out() {
  ((quiet)) && return
  local message="$@"
  local prefix=""
  if [[ -n $prefix_fmt ]]; then
    prefix=$(date "$prefix_fmt")
  fi
  if ((piped)); then
    message=$(echo $message | sed '
      s/\\[0-9]\{3\}\[[0-9]\(;[0-9]\{2\}\)\?m//g;
      s/[!]/ERROR:/g;
      s/[?]/ALERT:/g;
      s/___/OK   :/g;
    ')
    printf '%b\n' "$prefix$message";
  else
    printf '%b\n' "$prefix$message";
  fi
}

progress() {
  ((quiet)) && return
  local message="$@"
  if ((piped)); then
    printf '%b\n' "$message";
    # \r makes no sense in file or pipe
  else
    printf '%b\r' "$message                                             ";
    # next line will overwrite this line
  fi
}
rollback()  { die ; }
trap rollback INT TERM EXIT
safe_exit() { trap - INT TERM EXIT ; exit ; }

die()     { out " * \033[1;41m[!]\033[0m ** $@" >&2; safe_exit; }             # die with error message
alert()   { out " * \033[1;31m[ ]\033[0m !! $@" >&2 ; }                       # print error and continue
success() { out " * \033[1;32m[x]\033[0m .. $@"; }
log()     { [[ $verbose -gt 0 ]] && out "\033[1;33m# $@\033[0m";}
notify()  { [[ $? == 0 ]] && success "$@" || alert "$@"; }
escape()  { echo $@ | sed 's/\//\\\//g' ; }

lcase()   { echo $@ | awk '{print tolower($0)}' ; }
ucase()   { echo $@ | awk '{print toupper($0)}' ; }

confirm() { (($force)) && return 0; read -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}

is_set()     { local target=$1 ; [[ $target -gt 0 ]] ; }
is_empty()     { local target=$1 ; [[ -z $target ]] ; }
is_not_empty() { local target=$1;  [[ -n $target ]] ; }

is_file() { local target=$1; [[ -f $target ]] ; }
is_dir()  { local target=$1; [[ -d $target ]] ; }


usage() {
out "### Program: \033[1;32m$PROGNAME\033[0m by $PROGAUTH"
out "### Version: $PROGVERS - $PROGDATE"
echo -n "### Usage: $PROGNAME"
 list_options \
| awk '
BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="### Flags, options and parameters:"}
$1 ~ /flag/  {
  fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
  oneline  = oneline " [-" $2 "]"
  }
$1 ~ /option/  {
  fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
  if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
  oneline  = oneline " [-" $2 " <" $3 ">]"
  }
$1 ~ /secret/  {
  fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
    oneline  = oneline " [-" $2 " <" $3 ">]"
  }
$1 ~ /param/ {
  if($2 == "1"){
        fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
        oneline  = oneline " <" $3 ">"
   } else {
        fulltext = fulltext sprintf("\n    %-10s: [parameter] %s (1 or more)","<"$3">",$4);
        oneline  = oneline " <" $3 "> [<...>]"
   }
  }
  END {print oneline; print fulltext}
'
}

init_options() {
    init_command=$(list_options \
    | awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3"=0; "}
    $1 ~ /flag/   && $5 != "" {print $3"="$5"; "}
    $1 ~ /option/ && $5 == "" {print $3"=\" \"; "}
    $1 ~ /option/ && $5 != "" {print $3"="$5"; "}
    ')
    if [[ -n "$init_command" ]] ; then
        #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
        eval "$init_command"
   fi
}

parse_options() {
    if [[ $# -eq 0 ]] ; then
       usage >&2 ; safe_exit
    fi

    ## first process all the -x --xxxx flags and options
    while [[ $1 = -?* ]]; do
        # flag <flag> is savec as $flag = 0/1
        # option <option> is saved as $option
       save_option=$(list_options \
        | awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
        if [[ -n "$save_option" ]] ; then
            #log "parse_options: $save_option"
            eval $save_option
        else
            die "$PROGNAME cannot interpret option [$1]"
        fi
        shift
    done

    ## then run through the given parameters
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    nb_singles=$(echo $single_params | wc -w)
    [[ $nb_singles -gt 0 ]] && [[ $# -eq 0 ]] && die "$PROGNAME needs the parameter(s) [$(echo $single_params)]"

    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    nb_multis=$(echo $multi_param | wc -w)
    if [[ $nb_multis -gt 1 ]] ; then
        die "$PROGNAME cannot have more than 1 'multi' parameter: [$(echo $multi_param)]"
    fi

    for param in $single_params ; do
        if [[ -z $1 ]] ; then
            die "$PROGNAME needs parameter [$param]"
        fi
        log "$param=$1"
        eval $param="$1"
        shift
    done

    [[ $nb_multis -gt 0 ]] && [[ $# -eq 0 ]] && die "$PROGNAME needs the (multi) parameter [$multi_param]"
    [[ $nb_multis -eq 0 ]] && [[ $# -gt 0 ]] && die "$PROGNAME cannot interpret extra parameters"

    # save the rest of the params in the multi param
	if [[ -s "$*" ]] ; then
		eval "$multi_param=( $* )"
	fi
}

[[ $runasroot == 1  ]] && [[ $UID -ne 0 ]] && die "You MUST be root to run this script"
[[ $runasroot == -1 ]] && [[ $UID -eq 0 ]] && die "You MAY NOT be root to run this script"

################### DO NOT MODIFY ABOVE THIS LINE ###################
#####################################################################

## Put your helper scripts here
folder_prep(){
    if [[ -s "$1" ]] ; then
        folder="$1"
        maxdays=365
        if [[ -s "$2" ]] ; then
            maxdays=$2
        fi
        if [[ -s "$folder" ]] ; then
            if [ ! -d "$folder" ] ; then
                log "Create folder [$folder]"
                mkdir "$folder"
            else
                log "cleanup folder [$folder] - delete older than $maxdays days"
                find "$folder" -mtime +$maxdays -exec rm {} \;
            fi
        fi
	fi
}

default_interface(){
  defaultif=$(netstat -nr | grep ^0.0.0.0 | awk '{print $8}' | head -1)
  if [ -z "$defaultif" ] ; then
    defaultif=none
    alert "WARN: This system does not have a default route"
    problems_found=$(expr $problems_found + 1)
  elif [ $(netstat -nr | grep ^0.0.0.0 | wc -l) -gt 1 ] ; then
    alert "WARN: This system has more than one default route"
    problems_found=$(expr $problems_found + 1)
  else 
    success "This system has a default route, interface <$defaultif>"
  fi
}

ping_host () {
  host=$1
  [ -z "$host" ] && return 1
  COUNT=10
  [ -n "$2" ] && COUNT=$2
  status=0
  ping -q -c $COUNT "$host" >/dev/null 2>&1 
  if [ "$?" -ne 0 ]; then
    log "WARN: Host <$host> does not answer to ICMP pings"
    status=1
  else
    log "Host <$host> answers to ICMP pings"
  fi
  return $status
}

check_router () {
  router=$1
  [ -z "$router" ] && return 1
  status=0
  ping_host "$router" 3
  if [ "$?" -ne 0 ]; then
    alert "WARN: Router <$router> does not answer to ICMP pings"
    routerarp=`arp -n | grep "^$router" | grep -v incomplete`
    if [[ -z "$routerarp" ]] ; then
      alert "ERR: We cannot retrieve a MAC address for router $router"
      problems_found=$(expr $problems_found + 1)
      return 1
    fi
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  success "The router <$router> is reachable"
  return $status
}

check_local () {
  if [[ -z $(ifconfig | grep Link | grep lo) ]] ; then
    alert "ERR: There is no loopback interface in this system"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  if ! ping_host 127.0.0.1 1 ; then
    alert "Cannot ping localhost (127.0.0.1), loopback is broken in this system"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  if ! ping_host localhost 1; then
    alert "check /etc/hosts and verify localhost points to 127.0.0.1"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  success "Loopback interface is working properly"
  return 0
}

check_netroute () {
  ifname=$1
  [ -z "$ifname" ] && return 1
  netstat -nr  | grep "${ifname}$" |
  while read network gw netmask flags mss window irtt iface; do
  # For each gw that is not the default one, ping it
    if [ "$gw" != "0.0.0.0" ] ; then
      if ! check_router $gw  ; then
        alert "ERR: The default route is not available since the default router <$gw> is unreachable"
      fi
    fi
  done
}

check_if () {
  ifname=$1
  status=0
  [ -z "$ifname" ] && return 1
# Find IP addresses for $ifname
  inetaddr=$(ip addr show $ifname | grep inet | awk '{print $2}')
  if [[ -z "$inetaddr" ]] ; then
    alert "WARN: Interface <$ifname>: no IP address assigned"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  echo $inetaddr | while read ipaddr; do
    success "Interface <$ifname>: IP address(es) <$ipaddr>"
  done
  
  (( $rx )) && (
    txpkts=`ifconfig $ifname | awk '/TX packets/ { print $2 }' |sed 's/.*://'`
    rxpkts=`ifconfig $ifname | awk '/RX packets/ { print $2 }' |sed 's/.*://'`
    txerrors=`ifconfig $ifname | awk '/TX packets/ { print $3 }' |sed 's/.*://'`
    rxerrors=`ifconfig $ifname | awk '/RX packets/ { print $3 }' |sed 's/.*://'`

    if [[ "$txpkts" -eq 0 ]] && [[ "$rxpkts" -eq 0 ]] ; then
      alert "ERR: Interface <$ifname>: has not tx or rx any packets. Link down?"
      problems_found=$(expr $problems_found + 1)
      return 1
    elif [[ "$txpkts" -eq 0 ]] ; then
      alert "WARN: Interface <$ifname>: has not transmitted any packets."
    elif [ "$rxpkts" -eq 0 ] ; then
      alert "WARN: Interface <$ifname>: has not received any packets."
    else
      log "Interface <$ifname>: has tx and rx packets."
    fi

    if [ "$txerrors" -ne 0 ]; then
      echo "WARN: Interface <$ifname>: has tx errors."
      problems_found=$(expr $problems_found + 1)
      return 1
    fi
    if [ "$rxerrors" -ne 0 ]; then
      echo "WARN: Interface <$ifname>: has rx errors."
      problems_found=$(expr $problems_found + 1)
      return 1
    fi
    )
  return 0
}

check_allif () {
  status=0
  iffound=0
  ifok=0
  ifnames=$(ip link show   | egrep '^[[:digit:]]' | awk '{print $2}')
  for ifname in $ifnames ; do
    ifname=`echo $ifname | sed -e 's/:$//'`
    [[ $ifname == lo ]] && continue
    iffound=$(( $iffound +1 ))
    if [ -z "$(ifconfig $ifname | grep UP)" ] ; then
      if  [ "$ifname" = "$defaultif" ] ; then
        alert "ERR: Interface <$ifname>: default route is down!"
        status=1
      elif  [ "$ifname" = "lo"  ] ; then
        alert "ERR: Interface <$ifname>: is down, this might cause issues with local applications"
      else
        alert "WARN: Interface <$ifname>: is down"
      fi
    else
    # Check network routes associated with this interface
      log "Interface <$ifname>: is up!"
      if check_if $ifname ; then
        if check_netroute $ifname ; then
          ifok=$(( $ifok +1 ))
        fi
      fi
    fi
  done
  log "Interface: $ifok of $iffound interfaces are OK"
  if [[ $ifok -lt 1 ]] ;  then
    fatal_problem=1
    problems_found=$(expr $problems_found + 1)
  fi
  return $status
}

check_ns(){
  nameserver=$1
  [[ -z "$nameserver" ]] && return 1
  lookuplast=`host -W 5 $domain $nameserver 2>&1 | tail -1`
  log "$domain@$nameserver: '$lookuplast'"

  if [[ -n $(echo $lookuplast | grep NXDOMAIN) ]] ; then
    # example: host www.google.comp 8.8.8.8
    log "ERR: DNS <$nameserver>: domain <$domain> could not be resolved"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi

  if [[ -n $(echo $lookuplast | grep "timed out") ]] ; then
    # example: host www.google.com 8.8.8.7
    log "ERR: DNS <$nameserver>: NS server does not respond"
    problems_found=$(expr $problems_found + 1)
    return 1
  fi
  ipaddresses=$(host -W 5 $domain $nameserver | grep has | awk '/address/ {print $NF}')
  for ipaddress in $ipaddresses ; do
    success "DNS <$nameserver>: resolves <$domain> to <$ipaddress>"
  done
}

check_alldns(){
  status=1
  nsfound=0
  nsok=0
  nameservers=$( cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
  if ! check_ns $ns ; then
    alert "ERR: DNS <$ns>: cannot resolve <$domain>"
    problems_found=$(expr $problems_found + 1)
    return 1    
  fi
  for nameserver in $nameservers ;  do
    nsfound=$(( $nsfound + 1 ))
    log "DNS <$nameserver>: used as nameserver"
    if ping_host $nameserver 5 ; then
      if check_ns $nameserver ; then
        nsok=$(( $nsok +1 ))
      else
        problems_found=$(expr $problems_found + 1)
        status=$?
      fi
    fi
  done
  log "DNS: $nsok of $nsfound nameservers are OK"
  if [[ $nsok -lt 1 ]] ;  then
    fatal_problem=1
    problems_found=$(expr $problems_found + 1)
  fi

}

check_conn () {
# Checks network connectivity
  if ! ping_host $domain ; then
    alert "WARN: Host <$domain>: cannot be reached by ICMP ping"
    problems_found=$(expr $problems_found + 1)
  else
    success "Host <$domain>: can be reached by ICMP ping"
  fi
# Check web access, using nc
  httpversion=$(echo -e "HEAD / HTTP/1.0\n\n" | nc $domain $port 2>/dev/null  | grep HTTP)
  if [ $? -ne 0 ] ; then
    alert "WARN: Host <$domain:$port>: no response"
    problems_found=$(expr $problems_found + 1)
  else
    success "Host <$domain:$port>: web server responds!"
  fi
}

chapter () {
	out "\n### $1"
	if [[ "$2" != "" ]] ; then
		out "    -- $2"
	fi

}
####################################################################################
## Put your main script here
####################################################################################

main() {
    folder_prep "$tmpdir" 1
    folder_prep "$logdir" 7

    problems_found=0
    fatal_problem=0
    action=$(ucase $action)
    case $action in
    CHECK )
        chapter "CHECK NETWORK CARDS" "is your machine connected via wifi or cable?"
        [[ $fatal_problem -eq 0 ]] && default_interface
        [[ $fatal_problem -eq 0 ]] && check_local

        chapter "CHECK NETWORK CONNECTIONS" "does your gateway respond?"
        [[ $fatal_problem -eq 0 ]] && check_allif

        chapter "CHECK DNS RESOLUTION" "can you reach the internet?"
        [[ $fatal_problem -eq 0 ]] && check_alldns

        chapter "CHECK HTTP TRAFFIC" "can you access the web?"
        [[ $fatal_problem -eq 0 ]] && check_conn
        
        chapter "PROBLEMS FOUND: $problems_found" ""
        ;;
    *)
        die "\nAction [$action] not recognized"
    esac
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

init_options
parse_options $@
main
safe_exit
