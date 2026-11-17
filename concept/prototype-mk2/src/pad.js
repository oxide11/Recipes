/* ================= DEVICE ================= */
function fit(){
 var box=document.getElementById('stagebox'),ph=document.getElementById('phone'),wrap=document.getElementById('devwrap');
 var aw=box.clientWidth,ah=box.clientHeight,small=window.innerWidth<=760,dw,dh,frame=true;
 if(isPad()){dw=isLand()?1194:834;dh=isLand()?834:1194}else if(small&&aw&&ah){dw=aw;dh=ah;frame=false}else{dw=390;dh=844}
 var m=frame?(small?10:14):0;
 SCALE=frame?Math.min(1,(aw-m*2)/dw,(ah-m*2)/dh):1;if(!(SCALE>0))SCALE=1;
 ph.style.width=dw+'px';ph.style.height=dh+'px';ph.style.transform='scale('+SCALE+')';
 wrap.style.width=(dw*SCALE)+'px';wrap.style.height=(dh*SCALE)+'px';
 ph.className='phone'+(isPad()?' ipad '+(isLand()?'land':'port'):'')+(frame?'':' noframe')+(S.screen==='cook'?' norail':'');
}
function devSeg(){
 document.getElementById('devSeg').innerHTML=[['phone','iPhone'],['ipad','iPad']].map(function(x){return '<button data-device="'+x[0]+'" aria-pressed="'+(D.device===x[0])+'">'+x[1]+'</button>'}).join('');
 var o=document.getElementById('orientSeg');o.style.display=isPad()?'grid':'none';
 o.innerHTML=[['landscape','Landscape'],['portrait','Portrait']].map(function(x){return '<button data-orient="'+x[0]+'" aria-pressed="'+(D.orient===x[0])+'">'+x[1]+'</button>'}).join('');
}
function padW(){return (isLand()?1194:834)-88-64}

/* ================= iPad: HOME ================= */
function homePad(){
 function cooked(id){var n=(LOG[id]||[]).length;return n?'<span class="badge solid" style="height:22px;font-size:11px">Cooked '+n+'×</span>':''}
 return '<div class="pad">'+
 '<div class="between" style="gap:20px;flex-wrap:wrap"><div><p class="muted" style="margin:0 0 4px;font-size:14px">Monday evening</p><h1 class="t" style="font-size:40px">What\'s cooking?</h1></div>'+
 '<div class="row" style="gap:12px;flex:1;justify-content:flex-end;min-width:300px">'+searchField('flex:1;max-width:380px')+searchBtn(48)+
 '</div></div>'+
 tagBar()+useItUp()+'<div style="display:flex;flex-direction:column;gap:10px"><p class="kicker">Cook with what you have</p><div style="display:flex;gap:8px;flex-wrap:wrap">'+
  [['#F2C200','Lemons','piccata'],['#9CBF5A','Lemongrass','thai'],['#2E9E4F','Green onion','cajun'],['#6CBF3A','Limes','thai'],['#E9B98C','Chicken','cajun']].map(function(c){return '<button class="chip" data-open="'+c[2]+'" style="height:40px;font-size:15px"><span class="dot" style="background:'+c[0]+'"></span>'+c[1]+'</button>'}).join('')+'</div></div>'+
 '<div style="display:flex;flex-direction:column;gap:12px"><p class="kicker">From the family library</p><div class="rgrid">'+
  tagList().map(function(id,i){var r=RECIPES[id],q=r.card.questions.length;
   return '<button class="rcard" data-open="'+id+'" aria-label="Open '+esc(r.title)+'">'+fpBar(r,120)+
   '<div style="padding:16px 18px 18px;display:flex;flex-direction:column;gap:6px;width:100%"><div class="between" style="min-height:22px"><span class="kicker" style="color:#111">'+(i===0&&!S.tag?'Tonight\'s pick':r.kicker.split(' · ')[0])+'</span>'+cooked(id)+'</div>'+
   '<span style="font-family:var(--disp);font-size:24px;font-weight:700;line-height:1.15">'+esc(r.title)+'</span><span class="muted" style="font-size:14px">'+r.meta+' · '+r.base+' servings</span>'+
   '<span style="font-size:14px;line-height:1.45;color:#2B2B28">'+esc(r.desc)+'</span>'+
   '<span style="font-size:13px;font-weight:600;margin-top:2px">'+Object.keys(r.have).length+' of '+r.ING.length+' in your pantry'+(q?' · '+q+' card question'+(q>1?'s':''):'')+'</span></div></button>'}).join('')+
 '</div></div></div>';
}

/* ================= iPad: SANKEY ================= */
function sankeyWide(W){
 var M=MODES[S.mode],mode=S.mode,f=F();
 var vals=ING.map(function(i){return mval(i,mode)*f}),total=vals.reduce(function(a,b){return a+b},0);
 var GAP=8,MGAP=22,BX=W>900?300:236,PX=W-136,MX=Math.round(BX+(PX-BX)*.5);
 var spec=ING.map(function(it){return it.icon.map(function(p){return[p[0],Math.max(1,Math.round(p[1]*f))]})});
 var counts=spec.map(function(sp){return sp.reduce(function(a,p){return a+p[1]},0)});
 var sizes=counts.map(function(n){return n===1?46:n===2?38:n<=4?28:n<=8?22:18});
 var MINB=66,H=Math.max(560,ING.length*MINB+(ING.length-1)*GAP+40);
 var SPAN=H*.72,hs,bh,bt;
 for(var k=0;k<80;k++){var sc=SPAN/total;hs=vals.map(function(v){return Math.max(2,v*sc)});bh=hs.map(function(h){return Math.max(MINB,h)});bt=bh.reduce(function(a,b){return a+b},0)+GAP*(bh.length-1);if(bt<=H-8)break;SPAN-=10}
 var y=(H-bt)/2,bp=bh.map(function(h){var o={y0:y,y1:y+h};y+=h+GAP;return o});
 var G=skGroups(),SH=ING.map(skShares),gs=G.map(function(){return 0});ING.forEach(function(it,i){SH[i].forEach(function(sh,g){gs[g]+=hs[i]*sh})});
 var ph=gs.reduce(function(a,b){return a+b},0),my=(H-(ph+MGAP*(gs.length-1)))/2,mids=gs.map(function(h){var o={y0:my,y1:my+h};my+=h+MGAP;return o}),py=(H-ph)/2;
 function band(x0,a0,a1,x1,b0,b1){var c=(x0+x1)/2;function q(n){return n.toFixed(1)}return 'M'+x0+','+q(a0)+' C'+c+','+q(a0)+' '+c+','+q(b0)+' '+x1+','+q(b0)+' L'+x1+','+q(b1)+' C'+c+','+q(b1)+' '+c+','+q(a1)+' '+x0+','+q(a1)+' Z'}
 var cur=mids.map(function(m){return m.y0}),paths='',html='';
 ING.forEach(function(it,i){
  var b=bp[i],h=hs[i];var m=(b.y0+b.y1)/2,col=colorOf(it),sw=S.swaps[it.id];
  var a0=m-h/2;SH[i].forEach(function(sh,g){if(sh<=0)return;var hh=h*sh;paths+='<path d="'+band(BX,a0,a0+hh,MX,cur[g],cur[g]+hh)+'" fill="'+col+'" fill-opacity="'+(/^#(F[237]|E[89])/.test(col)?.6:.42)+'"/>';a0+=hh;cur[g]+=hh});
  var icons='',shown=0;spec[i].forEach(function(p){for(var n=0;n<p[1]&&shown<12;n++,shown++)icons+=icon(p[0],sizes[i])});
  html+='<div class="wblk'+tapAttr(it)+' style="top:'+b.y0.toFixed(1)+'px;height:'+(b.y1-b.y0).toFixed(1)+'px;width:'+(BX-6)+'px;background:'+col+'24">'+
   '<span class="wicons">'+icons+'</span><span style="display:flex;flex-direction:column;gap:1px;min-width:0"><b style="font-size:15px;line-height:18px">'+esc(shownName(it))+'</b><span style="font-size:13px;color:#3A3A38">'+M.fmt(vals[i])+'</span>'+(sw?'<span class="swaptag" style="width:max-content">for '+esc(it.name.toLowerCase())+'</span>':'')+'</span></div>'+
   '<div style="position:absolute;left:'+(BX-6)+'px;top:'+b.y0.toFixed(1)+'px;width:6px;height:'+(b.y1-b.y0).toFixed(1)+'px;background:'+edgeOf(it)+'"></div>';
 });
 var pc=py;
 mids.forEach(function(m,gi){var h=m.y1-m.y0;paths+='<path d="'+band(MX+6,m.y0,m.y1,PX,pc,pc+h)+'" fill="'+G[gi].color+'" fill-opacity="'+G[gi].op+'"/>';pc+=h;
  var gv=0;ING.forEach(function(it,i){gv+=vals[i]*SH[i][gi]});if(h<1)return;
  html+='<div style="position:absolute;left:'+MX+'px;top:'+m.y0.toFixed(1)+'px;width:6px;height:'+h.toFixed(1)+'px;background:#111"></div><div style="position:absolute;left:'+(MX+14)+'px;top:'+((m.y0+m.y1)/2-17).toFixed(1)+'px;font-size:14px;line-height:17px;font-weight:700;white-space:nowrap">'+G[gi].name+'<br><span style="font-weight:500;color:#3A3A38">'+skVal(gi,gv,' · ')+'</span></div>'});
 html+='<div style="position:absolute;left:'+PX+'px;top:'+py.toFixed(1)+'px;width:6px;height:'+ph.toFixed(1)+'px;background:#111"></div>'+
  '<div class="wplate" style="left:'+(PX+14)+'px;top:'+(H/2-58)+'px"><div>'+(S.photo?'<img src="'+S.photo+'" alt="Your plate">':'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></svg><span>Your plate<br>photo</span>')+'</div></div>'+
  '<div style="position:absolute;left:'+(PX+14)+'px;top:'+(H/2+66)+'px;width:116px;text-align:center;font-size:13px;font-weight:700;line-height:1.3">'+S.servings+' serving'+(S.servings>1?'s':'')+'<br>'+M.fmt(total)+'</div>';
 var aria='Sankey chart by '+M.label.toLowerCase()+': '+ING.map(function(it,i){return shownName(it)+' '+M.fmt(vals[i])}).join(', ')+'. Total '+M.fmt(total);
 return '<div role="img" aria-label="'+esc(aria)+'" style="position:relative;width:'+W+'px;height:'+H+'px;margin:0 auto"><svg width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'" aria-hidden="true" style="position:absolute;left:0;top:0">'+paths+'</svg>'+html+'</div>';
}

/* ================= iPad: RECIPE ================= */
function stepTime(st){var on=st.on||0,tot=Math.max(on,Math.round((st.secs||0)/60));return {on:on,wait:tot-on}}
function timeCard(){
 var on=0,wait=0,best=null;STEPS.forEach(function(st){var t=stepTime(st);on+=t.on;wait+=t.wait;if(t.wait&&(!best||t.wait>best.w))best={w:t.wait,t:stepTitle(st)}});
 return '<section class="card acard slim"><div class="between"><span class="kicker">Time at the stove</span><span style="font-size:13px"><b>'+(on+wait)+' min</b> total</span></div>'+
  '<div class="hbar" aria-hidden="true"><span style="flex:'+on+';background:#111"></span>'+(wait?'<span class="hatch" style="flex:'+wait+'"></span>':'')+'</div>'+
  '<div class="between" style="font-size:13px"><span><b>'+on+' min</b> hands-on</span><span style="color:#3A3A38"><b>'+wait+' min</b> waiting</span></div>'+
  myTimeLine()+'<button class="linkbtn" style="font-size:13px" data-act="together">Cook alongside another recipe</button></section>';
}
function cooksCard(){
 var log=LOG[R.id]||[],n=log.length;
 if(!n)return '<section class="card acard slim"><span class="kicker">Your cooks</span><span style="font-size:13px;line-height:1.45;color:#3A3A38">Not cooked yet. Ratings, swaps and notes collect here.</span></section>';
 var rated=log.filter(function(c){return c.rating}),avg=rated.length?(rated.reduce(function(a,c){return a+c.rating},0)/rated.length).toFixed(1):'–';
 var timed=log.filter(function(c){return c.mins}),am=timed.length?Math.round(timed.reduce(function(a,c){return a+c.mins},0)/timed.length):0;
 var i=n-1,c=log[i];
 return '<section class="card acard slim"><div class="between"><span class="kicker">Your cooks</span><span style="font-size:13px"><b>'+n+'</b> cook'+(n>1?'s':'')+' · <b>★ '+avg+'</b>'+(am?' · '+am+' min avg':'')+'</span></div>'+
  '<div class="cookrow"><button data-cooksgo="'+i+'" aria-label="Open your cooks, latest cook"><span class="pnum" style="width:24px;height:24px;font-size:11px">'+(i+1)+'</span><span style="flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis"><b>'+starsHtml(c.rating)+'</b> · '+esc(c.date||'')+' · '+esc(c.who||'You')+'</span><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg></button></div>'+
  '<button class="linkbtn" style="font-size:13px" data-go="cooks">'+(n>1?'See all '+n+' cooks':'Open your cooks')+'</button></section>';
}
function ingRowPad(it){
 var li=LINE[it.id]?lineInfo(it.id):null,sw=S.swaps[it.id],lf=sw?leafOf(it.id,sw):null,qty=li?li.qty:(lf&&lf.ratio!=='1 : 1'?lf.ratio:scaleQty(it.amt,F()));
 return '<div class="row" style="gap:12px;padding:10px 0;border-bottom:1px solid #ECECE8">'+icon(it.icon[0][0],38)+
  '<span style="flex:1;display:flex;flex-direction:column;gap:1px;padding-left:10px;border-left:4px solid '+edgeOf(it)+';min-width:0"><b style="font-size:16px">'+esc(shownName(it))+(sw?' <span class="muted" style="font-weight:500;text-decoration:line-through;font-size:13px">'+esc(it.name)+'</span>':'')+'</b><span class="muted" style="font-size:12px">'+esc(sw?lf.note:it.eq)+'</span></span>'+
  (li?'<button class="qty'+(li.check?' q':'')+'" data-conv="'+it.id+'" aria-label="'+esc(qty+' '+li.name+'. Change units')+'">'+esc(qty)+'</button>':'<span class="qty static">'+esc(qty)+'</span>')+
  (SETS[it.id]?'<button class="swapbtn'+(sw?' on':'')+'" data-focus="'+it.id+'" aria-label="'+(sw?'Swapped. Change swap for ':'Swap ')+esc(shownName(it))+'">'+SVG.swap+'</button>':'<span style="width:36px;flex-shrink:0"></span>')+'</div>';
}
function recipePad(){
 var M=MODES[S.mode],ins=R.INS[S.mode],saved=!!S.saved[R.id],land=isLand();
 var W=padW()-34;
 var nsw=ING.filter(function(it){return S.swaps[it.id]}).length;
 var method=STEPS.map(function(st,i){var t=stepTime(st);
  return '<li><span class="mnum">'+(i+1)+'</span><div style="display:flex;flex-direction:column;gap:8px;min-width:0"><div class="between" style="gap:12px;flex-wrap:wrap"><b style="font-family:var(--disp);font-size:20px">'+esc(stepTitle(st))+'</b>'+
   '<span class="row" style="gap:10px"><span class="hbar" style="width:'+((t.on+t.wait)*12)+'px;height:10px" aria-hidden="true"><span style="flex:'+t.on+';background:#111"></span>'+(t.wait?'<span class="hatch" style="flex:'+t.wait+'"></span>':'')+'</span><span style="font-size:12px;color:#3A3A38;white-space:nowrap">'+t.on+' min hands-on'+(t.wait?' · '+t.wait+' wait':'')+'</span>'+(st.secs?'<span class="badge" style="height:24px">'+Math.round(st.secs/60)+' min timer</span>':'')+'</span></div>'+
   safeBadge(st)+stepLines(st).map(function(l){return '<p class="mline">'+l+'</p>'}).join('')+(st.flag?'<p class="cardnote"><b>Card note:</b> '+esc(st.flag)+'</p>':'')+'</div></li>'}).join('');
 return '<div class="pad">'+
 '<div style="border-radius:5px;overflow:hidden;flex-shrink:0">'+fpBar(R,10)+'</div>'+
 '<header class="phead"><div class="row" style="gap:16px;align-items:flex-start;flex:1;min-width:420px"><button class="iconbtn" data-back="home" aria-label="Back">'+SVG.back+'</button>'+
  '<div style="display:flex;flex-direction:column;gap:10px;max-width:620px"><p class="kicker">'+R.kicker+'</p><h1 class="t" style="font-size:42px;line-height:1.05">'+esc(R.title)+'</h1>'+
  '<p style="margin:0;font-size:17px;line-height:1.55;color:#2B2B28">'+esc(R.desc)+'</p>'+
  '<div style="display:flex;gap:6px;flex-wrap:wrap">'+tagBadges()+'</div></div></div>'+
 '</header>'+
 '<div class="row pcta" style="gap:10px"><button class="iconbtn" style="width:52px;height:52px" aria-label="'+(saved?'Saved':'Save recipe')+'" aria-pressed="'+saved+'" data-act="save">'+(saved?SVG.heartOn:SVG.heart)+'</button>'+
   '<button class="secondary" data-act="share" style="display:inline-flex;align-items:center;gap:8px;padding:0 18px;border-color:#111">'+SVG.share+'<span class="lbl">Share</span></button><button class="secondary" data-go="shop">Shopping list</button>'+
  '<button class="primary" data-act="startcook">Start cooking</button></div>'+
 '<div class="stats">'+liveStats().map(function(s){return '<div><b>'+s[0]+'</b><span>'+s[1]+'</span></div>'}).join('')+'</div>'+
 '<div class="ovgrid"><section class="card" style="padding:18px 16px;display:flex;flex-direction:column;gap:14px;min-width:0">'+
   '<div class="between" style="gap:12px;flex-wrap:wrap"><div><h2 class="h2" style="font-size:20px">Where it all goes</h2><span class="muted" style="font-size:12px;font-weight:600">'+M.cap+' · tap an ingredient to see its swaps</span></div>'+
   '<div class="row skctl" style="gap:10px">'+'<div class="stepper servhead" role="group" aria-label="Servings"><button data-serv="-1" aria-label="Fewer servings"'+(S.servings<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+S.servings+'</b> serving'+(S.servings>1?'s':'')+'</span><button data-serv="1" aria-label="More servings"'+(S.servings>=12?' disabled':'')+'>+</button></div>'+'<div class="seg" role="group" aria-label="Measure by" style="grid-template-columns:repeat(4,1fr);width:340px">'+Object.keys(MODES).map(function(k){return '<button data-mode="'+k+'" aria-pressed="'+(k===S.mode)+'">'+MODES[k].label+'</button>'}).join('')+'</div></div></div>'+
   sankeyWide(W)+costSource()+'<p class="insight"><strong>'+ins[0]+'</strong> '+ins[1]+'</p></section>'+
  '<aside class="aside">'+cardSection()+timeCard()+cooksCard()+'</aside></div>'+
 '<div class="imgrid"><section style="display:flex;flex-direction:column;min-width:0"><div class="shead"><h2 class="h2" style="font-size:22px">Ingredients</h2><span class="muted" style="font-size:12px">for '+S.servings+' · swaps are optional</span></div>'+
   '<div class="ingcols">'+ING.map(ingRowPad).join('')+'</div></section>'+
  '<section style="display:flex;flex-direction:column;min-width:0"><div class="shead"><h2 class="h2" style="font-size:22px">Method</h2><span class="row muted" style="gap:12px;font-size:12px"><span class="row" style="gap:6px"><i class="lg" style="background:#111"></i>hands-on</span><span class="row" style="gap:6px"><i class="lg hatch"></i>waiting</span></span></div>'+
   '<ol class="method">'+method+'</ol></section></div>'+
 '</div>';
}

/* ================= iPad: THIS COOK ================= */
function ingredientsPad(){
 var ready=ING.filter(function(it){return S.have[it.id]}).length;
 return '<div class="pad">'+header('recipe','This cook','Optional. Swap anything or tick what you have, then start.')+
 '<div class="cookplan"><div style="display:flex;flex-direction:column;gap:16px">'+constellation()+profileBar()+'</div>'+
 '<section style="display:flex;flex-direction:column;min-width:0"><div class="shead"><h2 class="h2" style="font-size:22px">Gather</h2><span style="font-size:13px;font-weight:700">'+ready+' of '+ING.length+' ready</span></div>'+gatherRows()+
 (ready<ING.length?'<button class="secondary" data-go="shop" style="margin-top:16px">Shop for '+(ING.length-ready)+' missing</button>':'')+'</section></div>'+
 '</div><div class="bottombar"><button class="primary" data-act="startcook">Start cooking</button></div>';
}
function stepListPad(){
 return '<aside class="steplist"><span class="kicker" style="padding:0 10px 6px">'+esc(R.title)+'</span>'+STEPS.map(function(st,i){var t=S.timers[i],run=t&&t.started&&t.left>0;
  return '<button data-jumpstep="'+i+'" class="'+(i===S.step?'cur':i<S.step?'past':'')+'"'+(i===S.step?' aria-current="step"':'')+'><span class="mnum" style="width:28px;height:28px;font-size:13px">'+(i+1)+'</span><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>'+esc(stepTitle(st))+'</b><span>'+(st.secs?Math.round(st.secs/60)+' min timer'+(run?' · running':''):'No timer')+(safeFor(st)?' · '+safeFor(st).f+'°F':'')+'</span></span></button>'}).join('')+'</aside>';
}

/* ================= SHARE ================= */
function shareSheet(){
 var s=S.share,sw=ING.filter(function(it){return S.swaps[it.id]}),log=LOG[R.id]||[],serv=s.scale?R.base*2:S.servings;
 var swTxt=sw.map(function(it){return shownName(it).toLowerCase()+' for '+it.name.toLowerCase()}).join(', ');
 var T=[['swaps','Include swaps',sw.length?swTxt:'No swaps chosen for this cook'],['notes','Include ratings and notes','Your cook log stays private unless this is on'],['card','Include the original card',R.card.photos+' photo'+(R.card.photos>1?'s':'')+' of Ashley’s card'],['scale','Share at '+(R.base*2)+' servings','Amounts are scaled before sending']];
 var label={card:'Share recipe card',link:'Share link',pdf:'Share PDF',text:'Share as text'}[s.format];
 return '<div class="sheet sharesheet" role="dialog" aria-modal="true" aria-label="Share '+esc(R.title)+'">'+
  '<div class="between"><div><span class="kicker">Share</span><h2 class="h2" style="font-size:22px;line-height:1.15">'+esc(R.title)+'</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div class="seg" role="group" aria-label="Share as" style="grid-template-columns:repeat(4,1fr)">'+[['card','Card'],['link','Link'],['pdf','PDF'],['text','Text']].map(function(x){return '<button data-sharefmt="'+x[0]+'" aria-pressed="'+(s.format===x[0])+'">'+x[1]+'</button>'}).join('')+'</div>'+
  '<div style="padding:14px;border-radius:18px;background:var(--counter);display:flex;justify-content:center"><div style="width:100%;max-width:340px;border-radius:16px;background:#fff;box-shadow:0 10px 24px rgba(0,0,0,.1);overflow:hidden">'+fpBar(R,48)+
   '<div style="padding:12px 14px 14px;display:flex;flex-direction:column;gap:6px"><span class="kicker" style="font-size:10px">From Ashley’s recipe cards</span><b style="font-family:var(--disp);font-size:19px;line-height:1.15">'+esc(R.title)+'</b>'+
   '<span style="font-size:12px;font-weight:700">'+R.meta.split(' · ')[0]+' · '+serv+' servings · '+ING.length+' ingredients · '+STEPS.length+' steps</span>'+
   (s.swaps&&sw.length?'<span style="padding:6px 9px;border-radius:9px;background:var(--counter);font-size:12px;line-height:1.4"><b>Our swaps:</b> '+esc(swTxt)+'</span>':'')+
   (s.notes?'<span class="cardnote" style="font-size:12px;padding:6px 9px">'+(log.length?log.length+' cook'+(log.length>1?'s':'')+' logged'+(log[log.length-1].note?' · “'+esc(log[log.length-1].note)+'”':''):'No cooks logged yet')+'</span>':'')+
   (s.card?'<span class="muted" style="font-size:12px">Includes '+R.card.photos+' photo'+(R.card.photos>1?'s':'')+' of the original card</span>':'')+'</div></div></div>'+
  '<div style="display:flex;flex-direction:column">'+T.map(function(t){var on=!!s[t[0]];return '<button class="tog" role="switch" aria-checked="'+on+'" data-sharetog="'+t[0]+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>'+t[1]+'</b><span>'+esc(t[2])+'</span></span><i class="sw'+(on?' on':'')+'"><i></i></i></button>'}).join('')+'</div>'+
  '<div class="row" style="gap:14px"><span class="kicker">Send to</span>'+['Ashley','Nicole'].map(function(n){return '<button class="who" data-act="sharesend"><i>'+n.charAt(0)+'</i>'+n+'</button>'}).join('')+'</div>'+
  '<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-act="sharecopy">Copy link</button><button class="primary" style="flex:2;height:52px;font-size:15px" data-act="sharesend">'+label+'</button></div></div>';
}
function openShare(keepPos){
 var el=document.getElementById('sheet'),old=el.querySelector('.sheet'),y=old?old.scrollTop:0;
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1">'+shareSheet()+'</div>';
 if(keepPos)el.querySelector('.sheet').scrollTop=y;
}
function showSwapModal(keepPos){
 var el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap full'+(keepPos?' noanim':'')+'">'+swapView()+'</div>';
}

/* ================= PROFILE MENU ================= */
function keepUnder(){var el=document.getElementById('sheet'),h=el.innerHTML,y=el.querySelector('.sheet').scrollTop;keep(render);el.innerHTML=h;el.querySelector('.sheet').scrollTop=y}
function profileSheet(){
 var cooks=0,stars=0,rated=0,mins=0;Object.keys(LOG).forEach(function(k){LOG[k].forEach(function(c){cooks++;mins+=c.mins||0;if(c.rating){stars+=c.rating;rated++}})});
 var saved=Object.keys(S.saved).filter(function(k){return S.saved[k]}).length;
 function seg(key,opts){return '<div class="seg" style="grid-template-columns:repeat('+opts.length+',1fr);min-width:150px">'+opts.map(function(o){return '<button aria-pressed="'+(P[key]===o[0])+'" data-pset="'+key+':'+o[0]+'">'+o[1]+'</button>'}).join('')+'</div>'}
 function row(t,s,ctl){return '<div class="prow"><span class="ptxt"><b>'+t+'</b><span>'+s+'</span></span>'+ctl+'</div>'}
 function tog(key,t,s){var on=!!P[key];return '<button class="tog" role="switch" aria-checked="'+on+'" data-ptog="'+key+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>'+t+'</b><span>'+s+'</span></span><i class="sw'+(on?' on':'')+'"><i></i></i></button>'}
 function link(t,s,msg){return '<button class="plink" data-toast="'+esc(msg)+'"><span class="ptxt"><b>'+t+'</b><span>'+s+'</span></span>'+SVG.arrow+'</button>'}
 return '<div class="sheet profsheet" role="dialog" aria-modal="true" aria-label="Profile and settings">'+
  '<div class="row" style="gap:12px"><button class="iconbtn" data-closesheet="1" aria-label="Back">'+SVG.back+'</button><span class="pava">M</span><div><h2 class="h2" style="font-size:26px">Moussa</h2><p class="muted" style="margin:2px 0 0;font-size:13px">Cooking with Ashley and Nicole</p></div></div>'+
  '<div class="stats" style="grid-template-columns:repeat(4,1fr)"><div><b>'+cooks+'</b><span>cooks</span></div><div><b>'+(rated?(stars/rated).toFixed(1):'–')+'</b><span>avg rating</span></div><div><b>'+(cooks?Math.round(mins/cooks):0)+' min</b><span>avg cook</span></div><div><b>'+saved+'</b><span>saved</span></div></div>'+
  '<div class="pgrid"><div class="pcol"><section class="psec"><span class="kicker">Never suggested</span>'+
   '<p class="muted" style="margin:0;font-size:13px;line-height:1.4">Swaps and recipe picks skip these. Allergies are also flagged on any recipe that contains them.</p>'+
   '<div style="display:flex;gap:8px;flex-wrap:wrap">'+P.never.map(function(n,i){return '<span class="chip out pchip"'+(n[1]==='allergy'?' style="border-width:1.5px"':'')+'>'+(n[1]==='allergy'?SVG.warn('#111'):'')+esc(n[0])+' <span class="muted" style="font-weight:500">'+n[1]+'</span><button data-pdel="'+i+'" aria-label="Remove '+esc(n[0])+'">'+SVG.close+'</button></span>'}).join('')+
   '<button class="chip out" style="border-style:dashed" data-toast="Adding an ingredient to avoid is mocked in this prototype">+ Add</button></div></section>'+
  '<section class="psec"><span class="kicker">Appearance</span><div style="display:flex;flex-direction:column">'+tog('dark','Dark mode','A dark kitchen: black counters, the same ingredient colours')+'</div></section>'+
  '<section class="psec"><span class="kicker">Measurements</span>'+
   row('Temperature','Safe temperature badges',seg('temp',[['F','°F'],['C','°C']]))+
   row('Units','Default for new recipes',seg('units',[['us','US'],['metric','Metric']]))+
   row('Nutrition goal','Decides what counts as a better swap',seg('goal',[['lighter','Lighter'],['protein','Protein'],['gain','Gain']]))+
   row('Default servings','Recipes open scaled to this','<div class="stepper" style="height:44px" role="group" aria-label="Default servings"><button style="width:36px;height:36px" data-pserv="-1" aria-label="Fewer"'+(P.serv<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+P.serv+'</b></span><button style="width:36px;height:36px" data-pserv="1" aria-label="More"'+(P.serv>=12?' disabled':'')+'>+</button></div>')+'</section>'+
  '</div><div class="pcol"><section class="psec"><span class="kicker">While cooking</span><div style="display:flex;flex-direction:column">'+
   tog('awake','Keep screen awake','No dimming while a recipe is open')+
   tog('sound','Timer sounds','A chime when a timer ends')+
   tog('hf','Hands-free cooking','Reads each step aloud and moves on when its timer ends')+
   tog('hc','Stronger ingredient highlights','Outlined ingredients in step text instead of pale tints')+
   tog('photo','Ask for a plate photo','Prompt at the end of every cook')+'</div></section>'+
  '<section class="psec" style="gap:0"><span class="kicker" style="margin-bottom:6px">Sharing</span>'+
   '<button class="plink" data-act="librarymembers"><span class="ptxt"><b>Family library</b><span>'+LIBM.length+' people share these recipes</span></span>'+avStack(LIBM,4)+'</button>'+
   '<button class="plink" data-act="kitchens"><span class="ptxt"><b>Your kitchens</b><span>'+KITCHENS.length+' · plan, shopping and pantry are per kitchen</span></span>'+avStack(KITCHENS[KCUR].members,4)+'</button></section>'+
  '<section class="psec" style="gap:0"><span class="kicker" style="margin-bottom:6px">More</span>'+
   link('Cooking log',cooks+' cooks across '+Object.keys(LOG).filter(function(k){return LOG[k].length}).length+' recipes','The full cooking log is not built yet. Each recipe shows its own under Your cooks.')+
   link('Nutritional goals','Daily targets for calories and macros','Nutritional goals are on the backlog')+
   '<button class="plink" data-go="questions"><span class="ptxt"><b>Questions for Ashley</b><span>'+openQCount()+' open across her cards</span></span>'+SVG.arrow+'</button>'+
   '<button class="plink" data-act="importcard"><span class="ptxt"><b>Import recipe cards</b><span>Photograph a card to add it</span></span>'+SVG.arrow+'</button>'+'</section></div></div>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.4">Prototype: temperature units, the never-suggested list, the nutrition goal, hands-free cooking, stronger highlights and dark mode take effect. The other settings only remember their state.</p>'+
 '</div>';
}
function openProfile(keepPos){
 var el=document.getElementById('sheet'),old=el.querySelector('.sheet'),y=old?old.scrollTop:0;
 el.innerHTML='<div class="sheetwrap full'+(keepPos?' noanim':'')+'">'+profileSheet()+'</div>';
 if(keepPos)el.querySelector('.sheet').scrollTop=y;else{var c=el.querySelector('.iconbtn');if(c)c.focus()}
}

/* ================= YOUR COOKS (full screen) ================= */
function starsHtml(r){return r?'★★★★★'.slice(0,r)+'<span style="color:#BDBDB8">'+'★★★★★'.slice(r)+'</span>':'Not rated'}
function cooksView(){
 var log=LOG[R.id]||[],n=log.length,pad=isPad();
 var head='<div class="row" style="gap:12px;align-items:flex-start"><button class="iconbtn" data-back="recipe" aria-label="Back to recipe">'+SVG.back+'</button><div><h1 class="t" style="font-size:'+(pad?36:28)+'px">Your cooks</h1><p class="muted" style="margin:2px 0 0;font-size:'+(pad?14:13)+'px">'+esc(R.title)+'</p></div></div>';
 if(!n)return '<div class="pad">'+head+'<p class="insight">Not cooked yet. Your ratings, swaps and notes will collect here after each cook.</p><button class="primary" data-act="startcook">Start cooking</button></div>';
 var rated=log.filter(function(c){return c.rating}),avg=rated.length?(rated.reduce(function(s,c){return s+c.rating},0)/rated.length).toFixed(1):'–';
 var timed=log.filter(function(c){return c.mins}),am=timed.length?Math.round(timed.reduce(function(s,c){return s+c.mins},0)/timed.length):0;
 var best=timed.length?Math.min.apply(null,timed.map(function(c){return c.mins})):0,mx=timed.length?Math.max.apply(null,timed.map(function(c){return c.mins})):1;
 var tally={};log.forEach(function(c){(c.swapList||[]).forEach(function(x){tally[x]=(tally[x]||0)+1})});
 var tk=Object.keys(tally).sort(function(x,y){return tally[y]-tally[x]});
 var plain=log.filter(function(c){return !(c.swapList||[]).length}).length;
 var stats='<div class="stats" style="grid-template-columns:repeat(4,1fr)"><div><b>'+n+'</b><span>cook'+(n>1?'s':'')+'</span></div><div><b>★ '+avg+'</b><span>avg rating</span></div><div><b>'+(am||'–')+(am?' min':'')+'</b><span>avg time</span></div><div><b>'+(best||'–')+(best?' min':'')+'</b><span>fastest</span></div></div>';
 var chart='<section class="card acard"><div class="between"><span class="kicker">Start to plate</span><span class="muted" style="font-size:12px">The recipe card says '+esc(R.stats[0][0])+' prep + '+esc(R.stats[1][0])+' cook</span></div>'+
  '<div class="ckchart" role="img" aria-label="Cook time for each cook">'+log.map(function(c,i){return '<button class="ckbar'+(S.cookOpen===i?' on':'')+'" data-cook="'+i+'" aria-label="Cook '+(i+1)+', '+(c.mins?c.mins+' minutes':'not timed')+'"><b>'+(c.mins||'–')+'</b><i style="height:'+(c.mins?Math.max(8,Math.round(c.mins/mx*100)):4)+'%"></i><span>'+esc(c.date||'')+'</span></button>'}).join('')+'</div></section>';
 var swaps='<section class="card acard"><span class="kicker">Swaps you have made</span>'+(tk.length?'<div style="display:flex;flex-direction:column">'+tk.map(function(k){return '<div class="between" style="min-height:40px;border-bottom:1px solid #ECECE8;gap:12px"><span style="font-size:15px;font-weight:600">'+esc(k)+'</span><span class="row" style="gap:8px;flex-shrink:0">'+(PROMO[R.id+':'+k]?'<span class="badge" style="height:24px;font-size:12px">Default now</span>':(n>=2&&tally[k]*2>=n?'<button class="chip out" style="height:32px" data-promote="'+esc(k)+'">Make default</button>':''))+'<span class="badge solid" style="height:24px;font-size:12px">'+tally[k]+' of '+n+'</span></span></div>'}).join('')+'</div>':'')+
  '<span class="muted" style="font-size:13px">'+(plain?'Cooked as written '+plain+' time'+(plain>1?'s':'')+'.':'Never cooked exactly as written.')+'</span></section>';
 var entries='<section style="display:flex;flex-direction:column;gap:12px"><div class="between"><span class="kicker">Every cook, newest first</span></div>'+log.map(function(_,i){return i}).reverse().map(function(i){var c=log[i],sw=c.swapList||[];
  return '<article class="card ckentry'+(S.cookOpen===i?' on':'')+'" id="ck'+i+'"><div class="between" style="gap:12px"><div class="row" style="gap:12px;min-width:0"><span class="pnum" style="width:32px;height:32px;font-size:14px;flex-shrink:0">'+(i+1)+'</span><div style="min-width:0"><b style="font-size:17px;letter-spacing:1px">'+starsHtml(c.rating)+'</b><div class="muted" style="font-size:13px">'+esc(c.date||'')+' · '+esc(c.who||'You')+'</div></div></div>'+(c.mins?'<span style="text-align:right;white-space:nowrap"><b style="font-family:var(--disp);font-size:20px">'+c.mins+' min</b><div class="muted" style="font-size:12px">'+(am&&c.mins!==am?(Math.abs(c.mins-am)+' min '+(c.mins<am?'faster':'slower')+' than avg'):'right on average')+'</div></span>':'')+'</div>'+
   (sw.length?'<div style="display:flex;flex-wrap:wrap;gap:6px">'+sw.map(function(x){return '<span class="badge" style="height:26px;font-size:12px">'+esc(x)+'</span>'}).join('')+'</div>':'<span class="muted" style="font-size:13px">Cooked as written, no swaps</span>')+
   (c.note?'<p class="cardnote" style="margin:0;font-size:15px;line-height:1.5">“'+esc(c.note)+'”</p>':'')+'</article>'}).join('')+
  (log.some(function(c){return c.sample})?'<span class="muted" style="font-size:12px">Earlier entries are sample data for the prototype.</span>':'')+'</section>';
 return '<div class="pad">'+head+stats+'<div class="ckgrid"><div style="display:flex;flex-direction:column;gap:16px;min-width:0">'+chart+swaps+'</div>'+entries+'</div></div>'+
  '<div class="bottombar"><button class="primary" data-act="startcook">Cook it again</button></div>';
}

/* ================= RECIPES (library) ================= */
var PAPER=["Udon Noodles", "Lady Rose Relish", "Nora’s Pasta Salad", "Ginger Bread", "Lemon Glaze", "Grape Jelly (two cards)", "Sourdough Cinnamon Cardamom Knots", "Hollandaise for Eggs Benedict", "Healthy Banana Oat Pancakes", "Freezable Waffles", "Sherry’s Top Secret Cinnamon Buns", "Cinnamon Buns", "Carrot Cake", "Chocolate Chip Oatmeal Cookies", "Oh Henry Squares", "Pad Kee Mao", "Vietnamese Noodles with Lemongrass Chicken", "Yum Mustard Chicken", "Beef & Barley", "Lynd’s Focaccia", "Greek Turkey Burgers", "Clam Chowder", "Chilli Con Carne", "Sweet Cornbread", "Mom’s Sweet & Sour Meatballs", "Egg Rolls", "Bruschetta Tomato Topping", "Brown Bread", "Baked Beans", "Molasses and Oat Rolls", "Hummus", "Egg Seasoning"];

function libMins(r){var m=/(\d+)\s*hr(?:\s*(\d+))?/.exec(r.meta);if(m)return +m[1]*60+(+m[2]||0);m=/(\d+)\s*min/.exec(r.meta);return m?+m[1]:999}
function libIds(){
 var L=S.lib,q=(L.q||'').toLowerCase().trim();
 var ids=RECIPE_ORDER.filter(function(id){var r=RECIPES[id];
  if(L.f==='saved'&&!S.saved[id])return false;
  if(L.f==='cooked'&&!(LOG[id]||[]).length)return false;
  if(L.f==='check'&&!openQ(id))return false;
  if(L.tag&&!r.tags.some(function(t){return t[0]===L.tag}))return false;
  if(q&&r.title.toLowerCase().indexOf(q)<0&&!r.ING.some(function(it){return it.name.toLowerCase().indexOf(q)>-1}))return false;
  return true});
 if(L.s==='quick')ids.sort(function(x,y){return libMins(RECIPES[x])-libMins(RECIPES[y])});
 else if(L.s==='az')ids.sort(function(x,y){return RECIPES[x].title.localeCompare(RECIPES[y].title)});
 else ids.sort(function(x,y){return (LOG[y]||[]).length-(LOG[x]||[]).length});
 return ids;
}
function libList(){
 var ids=libIds(),pad=isPad();
 if(!ids.length)return '<p class="insight" style="grid-column:1/-1">No recipes match. Try another filter or clear the search.</p>';
 return ids.map(function(id){var r=RECIPES[id],n=(LOG[id]||[]).length,q=openQ(id),sv=!!S.saved[id],hv=Object.keys(r.have).length;
  var rt=(LOG[id]||[]).filter(function(c){return c.rating}),avg=rt.length?(rt.reduce(function(s,c){return s+c.rating},0)/rt.length).toFixed(1):null;
  return '<div class="librow"><button class="libopen" data-open="'+id+'" aria-label="Open '+esc(r.title)+'">'+
   '<span class="libfp">'+fpBar(r,pad?64:100)+'</span>'+
   '<span class="libtxt"><span class="kicker">'+r.kicker.split(' · ')[0]+'</span><b>'+esc(r.title)+'</b><span class="muted">'+r.meta+' · '+r.base+' servings</span>'+
   '<span class="libmeta">'+(n?'<span class="badge solid">Cooked '+n+'×'+(avg?' · ★ '+avg:'')+'</span>':'<span class="badge">Not cooked yet</span>')+'<span class="badge">'+hv+' of '+r.ING.length+' in pantry</span>'+(q?'<span class="badge" style="border-style:dashed">'+q+' to check</span>':'')+'</span></span></button>'+
   '<button class="iconbtn libsave" data-libsave="'+id+'" aria-pressed="'+sv+'" aria-label="'+(sv?'Remove '+esc(r.title)+' from saved':'Save '+esc(r.title))+'">'+(sv?SVG.heartOn:SVG.heart)+'</button></div>'}).join('');
}
function libraryView(){
 var L=S.lib,pad=isPad(),tags={};RECIPE_ORDER.forEach(function(id){RECIPES[id].tags.forEach(function(t){tags[t[0]]=(tags[t[0]]||0)+1})});
 var tk=Object.keys(tags).sort(function(x,y){return tags[y]-tags[x]||x.localeCompare(y)});
 var cnt={all:RECIPE_ORDER.length,saved:RECIPE_ORDER.filter(function(id){return S.saved[id]}).length,cooked:RECIPE_ORDER.filter(function(id){return (LOG[id]||[]).length}).length,check:RECIPE_ORDER.filter(function(id){return openQ(id)}).length};
 var F=[['all','All'],['saved','Saved'],['cooked','Cooked'],['check','To check']],SO=[['cooked','Most cooked'],['quick','Quickest'],['az','A to Z']];
 var paper=L.more?PAPER:PAPER.slice(0,pad?12:6);
 return '<div class="pad">'+
  '<div class="between" style="gap:16px;align-items:flex-end"><div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">'+RECIPE_ORDER.length+' ready to cook · '+PAPER.length+' still on paper</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Recipes</h1></div>'+
   '<div class="row" style="gap:8px"><button class="avbtn" data-act="librarymembers" aria-label="Family library, '+LIBM.length+' people">'+avStack(LIBM,3)+'</button><button class="secondary" style="height:44px;padding:0 16px;display:inline-flex;align-items:center;gap:6px;white-space:nowrap;border-color:#111" data-act="importcard">+ Add</button></div></div>'+
  '<label class="row searchf" style="animation:none"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#595954" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg><span class="sr">Search your recipes</span><input id="libq" type="search" placeholder="Search by name or ingredient" value="'+esc(L.q||'')+'"></label>'+
  '<div class="libctl"><div class="seg" role="group" aria-label="Show" style="grid-template-columns:repeat(4,1fr)">'+F.map(function(f){return '<button data-libf="'+f[0]+'" aria-pressed="'+(L.f===f[0])+'">'+f[1]+' <span style="opacity:.7;font-weight:500">'+cnt[f[0]]+'</span></button>'}).join('')+'</div>'+
   '</div>'+
  '<div class="libbar"><button class="libpick" data-libs="'+SO[(SO.map(function(s){return s[0]}).indexOf(L.s)+1)%SO.length][0]+'" aria-label="Sort: '+SO.filter(function(s){return s[0]===L.s})[0][1]+'. Tap to change"><span class="muted">Sort</span> '+SO.filter(function(s){return s[0]===L.s})[0][1]+'</button>'+
   (L.tag?'<button class="libpick on" data-libtag="'+esc(L.tag)+'" aria-label="Remove tag filter '+esc(L.tag)+'">'+esc(L.tag)+' <span aria-hidden="true">×</span></button>':'')+
   '<button class="libpick" data-act="libtags" aria-haspopup="dialog" style="margin-left:auto">'+(L.tag?'Change tag':'Filter by tag')+'</button></div>'+
  '<div class="libgrid" id="liblist">'+libList()+'</div>'+
  '<section class="card acard" style="gap:12px"><div class="between" style="gap:12px;align-items:flex-start"><div><span class="kicker">Still on paper</span><p style="margin:4px 0 0;font-size:14px;line-height:1.45;color:#2B2B28">'+PAPER.length+' more of Ashley’s cards are transcribed but not built into the app yet.</p></div></div>'+
   '<div class="papergrid">'+paper.map(function(n){return '<button class="paperrow" data-toast="'+esc(n)+' is transcribed but not built yet"><span class="cardthumb sm" aria-hidden="true" style="transform:none;width:26px;height:32px;padding:5px 4px;gap:3px"><i></i><i style="width:70%"></i><i></i></span>'+esc(n)+'</button>'}).join('')+'</div>'+
   '<button class="linkbtn" style="font-size:13px" data-libmore="1">'+(L.more?'Show fewer':'Show all '+PAPER.length)+'</button></section>'+
  '</div>'+(pad?'':tabbar('library'));
}

/* ================= PANTRY ================= */
var PAN={},PAN0=null,PLAN={};
function pKey(it){return it.name.toLowerCase().replace(/oes$/,'o').replace(/s$/,'')}
function syncHave(){RECIPE_ORDER.forEach(function(id){var r=RECIPES[id];r.have={};r.ING.forEach(function(it){if(PAN[pKey(it)])r.have[it.id]=1})});if(S&&S.recipe&&typeof ING!=='undefined'&&ING){var via=S.haveVia||{},old=S.have||{};S.have={};ING.forEach(function(it){if(via[it.id]){if(old[it.id])S.have[it.id]=true}else if(PAN[pKey(it)])S.have[it.id]=true})}}
function pantryFromS(){var via=S.haveVia||{};ING.forEach(function(it){if(via[it.id])return;if(S.have[it.id])PAN[pKey(it)]=1;else delete PAN[pKey(it)]});syncHave()}
function initPantry(){
 if(!PAN0){PAN0={};RECIPE_ORDER.forEach(function(id){var r=RECIPES[id];r.ING.forEach(function(it){if(r.have[it.id])PAN0[pKey(it)]=1})})}
 PAN={};for(var k in PAN0)PAN[k]=1;PLAN={0:['cajun'],2:['thai'],4:['scampi'],5:['hamsoup','potpie','cookies']};CART={};syncHave();
}
function catalog(){var m={},out=[];RECIPE_ORDER.forEach(function(id){RECIPES[id].ING.forEach(function(it){var k=pKey(it);if(!m[k]){m[k]={key:k,it:it,n:0};out.push(m[k])}m[k].n++})});return out}
function coverage(id){var r=RECIPES[id];return [Object.keys(r.have).length,r.ING.length]}
function panTile(c){
 var h=!!PAN[c.key],it=c.it,ex=h&&EXP[c.key];
 return '<button class="ptile'+(h?' on':'')+'" data-pan="'+esc(c.key)+'" aria-pressed="'+h+'" aria-label="'+esc(it.name)+(h?', on hand. Tap to mark used up':', not in the pantry. Tap to add')+'" style="'+(h?'background:'+it.color+'24':'')+'">'+icon(it.icon[0][0],30)+
  '<span class="ptxt"><b>'+esc(it.name)+'</b><span'+(ex?' class="exp'+(ex<=2?' soon':'')+'"':'')+'>'+(ex?'use within '+ex+' day'+(ex>1?'s':''):c.n+' recipe'+(c.n>1?'s':''))+'</span></span>'+
  '<i class="pchk" aria-hidden="true">'+(h?'<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10"/></svg>':'<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>')+'</i></button>';
}
function panList(){
 var q=(S.pan.q||'').toLowerCase().trim(),f=S.pan.f,cat=catalog().filter(function(c){if(f==='have'&&!PAN[c.key])return false;if(f==='out'&&PAN[c.key])return false;if(q&&c.key.indexOf(q)<0)return false;return true});
 if(!cat.length&&!spiceRack())return '<p class="insight">'+(q?'Nothing matches “'+esc(S.pan.q)+'”.':f==='have'?'Nothing on hand yet. Switch to Missing to add what you have.':'Nothing is missing. Every ingredient your recipes use is on hand.')+'</p>';
 var first=!q&&f!=='out'?cat.filter(function(c){return PAN[c.key]&&EXP[c.key]}).sort(function(x,y){return EXP[x.key]-EXP[y.key]}):[];
 var out=first.length?'<section class="psecn"><div class="shead"><h2 class="h2" style="font-size:18px">Use first</h2><span class="muted" style="font-size:12px;font-weight:600">closest to their date</span></div><div class="ptiles">'+first.map(panTile).join('')+'</div></section>':'';
 return out+spiceRack()+AISLES.map(function(a){var items=cat.filter(function(c){return c.it.aisle===a});if(!items.length)return '';
  items.sort(function(x,y){return (PAN[y.key]?1:0)-(PAN[x.key]?1:0)||x.it.name.localeCompare(y.it.name)});
  var all=catalog().filter(function(c){return c.it.aisle===a}),on=all.filter(function(c){return PAN[c.key]}).length;
  return '<section class="psecn"><div class="shead"><h2 class="h2" style="font-size:18px">'+a+'</h2><span class="muted" style="font-size:12px;font-weight:600">'+on+' of '+all.length+' on hand</span></div><div class="ptiles">'+items.map(panTile).join('')+'</div></section>'}).join('');
}
function pantryView(){
 var pad=isPad(),cat=catalog(),on=cat.filter(function(c){return PAN[c.key]}).length;
 var rank=RECIPE_ORDER.slice().sort(function(x,y){var a=coverage(x),b=coverage(y);return (a[1]-a[0])-(b[1]-b[0])||b[0]/b[1]-a[0]/a[1]}).slice(0,4);
 var F=[['have','On hand',on],['out','Missing',cat.length-on],['all','All',cat.length]];
 return '<div class="pad">'+
  kitchenBar()+'<div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">'+on+' of '+cat.length+' ingredients on hand</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Pantry</h1></div>'+
  '<section style="display:flex;flex-direction:column;gap:10px"><p class="kicker">Closest to ready</p><div class="canrow">'+rank.map(function(id){var c=coverage(id),miss=c[1]-c[0],r=RECIPES[id];
   return '<button class="cancard" data-open="'+id+'" aria-label="Open '+esc(r.title)+', '+(miss?miss+' to buy':'everything on hand')+'"><b>'+esc(r.title)+'</b><span class="canbar" aria-hidden="true"><i style="width:'+Math.round(c[0]/c[1]*100)+'%"></i></span><span>'+(miss?miss+' to buy':'Ready to cook')+'</span></button>'}).join('')+'</div></section>'+
  '<div class="panctl"><div class="seg" role="group" aria-label="Show" style="grid-template-columns:repeat(3,1fr)">'+F.map(function(f){return '<button data-panf="'+f[0]+'" aria-pressed="'+(S.pan.f===f[0])+'">'+f[1]+' <span style="opacity:.7;font-weight:500">'+f[2]+'</span></button>'}).join('')+'</div>'+
   '<label class="row searchf" style="animation:none"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#595954" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg><span class="sr">Search the pantry</span><input id="panq" type="search" placeholder="Search ingredients" value="'+esc(S.pan.q||'')+'"></label></div>'+
  '<div id="panlist" style="display:flex;flex-direction:column;gap:24px">'+panList()+'</div>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.45">Tap an ingredient to mark it on hand or used up. Recipes, the plan and shopping lists follow. Dates are sample data.</p>'+
  '</div>'+(pad?'':tabbar('pantry'));
}

/* ================= PLAN ================= */
var DAYS=[['Monday','Mon',16],['Tuesday','Tue',17],['Wednesday','Wed',18],['Thursday','Thu',19],['Friday','Fri',20],['Saturday','Sat',21],['Sunday','Sun',22]];
function planNeeds(){var m={},out=[];Object.keys(PLAN).forEach(function(d){var r=RECIPES[PLAN[d]];r.ING.forEach(function(it){var k=pKey(it);if(PAN[k])return;if(!m[k]){m[k]={it:it,for:[],amts:[]};out.push(m[k])}if(m[k].for.indexOf(r.short||r.title)<0){m[k].for.push(r.short||r.title);m[k].amts.push(it.amt)}})});return out}
function planView(){
 var pad=isPad(),n=Object.keys(PLAN).length,needs=planNeeds(),mins=0;Object.keys(PLAN).forEach(function(d){mins+=libMins(RECIPES[PLAN[d]])});
 var days=DAYS.map(function(D0,i){var id=PLAN[i],today=i===0;
  if(!id)return '<div class="pday"><div class="pdate'+(today?' today':'')+'"><b>'+D0[1]+'</b><span>'+D0[2]+'</span></div><button class="padd" data-planadd="'+i+'" aria-label="Add a recipe for '+D0[0]+'">+ Add a recipe</button></div>';
  var r=RECIPES[id],c=coverage(id),miss=c[1]-c[0];
  return '<div class="pday"><div class="pdate'+(today?' today':'')+'"><b>'+D0[1]+'</b><span>'+D0[2]+'</span></div><div class="pmeal"><button class="pmopen" data-open="'+id+'" aria-label="Open '+esc(r.title)+'"><span class="libfp">'+fpBar(r,60)+'</span><span class="libtxt" style="padding:12px 52px 12px 14px"><span class="kicker">'+(today?'Tonight · ':'')+r.kicker.split(' · ')[0]+'</span><b style="font-size:17px">'+esc(r.title)+'</b><span class="muted">'+r.meta+' · '+(miss?miss+' to buy':'everything on hand')+'</span></span></button><button class="iconbtn pdel" data-plandel="'+i+'" aria-label="Remove '+esc(r.title)+' from '+D0[0]+'">'+SVG.close+'</button></div></div>'}).join('');
 var buy='<section class="card acard" style="gap:12px"><div class="between"><span class="kicker">To buy for this week</span><span style="font-size:13px"><b>'+needs.length+'</b> item'+(needs.length===1?'':'s')+'</span></div>'+
  (needs.length?'<div style="display:flex;flex-direction:column">'+needs.map(function(x){return '<div class="row" style="gap:10px;min-height:44px;border-bottom:1px solid #ECECE8">'+icon(x.it.icon[0][0],28)+'<span style="flex:1;min-width:0;font-size:15px;font-weight:600;padding-left:8px;border-left:4px solid '+(x.it.edge||x.it.color)+'">'+esc(x.it.name)+'</span><span class="muted" style="font-size:12px;text-align:right">'+esc(x.for.join(', '))+'</span></div>'}).join('')+'</div>':'<span style="font-size:14px">Nothing. The pantry covers the whole week.</span>')+
  (needs.length?'<button class="secondary" style="height:44px;font-size:14px" data-go="shopall">Open the shopping list</button>':'')+'<span class="muted" style="font-size:12px;line-height:1.4">Based on your pantry.</span></section>';
 return '<div class="pad">'+
  '<div class="between" style="gap:16px;align-items:flex-end"><div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">Week of November 16</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Plan</h1></div></div>'+
  '<div class="stats" style="grid-template-columns:repeat(3,1fr)"><div><b>'+n+' of 7</b><span>nights planned</span></div><div><b>'+(mins>=60?Math.floor(mins/60)+' hr '+(mins%60?mins%60+' min':''):mins+' min')+'</b><span>cooking time</span></div><div><b>'+needs.length+'</b><span>to buy</span></div></div>'+
  '<div class="plangrid"><div class="pdays">'+days+'</div>'+buy+'</div>'+
  '</div>'+(pad?'':tabbar('plan'));
}
function openPlanPick(i){
 var el=document.getElementById('sheet'),used={};Object.keys(PLAN).forEach(function(d){used[PLAN[d]]=DAYS[d][1]});
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Choose a recipe for '+DAYS[i][0]+'">'+
  '<div class="between"><div><span class="kicker">'+DAYS[i][0]+', November '+DAYS[i][2]+'</span><h2 class="h2" style="font-size:20px">Choose a recipe</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column;gap:8px">'+RECIPE_ORDER.map(function(id){var r=RECIPES[id],c=coverage(id),miss=c[1]-c[0];
   return '<button class="opt" style="height:auto;min-height:56px;padding:8px 14px;text-align:left;gap:10px" data-planpick="'+i+':'+id+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b style="font-size:15px">'+esc(r.title)+'</b><span class="muted" style="font-size:12px">'+r.meta+' · '+(miss?miss+' to buy':'everything on hand')+'</span></span>'+(used[id]?'<span class="badge" style="height:22px;font-size:11px;flex-shrink:0">'+used[id]+'</span>':'')+'</button>'}).join('')+'</div></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}

/* ================= SHOP (weekly list) ================= */
var CART={};
function shopAllView(){
 var pad=isPad(),needs=planNeeds(),n=planIds().length;
 Object.keys(CART).forEach(function(k){if(!needs.some(function(x){return pKey(x.it)===k}))delete CART[k]});
 var inCart=needs.filter(function(x){return CART[pKey(x.it)]}).length;liveShop(needs);
 var planned=DAYS.map(function(D0,i){return (PLAN[i]||[]).map(function(id){return '<button class="chip out" data-open="'+id+'" style="height:36px"><span class="muted" style="font-weight:600">'+D0[1]+'</span> '+esc(RECIPES[id].short||RECIPES[id].title)+'</button>'}).join('')}).join('');
 var secs=AISLES.map(function(a){var items=needs.filter(function(x){return x.it.aisle===a});if(!items.length)return '';
  var left=items.filter(function(x){return !CART[pKey(x.it)]}).length;
  return '<section style="display:flex;flex-direction:column;gap:10px"><div class="between" style="border-bottom:1.5px solid #111;padding-bottom:6px"><h2 class="h2">'+a+'</h2><span class="muted" style="font-size:12px;font-weight:600">'+(left?left+' to get':'All in cart')+'</span></div><div class="tiles">'+
   items.map(function(x){var it=x.it,k=pKey(it),g=!!CART[k],cnt=Math.min(4,it.icon[0][1]),size=cnt===1?56:Math.min(36,Math.floor(140/cnt)),ic='';for(var j=0;j<cnt;j++)ic+=icon(it.icon[0][0],size);
    return '<button class="tile'+(g?' got':'')+'" data-wcart="'+esc(k)+'" aria-pressed="'+g+'" aria-label="'+esc(it.name+', '+it.amt+', for '+x.for.join(' and ')+(g?', in cart':''))+'" style="background:'+(g?'#fff':it.color+'24')+'"><span class="tchk">'+(g?SVG.tick:'')+'</span>'+(g&&CARTBY[k]?'<i class="byav" title="'+PEOPLE[CARTBY[k]]+'">'+CARTBY[k]+'</i>':'')+'<span class="ticons">'+ic+'</span><b>'+esc(it.name)+'</b><span style="font-size:12px;color:#3A3A38">'+esc(x.amts.join(' + '))+'</span><span class="ttag">'+esc(x.for.join(', '))+'</span></button>'}).join('')+'</div></section>'}).join('');
 return '<div class="pad">'+
  kitchenBar()+'<div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">For this week’s plan · '+n+' recipe'+(n===1?'':'s')+'</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Shopping</h1></div>'+
  (planned?'<div style="display:flex;gap:8px;flex-wrap:wrap">'+planned+'</div>':'')+
  (needs.length?'<div style="display:flex;flex-direction:column;gap:8px"><b style="font-size:14px">'+inCart+' of '+needs.length+' in your cart</b><div class="prog"><i style="width:'+Math.round(100*inCart/needs.length)+'%"></i></div></div><div class="aisles">'+secs+'</div>'
   :'<p class="insight"><strong>Nothing to buy.</strong> '+(n?'Your pantry covers everything planned this week.':'Nothing is planned yet.')+'</p><button class="secondary" data-go="plan">Open the plan</button>')+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.4">Built from the Plan tab and your pantry. Amounts are listed per recipe at each recipe’s base servings; they are not added together yet.</p>'+
  '</div>'+(needs.length?'<div class="bottombar"'+(pad?'':' style="bottom:84px"')+'><button class="primary" data-act="shopalldone"'+(inCart?'':' disabled')+'>'+(inCart?'Add '+inCart+' to pantry':'Tick items as you shop')+'</button></div>':'')+(pad?'':tabbar('shopall'));
}
initPantry();

function openLibTags(){
 var el=document.getElementById('sheet'),tags={};RECIPE_ORDER.forEach(function(id){RECIPES[id].tags.forEach(function(t){tags[t[0]]=(tags[t[0]]||0)+1})});
 var tk=Object.keys(tags).sort(function(x,y){return tags[y]-tags[x]||x.localeCompare(y)});
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Filter by tag"><div class="between"><div><span class="kicker">Recipes</span><h2 class="h2" style="font-size:20px">Filter by tag</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column">'+tk.map(function(t){var on=S.lib.tag===t;return '<button class="tagrow'+(on?' on':'')+'" data-libtag="'+esc(t)+'" aria-pressed="'+on+'"><b>'+esc(t)+'</b><span class="muted">'+tags[t]+' recipe'+(tags[t]>1?'s':'')+'</span></button>'}).join('')+'</div></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}
