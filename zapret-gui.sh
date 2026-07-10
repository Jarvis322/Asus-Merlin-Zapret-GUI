#!/bin/sh
##############################################################################
# zapret-gui : AsusWRT-Merlin Web UI addon for zapret
#   Adds a "zapret" page under the router's Network Tools menu:
#   live status, enable/disable/restart, editable strategy/ports/mode,
#   hostlist editor, blockcheck runner, log viewer, optional installer.
#
#   Why the odd event-encoding: on some Merlin builds httpd does NOT persist
#   custom nvram/amng_custom fields from web POSTs (only the rc_service event
#   fires). So the page encodes settings as base64url, splits them into
#   <128-char chunks, and streams them through rc_service events; this script
#   reassembles + applies them. It is the only reliable web->backend channel
#   on such firmware.
#
#   Repo: https://github.com/Jarvis322/Asus-Merlin-Zapret-GUI
#   License: MIT
##############################################################################
ADDON="zapret-gui"
ADDON_DIR="/jffs/addons/${ADDON}"
ASP_SRC="${ADDON_DIR}/zapret-gui.asp"
MENUTREE="/www/require/modules/menuTree.js"
MENUTREE_TMP="/tmp/menuTree.js"
# Menu anchor: the addon page is inserted right after this entry (Network Tools
# -> Site Survey). Change it if your firmware's menuTree.js differs.
MENU_ANCHOR='Advanced_Wireless_Survey.asp'
ZAPRET_DIR="/opt/zapret"
ZAPRET_INIT="${ZAPRET_DIR}/init.d/sysv/zapret"
ZAPRET_CONF="${ZAPRET_DIR}/config"
HOSTLIST="${ZAPRET_DIR}/ipset/zapret-hosts-user.txt"
HOSTLIST_EXCLUDE="${ZAPRET_DIR}/ipset/zapret-hosts-user-exclude.txt"
HOSTLIST_BAK="${HOSTLIST}.bak-gui"
PROFILE_DIR="${ADDON_DIR}/profiles"
SCHEDULE_FILE="${PROFILE_DIR}/schedule"
SCHED_LAST="/tmp/zapret-gui-scheduler.last"
BLOCKLOG="/tmp/zapret-blockcheck.log"
BLOCKPID="/tmp/zapret-blockcheck.pid"
SE="/jffs/scripts/service-event"
SEE="/jffs/scripts/service-event-end"
SS="/jffs/scripts/services-start"
TAG="# ${ADDON}"

[ -f /usr/sbin/helper.sh ] && . /usr/sbin/helper.sh

B64E()    { openssl base64 -A 2>/dev/null; }
# base64url decode (rc_service names can't carry +/=)
B64URL_D() { local b; b="$(echo "$1" | tr '_-' '/+')"; while [ $((${#b} % 4)) -ne 0 ]; do b="${b}="; done; echo "$b" | openssl base64 -d -A 2>/dev/null; }

Blockcheck_Running() {
	local p
	[ -f "$BLOCKPID" ] || { echo 0; return; }
	p="$(cat "$BLOCKPID" 2>/dev/null)"
	if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
		echo 1
	else
		rm -f "$BLOCKPID"
		echo 0
	fi
}

Ensure_Default_Lists() {
	[ -d "${ZAPRET_DIR}/ipset" ] || return 0
	if [ ! -s "$HOSTLIST" ]; then
		cat > "$HOSTLIST" <<'EOF'
discord.com
discordapp.com
discord.gg
discordapp.net
discordcdn.com
discord.media
gateway.discord.gg
cdn.discordapp.com
images-ext-1.discordapp.net
media.discordapp.net
status.discord.com
EOF
	fi
	if [ ! -s "$HOSTLIST_EXCLUDE" ]; then
		cat > "$HOSTLIST_EXCLUDE" <<'EOF'
# Apple / App Store / iCloud / software updates
apple.com
mzstatic.com
aaplimg.com
cdn-apple.com
icloud.com
icloud-content.com
apple-dns.net
itunes.com

# OpenAI / ChatGPT
openai.com
chatgpt.com
oaistatic.com
oaiusercontent.com
openaiapi-site.azureedge.net

# Anthropic / Claude
anthropic.com
claude.ai

# Google / Gemini
google.com
gemini.google.com
googleapis.com
gstatic.com
googleusercontent.com
googleusercontent.cn
withgoogle.com

# Common AI/CDN/auth dependencies
cloudflare.com
cloudflareaccess.com
challenges.cloudflare.com
EOF
	fi
	chmod 0666 "$HOSTLIST" "$HOSTLIST_EXCLUDE" 2>/dev/null
}

######## web page mount ################################################
Mount_UI() {
	local page
	Ensure_Default_Lists
	page="$(am_settings_get zapretgui_page)"
	if [ -z "$page" ]; then
		am_get_webui_page "$ASP_SRC"
		[ "$am_webui_page" = "none" ] && { logger -t "$ADDON" "no free user page slot"; return 1; }
		page="$am_webui_page"; am_settings_set zapretgui_page "$page"
	fi
	[ -f "$MENUTREE_TMP" ] || cp -f "$MENUTREE" "$MENUTREE_TMP"
	sed -i "\\~tabName: \"zapret\"~d" "$MENUTREE_TMP"
	sed -i "/url: \"${MENU_ANCHOR}\", tabName:/a {url: \"${page}\", tabName: \"zapret\"}," "$MENUTREE_TMP"
	umount "$MENUTREE" 2>/dev/null
	mount -o bind "$MENUTREE_TMP" "$MENUTREE"
	Gen_Status
	logger -t "$ADDON" "mounted as ${page}"
}
Unmount_UI() {
	local page; page="$(am_settings_get zapretgui_page)"
	umount "$MENUTREE" 2>/dev/null
	[ -n "$page" ] && rm -f "/www/user/${page}"
	sed -i "\\~tabName: \"zapret\"~d" "$MENUTREE_TMP" 2>/dev/null
}

######## build the page from the template with live values #############
Gen_Status() {
	local page enabled running pid qcount rules mode ports stamp strat ttl installed log_b64 hostlist_ok exclude_ok host_count exclude_count mode_ok bc_running custom_now
	page="$(am_settings_get zapretgui_page)"; [ -z "$page" ] && return
	[ -x "$ZAPRET_INIT" ] && installed=1 || installed=0
	[ -s "$HOSTLIST" ] && hostlist_ok=1 || hostlist_ok=0
	[ -s "$HOSTLIST_EXCLUDE" ] && exclude_ok=1 || exclude_ok=0
	host_count="$(grep -vE '^[[:space:]]*($|#)' "$HOSTLIST" 2>/dev/null | wc -l | tr -d ' ')"; [ -z "$host_count" ] && host_count=0
	exclude_count="$(grep -vE '^[[:space:]]*($|#)' "$HOSTLIST_EXCLUDE" 2>/dev/null | wc -l | tr -d ' ')"; [ -z "$exclude_count" ] && exclude_count=0
	enabled="$(grep -E '^NFQWS_ENABLE=' "$ZAPRET_CONF" 2>/dev/null | cut -d= -f2)"
	mode="$(grep -E '^MODE_FILTER=' "$ZAPRET_CONF" 2>/dev/null | cut -d= -f2)"
	# zapret stores "none" for process-everything; the GUI exposes it as "all"
	[ "$mode" = "none" ] && mode="all"
	# any recognised mode is a valid setup (hostlist / autohostlist / all-none)
	case "${mode:-hostlist}" in hostlist|autohostlist|all) mode_ok=1 ;; *) mode_ok=0 ;; esac
	bc_running="$(Blockcheck_Running)"
	ports="$(grep -E '^NFQWS_PORTS_TCP=' "$ZAPRET_CONF" 2>/dev/null | cut -d= -f2)"
	if grep -q -- '--hostspell=hoSt' "$ZAPRET_CONF" 2>/dev/null && grep -q -- '--dpi-desync=multidisorder --dpi-desync-split-pos=2 --dpi-desync-split-seqovl=1' "$ZAPRET_CONF" 2>/dev/null; then
		strat="superonline"
	else
		strat="$(grep -oE 'dpi-desync=[a-z0-9,]+' "$ZAPRET_CONF" 2>/dev/null | head -1 | cut -d= -f2)"
	fi
	# current raw 443 desync options, used to prefill the "custom" field (round-trip)
	custom_now="$(awk -F'--filter-tcp=443 ' '/--filter-tcp=443 /{sub(/ *(<HOSTLIST>|--new).*/,"",$2); print $2; exit}' "$ZAPRET_CONF" 2>/dev/null)"
	ttl="$(grep -oE 'dpi-desync-ttl=[0-9]+' "$ZAPRET_CONF" 2>/dev/null | head -1 | cut -d= -f2)"
	pid="$(pidof nfqws 2>/dev/null | awk '{print $1}')"
	[ -n "$pid" ] && running=1 || running=0
	qcount="$(awk '$1==200{print $8}' /proc/net/netfilter/nfnetlink_queue 2>/dev/null)"; [ -z "$qcount" ] && qcount=0
	# Some AsusWRT builds make `iptables -S` fail when vendor targets like
	# SKIPLOG are present.  The verbose listing still works and shows NFQUEUE.
	rules="$(iptables -t mangle -L -n 2>/dev/null | grep -c 'NFQUEUE.*num 200')"
	stamp="$(date '+%Y-%m-%d %H:%M:%S')"
	log_b64="$( { echo '### nfqws:'; cat /proc/$(pidof nfqws 2>/dev/null|awk '{print $1}')/cmdline 2>/dev/null | tr '\0' ' '; echo; echo; echo '### last restart log:'; tail -20 /tmp/zapret_restart.log 2>/dev/null; echo; echo "### blockcheck (running=${bc_running}):"; tail -80 "$BLOCKLOG" 2>/dev/null; } | B64E )"
	sed -e "s|@@ENABLED@@|${enabled:-0}|g" -e "s|@@RUNNING@@|${running}|g" \
	    -e "s|@@PID@@|${pid:-}|g" -e "s|@@QCOUNT@@|${qcount}|g" -e "s|@@RULES@@|${rules}|g" \
	    -e "s|@@MODE@@|${mode:-}|g" -e "s|@@PORTS@@|${ports:-}|g" -e "s|@@STAMP@@|${stamp}|g" \
	    -e "s|@@STRAT@@|${strat:-fake}|g" -e "s|@@TTL@@|${ttl:-2}|g" \
	    -e "s|@@INSTALLED@@|${installed}|g" -e "s|@@LOG_B64@@|${log_b64}|g" \
	    -e "s|@@HOSTLIST_OK@@|${hostlist_ok}|g" -e "s|@@EXCLUDE_OK@@|${exclude_ok}|g" \
	    -e "s|@@HOST_COUNT@@|${host_count}|g" -e "s|@@EXCLUDE_COUNT@@|${exclude_count}|g" \
	    -e "s|@@MODE_OK@@|${mode_ok}|g" \
	    -e "s|@@BC_RUNNING@@|${bc_running}|g" \
	    -e "s|@@CUSTOM@@|${custom_now}|g" \
	    -e "s|@@PAGE@@|${page}|g" \
	    "$ASP_SRC" \
	| awk -v hl="$HOSTLIST" '$0=="@@HOSTAREA@@"{print "<textarea id=\"f_hosts\" class=\"zg-hosts\" rows=\"9\" spellcheck=\"false\" oninput=\"upd_hc()\">"; while((getline l < hl)>0) print l; print "</textarea>"; next} {print}' \
	    > "/www/user/${page}"
}

######## simple actions ################################################
Do_Enable()  { sed -i 's/^NFQWS_ENABLE=.*/NFQWS_ENABLE=1/' "$ZAPRET_CONF"; "$ZAPRET_INIT" restart >/dev/null 2>&1; Gen_Status; }
Do_Disable() { "$ZAPRET_INIT" stop >/dev/null 2>&1; sed -i 's/^NFQWS_ENABLE=.*/NFQWS_ENABLE=0/' "$ZAPRET_CONF"; Gen_Status; }
Do_Restart() { "$ZAPRET_INIT" restart >/dev/null 2>&1; Gen_Status; }

Strat_Line() {  # $1=strategy $2=ttl
	case "$1" in
		fake)          echo "--dpi-desync=fake --dpi-desync-ttl=$2" ;;
		fakedsplit)    echo "--dpi-desync=fakedsplit --dpi-desync-ttl=$2" ;;
		fakeddisorder) echo "--dpi-desync=fakeddisorder --dpi-desync-ttl=$2" ;;
		disorder2)     echo "--dpi-desync=disorder2" ;;
		split2)        echo "--dpi-desync=split2" ;;
		multisplit)    echo "--dpi-desync=multisplit" ;;
		superonline)   echo "SUPERONLINE_PROFILE" ;;
		*)             echo "--dpi-desync=fake --dpi-desync-ttl=$2" ;;
	esac
}

######## apply settings decoded from the event blob ####################
Apply_Event_Cfg() {
	local dec en strat ttl ports mode hosts_raw sline p oi custom restart_rc
	dec="$(B64URL_D "$1")"
	[ -z "$dec" ] && { logger -t "$ADDON" "event cfg decode failed"; return 1; }
	en="$(echo "$dec" | sed -n 's/^enable=//p')"; [ "$en" = "1" ] || en=0
	strat="$(echo "$dec" | sed -n 's/^strat=//p' | tr -cd 'a-z0-9')"
	ttl="$(echo "$dec" | sed -n 's/^ttl=//p' | tr -cd '0-9')"; [ -z "$ttl" ] && ttl=2
	ports="$(echo "$dec" | sed -n 's/^ports=//p' | tr -cd '0-9,')"; [ -z "$ports" ] && ports=80,443
	mode="$(echo "$dec" | sed -n 's/^mode=//p' | tr -cd 'a-z')"
	# GUI "all" = process every connection; zapret's config value for that is "none"
	case "$mode" in hostlist|autohostlist|none) ;; all) mode=none ;; *) mode=hostlist ;; esac
	# raw custom strategy (used only when strat=custom). Allow the nfqws option
	# charset and strip shell metacharacters ("$`;\ etc.) so it can never break
	# out of the double-quoted NFQWS_OPT="" it gets written into.
	custom="$(echo "$dec" | sed -n 's/^custom=//p' | tr -cd 'A-Za-z0-9 =,.:+/-')"
	hosts_raw="$(echo "$dec" | sed -n 's/^hosts=//p')"
	[ -f "$ZAPRET_CONF" ] || return 1
	cp -f "$ZAPRET_CONF" "${ZAPRET_CONF}.bak-gui"
	[ -f "$HOSTLIST" ] && cp -f "$HOSTLIST" "$HOSTLIST_BAK"
	sed -i "s/^NFQWS_ENABLE=.*/NFQWS_ENABLE=$en/"         "$ZAPRET_CONF"
	sed -i "s/^NFQWS_PORTS_TCP=.*/NFQWS_PORTS_TCP=$ports/" "$ZAPRET_CONF"
	sed -i "s/^MODE_FILTER=.*/MODE_FILTER=$mode/"         "$ZAPRET_CONF"
	sline="$(Strat_Line "$strat" "$ttl")"
	if [ "$strat" = "superonline" ]; then
		# Superonline Discord profile found by focused blockcheck.
		ports="80,443"
		sed -i "s/^NFQWS_PORTS_TCP=.*/NFQWS_PORTS_TCP=$ports/" "$ZAPRET_CONF"
		{
			echo "NFQWS_OPT=\""
			echo "--filter-tcp=80 --hostspell=hoSt <HOSTLIST> --new"
			echo "--filter-tcp=443 --dpi-desync=multidisorder --dpi-desync-split-pos=2 --dpi-desync-split-seqovl=1 <HOSTLIST> --new"
			echo "\""
		} > /tmp/zg_opt
	elif [ "$strat" = "custom" ]; then
		# user-supplied raw desync options, e.g. pasted straight from a blockcheck
		# result for their own ISP. Falls back to plain fake if left empty.
		[ -z "$custom" ] && custom="--dpi-desync=fake --dpi-desync-ttl=$ttl"
		{ echo "NFQWS_OPT=\""; oi="$IFS"; IFS=','; for p in $ports; do echo "--filter-tcp=$p $custom <HOSTLIST> --new"; done; IFS="$oi"; echo "\""; } > /tmp/zg_opt
	else
		{ echo "NFQWS_OPT=\""; oi="$IFS"; IFS=','; for p in $ports; do echo "--filter-tcp=$p $sline <HOSTLIST> --new"; done; IFS="$oi"; echo "\""; } > /tmp/zg_opt
	fi
	awk 'BEGIN{while((getline l < "/tmp/zg_opt")>0) buf=buf l "\n"} /^NFQWS_OPT=/{printf "%s", buf; skip=1; next} skip==1{ if($0=="\"") skip=0; next } {print}' "$ZAPRET_CONF" > "${ZAPRET_CONF}.new" && mv "${ZAPRET_CONF}.new" "$ZAPRET_CONF"
	rm -f /tmp/zg_opt
	if [ -n "$hosts_raw" ]; then
		printf '%s\n' "$hosts_raw" | tr '~' '\n' > "$HOSTLIST"
	else
		: > "$HOSTLIST"
	fi
	if [ "$en" = "1" ]; then
		restart_rc=0
		"$ZAPRET_INIT" restart >/dev/null 2>&1 || restart_rc=$?
		sleep 2
		# A restart can return success while nfqws immediately exits because the
		# generated options are invalid. Roll back both config and hostlist.
		if [ "$restart_rc" -ne 0 ] || ! pidof nfqws >/dev/null 2>&1; then
			cp -f "${ZAPRET_CONF}.bak-gui" "$ZAPRET_CONF"
			[ -f "$HOSTLIST_BAK" ] && cp -f "$HOSTLIST_BAK" "$HOSTLIST"
			"$ZAPRET_INIT" restart >/dev/null 2>&1
			logger -t "$ADDON" "apply failed (rc=$restart_rc); rolled back config and hostlist"
			Gen_Status
			return 1
		fi
	else
		"$ZAPRET_INIT" stop >/dev/null 2>&1
	fi
	logger -t "$ADDON" "applied: en=$en strat=$strat ttl=$ttl ports=$ports mode=$mode hostlist_chars=${#hosts_raw}"
	Gen_Status
}

######## router-side profiles and scheduler ############################
Profile_Save_Event() {
	local dec name encoded
	dec="$(B64URL_D "$1")"
	name="$(echo "$dec" | sed -n 's/^name=//p' | tr -cd 'A-Za-z0-9_.-')"
	[ -n "$name" ] || return 1
	mkdir -p "$PROFILE_DIR"
	encoded="$(printf '%s\n' "$dec" | sed '/^name=/d' | B64E | tr '+/' '-_' | tr -d '=')"
	[ -n "$encoded" ] || return 1
	printf '%s\n' "$encoded" > "$PROFILE_DIR/${name}.profile"
	logger -t "$ADDON" "router profile saved: $name"
}
Profile_Apply() {
	local name payload
	name="$(printf '%s' "$1" | tr -cd 'A-Za-z0-9_.-')"
	payload="$PROFILE_DIR/${name}.profile"
	[ -s "$payload" ] || { logger -t "$ADDON" "router profile not found: $name"; return 1; }
	Apply_Event_Cfg "$(cat "$payload")"
}
Schedule_Save_Event() {
	local dec name start end days delete
	dec="$(B64URL_D "$1")"
	name="$(echo "$dec" | sed -n 's/^name=//p' | tr -cd 'A-Za-z0-9_.-')"
	start="$(echo "$dec" | sed -n 's/^start=//p' | tr -cd '0-9:')"
	end="$(echo "$dec" | sed -n 's/^end=//p' | tr -cd '0-9:')"
	days="$(echo "$dec" | sed -n 's/^days=//p' | tr -cd '1-7')"
	delete="$(echo "$dec" | sed -n 's/^delete=//p')"
	[ -n "$name" ] || return 1
	mkdir -p "$PROFILE_DIR"; touch "$SCHEDULE_FILE"
	sed -i "\\~^${name}|~d" "$SCHEDULE_FILE"
	if [ "$delete" != "1" ] && [ -s "$PROFILE_DIR/${name}.profile" ] && [ -n "$start" ] && [ -n "$end" ] && [ -n "$days" ]; then
		printf '%s|%s|%s|%s\n' "$name" "$start" "$end" "$days" >> "$SCHEDULE_FILE"
		logger -t "$ADDON" "schedule saved: $name $start-$end days=$days"
	else
		logger -t "$ADDON" "schedule removed: $name"
	fi
}
Scheduler() {
	local now day name start end days last key
	while :; do
		now="$(date '+%H:%M')"; day="$(date '+%u')"
		[ -f "$SCHEDULE_FILE" ] && while IFS='|' read -r name start end days; do
			[ -n "$name" ] || continue
			case "$days" in *"$day"*) ;; *) continue ;; esac
			[ "$start" \< "$end" ] || continue
			if { [ "$now" \> "$start" ] || [ "$now" = "$start" ]; } && [ "$now" \< "$end" ]; then
				key="${day}|${name}|${start}"; last="$(cat "$SCHED_LAST" 2>/dev/null)"
				if [ "$key" != "$last" ]; then printf '%s' "$key" > "$SCHED_LAST"; Profile_Apply "$name"; fi
			fi
		done < "$SCHEDULE_FILE"
		sleep 30
	done
}

# Remove every trace of a blockcheck run: its helper nfqws + the iptables chains
# it inserts. blockcheck redirects the test IP to its own NFQUEUE *without*
# --queue-bypass, so if the run is interrupted/killed those chains keep DROPping
# all traffic to that IP (this is what makes a site look "IP-blocked"). Idempotent.
# Only touches blockcheck's own nfqws (qnum 59780 / fwmark 0x10000000) and the
# blockcheck_* chains, so the main zapret daemon (qnum 200) is never affected.
Cleanup_Blockcheck() {
	kill $(ps w | grep '[b]lockcheck.sh' | awk '{print $1}') 2>/dev/null
	kill $(ps w | grep '[n]fqws' | grep -E 'qnum=59780|0x10000000' | awk '{print $1}') 2>/dev/null
	for tbl in filter mangle nat raw; do
		iptables  -t "$tbl" -D INPUT   -j blockcheck_input  2>/dev/null
		iptables  -t "$tbl" -D OUTPUT  -j blockcheck_output 2>/dev/null
		iptables  -t "$tbl" -D FORWARD -j blockcheck_input  2>/dev/null
		ip6tables -t "$tbl" -D INPUT   -j blockcheck_input  2>/dev/null
		ip6tables -t "$tbl" -D OUTPUT  -j blockcheck_output 2>/dev/null
		for ch in blockcheck_input blockcheck_output; do
			iptables  -t "$tbl" -F "$ch" 2>/dev/null; iptables  -t "$tbl" -X "$ch" 2>/dev/null
			ip6tables -t "$tbl" -F "$ch" 2>/dev/null; ip6tables -t "$tbl" -X "$ch" 2>/dev/null
		done
	done
}

Do_Blockcheck_Ev() {
	local dom bc_script
	dom="$(B64URL_D "$1" | sed -n 's/^bc=//p' | tr -cd 'a-zA-Z0-9.-')"; [ -z "$dom" ] && dom=rutracker.org
	bc_script="${ZAPRET_DIR}/blockcheck.sh"
	if [ ! -f "$bc_script" ]; then
		{ echo "blockcheck error: ${bc_script} not found"; echo "time: $(date)"; } > "$BLOCKLOG"
		Gen_Status
		return
	fi
	if [ "$(Blockcheck_Running)" = "1" ]; then
		echo "blockcheck already running, ignoring duplicate request - $(date)" >> "$BLOCKLOG"
		Gen_Status
		return
	fi
	Cleanup_Blockcheck   # clear leftover chains/nfqws from a previous crashed run
	(
		echo "### blockcheck started ###"
		echo "domain: $dom"
		echo "time: $(date)"
		echo
		cd "$ZAPRET_DIR" || exit 1
		if command -v timeout >/dev/null 2>&1; then
			DOMAINS="$dom" BATCH=1 CURL_MAX_TIME=5 timeout 180 sh ./blockcheck.sh
		else
			DOMAINS="$dom" BATCH=1 CURL_MAX_TIME=5 sh ./blockcheck.sh
		fi
		rc=$?
		echo
		echo "### blockcheck done: exit=${rc} time=$(date) ###"
		Cleanup_Blockcheck   # always remove blockcheck's DROP chains + helper nfqws
		rm -f "$BLOCKPID"
		Gen_Status
	) > "$BLOCKLOG" 2>&1 &
	echo $! > "$BLOCKPID"
	# Watchdog: `timeout` is absent on busybox, so a hung blockcheck could otherwise
	# leave its DROP chains up forever (and Blockcheck_Running would block retries).
	# Force cleanup after ~4 min if the run is still alive.
	(
		bcpid="$(cat "$BLOCKPID" 2>/dev/null)"; i=0
		while [ "$i" -lt 240 ]; do kill -0 "$bcpid" 2>/dev/null || exit 0; sleep 5; i=$((i+5)); done
		Cleanup_Blockcheck
		rm -f "$BLOCKPID"
		echo '### watchdog: blockcheck timed out, cleaned up ###' >> "$BLOCKLOG"
		Gen_Status
	) &
	Gen_Status
}

Do_Install() {  # best effort helper; run blockcheck afterwards to pick a strategy
	local url="https://github.com/bol-van/zapret.git"
	echo "zapret install started - $(date)" > /tmp/zapret_restart.log
	{
		if [ -x "$ZAPRET_INIT" ]; then echo "already installed."; else
			command -v git >/dev/null 2>&1 && git clone --depth 1 "$url" "$ZAPRET_DIR"
			[ -x "${ZAPRET_DIR}/install_bin.sh" ] && sh "${ZAPRET_DIR}/install_bin.sh"
		fi
		Ensure_Default_Lists
		echo "### install step done ###"
	} >> /tmp/zapret_restart.log 2>&1 &
	Gen_Status
}
Do_Update() {
	local repo="https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main" ts
	ts="$(date +%Y%m%d-%H%M%S)"
	command -v curl >/dev/null 2>&1 || { logger -t "$ADDON" "GitHub update failed: curl missing"; return 1; }
	if ! curl -fsSL "$repo/zapret-gui.sh" -o /tmp/zapret-gui.sh.update || ! curl -fsSL "$repo/zapret-gui.asp" -o /tmp/zapret-gui.asp.update; then
		logger -t "$ADDON" "GitHub update failed: download error"; rm -f /tmp/zapret-gui.*.update; return 1
	fi
	sh -n /tmp/zapret-gui.sh.update || { logger -t "$ADDON" "GitHub update rejected: shell syntax error"; rm -f /tmp/zapret-gui.*.update; return 1; }
	cp -p "${ADDON_DIR}/${ADDON}.sh" "${ADDON_DIR}/${ADDON}.sh.bak-github-${ts}"
	cp -p "$ASP_SRC" "${ASP_SRC}.bak-github-${ts}"
	mv -f /tmp/zapret-gui.sh.update "${ADDON_DIR}/${ADDON}.sh"
	mv -f /tmp/zapret-gui.asp.update "$ASP_SRC"
	chmod 0755 "${ADDON_DIR}/${ADDON}.sh"; chmod 0644 "$ASP_SRC"
	Mount_UI
	logger -t "$ADDON" "updated from GitHub main"
}

######## persistence hooks + install/uninstall #########################
Add_Hook() { [ -f "$1" ] || { echo "#!/bin/sh" > "$1"; chmod 0755 "$1"; }; grep -qF "$2" "$1" || echo "$2" >> "$1"; }
Install() {
	Ensure_Default_Lists
	Add_Hook "$SS"  "[ -x ${ADDON_DIR}/${ADDON}.sh ] && ${ADDON_DIR}/${ADDON}.sh mount & ${TAG}"
	Add_Hook "$SEE" "[ -x ${ADDON_DIR}/${ADDON}.sh ] && ${ADDON_DIR}/${ADDON}.sh event \"\$@\" & ${TAG}"
	Add_Hook "$SS"  "[ -x ${ADDON_DIR}/${ADDON}.sh ] && ${ADDON_DIR}/${ADDON}.sh scheduler >/dev/null 2>&1 & ${TAG}-scheduler"
	chmod 0755 "${ADDON_DIR}/${ADDON}.sh"; Mount_UI; echo "installed"
}
Uninstall() {
	Unmount_UI
	sed -i "\\~${TAG}~d" "$SS"  2>/dev/null; sed -i "\\~${TAG}~d" "$SE" 2>/dev/null; sed -i "\\~${TAG}~d" "$SEE" 2>/dev/null
	am_settings_set zapretgui_page ""; echo "uninstalled"
}

# service-event dispatcher. The page streams settings as base64url chunks via
# rc_service events: zgR = reset+first chunk, zgA = append, zgZ = end -> apply.
Handle_Event() {
	ev="$(printf '%s' "$*")"
	case "$ev" in
		"restart zgR"*)  printf '%s' "${ev#restart zgR}" > /tmp/zg_blob ;;
		"restart_zgR"*)  printf '%s' "${ev#restart_zgR}" > /tmp/zg_blob ;;
		"restart zgA"*)  printf '%s' "${ev#restart zgA}" >> /tmp/zg_blob ;;
		"restart_zgA"*)  printf '%s' "${ev#restart_zgA}" >> /tmp/zg_blob ;;
		"restart zgZ"*)  Apply_Event_Cfg "$(cat /tmp/zg_blob 2>/dev/null)" ;;
		"restart_zgZ"*)  Apply_Event_Cfg "$(cat /tmp/zg_blob 2>/dev/null)" ;;
		"restart_zpR"*)  printf '%s' "${ev#restart_zpR}" > /tmp/zp_blob ;;
		"restart_zpA"*)  printf '%s' "${ev#restart_zpA}" >> /tmp/zp_blob ;;
		"restart_zpZ"*)  Profile_Save_Event "$(cat /tmp/zp_blob 2>/dev/null)" ;;
		"restart_zs"*)  Schedule_Save_Event "${ev#restart_zs}" ;;
		*zgbc*)          Do_Blockcheck_Ev "${ev#*zgbc}" ;;
		*zapretinstall*) Do_Install ;;
		*zapretrestart*) Do_Restart ;;
		*zapreton*)      Do_Enable ;;
		*zapretoff*)     Do_Disable ;;
		*zapretstatus*)  Gen_Status ;;
		*zapretupdate*)  Do_Update ;;
	esac
	# re-mount page + menu after httpd restarts (tmpfs is rebuilt)
	if printf '%s' "$ev" | grep -qE '(start|restart).*httpd'; then sleep 3; Mount_UI; fi
}

case "$1" in
	install)   Install ;;
	uninstall) Uninstall ;;
	mount)     Mount_UI ;;
	unmount)   Unmount_UI ;;
	status)    Gen_Status ;;
	profile_apply) Profile_Apply "$2" ;;
	scheduler) Scheduler ;;
	event)     shift; Handle_Event "$@" ;;
	enable)    Do_Enable ;;
	disable)   Do_Disable ;;
	restart)   Do_Restart ;;
	*) echo "usage: $0 {install|uninstall|mount|unmount|status|enable|disable|restart}" ;;
esac
