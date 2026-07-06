<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>zapret</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="/device-map/device-map.css">
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script type="text/javascript">
var zapret_enabled='@@ENABLED@@', zapret_running='@@RUNNING@@', zapret_pid='@@PID@@',
    zapret_qcount='@@QCOUNT@@', zapret_rules='@@RULES@@', zapret_mode='@@MODE@@',
    zapret_ports='@@PORTS@@', zapret_stamp='@@STAMP@@', zapret_strat='@@STRAT@@',
    zapret_ttl='@@TTL@@', zapret_installed='@@INSTALLED@@', zapret_log_b64='@@LOG_B64@@';
function $id(x){ return document.getElementById(x); }
function yn(v){ return (v=='1')?'<span style="color:#093">&#10004; Evet</span>':'<span style="color:#c33">&#10008; Hay&#305;r</span>'; }
function setSel(id,val){ var s=$id(id); if(!s)return; for(var i=0;i<s.options.length;i++){ if(s.options[i].value==val){ s.selectedIndex=i; return; } } }
function initial(){
	var pg=location.pathname.replace(/^\//,'');
	try{ document.form.current_page.value=pg; document.form.next_page.value=pg; }catch(e){}
	try{ show_menu(); }catch(e){}
	try{ refresh_status(); }catch(e){}
	try{ fill_form(); }catch(e){}
}
function refresh_status(){
	$id('st_enabled').innerHTML=yn(zapret_enabled);
	$id('st_running').innerHTML=yn(zapret_running);
	$id('st_pid').innerHTML=(zapret_pid||'-');
	$id('st_rules').innerHTML=zapret_rules+' (iptables NFQUEUE)';
	$id('st_qcount').innerHTML=zapret_qcount+' paket';
	$id('st_mode').innerHTML=(zapret_mode||'-');
	$id('st_ports').innerHTML=(zapret_ports||'-');
	var ok=(zapret_running=='1' && zapret_rules>0);
	$id('st_overall').innerHTML=(ok?'<span style="color:#093;font-weight:bold;">&#9679; &Ccedil;ALI&#350;IYOR</span>':'<span style="color:#c33;font-weight:bold;">&#9679; DEVRE DI&#350;I / SORUNLU</span>')+'<span style="color:#aaa;font-size:11px;">&nbsp;&nbsp;(g&uuml;ncelleme: '+zapret_stamp+')</span>';
}
var _filled=false;
function fill_form(){
	if(_filled) return;   // populate once, so user edits are never clobbered by a late onload
	_filled=true;
	$id('f_enable').checked=(zapret_enabled=='1');
	setSel('f_strat',zapret_strat); $id('f_ttl').value=zapret_ttl;
	$id('f_ports').value=zapret_ports; setSel('f_mode',zapret_mode);
	try{ $id('f_log').textContent=atob(zapret_log_b64||''); }catch(e){}
	if(zapret_installed!='1'){ $id('install_panel').style.display=''; $id('main_panel').style.display='none'; }
	upd_hc();
}
function upd_hc(){
	var t=$id('f_hosts'); if(!t) return;
	var v=t.value.replace(/\r/g,'').replace(/\n+$/,'');
	$id('hc').textContent='satır: '+(v?v.split('\n').length:0);
}
function post_action(script,wait,reloadMs){
	document.form.action_script.value=script;
	document.form.action_wait.value=''+wait;
	if(typeof showLoading==='function') showLoading(wait+1);
	document.form.submit();
	if(reloadMs) setTimeout(function(){ location.reload(); }, reloadMs);
}
function do_action(act){
	var m=(act=='zapretoff')?'zapret KAPATILSIN mı?':(act=='zapreton')?'zapret AÇILSIN mı?':'zapret yeniden başlatılsın mı?';
	if(!confirm(m)) return; post_action('restart_'+act,12,14000);
}
function b64url(s){ return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,''); }
function fireEv(script,cb){ httpApi.nvramSet({"action_mode":"apply","rc_service":script}, cb); }
// httpd truncates rc_service names ~128 chars, so stream settings as base64url chunks
function save_apply(){
	if(!confirm('Ayarlar kaydedilip zapret yeniden başlatılsın mı?')) return;
	var tv=$id('f_hosts').value.replace(/\r/g,'').replace(/\n+$/,'');
	var blob='enable='+($id('f_enable').checked?'1':'0')+'\nstrat='+$id('f_strat').value
	  +'\nttl='+$id('f_ttl').value+'\nports='+$id('f_ports').value+'\nmode='+$id('f_mode').value
	  +'\nhosts='+tv.split('\n').join('~');
	var b=b64url(blob), chunks=[];
	for(var i=0;i<b.length;i+=100) chunks.push(b.substr(i,100));
	if(typeof showLoading==='function') showLoading(chunks.length+17);
	var idx=0;
	(function next(){
		if(idx<chunks.length){
			fireEv('restart_zg'+(idx===0?'R':'A')+chunks[idx], function(){ idx++; setTimeout(next,500); });
		}else{
			fireEv('restart_zgZ', function(){ setTimeout(function(){ location.reload(); }, 16000); });
		}
	})();
}
function run_blockcheck(){
	post_action('restart_zgbc'+b64url('bc='+$id('f_bcdomain').value),5,0);
	alert('Blockcheck arka planda başladı ('+$id('f_bcdomain').value+'). ~1-2 dk sonra "Yenile" ile aşağıdaki Log bölümünden sonucu görün.');
}
function do_install(){
	if(!confirm('zapret indirilip kurulsun mu? (DENEYSEL - internet gerekir)')) return;
	post_action('restart_zapretinstall',5,0);
	alert('Kurulum arka planda başladı. ~1 dk sonra "Yenile" ile Log bölümünü izleyin.');
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" width="0" height="0" frameborder="0" scrolling="no" style="display:none;"></iframe>
<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="group_id" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_wait" value="">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
<table class="content" align="center" cellpadding="0" cellspacing="0"><tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202"><div id="mainMenu"></div><div id="subMenu"></div></td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0"><tr><td valign="top">
<table width="760px" border="0" cellpadding="4" cellspacing="0" class="FormTitle" id="FormTitle"><tbody>
<tr><td bgcolor="#4D595D" valign="top"><div>&nbsp;</div>
<div class="formfonttitle">zapret &mdash; DPI Bypass <span style="font-size:12px;color:#9f9;">v1.0</span></div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>

<!-- INSTALL PANEL (only if zapret is not installed) -->
<div id="install_panel" style="display:none;">
<div class="formfontdesc">zapret bu cihazda <b>kurulu de&#287;il</b>. A&#351;a&#287;&#305;daki buton zapret'i GitHub'dan indirip ikili dosyalar&#305;n&#305; kurar (deneysel; internet gerekir). Sonras&#305;nda strateji i&ccedil;in blockcheck &ccedil;al&#305;&#351;t&#305;r&#305;n.</div>
<div style="margin:12px 5px;"><input class="button_gen" onclick="do_install();" type="button" value="zapret'i Kur"></div>
</div>

<!-- MAIN PANEL -->
<div id="main_panel">
<div id="st_overall" style="margin:8px 0 12px 5px;font-size:15px;">&#8230;</div>

<table width="99%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
<thead><tr><td colspan="2">Durum</td></tr></thead>
<tr><th width="40%">Etkin (config)</th><td id="st_enabled">-</td></tr>
<tr><th>nfqws &ccedil;al&#305;&#351;&#305;yor</th><td id="st_running">-</td></tr>
<tr><th>nfqws PID</th><td id="st_pid">-</td></tr>
<tr><th>Firewall kurallar&#305;</th><td id="st_rules">-</td></tr>
<tr><th>Kuyruk sayac&#305; (queue 200)</th><td id="st_qcount">-</td></tr>
<tr><th>Mod</th><td id="st_mode">-</td></tr>
<tr><th>Portlar (TCP)</th><td id="st_ports">-</td></tr>
</table>
<div style="margin:12px 0;text-align:center;">
<input class="button_gen" onclick="do_action('zapreton');" type="button" value="A&ccedil;">
<input class="button_gen" onclick="do_action('zapretrestart');" type="button" value="Yeniden Ba&#351;lat">
<input class="button_gen" onclick="do_action('zapretoff');" type="button" value="Kapat">
<input class="button_gen" onclick="location.reload();" type="button" value="Yenile">
</div>

<!-- SETTINGS -->
<table width="99%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
<thead><tr><td colspan="2">Ayarlar</td></tr></thead>
<tr><th width="40%">Etkin</th><td><input type="checkbox" id="f_enable"></td></tr>
<tr><th>Strateji</th><td><select id="f_strat" class="input_option">
<option value="fake">fake (varsay&#305;lan)</option>
<option value="fakedsplit">fakedsplit</option>
<option value="fakeddisorder">fakeddisorder</option>
<option value="disorder2">disorder2</option>
<option value="split2">split2</option>
<option value="multisplit">multisplit</option>
</select></td></tr>
<tr><th>TTL (fake i&ccedil;in)</th><td><input type="text" id="f_ttl" class="input_6_table" maxlength="3" value="2"></td></tr>
<tr><th>Portlar (TCP, virg&uuml;lle)</th><td><input type="text" id="f_ports" class="input_15_table" maxlength="64" value="80,443"></td></tr>
<tr><th>Mod</th><td><select id="f_mode" class="input_option">
<option value="hostlist">hostlist (sadece liste)</option>
<option value="autohostlist">autohostlist (otomatik)</option>
<option value="all">all (t&uuml;m trafik)</option>
</select></td></tr>
</table>

<!-- HOSTLIST (textarea content is server-rendered at @@HOSTAREA@@) -->
<table width="99%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
<thead><tr><td>Hostlist (her sat&#305;ra bir domain)</td></tr></thead>
<tr><td>
@@HOSTAREA@@
<div id="hc" class="formfontdesc" style="margin-top:4px;">sat&#305;r: 0</div>
</td></tr>
</table>
<div style="margin:12px 0;text-align:center;">
<input class="button_gen" style="background:#093;" onclick="save_apply();" type="button" value="Kaydet &amp; Uygula">
</div>

<!-- TOOLS / BLOCKCHECK / LOG -->
<table width="99%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
<thead><tr><td colspan="2">Ara&ccedil;lar</td></tr></thead>
<tr><th width="40%">Blockcheck test domaini</th><td>
<input type="text" id="f_bcdomain" class="input_15_table" value="rutracker.org">
<input class="button_gen" onclick="run_blockcheck();" type="button" value="Blockcheck &ccedil;al&#305;&#351;t&#305;r">
</td></tr>
</table>
<div class="formfontdesc" style="margin-top:8px;">Log (nfqws komutu + restart + blockcheck &ccedil;&#305;kt&#305;s&#305;):</div>
<pre id="f_log" style="background:#1a1a1a;color:#7f7;padding:8px;height:200px;overflow:auto;font-size:11px;white-space:pre-wrap;">-</pre>
<div class="formfontdesc" style="margin-top:10px;color:#FC0;">Not: &quot;Kaydet &amp; Uygula&quot; config'i yede&#287;e al&#305;p (config.bak-gui) zapret'i yeniden ba&#351;lat&#305;r. De&#287;i&#351;iklik sonras&#305; sayfa otomatik yenilenir.</div>
</div><!-- main_panel -->

</td></tr></tbody></table>
</td></tr></table>
</td>
<td width="10" align="center" valign="top"></td>
</tr></table>
</form>
<div id="footer"></div>
<script type="text/javascript">try{ refresh_status(); fill_form(); }catch(e){}</script>
</body>
</html>
