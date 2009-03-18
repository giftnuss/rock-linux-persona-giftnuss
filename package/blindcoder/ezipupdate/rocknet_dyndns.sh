public_dyndns() {
	addcode up 5 5 "dyndns_start $if"
	addcode down 5 5 "dyndns_stop $if"
}

dyndns_start () {
	if=$1
	[ ! -f /etc/ezipupdate/stone.$if ] && \
		error "$if not configured for ez-ipupdate usage! Run \`stone' first!"
	ez-ipupdate -F /var/run/ez-ipupdate.$if.pid -c /etc/ezipupdate/stone.$if
}
dyndns_stop () {
	if=$1
	[ ! -f /etc/ezipupdate/stone.$if ] && \
		error "$if not configured for ez-ipupdate usage! Run \`stone' first!"
	kill -QUIT `cat /var/run/ez-ipupdate.$if.pid`
	rm -f /var/run/ez-ipupdate.$if.pid
}
