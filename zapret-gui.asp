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
    zapret_ttl='@@TTL@@', zapret_installed='@@INSTALLED@@', zapret_log_b64='@@LOG_B64@@',
    zapret_hostlist_ok='@@HOSTLIST_OK@@', zapret_exclude_ok='@@EXCLUDE_OK@@',
    zapret_host_count='@@HOST_COUNT@@', zapret_exclude_count='@@EXCLUDE_COUNT@@',
    zapret_mode_ok='@@MODE_OK@@', zapret_bc_running='@@BC_RUNNING@@';
function $id(x){ return document.getElementById(x); }
function yn(v){ return (v=='1')?'<span style="color:#66ff99;font-weight:700">&#10004; Evet</span>':'<span style="color:#ff8f8f;font-weight:700">&#10008; Hay&#305;r</span>'; }
function wz(v, ok, bad){
	return (v=='1')?'<span class="zg-ok">&#10004; '+ok+'</span>':'<span class="zg-bad">&#10008; '+bad+'</span>';
}
function setSel(id,val){ var s=$id(id); if(!s)return; for(var i=0;i<s.options.length;i++){ if(s.options[i].value==val){ s.selectedIndex=i; return; } } }
function initial(){
	var pg=location.pathname.replace(/^\//,'');
	try{ document.form.current_page.value=pg; document.form.next_page.value=pg; }catch(e){}
	try{ show_menu(); }catch(e){}
	try{ refresh_status(); }catch(e){}
	try{ refresh_wizard(); }catch(e){}
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
	if($id('bc_status')) $id('bc_status').innerHTML=wz(zapret_bc_running,'blockcheck calisiyor','hazir');
	var ok=(zapret_running=='1' && zapret_rules>0);
	$id('st_overall').innerHTML=(ok?'<span style="color:#093;font-weight:bold;">&#9679; &Ccedil;ALI&#350;IYOR</span>':'<span style="color:#c33;font-weight:bold;">&#9679; DEVRE DI&#350;I / SORUNLU</span>')+'<span style="color:#aaa;font-size:11px;">&nbsp;&nbsp;(g&uuml;ncelleme: '+zapret_stamp+')</span>';
}
function refresh_wizard(){
	$id('wz_installed').innerHTML=wz(zapret_installed,'zapret bulundu','zapret kurulu degil');
	$id('wz_hostlist').innerHTML=wz(zapret_hostlist_ok,'hostlist hazir ('+zapret_host_count+' domain)','hostlist yok veya bos');
	$id('wz_exclude').innerHTML=wz(zapret_exclude_ok,'exclude list hazir ('+zapret_exclude_count+' domain)','exclude list yok veya bos');
	$id('wz_mode').innerHTML=wz(zapret_mode_ok,'onerilen mod aktif: hostlist','onerilen mod: hostlist');
	$id('wz_start').innerHTML=wz((zapret_running=='1' && zapret_rules>0)?'1':'0','servis calisiyor','servis henuz aktif degil');
	if(zapret_installed!='1'){
		$id('wz_hint').innerHTML='Once zapret kurulumunu tamamlayin, sonra test edip baslatin.';
	}else if(zapret_running=='1' && zapret_rules>0){
		$id('wz_hint').innerHTML='Kurulum tamam. Degisikliklerden sonra Yenile ile durumu tekrar kontrol edebilirsiniz.';
	}else{
		$id('wz_hint').innerHTML='Hazir gorunuyor. Test et veya Baslat ile devam edin.';
	}
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
	var n=(v?v.split('\n').filter(function(x){return x.replace(/\s/g,'').length>0;}).length:0);
	$id('hc').textContent='satir: '+n;
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
	if(zapret_installed!='1'){ alert('Blockcheck icin once zapret kurulu olmali.'); return; }
	if(zapret_bc_running=='1'){ alert('Blockcheck zaten calisiyor. Log bolumunden takip edip birazdan Yenile ile kontrol edin.'); return; }
	post_action('restart_zgbc'+b64url('bc='+$id('f_bcdomain').value),5,8000);
	alert('Blockcheck arka planda basladi ('+$id('f_bcdomain').value+'). Sayfa birazdan yenilenip calisma durumunu gosterecek.');
}
function wizard_test(){
	if(zapret_installed!='1'){ alert('Testten once zapret kurulu olmali. Once Kur / Onerileni Uygula ile kurulumu baslatin.'); return; }
	if(zapret_bc_running=='1'){ alert('Blockcheck zaten calisiyor. Log bolumunden takip edip birazdan Yenile ile kontrol edin.'); return; }
	post_action('restart_zgbc'+b64url('bc=discord.com'),5,8000);
	alert('Hizli test arka planda basladi (discord.com). Sayfa birazdan yenilenip calisma durumunu gosterecek.');
}
function wizard_recommended(){
	if(zapret_installed!='1'){ do_install(); return; }
	if($id('f_mode')) setSel('f_mode','hostlist');
	if($id('f_enable')) $id('f_enable').checked=true;
	save_apply();
}
function wizard_start(){
	if(zapret_installed!='1'){ do_install(); return; }
	do_action('zapreton');
}
function do_install(){
	if(!confirm('zapret indirilip kurulsun mu? (DENEYSEL - internet gerekir)')) return;
	post_action('restart_zapretinstall',5,0);
	alert('Kurulum arka planda başladı. ~1 dk sonra "Yenile" ile Log bölümünü izleyin.');
}
</script>

<style type="text/css">
.zg-wrap{max-width:980px;margin:0 auto 18px auto;color:#dbe5e8;}
.zg-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:6px 0 14px 0;padding:16px 18px;border:1px solid rgba(255,255,255,.12);border-radius:8px;background:linear-gradient(135deg,#26383d,#172326);box-shadow:0 1px 0 rgba(255,255,255,.06) inset;}
.zg-title{font-size:24px;font-weight:700;color:#fff;text-shadow:0 1px 2px #000;}
.zg-version{font-size:12px;color:#9cff9c;margin-left:6px;}
.zg-overall{font-size:14px;padding:8px 12px;border-radius:999px;background:rgba(0,0,0,.22);white-space:nowrap;}
.zg-card{margin:12px 0 16px 0;border:1px solid rgba(255,255,255,.13);border-radius:8px;overflow:hidden;background:#34484d;box-shadow:0 10px 24px rgba(0,0,0,.16);}
.zg-card-title{padding:10px 14px;font-size:15px;font-weight:700;color:#fff;background:linear-gradient(#77878b,#617277);border-bottom:1px solid rgba(0,0,0,.35);}
.zg-table{width:100%;border-collapse:collapse;}
.zg-table th,.zg-table td{padding:11px 14px;border-bottom:1px solid rgba(0,0,0,.32);border-right:1px solid rgba(0,0,0,.22);font-size:14px;}
.zg-table th{width:34%;text-align:left;color:#eef5f6;background:rgba(0,0,0,.16);}
.zg-table td{background:rgba(255,255,255,.035);}
.zg-actions{text-align:center;margin:12px 0 18px 0;display:flex;gap:8px;justify-content:center;flex-wrap:wrap;}
.zg-btn{min-width:122px;border:0;border-radius:7px;padding:10px 14px;background:#10191b;color:#fff;font-weight:700;cursor:pointer;box-shadow:0 1px 0 rgba(255,255,255,.08) inset,0 1px 4px rgba(0,0,0,.25);}
.zg-btn:hover{background:#172528;}
.zg-btn-save{background:#078a36;}
.zg-btn-save:hover{background:#0a9d40;}
.zg-input,.zg-select{background:#5b6f74;color:#fff;border:1px solid #93a4a8;border-radius:4px;padding:7px 8px;min-height:34px;box-sizing:border-box;}
.zg-hosts{width:100%;min-height:180px;box-sizing:border-box;font-family:Menlo,Consolas,monospace;font-size:14px;line-height:1.45;padding:12px;border:1px solid #aab7ba;border-radius:6px;background:#f7fafb;color:#111;resize:vertical;}
.zg-meta{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-top:7px;color:#cdd7da;font-size:12px;}
.zg-hint{color:#aebcc0;}
.zg-log{background:#111b1d;color:#8dff8d;padding:10px;border-radius:6px;height:200px;overflow:auto;font-size:11px;white-space:pre-wrap;border:1px solid rgba(255,255,255,.1);}
.zg-wizard{padding:14px;}
.zg-wizard-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px;margin-bottom:12px;}
.zg-step{padding:10px;border-radius:7px;background:rgba(0,0,0,.16);border:1px solid rgba(255,255,255,.08);min-height:44px;}
.zg-step-label{display:block;color:#aebcc0;font-size:11px;margin-bottom:4px;}
.zg-ok{color:#66ff99;font-weight:700;}
.zg-bad{color:#ff8f8f;font-weight:700;}
.zg-wizard-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;}
.zg-credit{text-align:center;color:#aebcc0;font-size:12px;margin:14px 0 2px 0;}
.zg-credit a{color:#9cff9c;text-decoration:none;}
.zg-credit a:hover{text-decoration:underline;}
@media(max-width:760px){.zg-head{display:block}.zg-overall{display:inline-block;margin-top:10px}.zg-table th,.zg-table td{display:block;width:auto}.zg-actions{justify-content:stretch}.zg-btn{flex:1 1 45%;}}
@media(max-width:760px){.zg-wizard-grid{grid-template-columns:1fr;}}
</style>
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
<div class="zg-wrap">
<div class="zg-head"><div class="zg-title">zapret &mdash; DPI Bypass <span class="zg-version">v1.0</span></div><div id="st_overall" class="zg-overall">&#8230;</div></div>

<!-- SETUP WIZARD -->
<div class="zg-card" id="wizard_panel">
<div class="zg-card-title">Kurulum Kontrol&uuml;</div>
<div class="zg-wizard">
<div class="zg-wizard-grid">
<div class="zg-step"><span class="zg-step-label">1. zapret</span><span id="wz_installed">-</span></div>
<div class="zg-step"><span class="zg-step-label">2. Hostlist</span><span id="wz_hostlist">-</span></div>
<div class="zg-step"><span class="zg-step-label">3. Exclude list</span><span id="wz_exclude">-</span></div>
<div class="zg-step"><span class="zg-step-label">4. Onerilen mod</span><span id="wz_mode">-</span></div>
<div class="zg-step"><span class="zg-step-label">5. Test / baslat</span><span id="wz_start">-</span></div>
</div>
<div class="zg-wizard-foot">
<span id="wz_hint" class="zg-hint">Kontrol ediliyor...</span>
<span class="zg-actions" style="margin:0;">
<input class="zg-btn" onclick="wizard_recommended();" type="button" value="Kur / Onerileni Uygula">
<input class="zg-btn" onclick="wizard_test();" type="button" value="Test Et">
<input class="zg-btn zg-btn-save" onclick="wizard_start();" type="button" value="Baslat">
<input class="zg-btn" onclick="location.reload();" type="button" value="Yenile">
</span>
</div>
</div>
</div>

<!-- INSTALL PANEL (only if zapret is not installed) -->
<div id="install_panel" style="display:none;">
<div class="formfontdesc">zapret bu cihazda <b>kurulu de&#287;il</b>. A&#351;a&#287;&#305;daki buton zapret'i GitHub'dan indirip ikili dosyalar&#305;n&#305; kurar (deneysel; internet gerekir). Sonras&#305;nda strateji i&ccedil;in blockcheck &ccedil;al&#305;&#351;t&#305;r&#305;n.</div>
<div style="margin:12px 5px;"><input class="zg-btn" onclick="do_install();" type="button" value="zapret'i Kur"></div>
</div>

<!-- MAIN PANEL -->
<div id="main_panel">
<div class="zg-card">
<div class="zg-card-title">Durum</div>
<table class="zg-table">
<tr><th width="40%">Etkin (config)</th><td id="st_enabled">-</td></tr>
<tr><th>nfqws &ccedil;al&#305;&#351;&#305;yor</th><td id="st_running">-</td></tr>
<tr><th>nfqws PID</th><td id="st_pid">-</td></tr>
<tr><th>Firewall kurallar&#305;</th><td id="st_rules">-</td></tr>
<tr><th>Kuyruk sayac&#305; (queue 200)</th><td id="st_qcount">-</td></tr>
<tr><th>Mod</th><td id="st_mode">-</td></tr>
<tr><th>Portlar (TCP)</th><td id="st_ports">-</td></tr>
</table>
</div>
<div class="zg-actions">
<input class="zg-btn" onclick="do_action('zapreton');" type="button" value="A&ccedil;">
<input class="zg-btn" onclick="do_action('zapretrestart');" type="button" value="Yeniden Ba&#351;lat">
<input class="zg-btn" onclick="do_action('zapretoff');" type="button" value="Kapat">
<input class="zg-btn" onclick="location.reload();" type="button" value="Yenile">
</div>

<!-- SETTINGS -->
<div class="zg-card">
<div class="zg-card-title">Ayarlar</div>
<table class="zg-table">
<tr><th width="40%">Etkin</th><td><input type="checkbox" id="f_enable"></td></tr>
<tr><th>Strateji</th><td><select id="f_strat" class="zg-select">
<option value="fake">fake (varsay&#305;lan)</option>
<option value="fakedsplit">fakedsplit</option>
<option value="fakeddisorder">fakeddisorder</option>
<option value="disorder2">disorder2</option>
<option value="split2">split2</option>
<option value="multisplit">multisplit</option>
<option value="superonline">Superonline TR (fake+md5sig)</option>
</select></td></tr>
<tr><th>TTL (fake i&ccedil;in)</th><td><input type="text" id="f_ttl" class="zg-input" maxlength="3" value="2"></td></tr>
<tr><th>Portlar (TCP, virg&uuml;lle)</th><td><input type="text" id="f_ports" class="zg-input" maxlength="64" value="80,443"></td></tr>
<tr><th>Mod</th><td><select id="f_mode" class="zg-select">
<option value="hostlist">hostlist (sadece liste)</option>
<option value="autohostlist">autohostlist (otomatik)</option>
<option value="all">all (t&uuml;m trafik)</option>
</select></td></tr>
</table>
</div>

<!-- HOSTLIST (textarea content is server-rendered at @@HOSTAREA@@) -->
<div class="zg-card">
<div class="zg-card-title">Hostlist</div>
<div style="padding:12px 14px;">
@@HOSTAREA@@
<div class="zg-meta"><span id="hc">satir: 0</span><span class="zg-hint">Her satira bir domain. Sadece listedeki hedefler islenir.</span></div>
</div>
</div>
<div class="zg-actions">
<input class="zg-btn zg-btn-save" onclick="save_apply();" type="button" value="Kaydet &amp; Uygula">
</div>

<!-- TOOLS / BLOCKCHECK / LOG -->
<div class="zg-card">
<div class="zg-card-title">Ara&ccedil;lar</div>
<table class="zg-table">
<tr><th width="40%">Blockcheck durumu</th><td id="bc_status">-</td></tr>
<tr><th width="40%">Blockcheck test domaini</th><td>
<input type="text" id="f_bcdomain" class="zg-input" value="rutracker.org">
<input class="zg-btn" onclick="run_blockcheck();" type="button" value="Blockcheck &ccedil;al&#305;&#351;t&#305;r">
</td></tr>
</table>
</div>
<div class="zg-card">
<div class="zg-card-title">Log</div>
<div style="padding:12px 14px;">
<div class="formfontdesc" style="margin-top:0;">Log (nfqws komutu + restart + blockcheck &ccedil;&#305;kt&#305;s&#305;):</div>
<pre id="f_log" class="zg-log">-</pre>
<div class="formfontdesc" style="margin-top:10px;color:#FC0;">Not: &quot;Kaydet &amp; Uygula&quot; config'i yede&#287;e al&#305;p (config.bak-gui) zapret'i yeniden ba&#351;lat&#305;r. De&#287;i&#351;iklik sonras&#305; sayfa otomatik yenilenir.</div>
</div>
</div>
</div><!-- main_panel -->
<div class="zg-credit">Developed by <a href="https://x.com/yigitech" target="_blank" rel="noopener">x.com/yigitech</a></div>
</div><!-- zg-wrap -->

</td></tr></tbody></table>
</td></tr></table>
</td>
<td width="10" align="center" valign="top"></td>
</tr></table>
</form>
<div id="footer"></div>
<script type="text/javascript">try{ refresh_status(); refresh_wizard(); fill_form(); }catch(e){}</script>
</body>
</html>
