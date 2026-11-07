extends RefCounted
## A readable direct-connect invitation, not a public room-code / relay service.
static func local_addresses() -> Array[String]:
	var addresses: Array[String]=[]
	for ip in IP.get_local_addresses():
		if ":" not in ip and not ip.begins_with("127.") and ip!="0.0.0.0": addresses.append(ip)
	# Prefer ordinary LAN addresses to VPN / benchmark adapters in the invite picker.
	addresses.sort_custom(func(a: String,b: String): return address_rank(a)<address_rank(b))
	if addresses.is_empty(): addresses.append("127.0.0.1")
	return addresses

static func address_rank(ip: String) -> int:
	if ip.begins_with("192.168."): return 0
	if ip.begins_with("10."): return 1
	if ip.begins_with("172.") and int(ip.get_slice(".",1))>=16 and int(ip.get_slice(".",1))<=31: return 1
	return 2

static func format_address(address: String, port: int) -> String:
	return "dustline://%s:%d"%[("["+address+"]") if ":" in address else address,port]

static func parse(value: String, default_port := 24567) -> Dictionary:
	var input := value.strip_edges().trim_prefix("dustline://")
	var host := input
	var port := default_port
	var port_text := ""
	if input.begins_with("["):
		var closing := input.find("]")
		if closing<2: return {}
		host=input.substr(1,closing-1)
		var rest := input.substr(closing+1)
		if not rest.is_empty():
			if not rest.begins_with(":"): return {}
			port_text=rest.substr(1)
			if port_text.is_empty(): return {}
	elif input.count(":")==1:
		host=input.get_slice(":",0)
		port_text=input.get_slice(":",1)
		if port_text.is_empty(): return {}
	if not port_text.is_empty():
		if not port_text.is_valid_int(): return {}
		port=int(port_text)
	if port<1024 or port>65535 or host.is_empty() or host.length()>253: return {}
	if not host.is_valid_ip_address():
		var allowed := RegEx.new()
		allowed.compile("^[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$")
		if allowed.search(host)==null or ".." in host: return {}
	return {"address":host,"port":port}
