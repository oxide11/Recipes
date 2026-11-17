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
 '<button class="iconbtn" style="width:48px;height:48px;background:#111;color:#fff;font-family:var(--disp);font-weight:700;font-size:18px" aria-label="Profile" data-act="profile" aria-haspopup="dialog">M</button></div></div>'+
 tagBar()+'<div style="display:flex;flex-direction:column;gap:10px"><p class="kicker">Cook with what you have</p><div style="display:flex;gap:8px;flex-wrap:wrap">'+
  [['#F2C200','Lemons','piccata'],['#9CBF5A','Lemongrass','thai'],['#2E9E4F','Green onion','cajun'],['#6CBF3A','Limes','thai'],['#E9B98C','Chicken','cajun']].map(function(c){return '<button class="chip" data-open="'+c[2]+'" style="height:40px;font-size:15px"><span class="dot" style="background:'+c[0]+'"></span>'+c[1]+'</button>'}).join('')+'</div></div>'+
 '<div style="display:flex;flex-direction:column;gap:12px"><p class="kicker">From Ashley’s recipe cards</p><div class="rgrid">'+
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
 var vals=ING.map(function(i){return (mode==='calories'?nutOf(i)[0]:i[mode])*f}),total=vals.reduce(function(a,b){return a+b},0);
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
  '</section>';
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
  '<div class="stepper" style="height:52px" role="group" aria-label="Servings"><button data-serv="-1" aria-label="Fewer servings"'+(S.servings<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+S.servings+'</b> serving'+(S.servings>1?'s':'')+'</span><button data-serv="1" aria-label="More servings"'+(S.servings>=12?' disabled':'')+'>+</button></div>'+'<button class="primary" data-act="startcook">Start cooking</button></div>'+
 '<div class="stats">'+liveStats().map(function(s){return '<div><b>'+s[0]+'</b><span>'+s[1]+'</span></div>'}).join('')+'</div>'+
 '<div class="ovgrid"><section class="card" style="padding:18px 16px;display:flex;flex-direction:column;gap:14px;min-width:0">'+
   '<div class="between" style="gap:12px;flex-wrap:wrap"><div><h2 class="h2" style="font-size:20px">Where it all goes</h2><span class="muted" style="font-size:12px;font-weight:600">'+M.cap+' · tap an ingredient to see its swaps</span></div>'+
   '<div class="seg" role="group" aria-label="Measure by" style="grid-template-columns:repeat(4,1fr);width:360px">'+Object.keys(MODES).map(function(k){return '<button data-mode="'+k+'" aria-pressed="'+(k===S.mode)+'">'+MODES[k].label+'</button>'}).join('')+'</div></div>'+
   sankeyWide(W)+'<p class="insight"><strong>'+ins[0]+'</strong> '+ins[1]+'</p></section>'+
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
  '<section class="psec"><span class="kicker">Measurements</span>'+
   row('Temperature','Safe temperature badges',seg('temp',[['F','°F'],['C','°C']]))+
   row('Units','Default for new recipes',seg('units',[['us','US'],['metric','Metric']]))+
   row('Default servings','Recipes open scaled to this','<div class="stepper" style="height:44px" role="group" aria-label="Default servings"><button style="width:36px;height:36px" data-pserv="-1" aria-label="Fewer"'+(P.serv<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+P.serv+'</b></span><button style="width:36px;height:36px" data-pserv="1" aria-label="More"'+(P.serv>=12?' disabled':'')+'>+</button></div>')+'</section>'+
  '</div><div class="pcol"><section class="psec"><span class="kicker">While cooking</span><div style="display:flex;flex-direction:column">'+
   tog('awake','Keep screen awake','No dimming while a recipe is open')+
   tog('sound','Timer sounds','A chime when a timer ends')+
   tog('photo','Ask for a plate photo','Prompt at the end of every cook')+'</div></section>'+
  '<section class="psec"><span class="kicker">Household</span><div class="row" style="gap:14px;flex-wrap:wrap">'+
   [['A','Ashley'],['N','Nicole']].map(function(h){return '<span class="phh"><span class="pava sm">'+h[0]+'</span>'+h[1]+'</span>'}).join('')+
   '<button class="chip out" style="border-style:dashed" data-toast="Invites are mocked in this prototype">+ Invite</button></div></section>'+
  '<section class="psec" style="gap:0"><span class="kicker" style="margin-bottom:6px">More</span>'+
   link('Cooking log',cooks+' cooks across '+Object.keys(LOG).filter(function(k){return LOG[k].length}).length+' recipes','The full cooking log is not built yet. Each recipe shows its own under Your cooks.')+
   link('Nutritional goals','Daily targets for calories and macros','Nutritional goals are on the backlog')+
   link('Import recipe cards','Photograph a card to add it','Card import is not part of this prototype')+'</section></div></div>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.4">Prototype: temperature units and the never-suggested list take effect. The other settings only remember their state.</p>'+
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
 var swaps='<section class="card acard"><span class="kicker">Swaps you have made</span>'+(tk.length?'<div style="display:flex;flex-direction:column">'+tk.map(function(k){return '<div class="between" style="min-height:40px;border-bottom:1px solid #ECECE8;gap:12px"><span style="font-size:15px;font-weight:600">'+esc(k)+'</span><span class="badge solid" style="height:24px;font-size:12px">'+tally[k]+' of '+n+'</span></div>'}).join('')+'</div>':'')+
  '<span class="muted" style="font-size:13px">'+(plain?'Cooked as written '+plain+' time'+(plain>1?'s':'')+'.':'Never cooked exactly as written.')+'</span></section>';
 var entries='<section style="display:flex;flex-direction:column;gap:12px"><div class="between"><span class="kicker">Every cook, newest first</span></div>'+log.map(function(_,i){return i}).reverse().map(function(i){var c=log[i],sw=c.swapList||[];
  return '<article class="card ckentry'+(S.cookOpen===i?' on':'')+'" id="ck'+i+'"><div class="between" style="gap:12px"><div class="row" style="gap:12px;min-width:0"><span class="pnum" style="width:32px;height:32px;font-size:14px;flex-shrink:0">'+(i+1)+'</span><div style="min-width:0"><b style="font-size:17px;letter-spacing:1px">'+starsHtml(c.rating)+'</b><div class="muted" style="font-size:13px">'+esc(c.date||'')+' · '+esc(c.who||'You')+'</div></div></div>'+(c.mins?'<span style="text-align:right;white-space:nowrap"><b style="font-family:var(--disp);font-size:20px">'+c.mins+' min</b><div class="muted" style="font-size:12px">'+(am&&c.mins!==am?(Math.abs(c.mins-am)+' min '+(c.mins<am?'faster':'slower')+' than avg'):'right on average')+'</div></span>':'')+'</div>'+
   (sw.length?'<div style="display:flex;flex-wrap:wrap;gap:6px">'+sw.map(function(x){return '<span class="badge" style="height:26px;font-size:12px">'+esc(x)+'</span>'}).join('')+'</div>':'<span class="muted" style="font-size:13px">Cooked as written, no swaps</span>')+
   (c.note?'<p class="cardnote" style="margin:0;font-size:15px;line-height:1.5">“'+esc(c.note)+'”</p>':'')+'</article>'}).join('')+
  (log.some(function(c){return c.sample})?'<span class="muted" style="font-size:12px">Earlier entries are sample data for the prototype.</span>':'')+'</section>';
 return '<div class="pad">'+head+stats+'<div class="ckgrid"><div style="display:flex;flex-direction:column;gap:16px;min-width:0">'+chart+swaps+'</div>'+entries+'</div></div>'+
  '<div class="bottombar"><button class="primary" data-act="startcook">Cook it again</button></div>';
}
