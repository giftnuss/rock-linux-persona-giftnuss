
iptables_init_if() {
	if isfirst "iptables_$if"; then
		addcode up   1 1 "iptables -N firewall_$if"
		addcode up   2 2 "iptables -A INPUT -i $if -j firewall_$if"
		addcode up   1 3 "iptables -A firewall_$if `
			`-m state --state ESTABLISHED,RELATED -j ACCEPT"

		addcode down 1 3 "iptables -F firewall_$if"
		addcode down 1 2 "iptables -D INPUT -i $if -j firewall_$if"
		addcode down 1 1 "iptables -X firewall_$if"
	fi
}

iptables_parse_conditions() {
	iptables_cond=""
	while [ -n "$1" ]
	do
		case "$1" in
			all)
			shift
			;;
		    icmp)
			iptables_cond="$iptables_cond -p icmp --icmp-type $2"
			shift; shift
			;;
			from)
			case "$2" in
				all)
				shift; shift;
				;;
				tcp|udp)
				if [[ "$iptables_cond" == *-p* ]] ; then
					if [[ "$iptables_cond" != *"-p $2"* ]] ; then
						error "Specify either tcp or udp rules"
					else
						iptables_cond="$iptables_cond --sport $3"
					fi
				else
					iptables_cond="$iptables_cond -p $2 --sport $3"
				fi
				shift; shift; shift;
				;;
				ip)
				iptables_cond="$iptables_cond -s $3"
				shift; shift; shift;
				;;
				*)
				error "Unknown source type $2";
				shift; shift;
				;;
			esac
			;;
			to)
			case "$2" in
				all)
				shift; shift;
				;;
				tcp|udp)
				if [[ "$iptables_cond" == *-p* ]] ; then
					if [[ "$iptables_cond" != *"-p $2"* ]] ; then
						error "Specify either tcp or udp rules"
					else
						iptables_cond="$iptables_cond --dport $3"
					fi
				else
					iptables_cond="$iptables_cond -p $2 --dport $3"
				fi
				shift; shift; shift;
				;;
				ip)
				iptables_cond="$iptables_cond -d $3"
				shift; shift; shift;
				;;
				*)
				error "Unknown destination type $2";
				shift; shift;
				;;
			esac
			;;
		    *)
			error "Unkown firewall condition: $1"
			shift
		esac
	done
}

public_accept() {
	iptables_parse_conditions "$@"
	addcode up 1 5 "iptables -A firewall_$if $iptables_cond -j ACCEPT"
	iptables_init_if
}

public_reject() {
	iptables_parse_conditions "$@"
	addcode up 1 5 "iptables -A firewall_$if $iptables_cond -j REJECT"
	iptables_init_if
}

public_drop() {
	iptables_parse_conditions "$@"
	addcode up 1 5 "iptables -A firewall_$if $iptables_cond -j DROP"
	iptables_init_if
}

public_log() {
	iptables_parse_conditions "$@"
	addcode up 1 5 "iptables -A firewall_$if $iptables_cond -j LOG"
	iptables_init_if
}

public_clamp_mtu() {
	addcode up 1 6 "iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
	                -j TCPMSS --clamp-mss-to-pmtu"
	addcode down 9 6  "iptables -D FORWARD -p tcp --tcp-flags SYN,RST SYN \
	                  -j TCPMSS --clamp-mss-to-pmtu"
}

public_masquerade() {
	iptables_parse_conditions "$@"
	addcode up 1 6 "iptables -t nat -A POSTROUTING $iptables_cond -o $if \
	                -j MASQUERADE"
	addcode down 9 6 "iptables -t nat -D POSTROUTING $iptables_cond -o $if \
	                  -j MASQUERADE"
}

public_fw() {
	# fw <policy> <chainspec> <iptables_cond>
# 	fw accept in from ip 
# 	fw reject out to ip jumpto BLUBBER
# 	fw accept forward jump MYCHAIN to ip 
	case "$1" in
		accept) 
		target=ACCEPT
		shift
		;;
		reject)
		target=REJECT
		shift
		;;
		drop)
		target=DROP
		shift
		;;
		return)
		target=RETURN
		shift
		;;
		log)
		target=LOG
		shift
		;;
		*)
		target=$1
		shift
		;;
	esac

	if [ "$if" != "none" ]; then
		case "$1" in
			out|outgoing)
			chain=OUTPUT
			dir=o
			shift
			;;
			in|incoming)
			chain=INPUT
			dir=i
			shift
			;;
			*)
			if [ "$1" == "forward" ]; then
				chain=FORWARD
			else
				chain=$1
			fi
			shift
			case "$1" in
				in|incoming)
				dir=i
				shift;
				;;
				out|outgoing)
				dir=o
				shift;
				;;
				*)
				error "Not a forward interface specification: $1"
				;;
			esac
			;;
		esac
	else
		case "$1" in
			out|outgoing)
			chain=OUTPUT
			shift
			;;
			in|incoming)
			chain=INPUT
			shift
			;;
			forward|FORWARD)
			chain=FORWARD
			shift
			;;
			*)
			chain=$1
			shift
			;;
		esac
		if [ "$1" == "policy" ]; then
			addcode up 1 6 "iptables -P $chain $target"
			shift
			return
		fi
	fi
	iptables_parse_conditions "$@"
	$iptables -L $chain -n >/dev/null 2>/dev/null || {
		if isfirst "iptables_$chain" && \
			[ "$chain" != "INPUT" ] && [ "$chain" != "OUTPUT" ] && \
			[ "$chain" != "FORWARD" ] ; then
			addcode up   1 1 "iptables -N $chain"
			addcode down 1 1 "iptables -X $chain"
		fi
	}
	if [ "$if" == "none" -o "$dir" == "" ]; then
		ifspec=""
	else
		iptables_init_if
		ifspec="-$dir $if"
	fi
	addcode up 1 6 "iptables -A $chain $iptables_cond $ifspec -j $target"
	addcode down 9 6 "iptables -D $chain $iptables_cond $ifspec -j $target"
}
