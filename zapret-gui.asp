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
var zapret_gui_version='v1.1', zapret_enabled='@@ENABLED@@', zapret_running='@@RUNNING@@', zapret_pid='@@PID@@',
    zapret_qcount='@@QCOUNT@@', zapret_rules='@@RULES@@', zapret_mode='@@MODE@@',
    zapret_ports='@@PORTS@@', zapret_stamp='@@STAMP@@', zapret_strat='@@STRAT@@',
    zapret_ttl='@@TTL@@', zapret_installed='@@INSTALLED@@', zapret_log_b64='@@LOG_B64@@',
    zapret_hostlist_ok='@@HOSTLIST_OK@@', zapret_exclude_ok='@@EXCLUDE_OK@@',
    zapret_host_count='@@HOST_COUNT@@', zapret_exclude_count='@@EXCLUDE_COUNT@@',
    zapret_mode_ok='@@MODE_OK@@', zapret_bc_running='@@BC_RUNNING@@';
function $id(x){ return document.getElementById(x); }
function yn(v){ return (v=='1')?'<span style="color:#66ff99;font-weight:700">✓ Evet</span>':'<span style="color:#ff8f8f;font-weight:700">✕ Hayır</span>'; }
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
	try{ refresh_profiles(); }catch(e){}
	try{ load_auto_refresh(); }catch(e){}
}
function refresh_status(){
	$id('st_enabled').innerHTML=yn(zapret_enabled);
	$id('st_running').innerHTML=yn(zapret_running);
	$id('st_pid').innerHTML=(zapret_pid||'-');
	$id('st_rules').innerHTML=zapret_rules+' (iptables NFQUEUE)';
	$id('st_qcount').innerHTML=zapret_qcount+' paket';
	$id('st_mode').innerHTML=(zapret_mode||'-');
	$id('st_ports').innerHTML=(zapret_ports||'-');
	if($id('bc_status')) $id('bc_status').innerHTML=(zapret_bc_running=='1'?'&#9203; çalışıyor':'<span style="color:#888;">hazır (boşta)</span>');
	var ok=(zapret_running=='1' && zapret_rules>0);
	$id('st_overall').innerHTML=(ok?'<span style="color:#63e6b0;font-weight:bold;">● ÇALIŞIYOR</span>':'<span style="color:#ff8c9e;font-weight:bold;">● DEVRE DIŞI / SORUNLU</span>')+'<span style="color:#9cacbf;font-size:11px;">&nbsp;&nbsp;(güncelleme: '+zapret_stamp+')</span>';
}
function refresh_wizard(){
	$id('wz_installed').innerHTML=wz(zapret_installed,'zapret bulundu','zapret kurulu değil');
	$id('wz_hostlist').innerHTML=wz(zapret_hostlist_ok,'hostlist hazır ('+zapret_host_count+' alan adı)','hostlist yok veya boş');
	$id('wz_exclude').innerHTML=wz(zapret_exclude_ok,'hariç listesi hazır ('+zapret_exclude_count+' alan adı)','hariç listesi yok veya boş');
	$id('wz_mode').innerHTML=wz(zapret_mode_ok,'mod etkin: '+(zapret_mode||'-'),'mod ayarlı değil');
	$id('wz_start').innerHTML=wz((zapret_running=='1' && zapret_rules>0)?'1':'0','servis çalışıyor','servis henüz etkin değil');
	if(zapret_installed!='1'){
		$id('wz_hint').innerHTML='Önce zapret kurulumunu tamamlayın, sonra test edip başlatın.';
	}else if(zapret_running=='1' && zapret_rules>0){
		$id('wz_hint').innerHTML='Kurulum tamam. Değişikliklerden sonra Yenile ile durumu tekrar kontrol edebilirsiniz.';
	}else{
		$id('wz_hint').innerHTML='Hazır görünüyor. Test Et veya Başlat ile devam edin.';
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
function profile_store(){
	try{ return JSON.parse(localStorage.getItem('zapret_gui_profiles')||'{}'); }catch(e){ return {}; }
}
function profile_save_store(o){
	try{ localStorage.setItem('zapret_gui_profiles',JSON.stringify(o)); return true; }catch(e){ return false; }
}
function profile_data(){
	return {enable:$id('f_enable').checked,strat:$id('f_strat').value,ttl:$id('f_ttl').value,
		ports:$id('f_ports').value,mode:$id('f_mode').value,custom:$id('f_custom').value,
		hosts:$id('f_hosts').value};
}
function refresh_profiles(){
	var s=$id('f_profile'); if(!s)return;
	while(s.options.length>1)s.remove(1);
	var o=profile_store();
	for(var k in o)if(Object.prototype.hasOwnProperty.call(o,k)){var op=document.createElement('option');op.value=k;op.text=k;s.appendChild(op);}
}
function save_profile(){
	var n=($id('f_profile_name').value||'').replace(/^\s+|\s+$/g,'');
	if(!n){alert('Profil adını girin.');return;}
	var o=profile_store();o[n]=profile_data();
	if(!profile_save_store(o)){alert('Profil kaydedilemedi. Tarayıcının localStorage desteği kapalı olabilir.');return;}
	refresh_profiles();setSel('f_profile',n);$id('f_profile_name').value='';alert('Profil kaydedildi: '+n);
}
function load_profile(){
	var n=$id('f_profile').value,o=profile_store();if(!n||!o[n])return;
	var p=o[n];$id('f_enable').checked=!!p.enable;setSel('f_strat',p.strat);$id('f_ttl').value=p.ttl||2;
	$id('f_ports').value=p.ports||'80,443';setSel('f_mode',p.mode||'hostlist');$id('f_custom').value=p.custom||'';
	$id('f_hosts').value=p.hosts||'';upd_hc();
}
function delete_profile(){
	var n=$id('f_profile').value;if(!n)return;
	if(!confirm('"'+n+'" profili silinsin mi?'))return;var o=profile_store();delete o[n];profile_save_store(o);refresh_profiles();
}
function export_profiles(){var raw=JSON.stringify(profile_store(),null,2);window.prompt('Profil yedeğini kopyalayın:',raw);}
function import_profiles(){var raw=window.prompt('Daha önce dışa aktardığınız profil JSON verisini yapıştırın:');if(!raw)return;try{var o=JSON.parse(raw);if(!o||typeof o!=='object')throw 0;profile_save_store(o);refresh_profiles();alert('Profiller içe aktarıldı.');}catch(e){alert('Geçersiz profil JSON verisi.');}}
function router_profile_blob(n){var p=profile_store()[n];if(!p)return '';return 'name='+n+'\nenable='+(p.enable?'1':'0')+'\nstrat='+(p.strat||'fake')+'\nttl='+(p.ttl||2)+'\nports='+(p.ports||'80,443')+'\nmode='+(p.mode||'hostlist')+'\ncustom='+(p.custom||'')+'\nhosts='+(p.hosts||'').replace(/\r?\n/g,'~');}
function send_router_profile(){var n=$id('f_profile').value;if(!n){alert('Önce yerel bir profil seçin.');return;}var b=b64url(router_profile_blob(n)),c=[];for(var i=0;i<b.length;i+=100)c.push(b.substr(i,100));var j=0;(function next(){if(j<c.length){fireEv('restart_zp'+(j===0?'R':'A')+c[j],function(){j++;setTimeout(next,300);});}else{fireEv('restart_zpZ',function(){alert('Profil routera kaydedildi: '+n);});}})();}
function save_schedule(){var n=$id('f_profile').value,s=$id('f_schedule_start').value,e=$id('f_schedule_end').value,d=$id('f_schedule_days').value.replace(/[^1-7]/g,'');if(!n||!s||!e||!d){alert('Profil, başlangıç, bitiş ve günleri doldurun.');return;}fireEv('restart_zs'+b64url('name='+n+'\nstart='+s+'\nend='+e+'\ndays='+d),function(){alert('Zamanlama routera kaydedildi.');});}
function delete_schedule(){var n=$id('f_profile').value;if(!n){alert('Profil seçin.');return;}fireEv('restart_zs'+b64url('name='+n+'\ndelete=1'),function(){alert('Profil zamanlaması kaldırıldı.');});}
function host_lines(){return $id('f_hosts').value.replace(/\r/g,'').split('\n');}
function clean_hostlist(){var seen={},out=[];host_lines().forEach(function(x){x=x.replace(/^\s+|\s+$/g,'');if(!x||x.charAt(0)==='#')return;var k=x.toLowerCase();if(!seen[k]){seen[k]=1;out.push(x);}});$id('f_hosts').value=out.join('\n');upd_hc();alert(out.length+' geçerli satır korundu; tekrarlar ve boş satırlar temizlendi.');}
function validate_hostlist(){var bad=[],rx=/^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/;host_lines().forEach(function(x,i){x=x.replace(/^\s+|\s+$/g,'');if(x&&x.charAt(0)!=='#'&&!rx.test(x))bad.push((i+1)+': '+x);});alert(bad.length?'Geçersiz satırlar:\n'+bad.slice(0,20).join('\n')+(bad.length>20?'\n...':''):'Hostlist biçimi geçerli.');}
function hostlist_clear(){if(confirm('Hostlist tamamen temizlensin mi?')){$id('f_hosts').value='';upd_hc();}}
function record_live(){try{var h=JSON.parse(localStorage.getItem('zapret_gui_history')||'[]');h.push({t:new Date().toISOString(),q:String(zapret_qcount),r:String(zapret_rules)});while(h.length>20)h.shift();localStorage.setItem('zapret_gui_history',JSON.stringify(h));}catch(e){}}
function toggle_auto_refresh(){try{localStorage.setItem('zapret_gui_auto_refresh',$id('f_auto_refresh').checked?'1':'0');}catch(e){}if($id('f_auto_refresh').checked)setTimeout(function(){location.reload();},10000);}
function load_auto_refresh(){try{$id('f_auto_refresh').checked=localStorage.getItem('zapret_gui_auto_refresh')==='1';}catch(e){}record_live();if($id('f_auto_refresh').checked)setTimeout(function(){location.reload();},10000);}
function check_update(){var out=$id('update_status');if(out)out.textContent='Kontrol ediliyor...';try{var x=new XMLHttpRequest();x.open('GET','https://raw.githubusercontent.com/Jarvis322/Asus-Merlin-Zapret-GUI/main/zapret-gui.asp?ts='+new Date().getTime(),true);x.onreadystatechange=function(){if(x.readyState!==4)return;if(x.status!==200){if(out)out.textContent='GitHub kontrolü başarısız ('+x.status+').';return;}var m=x.responseText.match(/zg-version[^>]*>(v[0-9.]+)/);if(out)out.textContent=m?'Yerel '+zapret_gui_version+' / GitHub '+m[1]:'GitHub erişilebilir; sürüm etiketi bulunamadı.';};x.send();}catch(e){if(out)out.textContent='Güncelleme kontrolü kullanılamıyor.';}}
function update_from_github(){if(!confirm('Güncelleme yalnızca GitHub main üzerinden indirilecek. Mevcut dosyalar yedeklenir. Devam edilsin mi?'))return;post_action('restart_zapretupdate',15,16000);}
function upd_hc(){
	var t=$id('f_hosts'); if(!t) return;
	var v=t.value.replace(/\r/g,'').replace(/\n+$/,'');
	var n=(v?v.split('\n').filter(function(x){return x.replace(/\s/g,'').length>0;}).length:0);
	$id('hc').textContent='satır: '+n;
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
	if(!confirm('Ayarlar kaydedilip zapret yeniden başlatılsın mı? Başarısız olursa otomatik geri alınır.')) return;
	var tv=$id('f_hosts').value.replace(/\r/g,'').replace(/\n+$/,'');
	var blob='enable='+($id('f_enable').checked?'1':'0')+'\nstrat='+$id('f_strat').value
	  +'\nttl='+$id('f_ttl').value+'\nports='+$id('f_ports').value+'\nmode='+$id('f_mode').value
	  +'\ncustom='+($id('f_custom')?$id('f_custom').value:'')
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
	if(zapret_installed!='1'){ alert('Blockcheck için önce zapret kurulu olmalı.'); return; }
	if(zapret_bc_running=='1'){ alert('Blockcheck zaten çalışıyor. Log bölümünden takip edip birazdan Yenile ile kontrol edin.'); return; }
	post_action('restart_zgbc'+b64url('bc='+$id('f_bcdomain').value),5,8000);
	alert('Blockcheck arka planda başladı ('+$id('f_bcdomain').value+'). Sayfa birazdan yenilenip çalışma durumunu gösterecek.');
}
function quick_test(d){$id('f_bcdomain').value=d;run_blockcheck();}
function wizard_test(){
	if(zapret_installed!='1'){ alert('Testten önce zapret kurulu olmalı. Önce Kur / Önerileni Uygula ile kurulumu başlatın.'); return; }
	if(zapret_bc_running=='1'){ alert('Blockcheck zaten çalışıyor. Log bölümünden takip edip birazdan Yenile ile kontrol edin.'); return; }
	post_action('restart_zgbc'+b64url('bc=discord.com'),5,8000);
	alert('Hızlı test arka planda başladı (discord.com). Sayfa birazdan yenilenip çalışma durumunu gösterecek.');
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
.zg-wrap{max-width:1080px;margin:0 auto 24px;color:#e8eef7;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif;}
.zg-head{display:flex;align-items:center;justify-content:space-between;gap:18px;margin:10px 0 18px;padding:24px;border:1px solid rgba(137,180,255,.25);border-radius:18px;background:linear-gradient(135deg,#172642 0%,#101722 60%,#172d37 100%);box-shadow:0 14px 35px rgba(0,0,0,.28),0 1px 0 rgba(255,255,255,.08) inset;}
.zg-kicker{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#8fb8ff;margin-bottom:5px;}
.zg-title{font-size:28px;font-weight:800;color:#fff;letter-spacing:-.5px;}
.zg-version{font-size:11px;color:#9ec5ff;margin-left:8px;vertical-align:middle;}
.zg-subtitle{margin-top:6px;color:#9cacbf;font-size:13px;}
.zg-overall{font-size:13px;padding:10px 14px;border:1px solid rgba(255,255,255,.13);border-radius:999px;background:rgba(7,13,24,.55);white-space:nowrap;}
.zg-card{margin:0 0 16px;border:1px solid rgba(148,177,218,.16);border-radius:16px;overflow:hidden;background:linear-gradient(145deg,rgba(32,48,72,.96),rgba(20,29,44,.96));box-shadow:0 10px 28px rgba(0,0,0,.18);}
.zg-card-title{display:flex;justify-content:space-between;align-items:center;padding:14px 18px;font-size:15px;font-weight:750;color:#fff;background:rgba(94,137,199,.13);border-bottom:1px solid rgba(148,177,218,.12);}
.zg-card-subtitle{font-size:11px;font-weight:400;color:#8fa4bf;}
.zg-table{width:100%;border-collapse:collapse;}
.zg-table th,.zg-table td{padding:13px 16px;border-bottom:1px solid rgba(148,177,218,.11);font-size:13px;}
.zg-table tr:last-child th,.zg-table tr:last-child td{border-bottom:0;}
.zg-table th{width:34%;text-align:left;color:#b9c9dd;background:rgba(2,8,18,.16);}
.zg-table td{color:#f4f7fb;}
.zg-actions{display:flex;gap:9px;justify-content:center;flex-wrap:wrap;margin:12px 0 18px;}
.zg-btn{min-width:116px;border:1px solid rgba(255,255,255,.1);border-radius:9px;padding:10px 14px;background:#263750;color:#f6f9ff;font-weight:700;cursor:pointer;transition:transform .15s,background .15s,box-shadow .15s;box-shadow:0 4px 10px rgba(0,0,0,.15);}
.zg-btn:hover{background:#344d70;transform:translateY(-1px);}
.zg-btn-save{background:linear-gradient(135deg,#167d66,#135b73);border-color:#3cb89b;}
.zg-btn-save:hover{background:linear-gradient(135deg,#1b997c,#176f8b);}
.zg-btn-secondary{min-width:96px;background:#1c2a40;}
.zg-input,.zg-select{width:100%;background:#101b2c;color:#f1f6ff;border:1px solid #3a5375;border-radius:9px;padding:9px 10px;min-height:36px;box-sizing:border-box;outline:none;}
.zg-input:focus,.zg-select:focus{border-color:#65a5ff;box-shadow:0 0 0 3px rgba(73,145,255,.16);}
.zg-hosts{width:100%;min-height:190px;box-sizing:border-box;font-family:Menlo,Consolas,monospace;font-size:13px;line-height:1.5;padding:13px;border:1px solid #3a5375;border-radius:10px;background:#0b1422;color:#dceaff;resize:vertical;}
.zg-meta,.zg-profile-row{display:flex;justify-content:space-between;align-items:center;gap:9px;margin-top:9px;color:#9fb0c6;font-size:12px;}
.zg-profile-row{padding:15px 18px 5px;margin:0;flex-wrap:wrap;}
.zg-profile-row .zg-select,.zg-profile-row .zg-input{max-width:210px;flex:1 1 160px;}
.zg-profile-row .zg-btn{min-width:0;flex:1 1 118px;white-space:nowrap;padding-left:9px;padding-right:9px;}
.zg-hint{color:#91a4bd;font-size:12px;line-height:1.5;}
.zg-profile-card>.zg-hint{display:block;padding:0 18px 16px;}
.zg-log{background:#09111d;color:#91f2c1;padding:13px;border-radius:10px;height:210px;overflow:auto;font-size:11px;white-space:pre-wrap;border:1px solid rgba(111,164,224,.16);}
.zg-wizard{padding:16px;}.zg-wizard-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:9px;margin-bottom:14px;}
.zg-step{padding:12px;border-radius:11px;background:rgba(5,13,25,.28);border:1px solid rgba(148,177,218,.12);min-height:44px;}
.zg-step-label{display:block;color:#8fa4bf;font-size:11px;margin-bottom:5px;}.zg-ok{color:#63e6b0;font-weight:700;}.zg-bad{color:#ff8c9e;font-weight:700;}
.zg-wizard-foot{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;}.zg-credit{text-align:center;color:#8194ad;font-size:12px;margin:18px 0 2px;}.zg-credit a{color:#8fb8ff;text-decoration:none;}.zg-credit a:hover{text-decoration:underline;}
@media(max-width:760px){.zg-head{display:block;padding:20px}.zg-overall{display:inline-block;margin-top:14px}.zg-table th,.zg-table td{display:block;width:auto}.zg-actions{justify-content:stretch}.zg-btn{flex:1 1 44%;}.zg-wizard-grid{grid-template-columns:1fr 1fr}.zg-profile-row{flex-wrap:wrap}.zg-profile-row .zg-select,.zg-profile-row .zg-input{max-width:none;flex:1 1 100%;}}
@media(max-width:420px){.zg-wizard-grid{grid-template-columns:1fr;}.zg-title{font-size:23px;}}
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
<div class="zg-head"><div><div class="zg-kicker">AĞ KONTROL MERKEZİ</div><div class="zg-title">zapret <span class="zg-version">v1.1</span></div><div class="zg-subtitle">DPI atlatma ayarlarını güvenli ve hızlı yönetin</div></div><div id="st_overall" class="zg-overall">&#8230;</div></div>

<!-- SETUP WIZARD -->
<div class="zg-card" id="wizard_panel">
<div class="zg-card-title">Kurulum Kontrolü</div>
<div class="zg-wizard">
<div class="zg-wizard-grid">
<div class="zg-step"><span class="zg-step-label">1. zapret</span><span id="wz_installed">-</span></div>
<div class="zg-step"><span class="zg-step-label">2. Hostlist</span><span id="wz_hostlist">-</span></div>
<div class="zg-step"><span class="zg-step-label">3. Exclude list</span><span id="wz_exclude">-</span></div>
<div class="zg-step"><span class="zg-step-label">4. Mod</span><span id="wz_mode">-</span></div>
<div class="zg-step"><span class="zg-step-label">5. Test / başlat</span><span id="wz_start">-</span></div>
</div>
<div class="zg-wizard-foot">
<span id="wz_hint" class="zg-hint">Kontrol ediliyor...</span>
<span class="zg-actions" style="margin:0;">
<input class="zg-btn" onclick="wizard_recommended();" type="button" value="Kur / Önerileni Uygula">
<input class="zg-btn" onclick="wizard_test();" type="button" value="Test Et">
<input class="zg-btn zg-btn-save" onclick="wizard_start();" type="button" value="Başlat">
<input class="zg-btn" onclick="location.reload();" type="button" value="Yenile">
</span>
</div>
</div>
</div>

<!-- INSTALL PANEL (only if zapret is not installed) -->
<div id="install_panel" style="display:none;">
<div class="formfontdesc">zapret bu cihazda <b>kurulu değil</b>. Aşağıdaki buton zapret'i GitHub'dan indirip ikili dosyalarını kurar (deneysel; internet gerekir). Sonrasında strateji için blockcheck çalıştırın.</div>
<div style="margin:12px 5px;"><input class="zg-btn" onclick="do_install();" type="button" value="zapret'i Kur"></div>
</div>

<!-- MAIN PANEL -->
<div id="main_panel">
<div class="zg-card">
<div class="zg-card-title">Durum</div>
<table class="zg-table">
<tr><th width="40%">Etkin (config)</th><td id="st_enabled">-</td></tr>
<tr><th>nfqws çalışıyor</th><td id="st_running">-</td></tr>
<tr><th>nfqws PID</th><td id="st_pid">-</td></tr>
<tr><th>Güvenlik duvarı kuralları</th><td id="st_rules">-</td></tr>
<tr><th>Kuyruk sayacı (queue 200)</th><td id="st_qcount">-</td></tr>
<tr><th>Mod</th><td id="st_mode">-</td></tr>
<tr><th>Portlar (TCP)</th><td id="st_ports">-</td></tr>
</table>
</div>
<div class="zg-actions">
<input class="zg-btn" onclick="do_action('zapreton');" type="button" value="Aç">
<input class="zg-btn" onclick="do_action('zapretrestart');" type="button" value="Yeniden Başlat">
<input class="zg-btn" onclick="do_action('zapretoff');" type="button" value="Kapat">
<input class="zg-btn" onclick="location.reload();" type="button" value="Yenile">
</div>

<!-- SETTINGS -->
<div class="zg-card">
<div class="zg-card-title">Ayarlar</div>
<table class="zg-table">
<tr><th width="40%">Etkin</th><td><input type="checkbox" id="f_enable"></td></tr>
<tr><th>Strateji</th><td><select id="f_strat" class="zg-select">
<option value="fake">fake (varsayılan)</option>
<option value="fakedsplit">fakedsplit</option>
<option value="fakeddisorder">fakeddisorder</option>
<option value="disorder2">disorder2</option>
<option value="split2">split2</option>
<option value="multisplit">multisplit</option>
<option value="superonline">Superonline Discord (onerilen)</option>
<option value="custom">custom (blockcheck sonucu / elle)</option>
</select></td></tr>
<tr><th>Özel strateji<br><small>(sadece "custom" seçilince kullanılır)</small></th><td><input type="text" id="f_custom" class="zg-input" style="width:100%" maxlength="300" value="@@CUSTOM@@" placeholder="--dpi-desync=fake --dpi-desync-fooling=md5sig --dpi-desync-ttl=6"></td></tr>
<tr><th>TTL (fake için)</th><td><input type="text" id="f_ttl" class="zg-input" maxlength="3" value="2"></td></tr>
<tr><th>Portlar (TCP, virgülle)</th><td><input type="text" id="f_ports" class="zg-input" maxlength="64" value="80,443"></td></tr>
<tr><th>Mod</th><td><select id="f_mode" class="zg-select">
<option value="hostlist">hostlist (sadece liste)</option>
<option value="autohostlist">autohostlist (otomatik)</option>
<option value="all">all (tüm trafik)</option>
</select></td></tr>
</table>
</div>

<div class="zg-card zg-profile-card">
<div class="zg-card-title"><span>Profiller</span><span class="zg-card-subtitle">Tarayıcıya kaydedilir</span></div>
<div class="zg-profile-row">
<select id="f_profile" class="zg-select" onchange="load_profile();"><option value="">Profil seç...</option></select>
<input id="f_profile_name" class="zg-input" maxlength="40" placeholder="Yeni profil adı">
<input class="zg-btn zg-btn-secondary" onclick="save_profile();" type="button" value="Profili Kaydet">
<input class="zg-btn zg-btn-secondary" onclick="delete_profile();" type="button" value="Sil">
<input class="zg-btn zg-btn-secondary" onclick="export_profiles();" type="button" value="Dışa Aktar">
<input class="zg-btn zg-btn-secondary" onclick="import_profiles();" type="button" value="İçe Aktar">
<input class="zg-btn zg-btn-secondary" onclick="send_router_profile();" type="button" value="Router'a Kaydet">
</div>
<div class="zg-hint">Örnek: Superonline Discord, Genel, Oyunlar. Ayarlar uygulanırken servis başarısız olursa önceki config ve hostlist otomatik geri yüklenir.</div>
<div class="zg-profile-row">
<input id="f_schedule_start" class="zg-input" type="time" value="18:00" title="Başlangıç">
<input id="f_schedule_end" class="zg-input" type="time" value="23:00" title="Bitiş">
<input id="f_schedule_days" class="zg-input" maxlength="7" value="1234567" placeholder="Günler: 1234567">
<input class="zg-btn zg-btn-secondary" onclick="save_schedule();" type="button" value="Zamanla">
<input class="zg-btn zg-btn-secondary" onclick="delete_schedule();" type="button" value="Zamanlamayı Sil">
</div>
<div class="zg-hint">Router zamanlayıcısı: günler 1=Pzt ... 7=Paz. Profil, seçilen saat aralığının başında otomatik uygulanır.</div>
</div>

<!-- HOSTLIST (textarea content is server-rendered at @@HOSTAREA@@) -->
<div class="zg-card">
<div class="zg-card-title">Hostlist</div>
<div style="padding:12px 14px;">
@@HOSTAREA@@
<div class="zg-meta"><span id="hc">satır: 0</span><span class="zg-hint">Her satıra bir alan adı. Sadece listedeki hedefler işlenir.</span></div>
<div class="zg-actions" style="justify-content:flex-start;margin:12px 0 0;">
<input class="zg-btn zg-btn-secondary" onclick="clean_hostlist();" type="button" value="Temizle ve Tekrarları Sil">
<input class="zg-btn zg-btn-secondary" onclick="validate_hostlist();" type="button" value="Doğrula">
<input class="zg-btn zg-btn-secondary" onclick="hostlist_clear();" type="button" value="Tümünü Temizle">
</div>
</div>
</div>
<div class="zg-actions">
<input class="zg-btn zg-btn-save" onclick="save_apply();" type="button" value="Kaydet &amp; Uygula">
</div>

<!-- TOOLS / BLOCKCHECK / LOG -->
<div class="zg-card">
<div class="zg-card-title">Araçlar</div>
<table class="zg-table">
<tr><th width="40%">Blockcheck durumu</th><td id="bc_status">-</td></tr>
<tr><th width="40%">Blockcheck test domaini</th><td>
<input type="text" id="f_bcdomain" class="zg-input" value="rutracker.org">
<input class="zg-btn" onclick="run_blockcheck();" type="button" value="Blockcheck çalıştır">
</td></tr>
<tr><th>Hızlı test profilleri</th><td><input class="zg-btn zg-btn-secondary" onclick="quick_test('discord.com');" type="button" value="Discord"> <input class="zg-btn zg-btn-secondary" onclick="quick_test('rutracker.org');" type="button" value="Rutracker"> <span class="zg-hint">Blockcheck, uygun stratejileri arka planda karşılaştırır.</span></td></tr>
<tr><th>Canlı sayaç</th><td><label><input type="checkbox" id="f_auto_refresh" onchange="toggle_auto_refresh();"> 10 saniyede bir yenile</label></td></tr>
<tr><th>GitHub güncellemesi</th><td><input class="zg-btn" onclick="check_update();" type="button" value="Sürümü Kontrol Et"> <input class="zg-btn zg-btn-save" onclick="update_from_github();" type="button" value="GitHub'dan Güncelle"> <span id="update_status" class="zg-hint">Kaynak: GitHub main</span></td></tr>
</table>
</div>
<div class="zg-card">
<div class="zg-card-title">Log</div>
<div style="padding:12px 14px;">
<div class="formfontdesc" style="margin-top:0;">Log (nfqws komutu + yeniden başlatma + blockcheck çıktısı):</div>
<pre id="f_log" class="zg-log">-</pre>
<div class="formfontdesc" style="margin-top:10px;color:#FC0;">Not: &quot;Kaydet &amp; Uygula&quot; config'i yedeğe alıp (config.bak-gui) zapret'i yeniden başlatır. Değişiklik sonrasında sayfa otomatik yenilenir.</div>
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
