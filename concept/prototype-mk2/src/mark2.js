/* ================= MARK 2: features from the review ================= */
var ONHAND={},EXP={},PROMO={},QA={};
function initMark2(){
 ONHAND={};PROMO={};QA={};EXP={};
 // sample data: the second swap in every map is treated as already in the kitchen
 RECIPE_ORDER.forEach(function(id){var sets=RECIPES[id].SETS;Object.keys(sets).forEach(function(k){var l=sets[k].leaves[1];if(l&&!l.allergen&&!l.dislike)ONHAND[l.id]=1})});
 // sample data: a few things on hand are close to their date
 kitchenInit();
 SPICE=SPICE0.map(function(s){return {name:s[0],color:s[1],level:s[2],months:s[3],keys:s[4]}});
 STOCK={};var seedExp={milk:2,parmesan:3,egg:4,potato:5};catalog().forEach(function(c){if(PAN[c.key]){var s=stockOf(c.key);s.bought=1+hashStr(c.key)%11;if(seedExp[c.key]){s.exp=seedExp[c.key]}else if(s.exp!==null){s.exp=Math.max(6,s.exp-Math.min(s.bought,s.exp-6))}}});syncExp();
}

/* ---- F8 receipt prices ---- */
function hashStr(s){var h=7;for(var i=0;i<s.length;i++)h=(h*31+s.charCodeAt(i))%9973;return h}
function receiptHit(it){return hashStr(it.name)%3!==0}
function costOf(it){if(!P.receipts||!receiptHit(it))return it.cost;return Math.round(it.cost*(0.82+(hashStr(it.name)%45)/100)*100)/100}
function mval(it,mode){return mode==='calories'?nutOf(it)[0]:mode==='cost'?costOf(it):it[mode]}
function costSource(){
 if(S.mode!=='cost')return '';
 var hit=ING.filter(receiptHit).length;
 return '<div class="costsrc"><div class="seg" role="group" aria-label="Prices from" style="grid-template-columns:1fr 1fr"><button data-m2set="receipts:0" aria-pressed="'+(!P.receipts)+'">Estimated</button><button data-m2set="receipts:1" aria-pressed="'+(!!P.receipts)+'">From receipts</button></div>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">'+(P.receipts?hit+' of '+ING.length+' ingredients matched to your Nov 12 receipt.'+(hit<ING.length?' The rest stay estimated.':'')+' Receipt data is sample data in this prototype.':'Estimated prices. Switch to use what you actually paid.')+'</span></div>';
}

/* ---- F9 goals decide what "better" means ---- */
function goodDelta(i,d){
 if(!d)return 0;var g=P.goal||'lighter';
 if(g==='protein')return i===1?(d>0?1:-1):0;
 if(g==='gain')return i===0||i===1?(d>0?1:-1):0;
 return i===1?(d>0?1:-1):(d<0?1:-1);
}
function goalKey(){var g=P.goal||'lighter';return g==='protein'?'Goal: more protein. Other changes are neutral.':g==='gain'?'Goal: gain. More calories and protein count as better.':'Goal: lighter. Less is better, except protein.'}

/* ---- F1 swaps that know the pantry ---- */
function leafOnHand(l){return !!(ONHAND[l.id]||PAN[pKey({name:l.name})])}
function ohNote(id,s,why){
 if(why)return '';var miss=!S.have[id]||S.haveVia[id];
 if(leafOnHand(s))return '<div class="ohnote"><i></i><span><b>On hand.</b> '+(miss&&!PAN[pKey(ing(id))]?'Using it takes '+esc(ing(id).name.toLowerCase())+' off your shopping list.':'No shopping needed.')+'</span></div>';
 return '<div class="ohnote no"><i></i><span>Not in your pantry. It goes on the shopping list.</span></div>';
}

/* ---- F2 hands-free cooking ---- */
function hfButton(){return '<button class="hfbtn'+(P.hf?' on':'')+'" data-act="hfsheet" aria-label="Hands-free cooking, '+(P.hf?'on':'off')+'" aria-haspopup="dialog"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg><span>'+(P.hf?'On':'Hands-free')+'</span></button>'}
function plainStep(){var d=document.createElement('div');d.innerHTML=stepLines(STEPS[S.step]).join(' ');return 'Step '+(S.step+1)+'. '+stepTitle(STEPS[S.step])+'. '+d.textContent}
function hfSpeak(){
 if(!P.hf||S.screen!=='cook'||S.spoken===S.recipe+':'+S.step)return;S.spoken=S.recipe+':'+S.step;
 try{if(window.speechSynthesis&&window.SpeechSynthesisUtterance){speechSynthesis.cancel();var u=new SpeechSynthesisUtterance(plainStep());u.rate=.95;speechSynthesis.speak(u)}}catch(e){}
}
function hfTimerDone(k){
 if(!P.hf||+k!==S.step||S.step>=STEPS.length-1)return;
 setTimeout(function(){if(S.screen==='cook'&&+k===S.step&&P.hf){var t=S.timers[k];if(t)t.ack=true;dockSig='';S.step++;S.dir=1;render(true);toast('Timer done. On to step '+(S.step+1))}},1800);
}
function lockPreview(){
 var keys=typeof activeTimers==='function'&&S.timers?activeTimers():[];
 var rows=keys.length?keys.map(function(k){var t=S.timers[k],v=timerView(t);return '<div class="lockrow">'+miniRing(46,v.f>.32&&!v.done?'#FFFFFF':v.col,v.f)+'<span><b>'+clock(t.left)+'</b><small>'+esc(STEPS[k].label)+' · step '+(+k+1)+'</small></span></div>'}).join(''):
  '<div class="lockrow">'+miniRing(46,colorFor(.28),.28)+'<span><b>2:48</b><small>Sample timer · starts when you start one</small></span></div>';
 return '<div class="lock" aria-label="Lock screen preview"><span class="locktime">6:42</span>'+rows+'</div>';
}
function openHf(keepPos){
 var el=document.getElementById('sheet'),can=!!(window.speechSynthesis&&window.SpeechSynthesisUtterance);
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Hands-free cooking">'+
  '<div class="between"><div><span class="kicker">Cooking mode</span><h2 class="h2" style="font-size:20px">Hands-free</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<button class="tog" role="switch" aria-checked="'+(!!P.hf)+'" data-hf="1" style="border-bottom:none"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>Hands-free cooking</b><span>Reads each step aloud. When a step’s timer ends it moves to the next step.</span></span><i class="sw'+(P.hf?' on':'')+'"><i></i></i></button>'+
  (can?'':'<p class="cardnote" style="margin:0">This browser has no speech voice, so steps will not be read aloud here. Moving on after timers still works.</p>')+
  '<div style="display:flex;flex-direction:column;gap:8px"><span class="kicker">On your lock screen</span>'+lockPreview()+'<span class="muted" style="font-size:12px;line-height:1.4">In the app this is a Live Activity, so the timer keeps its colour on the lock screen. Voice commands such as “next” are not in this prototype.</span></div>'+
  '</div></div>';
}

/* ---- F4 how long it takes you ---- */
function logAvg(id){var t=(LOG[id]||[]).filter(function(c){return c.mins});return t.length?{m:Math.round(t.reduce(function(s,c){return s+c.mins},0)/t.length),n:t.length}:null}
function myRatio(){var s=0,n=0;RECIPE_ORDER.forEach(function(id){var a=logAvg(id),c=libMins(RECIPES[id]);if(a&&c<999){s+=a.m/c;n++}});return n?s/n:1}
function myMins(id){var a=logAvg(id);if(a)return {m:a.m,n:a.n,yours:true};return {m:Math.round(libMins(RECIPES[id])*myRatio()),n:0,yours:false}}
function myTimeLine(){
 var t=myMins(R.id),card=libMins(R),pct=Math.round((myRatio()-1)*100);
 return '<span class="mytime"><b>'+(t.yours?'':'~')+t.m+' min for you</b> · '+(t.yours?'your average over '+t.n+' cook'+(t.n>1?'s':'')+', the card says '+card:'predicted: you run '+(pct>=0?pct+'% over':Math.abs(pct)+'% under')+' the card')+'</span>';
}

/* ---- F5 use it up ---- */
function useItUp(){
 var keys=Object.keys(EXP).filter(function(k){return PAN[k]}).sort(function(a,b){return EXP[a]-EXP[b]}).slice(0,4);if(!keys.length||S.tag)return '';
 var cat={};catalog().forEach(function(c){cat[c.key]=c.it});
 var best=null;RECIPE_ORDER.forEach(function(id){var r=RECIPES[id],hit=r.ING.filter(function(it){return EXP[pKey(it)]&&PAN[pKey(it)]}),c=coverage(id),sc=hit.length*10+c[0]/c[1];if(hit.length&&(!best||sc>best.sc))best={id:id,sc:sc,hit:hit,miss:c[1]-c[0]}});
 return '<section class="useup"><div class="between"><p class="kicker" style="color:#111">Use it up</p><button class="linkbtn" style="font-size:13px" data-go="pantry">Pantry</button></div>'+
  '<div style="display:flex;gap:8px;flex-wrap:wrap">'+keys.map(function(k){var it=cat[k];return it?'<span class="uchip'+(EXP[k]<=2?' soon':'')+'">'+icon(it.icon[0][0],24)+'<b>'+esc(it.name)+'</b><em>'+EXP[k]+' day'+(EXP[k]>1?'s':'')+'</em></span>':''}).join('')+'</div>'+
  (best?'<button class="upick" data-open="'+best.id+'"><span><b>'+esc(RECIPES[best.id].title)+'</b><small>uses '+best.hit.map(function(it){return it.name.toLowerCase()}).join(' and ')+' · '+(best.miss?best.miss+' to buy':'everything on hand')+'</small></span>'+SVG.arrow+'</button>':'')+'</section>';
}

/* ---- F3 cook two recipes together (plan only) ---- */
function plainTitle(r,st){return st.title.replace(/\{(\w+)!?\}/g,function(_,k){var li=r.LINE[k],it=li&&li.ing?r.ING.filter(function(x){return x.id===li.ing})[0]:r.ING.filter(function(x){return x.id===k})[0];return it?it.name.toLowerCase():k})}
function mergePlan(A0,B0){
 var list=Array.isArray(A0)?A0:[A0,B0],Q=list.map(function(r){return {r:r,i:0,ready:0}}),busy=0,rows=[];
 function left(q){var s=0;for(var j=q.i;j<q.r.STEPS.length;j++){var t=stepTime(q.r.STEPS[j]);s+=t.on+t.wait}return s}
 function open(){return Q.filter(function(q){return q.i<q.r.STEPS.length})}
 while(open().length){
  var c=open();c.sort(function(x,y){var sx=Math.max(busy,x.ready),sy=Math.max(busy,y.ready);return sx-sy||left(y)-left(x)});
  var q=c[0],st=q.r.STEPS[q.i],t=stepTime(st),s=Math.max(busy,q.ready);
  rows.push({at:s,lane:Q.indexOf(q),r:q.r,n:q.i+1,title:plainTitle(q.r,st),on:t.on,wait:t.wait});
  busy=s+t.on;q.ready=s+t.on+t.wait;q.i++;
 }
 var apart=0;list.forEach(function(r){r.STEPS.forEach(function(st){var t=stepTime(st);apart+=t.on+t.wait})});
 return {rows:rows,end:Math.max.apply(null,Q.map(function(q){return q.ready}).concat([busy])),apart:apart,done:Q.map(function(q){return q.ready})};
}
function openWith(){
 var el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Cook alongside"><div class="between"><div><span class="kicker">With '+esc(R.title)+'</span><h2 class="h2" style="font-size:20px">Cook alongside</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column;gap:8px">'+RECIPE_ORDER.filter(function(id){return id!==R.id}).map(function(id){var r=RECIPES[id],m=mergePlan(R,r);
   return '<button class="opt" style="height:auto;min-height:56px;padding:8px 14px;text-align:left;gap:10px" data-withpick="'+id+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b style="font-size:15px">'+esc(r.title)+'</b><span class="muted" style="font-size:12px">'+m.end+' min together · saves '+(m.apart-m.end)+' min</span></span></button>'}).join('')+'</div></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}
function togetherView(){
 var B0=RECIPES[S.with],pad=isPad();if(!B0||B0===R)return '<div class="pad">'+'<button class="secondary" data-back="recipe">Back</button></div>';
 var m=mergePlan(R,B0),names=[R.short||R.title,B0.short||B0.title];
 function hm(x){return Math.floor(x/60)+':'+(x%60<10?'0':'')+x%60}
 return '<div class="pad">'+
  '<div class="row" style="gap:12px;align-items:flex-start"><button class="iconbtn" data-back="recipe" aria-label="Back to recipe">'+SVG.back+'</button><div><h1 class="t" style="font-size:'+(pad?36:26)+'px">Cook together</h1><p class="muted" style="margin:2px 0 0;font-size:'+(pad?14:13)+'px">'+esc(R.title)+' + '+esc(B0.title)+'</p></div></div>'+
  '<div class="stats" style="grid-template-columns:repeat(3,1fr)"><div><b>'+m.end+' min</b><span>together</span></div><div><b>'+m.apart+' min</b><span>one after the other</span></div><div><b>'+(m.apart-m.end)+' min</b><span>saved</span></div></div>'+
  '<div class="row" style="gap:14px;flex-wrap:wrap;font-size:13px;font-weight:600"><span class="row" style="gap:6px"><i class="lane l0"></i>'+esc(names[0])+'</span><span class="row" style="gap:6px"><i class="lane l1"></i>'+esc(names[1])+'</span><button class="linkbtn" style="font-size:13px;margin-left:auto" data-act="together">Change</button></div>'+
  '<ol class="tl">'+m.rows.map(function(x){return '<li class="tlrow"><span class="tlat">'+hm(x.at)+'</span><i class="lane l'+x.lane+'"></i><span class="tltxt"><b>'+esc(x.title)+'</b><small>'+esc(names[x.lane])+' · step '+x.n+' · '+x.on+' min hands-on'+(x.wait?' · then '+x.wait+' min on a timer':'')+'</small></span></li>'}).join('')+
   '<li class="tlrow end"><span class="tlat">'+hm(m.end)+'</span><i class="lane done"></i><span class="tltxt"><b>Both on the table</b></span></li></ol>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.45">Steps are ordered so your hands are only on one thing at a time and waits overlap. This is a plan only for now: cooking mode still runs one recipe at a time. Times come from each card’s steps.</p>'+
  '</div><div class="bottombar"><button class="primary" data-act="startcook">Start with '+esc(names[m.rows[0].lane])+'</button></div>';
}

/* ---- F7 questions for Ashley + card import ---- */
function openQ(id){var q=RECIPES[id].card.questions,n=0;q.forEach(function(_,i){if(!QA[id+':'+i])n++});return n}
function openQCount(){var n=0;RECIPE_ORDER.forEach(function(id){n+=openQ(id)});return n}
function questionsView(){
 var pad=isPad(),open=openQCount(),tot=0;RECIPE_ORDER.forEach(function(id){tot+=RECIPES[id].card.questions.length});
 var secs=RECIPE_ORDER.map(function(id){var r=RECIPES[id],q=r.card.questions;if(!q.length)return '';
  return '<section class="card acard" style="gap:8px"><div class="between" style="gap:12px"><button class="linkbtn" style="font-size:15px;text-decoration:none;font-family:var(--disp)" data-open="'+id+'">'+esc(r.title)+'</button><span class="muted" style="font-size:12px;font-weight:600;white-space:nowrap">'+openQ(id)+' open</span></div>'+
   q.map(function(t,i){var done=!!QA[id+':'+i];return '<button class="qrow'+(done?' done':'')+'" data-qa="'+id+':'+i+'" aria-pressed="'+done+'"><i class="pchk" aria-hidden="true" style="'+(done?'background:#111;border-color:#111':'')+'">'+(done?'<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l5 5 9-10"/></svg>':'')+'</i><span>'+esc(t)+'</span></button>'}).join('')+'</section>'}).join('');
 return '<div class="pad">'+
  '<div class="row" style="gap:12px;align-items:flex-start"><button class="iconbtn" data-back="library" aria-label="Back to recipes">'+SVG.back+'</button><div><h1 class="t" style="font-size:'+(pad?36:26)+'px">Questions for Ashley</h1><p class="muted" style="margin:2px 0 0;font-size:'+(pad?14:13)+'px">'+open+' open of '+tot+' · from the cards that were unclear</p></div></div>'+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">Tick a question once Ashley has answered it. Until then the app shows its assumption as a card note in the recipe.</p>'+
  '<div class="qgrid">'+secs+'</div>'+
  '</div><div class="bottombar"><button class="primary" data-act="sendqs"'+(open?'':' disabled')+'>'+(open?'Send '+open+' open question'+(open===1?'':'s')+' to Ashley':'All answered')+'</button></div>';
}
function openImport(){
 var el=document.getElementById('sheet'),steps=[['Photograph the card','Front and back. Handwriting is fine.'],['The app transcribes it','Ingredients, amounts and steps become a recipe you can cook from.'],['Unclear bits become questions','Missing units or steps are flagged and added to Questions for Ashley.']];
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Import a recipe card"><div class="between"><div><span class="kicker">Add a recipe</span><h2 class="h2" style="font-size:20px">Import a card</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<ol style="list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:12px">'+steps.map(function(s,i){return '<li class="row" style="gap:12px;align-items:flex-start"><span class="pnum" style="width:28px;height:28px;font-size:13px;flex-shrink:0">'+(i+1)+'</span><span style="display:flex;flex-direction:column;gap:2px"><b style="font-size:15px">'+s[0]+'</b><span class="muted" style="font-size:13px;line-height:1.4">'+s[1]+'</span></span></li>'}).join('')+'</ol>'+
  '<button class="primary" data-toast="The camera is not wired up in this prototype">Take a photo</button><button class="secondary" data-go="questions">See the '+openQCount()+' open questions</button>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">The existing app already imports from photos; this would reuse it. 32 of Ashley’s cards are still waiting.</span></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}

/* ---- pencil strike-outs: one hand-drawn pass per row of text, in varied styles ---- */
function rng(seed){var s=seed%2147483647;if(s<=0)s+=2147483646;return function(){s=s*16807%2147483647;return (s-1)/2147483646}}
function pencil(fresh){
 if(S.screen!=='cook')return;
 scr.querySelectorAll('.pl .pencil').forEach(function(x){x.remove()});
 scr.querySelectorAll('.line.struck').forEach(function(line){
  var pl=line.querySelector('.pl');if(!pl)return;var key=line.dataset.strike,seed=hashStr(S.recipe+':'+key)*13+5;
  var pr=pl.getBoundingClientRect(),rows=[];
  pl.querySelectorAll('.w').forEach(function(w){var r=w.getBoundingClientRect();if(!r.width)return;
   var top=(r.top-pr.top)/SCALE,h=r.height/SCALE,x0=(r.left-pr.left)/SCALE,x1=(r.right-pr.left)/SCALE,last=rows[rows.length-1];
   if(last&&Math.abs(last.top-top)<h*.5){last.x0=Math.min(last.x0,x0);last.x1=Math.max(last.x1,x1)}else rows.push({top:top,h:h,x0:x0,x1:x1})});
  if(!rows.length)return;
  var W=pl.offsetWidth,H=pl.offsetHeight,out='',anim=fresh===key;
  rows.forEach(function(row,ri){
   var R=rng(seed+ri*977),style=[0,1,3,4,5][(hashStr(key)+ri*2+Math.floor(R()*3))%5],h=row.h,y=row.top+h*(.5+(R()-.5)*.14),ov=h*(.08+R()*.18),x0=row.x0-ov,x1=row.x1+ov*(.6+R()),len=x1-x0;
   var slope=(R()-.5)*h*.16,amp=h*(.03+R()*.05),sw=h*(.055+R()*.045),op=.72+R()*.2,paths=[];
   function wob(a,b,ya,yb,k){var n=Math.max(3,Math.round(Math.abs(b-a)/(h*1.1))),d='M'+a.toFixed(1)+' '+ya.toFixed(1);for(var i=1;i<=n;i++){var t=i/n,x=a+(b-a)*t,yy=ya+(yb-ya)*t+(R()-.5)*2*amp*(k||1),cx=a+(b-a)*(t-.5/n),cy=ya+(yb-ya)*(t-.5/n)+(R()-.5)*2*amp*(k||1);d+=' Q'+cx.toFixed(1)+' '+cy.toFixed(1)+' '+x.toFixed(1)+' '+yy.toFixed(1)}return d}
   if(style===0){paths.push([wob(x0,x1,y-slope/2,y+slope/2),sw,op])}
   else if(style===1){var d1=wob(x0,x1,y-slope/2,y+slope/2),back=wob(x1,x0+len*(.08+R()*.2),y+slope/2+h*.1,y-slope/2+h*.13);paths.push([d1+' L'+back.slice(1),sw*.9,op])}
   else if(style===2){var p=h*(.55+R()*.25),a2=h*(.16+R()*.08),d2='M'+x0.toFixed(1)+' '+(y+a2).toFixed(1),up=true;for(var x=x0+p*.5;x<x1+p*.5;x+=p*.5){d2+=' L'+(x+(R()-.5)*p*.2).toFixed(1)+' '+(y+(up?-a2:a2)+(R()-.5)*a2*.5).toFixed(1);up=!up}paths.push([d2,sw*.7,op-.08])}
   else if(style===3){paths.push([wob(x0,x1-len*R()*.1,y-h*.09,y+h*.07),sw*.85,op]);paths.push([wob(x0+len*R()*.08,x1,y+h*.1,y-h*.08),sw*.75,op-.1])}
   else if(style===4){var d4=wob(x0,x1,y-slope/2,y+slope/2,.6);d4+=' q'+(h*.18).toFixed(1)+' '+(h*.02).toFixed(1)+' '+(h*.1).toFixed(1)+' '+(-h*.22).toFixed(1);paths.push([d4,sw*1.35,Math.min(.95,op+.1)])}
   else{var mid=x0+len*(.45+R()*.15);paths.push([wob(x0,mid+h*.2,y-h*.05,y+h*.04),sw,op]);paths.push([wob(mid-h*.25,x1,y+h*.07,y-h*.03),sw*.9,op-.05])}
   paths.forEach(function(pp,pi){var dl=(ri*110+pi*90);
    out+='<path d="'+pp[0]+'" stroke-width="'+pp[1].toFixed(2)+'" stroke-opacity="'+pp[2].toFixed(2)+'" pathLength="1"'+(anim?' class="pdraw" style="animation-delay:'+dl+'ms"':'')+'/>'+
     '<path d="'+pp[0]+'" stroke-width="'+(pp[1]*.45).toFixed(2)+'" stroke-opacity="'+(pp[2]*.5).toFixed(2)+'" transform="translate('+((R()-.5)*h*.05).toFixed(1)+' '+(h*.035).toFixed(1)+')" pathLength="1"'+(anim?' class="pdraw" style="animation-delay:'+(dl+40)+'ms"':'')+'/>'});
  });
  var id='pf'+key.replace(/\W/g,'_');
  pl.insertAdjacentHTML('beforeend','<svg class="pencil" width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'" aria-hidden="true"><defs><filter id="'+id+'" x="-5%" y="-40%" width="110%" height="180%"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="'+(seed%97)+'" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="'+(2.2+rows[0].h*.04).toFixed(1)+'" xChannelSelector="R" yChannelSelector="G"/></filter></defs><g fill="none" stroke="#2B2B28" stroke-linecap="round" stroke-linejoin="round" filter="url(#'+id+')">'+out+'</g></svg>');
 });
}

/* ---- dark mode ---- */
function applyTheme(){var on=!!P.dark;document.getElementById('phone').classList.toggle('dark',on);document.body.classList.toggle('darkstage',on);var b=document.getElementById('themeBtn');if(b){b.setAttribute('aria-checked',on);b.querySelector('.sw').classList.toggle('on',on)}}

/* ---- plan: several recipes a day, and prep sessions ---- */
function planIds(){var out=[];Object.keys(PLAN).forEach(function(d){PLAN[d].forEach(function(id){out.push(id)})});return out}
function planNeeds(){var m={},out=[];planIds().forEach(function(id){var r=RECIPES[id];r.ING.forEach(function(it){var k=pKey(it);if(PAN[k])return;if(!m[k]){m[k]={it:it,for:[],amts:[]};out.push(m[k])}if(m[k].for.indexOf(r.short||r.title)<0){m[k].for.push(r.short||r.title);m[k].amts.push(it.amt)}})});return out}
function fmtS(x){return x>=60?Math.floor(x/60)+'h'+(x%60?' '+x%60+'m':''):x+' min'}
function fmtMin(x){return x>=60?Math.floor(x/60)+' hr'+(x%60?' '+x%60+' min':''):x+' min'}
function planView(){
 var pad=isPad(),ids=planIds(),needs=planNeeds(),mins=0,nights=Object.keys(PLAN).length;ids.forEach(function(id){mins+=myMins(id).m});
 var days=DAYS.map(function(D0,i){var list=PLAN[i]||[],today=i===0,prep=list.length>1,pm=prep?mergePlan(list.map(function(id){return RECIPES[id]})):null;
  var date='<div class="pdate'+(today?' today':'')+'"><b>'+D0[1]+'</b><span>'+D0[2]+'</span></div>';
  if(!list.length)return '<div class="pday empty">'+date+'<button class="padd" data-planadd="'+i+'" aria-label="Add a recipe for '+D0[0]+'">+ Add a recipe</button></div>';
  var meals=list.map(function(id,j){var r=RECIPES[id],c=coverage(id),miss=c[1]-c[0],t=myMins(id);
   return '<div class="pmeal"><button class="pmopen" data-open="'+id+'" aria-label="Open '+esc(r.title)+'"><span class="libfp">'+fpBar(r,60)+'</span><span class="libtxt" style="padding:11px 52px 11px 14px"><b style="font-size:17px">'+esc(r.title)+'</b><span class="muted">'+(t.yours?'':'~')+fmtMin(t.m)+' for you · '+(miss?miss+' to buy':'everything on hand')+(KITCHENS[KCUR].members.length>1?' · added by '+PEOPLE[PLANBY[i+':'+id]||'M']:'')+'</span></span></button><button class="iconbtn pdel" data-plandel="'+i+':'+j+'" aria-label="Remove '+esc(r.title)+' from '+D0[0]+'">'+SVG.close+'</button></div>'}).join('');
  var head='<div class="pdhead"><span class="kicker" style="color:#111">'+(today?'Tonight':D0[0])+(prep?' · prep day':'')+'</span>'+(prep?'<span class="muted" style="font-size:12px">'+list.length+' recipes · '+fmtS(pm.end)+'</span>':'')+'</div>';
  return '<div class="pday'+(prep?' prep':'')+'">'+date+'<div class="pdcol">'+head+meals+
   '<div class="pdfoot">'+(prep?'<button class="primary" style="height:44px;font-size:14px;width:auto;padding:0 18px" data-prep="'+i+'">Open prep session</button>':'')+'<button class="linkbtn" style="font-size:13px" data-planadd="'+i+'" aria-label="Add another recipe for '+D0[0]+'">+ Add another</button></div></div></div>'}).join('');
 var buy='<section class="card acard" style="gap:12px"><div class="between"><span class="kicker">To buy for this week</span><span style="font-size:13px"><b>'+needs.length+'</b> item'+(needs.length===1?'':'s')+'</span></div>'+
  (needs.length?'<div style="display:flex;flex-direction:column">'+needs.slice(0,pad?99:6).map(function(x){return '<div class="row" style="gap:10px;min-height:44px;border-bottom:1px solid #ECECE8">'+icon(x.it.icon[0][0],28)+'<span style="flex:1;min-width:0;font-size:15px;font-weight:600;padding-left:8px;border-left:4px solid '+(x.it.edge||x.it.color)+'">'+esc(x.it.name)+'</span><span class="muted" style="font-size:12px;text-align:right">'+esc(x.for.join(', '))+'</span></div>'}).join('')+'</div>'+(!pad&&needs.length>6?'<span class="muted" style="font-size:13px">and '+(needs.length-6)+' more</span>':''):'<span style="font-size:14px">Nothing. The pantry covers the whole week.</span>')+
  (needs.length?'<button class="secondary" style="height:44px;font-size:14px" data-go="shopall">Open the shopping list</button>':'')+'</section>';
 return '<div class="pad">'+
  kitchenBar()+'<div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">November 16 to 22</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Plan</h1></div>'+
  '<div class="stats" style="grid-template-columns:repeat(4,1fr)"><div><b>'+nights+' of 7</b><span>days planned</span></div><div><b>'+ids.length+'</b><span>recipes</span></div><div><b>'+fmtS(mins)+'</b><span>at your pace</span></div><div><b>'+needs.length+'</b><span>to buy</span></div></div>'+
  '<div class="plangrid"><div class="pdays">'+days+'</div>'+buy+'</div>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.45">Add more than one recipe to a day to make it a prep day. The week is sample data.</p>'+
  '</div>'+(pad?'':tabbar('plan'));
}
function openPlanPick(i){
 var el=document.getElementById('sheet'),used={},here=PLAN[i]||[];Object.keys(PLAN).forEach(function(d){PLAN[d].forEach(function(id){used[id]=DAYS[d][1]})});
 var cur=here.map(function(id){return RECIPES[id]});
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Choose a recipe for '+DAYS[i][0]+'">'+
  '<div class="between"><div><span class="kicker">'+DAYS[i][0]+', November '+DAYS[i][2]+'</span><h2 class="h2" style="font-size:20px">'+(here.length?'Add to this prep day':'Choose a recipe')+'</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column;gap:8px">'+RECIPE_ORDER.filter(function(id){return here.indexOf(id)<0}).map(function(id){var r=RECIPES[id],c=coverage(id),miss=c[1]-c[0],extra='';
   if(cur.length){var mm=mergePlan(cur.concat([r])),m0=cur.length>1?mergePlan(cur).end:cur[0].STEPS.reduce(function(s,st){var t=stepTime(st);return s+t.on+t.wait},0);extra=' · adds '+fmtMin(Math.max(0,mm.end-m0))}
   return '<button class="opt" style="height:auto;min-height:56px;padding:8px 14px;text-align:left;gap:10px" data-planpick="'+i+':'+id+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b style="font-size:15px">'+esc(r.title)+'</b><span class="muted" style="font-size:12px">'+r.meta+' · '+(miss?miss+' to buy':'everything on hand')+extra+'</span></span>'+(used[id]?'<span class="badge" style="height:22px;font-size:11px;flex-shrink:0">'+used[id]+'</span>':'')+'</button>'}).join('')+'</div></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}
function prepView(){
 var i=S.prepDay,list=(PLAN[i]||[]).map(function(id){return RECIPES[id]}),pad=isPad();
 if(list.length<2)return '<div class="pad"><div class="row" style="gap:12px"><button class="iconbtn" data-go="plan" aria-label="Back to plan">'+SVG.back+'</button><h1 class="t" style="font-size:26px">Prep session</h1></div><p class="insight">A prep session needs two or more recipes on the same day.</p></div>';
 var m=mergePlan(list),names=list.map(function(r){return r.short||r.title}),D0=DAYS[i];
 function hm(x){return Math.floor(x/60)+':'+(x%60<10?'0':'')+x%60}
 var share={};list.forEach(function(r,ri){r.ING.forEach(function(it){var k=pKey(it);(share[k]=share[k]||{it:it,rs:[],amts:[]});if(share[k].rs.indexOf(ri)<0){share[k].rs.push(ri);share[k].amts.push(it.amt)}})});
 var shared=Object.keys(share).map(function(k){return share[k]}).filter(function(x){return x.rs.length>1}).sort(function(x,y){return y.rs.length-x.rs.length});
 var hands=m.rows.reduce(function(s,x){return s+x.on},0);
 var lanes='<div class="lanes">'+list.map(function(r,ri){return '<button class="lanechip" data-open="'+r.id+'"><i class="lane l'+ri+'"></i><span><b>'+esc(r.title)+'</b><small>done at '+hm(m.done[ri])+' · '+r.base+' servings</small></span></button>'}).join('')+'</div>';
 var sharedCard=shared.length?'<section class="card acard" style="gap:10px"><span class="kicker">Get out once</span><p class="muted" style="margin:0;font-size:13px;line-height:1.4">These go into more than one recipe today. Measure or chop them together.</p><div style="display:flex;flex-direction:column">'+shared.map(function(x){return '<div class="row" style="gap:10px;min-height:44px;border-bottom:1px solid #ECECE8">'+icon(x.it.icon[0][0],28)+'<span style="flex:1;min-width:0;font-size:15px;font-weight:600;padding-left:8px;border-left:4px solid '+(x.it.edge||x.it.color)+'">'+esc(x.it.name)+'</span><span class="muted" style="font-size:12px;text-align:right">'+esc(x.amts.join(' + '))+'</span><span class="row" style="gap:3px">'+x.rs.map(function(ri){return '<i class="lane l'+ri+'"></i>'}).join('')+'</span></div>'}).join('')+'</div></section>':'';
 var tl='<ol class="tl">'+m.rows.map(function(x){return '<li class="tlrow"><span class="tlat">'+hm(x.at)+'</span><i class="lane l'+x.lane+'"></i><span class="tltxt"><b>'+esc(x.title)+'</b><small>'+esc(names[x.lane])+' · step '+x.n+' · '+x.on+' min hands-on'+(x.wait?' · then '+x.wait+' min on a timer':'')+'</small></span></li>'}).join('')+
  '<li class="tlrow end"><span class="tlat">'+hm(m.end)+'</span><i class="lane done"></i><span class="tltxt"><b>Everything done</b></span></li></ol>';
 return '<div class="pad">'+
  '<div class="row" style="gap:12px;align-items:flex-start"><button class="iconbtn" data-go="plan" aria-label="Back to plan">'+SVG.back+'</button><div><h1 class="t" style="font-size:'+(pad?36:26)+'px">Prep session</h1><p class="muted" style="margin:2px 0 0;font-size:'+(pad?14:13)+'px">'+D0[0]+', November '+D0[2]+' · '+list.length+' recipes</p></div></div>'+
  '<div class="stats" style="grid-template-columns:repeat(4,1fr)"><div><b>'+fmtS(m.end)+'</b><span>start to finish</span></div><div><b>'+fmtS(hands)+'</b><span>hands-on</span></div><div><b>'+fmtS(m.apart)+'</b><span>one at a time</span></div><div><b>'+fmtS(m.apart-m.end)+'</b><span>saved</span></div></div>'+
  lanes+
  '<div class="prepgrid"><div style="display:flex;flex-direction:column;gap:12px;min-width:0"><span class="kicker">One timeline</span>'+tl+'</div><div style="display:flex;flex-direction:column;gap:16px;min-width:0">'+sharedCard+
   '<p class="muted" style="margin:0;font-size:12px;line-height:1.45">Steps are ordered so your hands are on one thing at a time and waits overlap. It does not yet account for oven space or the number of burners. This is a plan only: cooking mode still runs one recipe at a time.</p></div></div>'+
  '</div><div class="bottombar"><button class="primary" data-open="'+m.rows[0].r.id+'">Start with '+esc(names[m.rows[0].lane])+'</button></div>';
}

/* ---- pantry inventory: how much, bought when, use by ---- */
var STOCK={},SHELF={'Produce':8,'Meat and seafood':3,'Dairy and eggs':12};
function catItem(key){var f=catalog().filter(function(c){return c.key===key})[0];return f?f.it:null}
function pv(str){var mm=/^(\d+(?:\.\d+)?)?([½¼¾⅓⅔⅛])?\s?(.*)$/.exec(str||'');if(!mm||(!mm[1]&&!mm[2]))return null;var v=(mm[1]?parseFloat(mm[1]):0)+({'½':.5,'¼':.25,'¾':.75,'⅓':1/3,'⅔':2/3,'⅛':.125}[mm[2]]||0);return v?{v:v,u:mm[3].replace(/\s+/g,' ').trim()}:null}
function stockOf(key){
 if(!STOCK[key]){var it=catItem(key),sh=it?SHELF[it.aisle]:null;STOCK[key]={mult:2+hashStr(key)%3,bought:0,exp:sh===undefined||sh===null?null:sh}}
 return STOCK[key];
}
function syncExp(){EXP={};Object.keys(PAN).forEach(function(k){var s=STOCK[k];if(s&&s.exp!==null&&s.exp<=5)EXP[k]=Math.max(0,s.exp)})}
function qtyText(key){var it=catItem(key),s=stockOf(key);if(!it)return '';return pv(it.amt)?scaleQty(it.amt,s.mult):'×'+s.mult}
function boughtText(d){return d===0?'today':d===1?'yesterday':d+' days ago'}
function dateText(d){var day=16-d,mo='Nov';if(day<1){day+=31;mo='Oct'}return mo+' '+day}
function uses(key){var it0=catItem(key),base=it0?pv(it0.amt):null,s=stockOf(key),out=[];RECIPE_ORDER.forEach(function(id){RECIPES[id].ING.forEach(function(it){if(pKey(it)!==key)return;var q=pv(it.amt),cmp=base&&q&&q.u===base.u;out.push({id:id,amt:it.amt,ok:cmp?base.v*s.mult>=q.v-1e-9:null})})});return out}
function isLow(key){return uses(key).some(function(u){return u.ok===false})}
function panTile(c){
 var h=!!PAN[c.key],it=c.it,s=h?stockOf(c.key):null,ex=h&&s.exp!==null&&s.exp<=5,low=h&&isLow(c.key);
 return '<button class="ptile'+(h?' on':'')+'" data-pan="'+esc(c.key)+'" aria-haspopup="dialog" aria-label="'+esc(it.name)+(h?', '+qtyText(c.key)+' on hand, bought '+boughtText(s.bought):', not in the pantry. Add it')+'" style="'+(h?'background:'+it.color+'24':'')+'">'+icon(it.icon[0][0],30)+
  '<span class="ptxt"><b>'+esc(it.name)+'</b>'+(h?'<span><strong>'+esc(qtyText(c.key))+'</strong> · bought '+boughtText(s.bought)+'</span>'+(ex||low?'<span class="ptags">'+(ex?'<em class="exp'+(s.exp<=2?' soon':'')+'">use within '+s.exp+' day'+(s.exp===1?'':'s')+'</em>':'')+(low?'<em class="low">running low</em>':'')+'</span>':''):'<span>'+c.n+' recipe'+(c.n>1?'s':'')+'</span>')+'</span>'+
  (h?'<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#8A8A85" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex-shrink:0"><path d="M9 6l6 6-6 6"/></svg>':'<i class="pchk" aria-hidden="true"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg></i>')+'</button>';
}
function openStock(key,keepPos){
 var it=catItem(key);if(!it)return;var el=document.getElementById('sheet'),h=!!PAN[key],s=stockOf(key),U=uses(key);
 function stp(label,val,minus,plus,dis){return '<div class="prow"><span class="ptxt"><b>'+label+'</b></span><div class="stepper" style="height:44px" role="group" aria-label="'+label+'"><button style="width:36px;height:36px" data-stk="'+esc(key)+':'+minus+'" aria-label="Less"'+(dis?' disabled':'')+'>−</button><span aria-live="polite" style="min-width:86px;text-align:center"><b>'+val+'</b></span><button style="width:36px;height:36px" data-stk="'+esc(key)+':'+plus+'" aria-label="More">+</button></div></div>'}
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="'+esc(it.name)+' in your pantry">'+
  '<div class="between"><div class="row" style="gap:12px">'+icon(it.icon[0][0],40)+'<div><span class="kicker">'+esc(it.aisle)+'</span><h2 class="h2" style="font-size:22px">'+esc(it.name)+'</h2></div></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  (h?
   '<div style="display:flex;flex-direction:column">'+stp('On hand',esc(qtyText(key)),'minus','plus',s.mult<=.5)+
    '<div class="prow"><span class="ptxt"><b>Bought</b><span>'+dateText(s.bought)+' · '+boughtText(s.bought)+'</span></span><button class="chip out" style="height:36px" data-stk="'+esc(key)+':today"'+(s.bought===0?' disabled':'')+'>Bought today</button></div>'+
    (s.exp!==null?stp('Use within',s.exp+' day'+(s.exp===1?'':'s'),'expminus','expplus',s.exp<=0):'<div class="prow"><span class="ptxt"><b>Use within</b><span>Keeps. No date tracked.</span></span><button class="chip out" style="height:36px" data-stk="'+esc(key)+':expset">Set a date</button></div>')+'</div>'+
   '<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker">Enough for</span>'+U.map(function(u){return '<button class="userow" data-open="'+u.id+'"><i class="udot'+(u.ok===true?' ok':u.ok===false?' no':'')+'"></i><span style="flex:1;min-width:0"><b>'+esc(RECIPES[u.id].title)+'</b></span><span class="muted" style="font-size:13px;white-space:nowrap">needs '+esc(u.amt)+(u.ok===false?' · short':u.ok===null?' · check':'')+'</span></button>'}).join('')+'</div>'+
   '<button class="secondary" data-stk="'+esc(key)+':used">Used up</button>'
  :'<p style="margin:0;font-size:15px;line-height:1.5">Not in your pantry. Used in '+U.length+' recipe'+(U.length>1?'s':'')+': '+U.map(function(u){return esc(RECIPES[u.id].short||RECIPES[u.id].title)}).join(', ')+'.</p><button class="primary" data-stk="'+esc(key)+':add">Add to pantry, bought today</button>')+
  '</div></div>';
 if(!keepPos){var b=el.querySelector('.iconbtn');if(b)b.focus()}
}
function stockAct(arg){
 var i=arg.lastIndexOf(':'),key=arg.slice(0,i),act=arg.slice(i+1),it=catItem(key),s=stockOf(key);
 if(act==='plus')s.mult+=.5;else if(act==='minus')s.mult=Math.max(.5,s.mult-.5);
 else if(act==='today'){s.bought=0;if(s.exp!==null)s.exp=SHELF[it.aisle]||7}
 else if(act==='expplus')s.exp++;else if(act==='expminus')s.exp=Math.max(0,s.exp-1);else if(act==='expset')s.exp=7;
 else if(act==='used'){delete PAN[key];delete STOCK[key];syncHave();syncExp();closeSheet();keep(render);toast((it?it.name:'Item')+' marked used up');return}
 else if(act==='add'){PAN[key]=1;delete STOCK[key];stockOf(key);syncHave();syncExp();openStock(key,true);keepUnder();toast((it?it.name:'Item')+' added to your pantry');return}
 syncExp();openStock(key,true);keepUnder();
}
function stockDeduct(){
 if(typeof ING==='undefined'||!ING)return;var f=F();
 ING.forEach(function(it){var k=pKey(it);if(!PAN[k]||(S.haveVia&&S.haveVia[it.id]))return;var base=catItem(k),b=base?pv(base.amt):null,q=pv(it.amt),s=stockOf(k);
  if(b&&q&&b.u===q.u){s.mult=Math.round((s.mult-q.v*f/b.v)*100)/100;if(s.mult<=0.01){delete PAN[k];delete STOCK[k]}}});
 syncHave();syncExp();
}

/* ---- spice rack ---- */
var SPICE=[],SPICE0=[
 ['Salt','#E9E7E0',.8,3,['salt']],['Black pepper','#4A4744',.55,5,['pepper']],['Cajun seasoning','#C8642B',.35,7,['cajun']],
 ['Garlic powder','#E6D6A8',.6,9,['garlic powder']],['Dried basil','#6E8B4E',.15,14,['basil']],['Red pepper flakes','#B8382C',.7,6,['pepper flakes']],
 ['Paprika','#C2452D',.9,2,['paprika']],['Dried thyme','#8A9A6A',.45,16,['thyme']],['Dried parsley','#7FA35A',.3,10,['dried parsley']],
 ['Oregano','#7C8A52',.65,8,['oregano']],['Cumin','#A9793F',.5,11,['cumin']],['Chili powder','#9E3B26',0,13,['chili powder','chilli powder']],
 ['Cinnamon','#9A5B32',.75,4,['cinnamon']],['Nutmeg','#8B5E3C',.4,20,['nutmeg']],['Bay leaves','#7A8F5C',.85,7,['bay']],['Vanilla','#5E3B22',.25,5,['vanilla']]
];
function spiceUses(s){var out=[];RECIPE_ORDER.forEach(function(id){var r=RECIPES[id],hay=(r.ING.map(function(it){return it.name}).join('|')+'|'+Object.keys(r.LINE).map(function(k){var l=r.LINE[k];return (l.name||'')+' '+(l.noun||'')+' '+k}).join('|')).toLowerCase();
  if(s.keys.some(function(k){return k==='pepper'?/(black pepper|\bpepper\b(?! flakes))/.test(hay.replace(/green pepper|bell pepper|red pepper flakes|pepper flakes/g,'')):hay.indexOf(k)>-1}))out.push(id)});return out}
function spiceState(s){return s.level<=0?'out':s.level<.22?'low':s.months>=12?'old':''}
function jar(s,i){var st=spiceState(s),fill=Math.round(Math.max(0,Math.min(1,s.level))*100);
 return '<button class="jar'+(st?' '+st:'')+'" data-spice="'+i+'" aria-haspopup="dialog" aria-label="'+esc(s.name)+', '+(st==='out'?'empty':fill+' percent full')+(st==='old'?', over a year old':'')+'"><span class="jlid"></span><span class="jbody"><i style="height:'+fill+'%;background:'+s.color+'"></i></span><b>'+esc(s.name)+'</b>'+(st?'<em>'+(st==='out'?'empty':st==='low'?'low':'old')+'</em>':'')+'</button>'}
function spiceRack(){
 if(S.pan.f==='out')return '';var q=(S.pan.q||'').toLowerCase().trim(),list=SPICE.map(function(s,i){return [s,i]}).filter(function(x){return !q||x[0].name.toLowerCase().indexOf(q)>-1});
 if(!list.length)return '';var need=SPICE.filter(function(s){return spiceState(s)==='out'||spiceState(s)==='low'}).length;
 return '<section class="psecn"><div class="shead"><h2 class="h2" style="font-size:18px">Spice rack</h2><span class="muted" style="font-size:12px;font-weight:600">'+SPICE.length+' jars'+(need?' · '+need+' to restock':'')+'</span></div><div class="rack">'+list.map(function(x){return jar(x[0],x[1])}).join('')+'</div></section>';
}
function openSpice(i,keepPos){
 var s=SPICE[i],el=document.getElementById('sheet'),U=spiceUses(s),st=spiceState(s),L=[[1,'Full'],[.5,'Half'],[.15,'Low'],[0,'Empty']];
 var cur=s.level<=0?0:s.level<.22?.15:s.level<.7?.5:1,mo=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],mi=((10-s.months)%12+12)%12,yr=2026-Math.floor((s.months-10+11)/12)-(s.months>10?0:0);
 if(s.months<=10)yr=2026;else yr=2025-Math.floor((s.months-11)/12);
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="'+esc(s.name)+'">'+
  '<div class="between"><div class="row" style="gap:14px"><span class="jar big'+(st?' '+st:'')+'" aria-hidden="true"><span class="jlid"></span><span class="jbody"><i style="height:'+Math.round(s.level*100)+'%;background:'+s.color+'"></i></span></span><div><span class="kicker">Spice rack</span><h2 class="h2" style="font-size:22px">'+esc(s.name)+'</h2></div></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column;gap:8px"><span class="kicker">How much is left</span><div class="seg" role="group" aria-label="How much is left" style="grid-template-columns:repeat(4,1fr)">'+L.map(function(l){return '<button data-spset="'+i+':'+l[0]+'" aria-pressed="'+(cur===l[0])+'">'+l[1]+'</button>'}).join('')+'</div></div>'+
  '<div class="prow"><span class="ptxt"><b>Bought</b><span>'+(s.months===0?'This month':mo[mi]+' '+yr+' · '+s.months+' month'+(s.months===1?'':'s')+' ago')+'</span></span><button class="chip out" style="height:36px" data-spset="'+i+':today"'+(s.months===0&&s.level>=1?' disabled':'')+'>New jar today</button></div>'+
  (s.months>=12?'<p class="cardnote" style="margin:0">Over a year old. Ground spices fade, so you may need a little more than the card says.</p>':'')+
  '<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker">Used in</span>'+(U.length?U.map(function(id){return '<button class="userow" data-open="'+id+'"><span style="flex:1"><b>'+esc(RECIPES[id].title)+'</b></span>'+SVG.arrow+'</button>'}).join(''):'<span class="muted" style="font-size:14px">None of your nine recipes yet.</span>')+'</div>'+
  (st==='out'||st==='low'?'<button class="secondary" data-toast="'+esc(s.name)+' added to the shopping list (mocked)">Add to shopping list</button>':'')+
  '</div></div>';
 if(!keepPos){var b=el.querySelector('.iconbtn');if(b)b.focus()}
}

/* ---- pantry amounts by weight, volume or count ---- */
var UNITS={w:[['g',1,'g'],['kg',1000,'kg'],['oz',28.35,'oz'],['lb',453.6,'lb']],v:[['ml',1,'ml'],['L',1000,'L'],['cup',240,'cups'],['tbsp',15,'tbsp'],['tsp',5,'tsp']]};
var STEP={g:50,kg:.25,oz:1,lb:.25,ml:50,L:.25,cup:.25,tbsp:1,tsp:1,c:1};
function countInfo(it){var q=pv(it.amt);if(q){var mm=/^(large|medium|small|cloves?|stalks?|breasts?|cans?|sticks?|slices?|heads?|bunch(?:es)?|sprigs?|ears?|whole|fillets?|thighs?|cutlets?)\b/i.exec(q.u);if(q.u===''||mm){var lab=q.u===''?'':mm[1].toLowerCase();return {g:it.weight/q.v,label:lab,real:true}}}return {g:Math.max(50,Math.round(it.weight*2/50)*50),label:'packs',real:false}}
function stockSetup(key){var s=stockOf(key);if(s.mode)return s;var it=catItem(key),q=pv(it.amt),ci=countInfo(it),dens=it.volume?it.weight/it.volume:0,volU=q&&/^(cups?|tbsp|tsp|ml|l|fl oz)\b/i.test(q.u),us=P.units!=='metric';
 var G=it.weight*s.mult,V=it.volume*s.mult;
 if(ci.real){s.mode='c'}else if((volU&&dens>=.85&&dens<=1.15)||(G<60&&it.volume)){s.mode='v'}else s.mode='w';
 s.uw=us?(G>=454?'lb':'oz'):(G>=1000?'kg':'g');s.uv=us?(V>=60?'cup':V>=15?'tbsp':'tsp'):(V>=1000?'L':'ml');return s}
function unitOf(s){return s.mode==='c'?'c':s.mode==='v'?s.uv:s.uw}
function stockVal(key){var it=catItem(key),s=stockSetup(key),u=unitOf(s);
 if(u==='c')return it.weight*s.mult/countInfo(it).g;var def=(s.mode==='v'?UNITS.v:UNITS.w).filter(function(x){return x[0]===u})[0];return (s.mode==='v'?it.volume:it.weight)*s.mult/def[1]}
function numText(v,u){
 if(u==='g'||u==='ml')return String(v>=100?Math.round(v/5)*5:Math.round(v));
 if(u==='kg'||u==='L')return String(Math.round(v*100)/100);
 if(u==='oz')return String(Math.round(v*10)/10);
 var r=Math.round(v*4)/4,w=Math.floor(r),f=r-w,fc={0:'',.25:'¼',.5:'½',.75:'¾'}[f];return (w||!fc?w:'')+fc||'0'}
function unitLabel(key,s,v){var u=unitOf(s);if(u!=='c')return (s.mode==='v'?UNITS.v:UNITS.w).filter(function(x){return x[0]===u})[0][2].replace(/^cups$/,v<=1?'cup':'cups');var ci=countInfo(catItem(key));return ci.label==='packs'?(v<=1?'pack':'packs'):ci.label}
function qtyText(key){var it=catItem(key);if(!it)return '';var s=stockSetup(key),v=stockVal(key),u=unitOf(s),lab=unitLabel(key,s,v);return numText(v,u)+(lab?' '+lab:'')}
function stockSetVal(key,v){var it=catItem(key),s=stockSetup(key),u=unitOf(s);if(!(v>0))return;
 if(u==='c')s.mult=v*countInfo(it).g/it.weight;else{var def=(s.mode==='v'?UNITS.v:UNITS.w).filter(function(x){return x[0]===u})[0];s.mult=v*def[1]/(s.mode==='v'?it.volume:it.weight)}}
function uses(key){var base=catItem(key),s=stockOf(key),G=base?base.weight*s.mult:0,out=[];RECIPE_ORDER.forEach(function(id){RECIPES[id].ING.forEach(function(it){if(pKey(it)!==key)return;out.push({id:id,amt:it.amt,ok:G>=it.weight-.5})})});return out}
function parseQty(t){t=String(t).replace(',', '.').trim();var fr={'¼':.25,'½':.5,'¾':.75,'⅓':1/3,'⅔':2/3,'⅛':.125},mm=/^(\d+(?:\.\d+)?)?\s*(?:(\d+)\s*\/\s*(\d+)|([¼½¾⅓⅔⅛]))?/.exec(t);if(!mm)return NaN;var v=(mm[1]?parseFloat(mm[1]):0)+(mm[2]&&+mm[3]?mm[2]/mm[3]:0)+(mm[4]?fr[mm[4]]:0);return v||NaN}
function openStock(key,keepPos){
 var it=catItem(key);if(!it)return;var el=document.getElementById('sheet'),h=!!PAN[key],s=stockSetup(key),U=uses(key),ci=countInfo(it),u=unitOf(s),v=stockVal(key);
 function stp(label,val,minus,plus,dis){return '<div class="prow"><span class="ptxt"><b>'+label+'</b></span><div class="stepper" style="height:44px" role="group" aria-label="'+label+'"><button style="width:36px;height:36px" data-stk="'+esc(key)+':'+minus+'" aria-label="Less"'+(dis?' disabled':'')+'>−</button><span aria-live="polite" style="min-width:86px;text-align:center"><b>'+val+'</b></span><button style="width:36px;height:36px" data-stk="'+esc(key)+':'+plus+'" aria-label="More">+</button></div></div>'}
 var modes=[['w','Weight'],['v','Volume'],['c',ci.real?'Count':'Packs']],ul=s.mode==='c'?[]:(s.mode==='v'?UNITS.v:UNITS.w);
 var amount='<div class="amt"><div class="between" style="gap:10px"><span class="kicker" style="color:#111">On hand</span><span class="muted" style="font-size:12px">measure by</span></div>'+
  '<div class="seg" role="group" aria-label="Measure by" style="grid-template-columns:repeat(3,1fr)">'+modes.map(function(md){return '<button data-stk="'+esc(key)+':mode-'+md[0]+'" aria-pressed="'+(s.mode===md[0])+'">'+md[1]+'</button>'}).join('')+'</div>'+
  '<div class="amtrow"><button class="amtbtn" data-stk="'+esc(key)+':minus" aria-label="Less">−</button><label class="amtfield"><span class="sr">Amount on hand</span><input id="stkq" data-key="'+esc(key)+'" type="text" inputmode="decimal" autocomplete="off" value="'+esc(numText(v,u))+'"><span class="amtunit">'+esc(unitLabel(key,s,v)||(ci.real?'':'packs'))+'</span></label><button class="amtbtn" data-stk="'+esc(key)+':plus" aria-label="More">+</button></div>'+
  (ul.length?'<div class="unitrow" role="group" aria-label="Unit">'+ul.map(function(x){return '<button class="uchipb" data-stk="'+esc(key)+':unit-'+x[0]+'" aria-pressed="'+(u===x[0])+'">'+x[2]+'</button>'}).join('')+'</div>':'<span class="muted" style="font-size:12px">'+(ci.real?'About '+Math.round(ci.g)+' g each, from the recipe.':'A pack is assumed to be about '+ci.g+' g.')+'</span>')+'</div>';
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="'+esc(it.name)+' in your pantry">'+
  '<div class="between"><div class="row" style="gap:12px">'+icon(it.icon[0][0],40)+'<div><span class="kicker">'+esc(it.aisle)+'</span><h2 class="h2" style="font-size:22px">'+esc(it.name)+'</h2></div></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  (h?amount+
   '<div style="display:flex;flex-direction:column">'+
    '<div class="prow"><span class="ptxt"><b>Bought</b><span>'+dateText(s.bought)+' · '+boughtText(s.bought)+'</span></span><button class="chip out" style="height:36px" data-stk="'+esc(key)+':today"'+(s.bought===0?' disabled':'')+'>Bought today</button></div>'+
    (s.exp!==null?stp('Use within',s.exp+' day'+(s.exp===1?'':'s'),'expminus','expplus',s.exp<=0):'<div class="prow"><span class="ptxt"><b>Use within</b><span>Keeps. No date tracked.</span></span><button class="chip out" style="height:36px" data-stk="'+esc(key)+':expset">Set a date</button></div>')+'</div>'+
   '<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker">Enough for</span>'+U.map(function(x){return '<button class="userow" data-open="'+x.id+'"><i class="udot'+(x.ok?' ok':' no')+'"></i><span style="flex:1;min-width:0"><b>'+esc(RECIPES[x.id].title)+'</b></span><span class="muted" style="font-size:13px;white-space:nowrap">needs '+esc(x.amt)+(x.ok?'':' · short')+'</span></button>'}).join('')+'</div>'+
   '<button class="secondary" data-stk="'+esc(key)+':used">Used up</button>'
  :'<p style="margin:0;font-size:15px;line-height:1.5">Not in your pantry. Used in '+U.length+' recipe'+(U.length>1?'s':'')+': '+U.map(function(x){return esc(RECIPES[x.id].short||RECIPES[x.id].title)}).join(', ')+'.</p><button class="primary" data-stk="'+esc(key)+':add">Add to pantry, bought today</button>')+
  '</div></div>';
 if(!keepPos){var b=el.querySelector('.iconbtn');if(b)b.focus()}
}
function stockAct(arg){
 var i=arg.lastIndexOf(':'),key=arg.slice(0,i),act=arg.slice(i+1),it=catItem(key),s=stockSetup(key),u=unitOf(s);
 if(act==='plus'||act==='minus'){var st=STEP[u]||1,v=stockVal(key);if(u==='g'||u==='ml')st=v<100?10:50;var nv=Math.round((v+(act==='plus'?st:-st))/st)*st;if(nv<=0)nv=Math.min(v,st)/2;stockSetVal(key,nv)}
 else if(act.indexOf('mode-')===0)s.mode=act.slice(5);
 else if(act.indexOf('unit-')===0){if(s.mode==='v')s.uv=act.slice(5);else s.uw=act.slice(5)}
 else if(act==='today'){s.bought=0;if(s.exp!==null)s.exp=SHELF[it.aisle]||7}
 else if(act==='expplus')s.exp++;else if(act==='expminus')s.exp=Math.max(0,s.exp-1);else if(act==='expset')s.exp=7;
 else if(act==='used'){delete PAN[key];delete STOCK[key];syncHave();syncExp();closeSheet();keep(render);toast((it?it.name:'Item')+' marked used up');return}
 else if(act==='add'){PAN[key]=1;delete STOCK[key];stockSetup(key);syncHave();syncExp();openStock(key,true);keepUnder();toast((it?it.name:'Item')+' added to your pantry');return}
 syncExp();openStock(key,true);keepUnder();
}
function stockDeduct(){
 if(typeof ING==='undefined'||!ING)return;var f=F();
 ING.forEach(function(it){var k=pKey(it);if(!PAN[k]||(S.haveVia&&S.haveVia[it.id]))return;var base=catItem(k),s=stockOf(k);if(!base||!base.weight)return;
  s.mult=Math.round((s.mult-it.weight*f/base.weight)*1000)/1000;if(s.mult<=0.01){delete PAN[k];delete STOCK[k]}});
 syncHave();syncExp();
}
document.addEventListener('change',function(e){var t=e.target;if(t&&t.id==='stkq'){var v=parseQty(t.value),key=t.dataset.key;if(v>0){stockSetVal(key,v)}syncExp();openStock(key,true);keepUnder()}});
document.addEventListener('keydown',function(e){if(e.target&&e.target.id==='stkq'&&e.key==='Enter'){e.preventDefault();e.target.blur()}});

/* ---- sharing: one family library, separate kitchens (plan, shopping, pantry) ---- */
var PEOPLE={M:'Moussa',A:'Ashley',N:'Nicole',D:'Dan',Y:'Maya',C:'Chris'},LIBM=['M','A','N','D','Y','C'],KITCHENS=[],KCUR=0,PLANBY={},CARTBY={};
function kitchenInit(){KITCHENS=[{name:'Moussa & Ashley',members:['M','A'],st:null},{name:'Cottage weekend',members:['M','A','N','D'],st:null}];KCUR=0;PLANBY={'2:thai':'A','5:cookies':'A','5:potpie':'A'};CARTBY={}}
function avStack(list,max){var show=list.slice(0,max||3),more=list.length-show.length;return '<span class="avs" aria-hidden="true">'+show.map(function(k){return '<i class="av'+(k==='M'?' me':'')+'">'+k+'</i>'}).join('')+(more>0?'<i class="av more">+'+more+'</i>':'')+'</span>'}
function kitchenBar(){var K=KITCHENS[KCUR],others=K.members.filter(function(x){return x!=='M'});
 return '<button class="kbar" data-act="kitchens" aria-haspopup="dialog" aria-label="Kitchen: '+esc(K.name)+'. Change kitchen">'+avStack(K.members,4)+'<span class="ktxt"><b>'+esc(K.name)+'</b><small>'+(others.length?'Shared with '+others.map(function(k){return PEOPLE[k]}).join(', ')+' · synced just now':'Only you')+'</small></span><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button>'}
function switchKitchen(i){
 if(i===KCUR)return;KITCHENS[KCUR].st={PLAN:PLAN,PAN:PAN,STOCK:STOCK,CART:CART,SPICE:SPICE,PLANBY:PLANBY,CARTBY:CARTBY};
 KCUR=i;var st=KITCHENS[i].st;
 if(st){PLAN=st.PLAN;PAN=st.PAN;STOCK=st.STOCK;CART=st.CART;SPICE=st.SPICE;PLANBY=st.PLANBY;CARTBY=st.CARTBY}
 else{PLAN=KITCHENS[i].name==='Cottage weekend'?{5:['pancakes'],6:['shepherd','cookies']}:{};PLANBY={'5:pancakes':'N','6:cookies':'D'};CART={};CARTBY={};STOCK={};
  PAN={};if(KITCHENS[i].name==='Cottage weekend')Object.keys(PAN0).forEach(function(k){if(hashStr(k)%2===0)PAN[k]=1});
  SPICE=SPICE0.slice(0,KITCHENS[i].name==='Cottage weekend'?6:0).map(function(s,j){return {name:s[0],color:s[1],level:[.9,.4,.1,.6,0,.7][j],months:s[3],keys:s[4]}})}
 syncHave();syncExp();
}
function liveShop(needs){
 var K=KITCHENS[KCUR],others=K.members.filter(function(x){return x!=='M'});if(K.sim||!others.length||needs.length<2)return;K.sim=true;var kc=KCUR;
 setTimeout(function(){if(S.screen!=='shopall'||KCUR!==kc)return;var nx=planNeeds().filter(function(x){return !CART[pKey(x.it)]})[1];if(!nx)return;var k=pKey(nx.it);CART[k]=1;CARTBY[k]=others[0];keep(render);toast(PEOPLE[others[0]]+' just ticked '+nx.it.name)},3500);
}
function openKitchens(){
 var el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Your kitchens"><div class="between"><div><span class="kicker">Plan, shopping and pantry</span><h2 class="h2" style="font-size:20px">Your kitchens</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">A kitchen is the group you plan and shop with. Each has its own meal plan, shopping list and pantry. Recipes are shared by the whole family and are not part of a kitchen.</p>'+
  '<div style="display:flex;flex-direction:column;gap:8px">'+KITCHENS.map(function(K,i){var on=i===KCUR;return '<div class="krow'+(on?' on':'')+'"><button class="kpick" data-kpick="'+i+'" aria-pressed="'+on+'">'+avStack(K.members,4)+'<span class="ktxt"><b>'+esc(K.name)+'</b><small>'+K.members.map(function(k){return k==='M'?'You':PEOPLE[k]}).join(', ')+'</small></span>'+(on?'<span class="badge solid" style="height:22px;font-size:11px">Current</span>':'')+'</button><button class="chip out" style="height:36px;padding:0 12px" data-kman="'+i+'">Members</button></div>'}).join('')+'</div>'+
  '<button class="secondary" data-act="newkitchen">+ New kitchen</button>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">Other family members can have kitchens you are not in. You will not see those, and they will not see yours.</span></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}
function openKitchen(i,keepPos){
 var K=KITCHENS[i],el=document.getElementById('sheet'),out=LIBM.filter(function(k){return K.members.indexOf(k)<0});
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="'+esc(K.name)+' members"><div class="between"><div><span class="kicker">Kitchen</span><h2 class="h2" style="font-size:20px">'+esc(K.name)+'</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker">In this kitchen</span>'+K.members.map(function(k){return '<div class="mrow"><i class="av'+(k==='M'?' me':'')+'">'+k+'</i><span style="flex:1"><b>'+(k==='M'?'You':PEOPLE[k])+'</b><small>Sees and edits the plan, shopping list and pantry</small></span>'+(k==='M'?'':'<button class="chip out" style="height:34px;padding:0 12px" data-kmem="'+i+':'+k+'" aria-label="Remove '+PEOPLE[k]+'">Remove</button>')+'</div>'}).join('')+'</div>'+
  (out.length?'<div style="display:flex;flex-direction:column;gap:8px"><span class="kicker">Add from the family</span><div style="display:flex;gap:8px;flex-wrap:wrap">'+out.map(function(k){return '<button class="chip out" style="height:40px;padding:0 12px 0 6px;gap:8px" data-kmem="'+i+':'+k+'"><i class="av">'+k+'</i>'+PEOPLE[k]+'</button>'}).join('')+'</div></div>':'')+
  '<button class="secondary" data-act="kitchens">All kitchens</button>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">Only people listed here can see this kitchen. Being in the family library does not give anyone access to it.</span></div></div>';
 if(!keepPos){var b=el.querySelector('.iconbtn');if(b)b.focus()}
}
function openLibraryMembers(){
 var el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Family library"><div class="between"><div><span class="kicker">Recipes</span><h2 class="h2" style="font-size:20px">Family library</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">Everyone here sees and can edit the same recipes, cards and cooking notes. Meal plans, shopping lists and pantries are separate and stay inside each kitchen.</p>'+
  '<div style="display:flex;flex-direction:column;gap:6px">'+LIBM.map(function(k){var shared=KITCHENS.filter(function(K){return K.members.indexOf(k)>-1&&K.members.indexOf('M')>-1}).map(function(K){return K.name});
   return '<div class="mrow"><i class="av'+(k==='M'?' me':'')+'">'+k+'</i><span style="flex:1"><b>'+(k==='M'?'You':PEOPLE[k])+(k==='A'?' <em class="role">organiser</em>':'')+'</b><small>'+(k==='M'?'In '+shared.length+' kitchen'+(shared.length===1?'':'s'):shared.length?'Shares '+shared.join(' and ')+' with you':'No kitchen in common with you')+'</small></span></div>'}).join('')+'</div>'+
  '<button class="secondary" data-toast="Invites are mocked in this prototype. In the app this sends an iCloud share link.">+ Invite someone</button></div></div>';
 var b=el.querySelector('.iconbtn');if(b)b.focus();
}

/* ---- settings, built out ---- */
function blockedReason(l){
 var nm=(l.name||'').toLowerCase();
 for(var i=0;i<P.never.length;i++){var n=P.never[i],k=n[0].toLowerCase(),al=n[1]==='allergy';
  if(l.allergen&&l.allergen.toLowerCase()===k)return 'Contains '+k;
  if(l.dislike&&l.dislike.toLowerCase()===k)return (al?'Contains ':'You dislike ')+k;
  if(nm.indexOf(k.replace(/s$/,''))>-1)return (al?'Contains ':'You dislike ')+k}
 return '';
}
function perServing(id){var r=RECIPES[id],c=0,p=0;r.ING.forEach(function(it){c+=it.calories||0;p+=(it.macro&&it.macro[0])||0});return {kcal:c/r.base,protein:p/r.base}}
function subHead(kicker,title){return '<div class="between"><div class="row" style="gap:12px"><button class="iconbtn" data-act="profile" aria-label="Back to settings">'+SVG.back+'</button><div><span class="kicker">'+kicker+'</span><h2 class="h2" style="font-size:20px">'+title+'</h2></div></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'}
function subWrap(label,inner,keepPos){var el=document.getElementById('sheet'),old=el.querySelector('.sheet'),y=old?old.scrollTop:0;el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="'+label+'">'+inner+'</div></div>';if(keepPos)el.querySelector('.sheet').scrollTop=y;else{var b=el.querySelector('.iconbtn');if(b)b.focus()}}
function openNeverAdd(keepPos){
 var C=['Peanuts','Tree nuts','Shellfish','Fish','Dairy','Eggs','Gluten','Soy','Sesame','Mushrooms','Cilantro','Olives','Shrimp','Pork'],have={};P.never.forEach(function(n){have[n[0]]=n[1]});
 subWrap('Add to never suggested',subHead('Never suggested','Add something to avoid')+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">Dislikes are left out of swaps and picks. Allergies are also flagged wherever they appear.</p>'+
  '<div style="display:flex;flex-direction:column">'+C.map(function(c){return '<div class="mrow"><span style="flex:1"><b>'+c+'</b>'+(have[c]?'<small>Added as '+have[c]+'</small>':'')+'</span>'+(have[c]?'<span class="badge solid" style="height:24px;font-size:11px">Added</span>':'<button class="chip out" style="height:36px;padding:0 12px" data-never="'+c+':dislike">Dislike</button><button class="chip out" style="height:36px;padding:0 12px;border-width:2px" data-never="'+c+':allergy">Allergy</button>')+'</div>'}).join('')+'</div>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">In the app you could also type any ingredient. This list is a sample.</span>',keepPos);
}
function openGoals(keepPos){
 var id=(PLAN[0]&&PLAN[0][0])||'cajun',r=RECIPES[id],ps=perServing(id),kp=Math.round(ps.kcal/P.kcal*100),pp=Math.round(ps.protein/P.protein*100);
 function stp(label,key,step,min,unit){return '<div class="prow"><span class="ptxt"><b>'+label+'</b><span>per day</span></span><div class="stepper" style="height:44px" role="group" aria-label="'+label+'"><button style="width:36px;height:36px" data-pstep="'+key+':-'+step+':'+min+'" aria-label="Less"'+(P[key]<=min?' disabled':'')+'>−</button><span aria-live="polite" style="min-width:92px;text-align:center"><b>'+P[key].toLocaleString('en-US')+'</b> '+unit+'</span><button style="width:36px;height:36px" data-pstep="'+key+':'+step+':'+min+'" aria-label="More">+</button></div></div>'}
 function bar(label,pct,txt){return '<div style="display:flex;flex-direction:column;gap:6px"><div class="between" style="font-size:13px"><b>'+label+'</b><span class="muted">'+txt+'</span></div><div class="prog"><i style="width:'+Math.min(100,pct)+'%'+(pct>100?';background:var(--bad)':'')+'"></i></div></div>'}
 subWrap('Nutrition goals',subHead('Settings','Nutrition goals')+
  '<div style="display:flex;flex-direction:column">'+stp('Calories','kcal',50,1200,'kcal')+stp('Protein','protein',5,30,'g')+'</div>'+
  '<div class="amt" style="gap:12px"><span class="kicker" style="color:#111">Tonight against your day</span><b style="font-family:var(--disp);font-size:17px">'+esc(r.title)+'</b>'+
   bar('Calories',kp,'~'+(Math.round(ps.kcal/10)*10).toLocaleString('en-US')+' of '+P.kcal.toLocaleString('en-US')+' kcal · '+kp+'%')+
   bar('Protein',pp,'~'+Math.round(ps.protein)+' of '+P.protein+' g · '+pp+'%')+
   '<span class="muted" style="font-size:12px;line-height:1.4">One serving, from estimated nutrition. Swaps change these numbers.</span></div>'+
  '<span class="muted" style="font-size:12px;line-height:1.45">The goal direction (lighter, protein, gain) is set on the settings screen and decides which swaps count as better. These daily targets are shown here only; they are not yet on the recipe or plan screens.</span>',keepPos);
}
function openAisles(keepPos){
 subWrap('Store order',subHead('Shopping','Your store’s order')+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">Shopping lists follow this order, so put the aisles the way you walk your store.</p>'+
  '<div style="display:flex;flex-direction:column">'+AISLES.map(function(a,i){return '<div class="mrow"><span class="pnum" style="width:26px;height:26px;font-size:12px">'+(i+1)+'</span><span style="flex:1"><b>'+a+'</b></span><button class="iconbtn" style="width:40px;height:40px" data-aisle="'+i+':-1" aria-label="Move '+a+' up"'+(i===0?' disabled':'')+'><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></svg></button><button class="iconbtn" style="width:40px;height:40px" data-aisle="'+i+':1" aria-label="Move '+a+' down"'+(i===AISLES.length-1?' disabled':'')+'><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></button></div>'}).join('')+'</div>',keepPos);
}
function openAbout(){
 subWrap('About',subHead('Settings','About')+
  '<div style="display:flex;flex-direction:column"><div class="mrow"><span style="flex:1"><b>Recipes, Mark 2</b><small>Design prototype, not the shipping app</small></span></div><div class="mrow"><span style="flex:1"><b>Recipes</b><small>'+RECIPE_ORDER.length+' built from Ashley’s cards, 32 still on paper</small></span></div><div class="mrow"><span style="flex:1"><b>Nutrition, cost and timings</b><small>Estimates. Marked with “~” throughout.</small></span></div><div class="mrow"><span style="flex:1"><b>Ingredient graphics</b><small>Set 2, drawn for this prototype</small></span></div></div>'+
  '<button class="secondary" data-toast="Feedback is collected through the comments on this prototype">Send feedback</button>');
}
function logView(){
 var pad=isPad(),all=[],mo={Jan:1,Feb:2,Mar:3,Apr:4,May:5,Jun:6,Jul:7,Aug:8,Sep:9,Oct:10,Nov:11,Dec:12};
 Object.keys(LOG).forEach(function(id){LOG[id].forEach(function(c){var d=(c.date||'').split(' ');all.push({id:id,c:c,k:(mo[d[0]]||12)*100+(+d[1]||31)})})});
 all.sort(function(x,y){return y.k-x.k});
 return '<div class="pad"><div class="row" style="gap:12px;align-items:flex-start"><button class="iconbtn" data-back="home" aria-label="Back">'+SVG.back+'</button><div><h1 class="t" style="font-size:'+(pad?36:26)+'px">Cooking log</h1><p class="muted" style="margin:2px 0 0;font-size:'+(pad?14:13)+'px">'+all.length+' cooks, newest first</p></div></div>'+
  '<div class="qgrid">'+all.map(function(x){var c=x.c,r=RECIPES[x.id],sw=c.swapList||[];return '<button class="card ckentry" style="text-align:left;cursor:pointer;background:#fff" data-open="'+x.id+'"><div class="between" style="gap:12px"><div style="min-width:0"><b style="font-family:var(--disp);font-size:17px">'+esc(r.title)+'</b><div class="muted" style="font-size:13px">'+esc(c.date||'Today')+' · '+esc(c.who||'You')+'</div></div><span style="text-align:right;white-space:nowrap"><b style="letter-spacing:1px">'+starsHtml(c.rating)+'</b>'+(c.mins?'<div class="muted" style="font-size:12px">'+c.mins+' min</div>':'')+'</span></div>'+(sw.length?'<div style="display:flex;flex-wrap:wrap;gap:6px">'+sw.map(function(s){return '<span class="badge" style="height:24px;font-size:12px">'+esc(s)+'</span>'}).join('')+'</div>':'')+(c.note?'<p style="margin:0;font-size:14px;line-height:1.45;color:#2B2B28">“'+esc(c.note)+'”</p>':'')+'</button>'}).join('')+'</div></div>';
}
function profileSheet(){
 var cooks=0,stars=0,rated=0,mins=0;Object.keys(LOG).forEach(function(k){LOG[k].forEach(function(c){cooks++;mins+=c.mins||0;if(c.rating){stars+=c.rating;rated++}})});
 var saved=Object.keys(S.saved).filter(function(k){return S.saved[k]}).length,K=KITCHENS[KCUR],others=K.members.filter(function(x){return x!=='M'}).map(function(k){return PEOPLE[k]});
 function seg(key,opts){return '<div class="seg" style="grid-template-columns:repeat('+opts.length+',1fr);min-width:150px">'+opts.map(function(o){return '<button aria-pressed="'+(P[key]===o[0])+'" data-pset="'+key+':'+o[0]+'">'+o[1]+'</button>'}).join('')+'</div>'}
 function row(t,s,ctl){return '<div class="prow"><span class="ptxt"><b>'+t+'</b><span>'+s+'</span></span>'+ctl+'</div>'}
 function tog(key,t,s){var on=!!P[key];return '<button class="tog" role="switch" aria-checked="'+on+'" data-ptog="'+key+'"><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>'+t+'</b><span>'+s+'</span></span><i class="sw'+(on?' on':'')+'"><i></i></i></button>'}
 function nav(t,s,attr,right){return '<button class="plink" '+attr+'><span class="ptxt"><b>'+t+'</b><span>'+s+'</span></span>'+(right||SVG.arrow)+'</button>'}
 function sec(title,body,flat){return '<section class="psec"'+(flat?' style="gap:0"':'')+'><span class="kicker"'+(flat?' style="margin-bottom:6px"':'')+'>'+title+'</span>'+body+'</section>'}
 var col1=
  sec('Never suggested','<p class="muted" style="margin:0;font-size:13px;line-height:1.4">Swaps and recipe picks skip these. Allergies are also flagged wherever they appear.</p>'+
   '<div style="display:flex;gap:8px;flex-wrap:wrap">'+P.never.map(function(n,i){return '<span class="chip out pchip"'+(n[1]==='allergy'?' style="border-width:1.5px"':'')+'>'+(n[1]==='allergy'?SVG.warn('#111'):'')+esc(n[0])+' <span class="muted" style="font-weight:500">'+n[1]+'</span><button data-pdel="'+i+'" aria-label="Remove '+esc(n[0])+'">'+SVG.close+'</button></span>'}).join('')+
   '<button class="chip out" style="border-style:dashed" data-act="neveradd">+ Add</button></div>')+
  sec('Nutrition',nav('Daily goals',P.kcal.toLocaleString('en-US')+' kcal · '+P.protein+' g protein','data-act="goals"')+
   row('Goal direction','Decides what counts as a better swap',seg('goal',[['lighter','Lighter'],['protein','Protein'],['gain','Gain']])),true)+
  sec('Measurements',row('Units','Amounts in recipes and the pantry',seg('units',[['us','US'],['metric','Metric']]))+
   row('Temperature','Oven and safe temperatures',seg('temp',[['F','°F'],['C','°C']]))+
   row('Default servings','Recipes open scaled to this','<div class="stepper" style="height:44px" role="group" aria-label="Default servings"><button style="width:36px;height:36px" data-pserv="-1" aria-label="Fewer"'+(P.serv<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+P.serv+'</b></span><button style="width:36px;height:36px" data-pserv="1" aria-label="More"'+(P.serv>=12?' disabled':'')+'>+</button></div>')+
   row('Week starts','In the plan',seg('week',[['mon','Monday'],['sun','Sunday']])))+
  sec('Appearance','<div style="display:flex;flex-direction:column">'+tog('dark','Dark mode','A dark kitchen: black counters, the same ingredient colours')+tog('hc','Stronger ingredient highlights','Outlined ingredients in step text instead of pale tints')+tog('big','Larger text','Bigger type across the app')+'</div>')+
  sec('While cooking','<div style="display:flex;flex-direction:column">'+tog('awake','Keep screen awake','No dimming while a recipe is open')+tog('hf','Hands-free cooking','Reads each step aloud and moves on when its timer ends')+tog('sound','Timer sounds','A chime when a timer ends')+tog('photo','Ask for a plate photo','Prompt at the end of every cook')+'</div>');
 var col2=
  sec('Sharing',nav('Family library',LIBM.length+' people share these recipes','data-act="librarymembers"',avStack(LIBM,4))+
   nav('Your kitchens',KITCHENS.length+' · currently '+esc(K.name),'data-act="kitchens"',avStack(K.members,4))+
   '<div class="prow"><span class="ptxt"><b>iCloud sync</b><span>Synced just now · library and '+KITCHENS.length+' kitchens</span></span><span class="badge" style="height:24px;font-size:11px">On</span></div>',true)+
  sec('Notifications','<div style="display:flex;flex-direction:column">'+tog('nTimer','Timers','When a cooking timer ends')+tog('nShop','Shopping together','When someone in your kitchen ticks or adds an item')+tog('nPlan','Tomorrow’s plan','An evening reminder of what is planned and what to thaw')+tog('nExp','Use it up','When something in the pantry is close to its date')+tog('nCook','Cooking streak','A nudge if you have not cooked in a while')+'</div>')+
  sec('Shopping',nav('Your store’s order',AISLES.slice(0,3).join(', ')+'…','data-act="aisles"')+row('Currency','For cost estimates',seg('currency',[['CAD','CAD'],['USD','USD']])),true)+
  sec('Recipes and history',nav('Cooking log',cooks+' cooks across '+Object.keys(LOG).filter(function(k){return LOG[k].length}).length+' recipes','data-go="log"')+
   nav('Questions for Ashley',openQCount()+' open across her cards','data-go="questions"')+nav('Import a recipe','Photo, website, pasted text or a file','data-act="importcard"'),true)+
  sec('Privacy and data',row('Recipe help','Where suggestions and card reading run',seg('ai',[['device','On device'],['hybrid','Allow cloud']]))+
   nav('Export my recipes','A file you can keep or move','data-toast="Export is not built in this prototype"')+nav('About','Version, data sources, feedback','data-act="about"'),true);
 return '<div class="sheet profsheet" role="dialog" aria-modal="true" aria-label="Settings">'+
  '<div class="row" style="gap:12px"><button class="iconbtn" data-closesheet="1" aria-label="Back">'+SVG.back+'</button><span class="pava">M</span><div><h2 class="h2" style="font-size:26px">Moussa</h2><p class="muted" style="margin:2px 0 0;font-size:13px">'+(others.length?'Cooking with '+others.join(' and ')+' in '+esc(K.name):esc(K.name))+'</p></div></div>'+
  '<div class="stats" style="grid-template-columns:repeat(4,1fr)"><div><b>'+cooks+'</b><span>cooks</span></div><div><b>'+(rated?(stars/rated).toFixed(1):'–')+'</b><span>avg rating</span></div><div><b>'+(cooks?Math.round(mins/cooks):0)+' min</b><span>avg cook</span></div><div><b>'+saved+'</b><span>saved</span></div></div>'+
  '<div class="pgrid"><div class="pcol">'+col1+'</div><div class="pcol">'+col2+'</div></div>'+
  '<p class="muted" style="margin:0;font-size:12px;line-height:1.45">Prototype: units and temperature, the never-suggested list, goal direction and daily goals, dark mode, stronger highlights, larger text, hands-free, store order and sharing all take effect. Notifications, week start, currency, recipe help, sync and export only remember their state.</p>'+
 '</div>';
}

/* ---- share sheet, completed ---- */
function shareInit(){var s=S.share;if(!s.to)s.to={};if(s.msg==null)s.msg='';return s}
function shareServ(){return S.share.serv||S.servings}
function shareTo(){var s=shareInit();return LIBM.filter(function(k){return k!=='M'&&s.to[k]})}
function nameList(a){return a.length<2?a.join(''):a.slice(0,-1).join(', ')+' and '+a[a.length-1]}
function shareSwaps(){return ING.filter(function(it){return S.swaps[it.id]})}
function shareLink(){return 'recipes.example/r/'+R.id+(S.share.swaps&&shareSwaps().length?'?v=mine':'')}
function atServ(fn){var keepS=S.servings;S.servings=shareServ();try{return fn()}finally{S.servings=keepS}}
function shareIngs(){var s=S.share,f=shareServ()/R.base;return ING.map(function(it){var sw=s.swaps&&S.swaps[it.id];return {q:scaleQty(it.amt,f),n:sw?shownName(it):it.name,sw:!!sw}})}
function shareSteps(){return atServ(function(){var keepSw=S.swaps;if(!S.share.swaps)S.swaps={};try{return STEPS.map(function(st){var d=document.createElement('div');d.innerHTML=stepLines(st).join(' ');return {t:stepTitle(st),x:d.textContent.replace(/Change units/g,'').replace(/\s+/g,' ').trim()}})}finally{S.swaps=keepSw}})}
function shareText(){
 var s=S.share,log=LOG[R.id]||[],last=log[log.length-1],L=[R.title.toUpperCase(),R.meta.split(' · ')[0]+' · '+shareServ()+' servings','','INGREDIENTS'];
 shareIngs().forEach(function(x){L.push('- '+x.q+' '+x.n.toLowerCase()+(x.sw?' (our swap)':''))});
 L.push('','METHOD');shareSteps().forEach(function(x,i){L.push((i+1)+'. '+x.t+'. '+x.x)});
 if(s.notes&&last)L.push('','OUR NOTES',log.length+' cook'+(log.length>1?'s':'')+(last.rating?', last rated '+last.rating+'/5':'')+(last.note?'. "'+last.note+'"':''));
 L.push('','From Ashley’s recipe cards');return L.join('\n');
}
function sharePreview(){
 var s=S.share,sw=shareSwaps(),log=LOG[R.id]||[],last=log[log.length-1],serv=shareServ(),ings=shareIngs(),steps;
 var swTxt=sw.map(function(it){return shownName(it).toLowerCase()+' for '+it.name.toLowerCase()}).join(', ');
 var facts=R.meta.split(' · ')[0]+' · '+serv+' servings · '+ING.length+' ingredients · '+STEPS.length+' steps';
 var notes=s.notes?'<span class="cardnote" style="font-size:12px;padding:6px 9px">'+(log.length?log.length+' cook'+(log.length>1?'s':'')+' logged'+(last.note?' · “'+esc(last.note)+'”':''):'No cooks logged yet')+'</span>':'';
 if(s.format==='link')return '<div class="shprev"><div class="shbubble">'+fpBar(R,40)+'<div style="padding:10px 12px 12px;display:flex;flex-direction:column;gap:3px"><b style="font-family:var(--disp);font-size:16px;line-height:1.15">'+esc(R.title)+'</b><span class="muted" style="font-size:12px">'+esc(facts)+'</span><span style="font-size:12px;font-weight:700;margin-top:2px">'+esc(shareLink())+'</span></div></div>'+
  '<span class="muted" style="font-size:12px;line-height:1.4;text-align:center">How it looks in Messages. Opens in the app, or as a web page for people without it.</span></div>';
 if(s.format==='text')return '<div class="shprev"><pre class="shtext" tabindex="0" aria-label="Text preview">'+esc(shareText())+'</pre></div>';
 if(s.format==='pdf'){steps=shareSteps();return '<div class="shprev"><div class="shpage" aria-label="PDF preview, one page">'+fpBar(R,10)+'<b class="shpt">'+esc(R.title)+'</b><span class="shpm">'+esc(facts)+'</span><div class="shpc"><div><i>Ingredients</i>'+ings.map(function(x){return '<span>'+esc(x.q)+' '+esc(x.n.toLowerCase())+(x.sw?' *':'')+'</span>'}).join('')+(sw.length&&s.swaps?'<span style="margin-top:3px">* our swap</span>':'')+'</div><div><i>Method</i>'+steps.map(function(x,i){return '<span>'+(i+1)+'. '+esc(x.t)+'. '+esc(x.x)+'</span>'}).join('')+'</div></div>'+(s.card?'<span class="shpm" style="margin-top:auto">Page 2: the original card</span>':'')+'</div>'+
  '<span class="muted" style="font-size:12px">'+(s.card?'2 pages':'1 page')+' · Letter · prints in black and white</span></div>'}
 return '<div class="shprev"><div class="shcard">'+fpBar(R,48)+
  '<div style="padding:12px 14px 14px;display:flex;flex-direction:column;gap:6px"><span class="kicker" style="font-size:10px">From Ashley’s recipe cards</span><b style="font-family:var(--disp);font-size:19px;line-height:1.15">'+esc(R.title)+'</b>'+
  '<span style="font-size:12px;font-weight:700">'+esc(facts)+'</span>'+
  '<span class="muted" style="font-size:12px;line-height:1.4">'+esc(ings.slice(0,5).map(function(x){return x.n.toLowerCase()}).join(', '))+(ings.length>5?' and '+(ings.length-5)+' more':'')+'</span>'+
  (s.swaps&&sw.length?'<span style="padding:6px 9px;border-radius:9px;background:var(--counter);font-size:12px;line-height:1.4"><b>Our swaps:</b> '+esc(swTxt)+'</span>':'')+notes+
  (s.card?'<span class="muted" style="font-size:12px">Includes '+R.card.photos+' photo'+(R.card.photos>1?'s':'')+' of the original card</span>':'')+'</div></div></div>';
}
function shareSheet(){
 var s=shareInit(),sw=shareSwaps(),serv=shareServ(),to=shareTo(),names=to.map(function(k){return PEOPLE[k]});
 var fmtName={card:'recipe card',link:'link',pdf:'PDF',text:'text'}[s.format];
 var head='<div class="between"><div><span class="kicker">'+(s.sent?'Shared':'Share')+'</span><h2 class="h2" style="font-size:22px;line-height:1.15">'+esc(R.title)+'</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>';
 if(s.sent){var inc=[serv+' servings'];if(s.swaps&&sw.length)inc.push(sw.length+' swap'+(sw.length>1?'s':''));if(s.notes)inc.push('ratings and notes');if(s.card&&s.format!=='text')inc.push('the original card');
  return '<div class="sheet sharesheet" role="dialog" aria-modal="true" aria-label="Shared '+esc(R.title)+'">'+head+
   '<div class="shdone" role="status"><span class="shtick"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span><b style="font-family:var(--disp);font-size:20px;line-height:1.2">Sent to '+esc(nameList(names))+'</b><span class="muted" style="font-size:13px;line-height:1.45">As a '+fmtName+', with '+esc(nameList(inc))+'.'+(s.msg?' Your note went with it.':'')+'</span>'+avStack(to,5)+'</div>'+
   (s.msg?'<p class="cardnote" style="margin:0">“'+esc(s.msg)+'”</p>':'')+
   '<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-act="shareagain">Share again</button><button class="primary" style="flex:1;height:52px;font-size:15px" data-closesheet="1">Done</button></div>'+
   '<span class="muted" style="font-size:12px;line-height:1.4;text-align:center">Prototype: nothing was actually sent.</span></div>'}
 var T=[['swaps','Include our swaps',sw.length?sw.map(function(it){return shownName(it).toLowerCase()+' for '+it.name.toLowerCase()}).join(', '):'No swaps chosen on this recipe yet',!sw.length],['notes','Include ratings and notes','Your cook log stays private unless this is on',false],['card','Include the original card',s.format==='text'?'Photos cannot go in plain text':R.card.photos+' photo'+(R.card.photos>1?'s':'')+' of Ashley’s card',s.format==='text']];
 return '<div class="sheet sharesheet" role="dialog" aria-modal="true" aria-label="Share '+esc(R.title)+'">'+head+
  '<div class="seg" role="group" aria-label="Share as" style="grid-template-columns:repeat(4,1fr)">'+[['card','Card'],['link','Link'],['pdf','PDF'],['text','Text']].map(function(x){return '<button data-sharefmt="'+x[0]+'" aria-pressed="'+(s.format===x[0])+'">'+x[1]+'</button>'}).join('')+'</div>'+
  sharePreview()+
  '<div style="display:flex;flex-direction:column">'+
   '<div class="prow" style="min-height:54px"><span class="ptxt"><b>Servings</b><span>'+(serv===R.base?'As written on the card':'Amounts scaled from '+R.base)+'</span></span><div class="stepper" style="height:44px" role="group" aria-label="Servings to share"><button style="width:36px;height:36px" data-shareserv="-1" aria-label="Fewer"'+(serv<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+serv+'</b></span><button style="width:36px;height:36px" data-shareserv="1" aria-label="More"'+(serv>=24?' disabled':'')+'>+</button></div></div>'+
   T.map(function(t){var on=!!s[t[0]]&&!t[3];return '<button class="tog" role="switch" aria-checked="'+on+'" data-sharetog="'+t[0]+'"'+(t[3]?' disabled':'')+'><span style="display:flex;flex-direction:column;gap:2px;min-width:0"><b>'+t[1]+'</b><span>'+esc(t[2])+'</span></span><i class="sw'+(on?' on':'')+'"><i></i></i></button>'}).join('')+'</div>'+
  '<div style="display:flex;flex-direction:column;gap:10px"><div class="between"><span class="kicker">Send to</span><span class="muted" style="font-size:12px">'+(to.length?esc(nameList(names)):'Tap to choose')+'</span></div>'+
   '<div class="shwho" role="group" aria-label="Send to">'+LIBM.filter(function(k){return k!=='M'}).map(function(k){var on=!!s.to[k];return '<button class="who'+(on?' on':'')+'" aria-pressed="'+on+'" data-shareto="'+k+'"><i>'+k+(on?'<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>':'')+'</i>'+PEOPLE[k]+'</button>'}).join('')+
   '<button class="who other" data-act="shareos"><i>'+SVG.share+'</i>Other</button></div>'+
   '<input id="sharemsg" class="shmsg" type="text" maxlength="140" placeholder="Add a note (optional)" aria-label="Note to send with the recipe" value="'+esc(s.msg)+'">'+
   '<span class="muted" style="font-size:12px;line-height:1.4">Everyone here already has this recipe in the family library. Sharing sends your version of it.</span></div>'+
  '<div class="row" style="gap:10px"><button class="secondary" style="flex:1;white-space:nowrap" data-act="sharecopy">'+(s.copied?'Copied':s.format==='text'?'Copy text':'Copy link')+'</button><button class="primary" style="flex:2;height:52px;font-size:15px" data-act="'+(to.length?'sharesend':'shareos')+'">'+(to.length?'Send to '+(to.length===1?esc(names[0]):to.length+' people'):'Share '+fmtName+'…')+'</button></div></div>';
}
function openShare(keepPos){
 var el=document.getElementById('sheet'),old=el.querySelector('.sheet'),y=old?old.scrollTop:0;
 if(!keepPos){shareInit();S.share.sent=false;S.share.copied=false}
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1">'+shareSheet()+'</div>';
 if(keepPos)el.querySelector('.sheet').scrollTop=y;else{var b=el.querySelector('.iconbtn');if(b)b.focus()}
 var mi=document.getElementById('sharemsg');if(mi)mi.addEventListener('input',function(){S.share.msg=mi.value});
}
function shareSend(){S.share.sent=true;openShare(true);var sh=document.querySelector('#sheet .sheet');if(sh)sh.scrollTop=0}
function shareCopy(){var t=S.share.format==='text'?shareText():'https://'+shareLink();try{if(navigator.clipboard)navigator.clipboard.writeText(t).catch(function(){})}catch(e){}S.share.copied=true;openShare(true)}

/* ---- import: photo, website, pasted text, file, or typed in ---- */
var DRAFTS=[],IMP={step:'pick'},IMPT=0;
var IMPM={
 photo:{t:'Photo of a card or page',s:'Recipe cards, cookbook pages, handwriting',k:'From a photo'},
 web:{t:'Website or video link',s:'Paste a link; the recipe is pulled out of the page',k:'From a website'},
 paste:{t:'Paste text',s:'From a message, an email or your notes',k:'From pasted text'},
 file:{t:'File',s:'A PDF or document from Files',k:'From a file'},
 type:{t:'Type it in',s:'Write a recipe from scratch',k:'Typed in'}};
var IMPIC={photo:'<rect x="3" y="6" width="18" height="14" rx="3"/><circle cx="12" cy="13" r="3.5"/><path d="M8.5 6l1.2-2h4.6l1.2 2"/>',web:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.800 0 18M12 3c-3 3.2-3 14.800 0 18"/>',paste:'<rect x="5" y="4" width="14" height="17" rx="2.500"/><path d="M9 4.500h6V7H9zM8.500 11.500h7M8.500 15h5"/>',file:'<path d="M7 3h7l5 5v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M14 3v5h5"/>',type:'<path d="M4 20h4L19 9l-4-4L4 16v4z"/><path d="M13.500 6.500l4 4"/>'};
function impIcon(k){return '<span class="impic"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">'+IMPIC[k]+'</svg></span>'}
var IMPSAMPLE='Nora’s Pasta Salad\n\nIngredients\n1 lb rotini\n2 cups cherry tomatoes, halved\n1 cucumber, diced\n1/2 cup olive oil\n3 tbsp red wine vinegar\nfeta\nsalt and pepper\n\nMethod\n1. Boil the rotini until just tender. Drain and rinse under cold water.\n2. Whisk the oil and vinegar with salt and pepper.\n3. Toss everything together and chill for an hour before serving.';
var IMPUNIT='cups?|tbsp|tsp|tablespoons?|teaspoons?|g|kg|ml|l|oz|lbs?|pounds?|cloves?|cans?|sticks?|pinch(?:es)?|slices?|bunch(?:es)?|packages?|pkg';
function impParse(txt,kicker,src){
 var lines=txt.split(/\r?\n/).map(function(l){return l.trim()}).filter(function(l){return l}),title=lines.length?lines.shift().replace(/^#+\s*/,''):'Untitled recipe',mode='',ings=[],steps=[],flags=[];
 var qre=new RegExp('^((?:about\\s+)?[\\d¼½¾⅓⅔⅛⅜⅝⅞][\\d¼½¾⅓⅔⅛⅜⅝⅞\\s/.,-]*(?:(?:'+IMPUNIT+')\\b\\.?)?)\\s*(.*)$','i');
 lines.forEach(function(l){
  if(/^(ingredients?|you(’|')?ll need|what you need)\b.{0,12}$/i.test(l)){mode='i';return}
  if(/^(method|instructions?|directions?|steps?|preparation|how to make it)\b.{0,12}$/i.test(l)){mode='s';return}
  var bare=l.replace(/^[-•*·]\s*/,''),isNum=/^(step\s*)?\d+\s*[.):]\s+/i.test(l),m2=qre.exec(bare);
  var asIng=mode==='i'||(mode===''&&!isNum&&(l!==bare||(m2&&bare.length<70)));
  if(asIng){if(m2&&m2[2])ings.push({q:m2[1].trim(),n:m2[2].trim()});else{ings.push({q:'',n:bare})}}
  else steps.push(bare.replace(/^(step\s*)?\d+\s*[.):]\s+/i,''));
 });
 ings.forEach(function(x){if(!x.q&&!/salt|pepper|to taste/i.test(x.n))flags.push('No amount given for '+x.n.toLowerCase()+'.')});
 if(!ings.length)flags.push('No ingredients found. Check the text has one ingredient per line.');
 if(!steps.length)flags.push('No method found. Add the steps before cooking from this.');
 return {title:title,kicker:kicker,src:src,ings:ings,steps:steps,flags:flags};
}
function impSample(method){
 if(method==='photo'){var d=impParse('Udon Noodles\nIngredients\n2 packages udon noodles\n1 tbsp sesame oil\n2 cloves garlic, minced\n3 tbsp soy sauce\n1 tbsp brown sugar\n2 green onions, sliced\nMethod\nCook the noodles as the package says. Drain.\nWarm the sesame oil and cook the garlic for 30 seconds.\nStir in the soy sauce and brown sugar, then toss with the noodles.\nTop with green onions.',IMPM.photo.k,'Ashley’s card, 1 photo');d.flags=['“Brown sugar” could read 1 tbsp or 1 tsp. The handwriting is unclear.','The card does not say how many it serves.'];d.sample=true;return d}
 if(method==='file'){var f=impParse('Sunday Pot Roast\nIngredients\n3 lb chuck roast\n2 tbsp olive oil\n1 onion, quartered\n4 carrots, in chunks\n2 cups beef stock\n2 sprigs thyme\nMethod\nSeason the roast and brown it in the oil on all sides.\nAdd the onion, carrots, stock and thyme. Cover.\nCook at 300°F for 3 hours, until it pulls apart.',IMPM.file.k,'pot-roast.pdf, 1 page');f.flags=[];f.sample=true;return f}
 var u=(IMP.url||'').trim(),host=u.replace(/^https?:\/\//i,'').split(/[/?#]/)[0].replace(/^www\./,'')||'example.com',slug=u.replace(/[?#].*$/,'').replace(/\/+$/,'').split('/').pop()||'',t=slug&&slug.indexOf('.')<0?slug.replace(/[-_]+/g,' ').replace(/\b\w/g,function(c){return c.toUpperCase()}):'Weeknight Sheet-Pan Chicken';
 var w=impParse(t+'\nIngredients\n1½ lb chicken thighs\n1 lb baby potatoes, halved\n2 tbsp olive oil\n1 tsp smoked paprika\n1 lemon, sliced\nsalt and pepper\nMethod\nHeat the oven to 425°F.\nToss the potatoes with half the oil and roast for 15 minutes.\nRub the chicken with the rest of the oil and the paprika. Add to the pan with the lemon.\nRoast 25 minutes, until the chicken reaches 165°F.',IMPM.web.k,host);w.flags=[];w.sample=true;w.web=true;return w;
}
function impSheet(){
 var st=IMP.step,M=IMPM[IMP.method]||{},back='<button class="iconbtn" data-imp="back" aria-label="Back">'+SVG.back+'</button>',close='<button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button>';
 function head(k,t,b){return '<div class="between"><div class="row" style="gap:12px">'+(b?back:'')+'<div><span class="kicker">'+k+'</span><h2 class="h2" style="font-size:20px">'+t+'</h2></div></div>'+close+'</div>'}
 if(st==='pick')return head('Add a recipe','How do you want to add it?')+
  '<div style="display:flex;flex-direction:column">'+['photo','web','paste','file','type'].map(function(k){return '<button class="plink implink" data-imp="method:'+k+'">'+impIcon(k)+'<span class="ptxt"><b>'+IMPM[k].t+'</b><span>'+IMPM[k].s+'</span></span>'+SVG.arrow+'</button>'}).join('')+'</div>'+
  '<span class="muted" style="font-size:12px;line-height:1.45">Whatever the source, you review the result before it joins the library. Anything unclear is flagged as a question rather than guessed.</span>';
 if(st==='input'){
  if(IMP.method==='photo')return head('Add a recipe',M.t,1)+'<div class="impdrop">'+impIcon('photo')+'<b>Front and back, if there is one</b><span class="muted" style="font-size:13px;line-height:1.4">Handwriting is fine. Several photos become one recipe.</span></div>'+
   '<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-imp="read">Choose photos</button><button class="primary" style="flex:1;height:52px;font-size:15px" data-imp="read">Take a photo</button></div>'+
   '<span class="muted" style="font-size:12px;line-height:1.4">Prototype: no camera here, so both buttons load a sample card (Udon Noodles, one of the 32 still on paper).</span>';
  if(IMP.method==='file')return head('Add a recipe',M.t,1)+'<div class="impdrop">'+impIcon('file')+'<b>PDF, Word or a text file</b><span class="muted" style="font-size:13px;line-height:1.4">A file with several recipes is split into one draft each.</span></div>'+
   '<button class="primary" data-imp="read">Choose a file</button><span class="muted" style="font-size:12px;line-height:1.4">Prototype: this loads a sample file (pot-roast.pdf).</span>';
  if(IMP.method==='web')return head('Add a recipe',M.t,1)+'<label class="implab">Link<input id="impurl" class="shmsg" type="url" inputmode="url" placeholder="https://…" value="'+esc(IMP.url||'')+'" aria-label="Recipe link"></label>'+
   '<span class="muted" style="font-size:13px;line-height:1.45">Only the recipe is kept: ingredients, amounts and steps. The life story and the ads stay behind. Video links use the recipe in the caption or description.</span>'+
   '<button class="primary" data-imp="read">Read the page</button><span class="muted" style="font-size:12px;line-height:1.4">Prototype: nothing is fetched. The title comes from your link; the recipe itself is a sample.</span>';
  var ty=IMP.method==='type';
  return head('Add a recipe',M.t,1)+'<label class="implab">'+(ty?'Recipe':'Pasted text')+'<textarea id="imptext" class="imptext" placeholder="'+(ty?'Title on the first line, then ingredients one per line, then the steps.':'Paste the recipe here. A title, an ingredient per line, then the steps.')+'" aria-label="Recipe text">'+esc(IMP.text||'')+'</textarea></label>'+
   '<div class="row" style="gap:10px">'+(ty?'':'<button class="secondary" style="flex:1" data-imp="sample">Use sample text</button>')+'<button class="primary" style="flex:1;height:52px;font-size:15px" data-imp="read">'+(ty?'Review':'Read it')+'</button></div>'+
   '<span class="muted" style="font-size:12px;line-height:1.4">This one is real in the prototype: whatever you '+(ty?'type':'paste')+' is sorted into a title, ingredients and steps.</span>';
 }
 if(st==='reading')return head('Add a recipe',IMP.method==='photo'?'Reading the card':IMP.method==='web'?'Reading the page':'Reading it')+'<div class="impdrop" role="status"><span class="impspin" aria-hidden="true"></span><b>Finding the ingredients and steps</b><span class="muted" style="font-size:13px">A few seconds</span></div>';
 var d=IMP.draft;
 if(st==='done')return head('Added','In your library')+'<div class="shdone" role="status"><span class="shtick"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span><b style="font-family:var(--disp);font-size:20px;line-height:1.2">'+esc(d.title)+'</b><span class="muted" style="font-size:13px;line-height:1.45">Saved as a draft'+(d.flags.length?' with '+d.flags.length+' thing'+(d.flags.length>1?'s':'')+' to check':'')+'. The family sees it once you publish it.</span></div>'+
  '<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-imp="again">Add another</button><button class="primary" style="flex:1;height:52px;font-size:15px" data-imp="lib">See it in Recipes</button></div>';
 var saved=IMP.saved!=null;
 return head(esc(d.kicker)+' · '+esc(d.src),esc(d.title),!saved)+
  '<div class="row" style="gap:6px;flex-wrap:wrap"><span class="badge">'+d.ings.length+' ingredient'+(d.ings.length===1?'':'s')+'</span><span class="badge">'+d.steps.length+' step'+(d.steps.length===1?'':'s')+'</span>'+(d.flags.length?'<span class="badge" style="border-style:dashed">'+d.flags.length+' to check</span>':'<span class="badge solid">Nothing to check</span>')+(d.sample?'<span class="badge">Sample result</span>':'')+'</div>'+
  (d.flags.length?'<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker" style="color:#111">To check</span>'+d.flags.map(function(q){return '<p class="cardnote" style="margin:0">'+esc(q)+'</p>'}).join('')+'</div>':'')+
  (d.ings.length?'<div style="display:flex;flex-direction:column"><span class="kicker" style="margin-bottom:4px">Ingredients</span>'+d.ings.map(function(x){return '<div class="improw"><b>'+(x.q?esc(x.q):'<span class="muted" style="font-weight:600">'+(/salt|pepper|to taste/i.test(x.n)?'to taste':'amount?')+'</span>')+'</b><span>'+esc(x.n)+'</span></div>'}).join('')+'</div>':'')+
  (d.steps.length?'<div style="display:flex;flex-direction:column;gap:10px"><span class="kicker">Method</span>'+d.steps.map(function(x,i){return '<div class="row" style="gap:10px;align-items:flex-start"><span class="pnum" style="width:26px;height:26px;font-size:12px">'+(i+1)+'</span><span style="font-size:14px;line-height:1.5;flex:1">'+esc(x)+'</span></div>'}).join('')+'</div>':'')+
  (d.sample?'<span class="muted" style="font-size:12px;line-height:1.4">Prototype: '+(d.web?'the title comes from your link, but the ingredients and steps are a stand-in, so they may not match it.':'this is a stand-in result, not read from a real '+(d.kicker==='From a file'?'file':'photo')+'.')+'</span>':'')+
  (d.web?'<span class="muted" style="font-size:12px;line-height:1.4">Source kept with the recipe: '+esc(d.src)+'. Credit and a link back stay attached when you share it.</span>':'')+
  (saved?'<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-imp="del:'+IMP.saved+'">Remove draft</button><button class="primary" style="flex:1;height:52px;font-size:15px" data-toast="Publishing a draft to the family library is not built in this prototype">Publish</button></div><span class="muted" style="font-size:12px;line-height:1.4">Drafts cannot be cooked from in this prototype; the nine built recipes can.</span>'
   :'<div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-imp="back">Back</button><button class="primary" style="flex:2;height:52px;font-size:15px" data-imp="save">Save to library</button></div>');
}
function impRender(keepPos){
 var el=document.getElementById('sheet'),old=el.querySelector('.sheet'),y=old?old.scrollTop:0;
 el.innerHTML='<div class="sheetwrap'+(keepPos?' noanim':'')+'" data-closesheet="1"><div class="sheet impsheet" role="dialog" aria-modal="true" aria-label="Add a recipe">'+impSheet()+'</div></div>';
 if(keepPos===2)el.querySelector('.sheet').scrollTop=y;
 var u=document.getElementById('impurl'),t=document.getElementById('imptext');
 if(u){u.addEventListener('input',function(){IMP.url=u.value});if(keepPos)u.focus()}
 if(t){t.addEventListener('input',function(){IMP.text=t.value});if(keepPos&&!IMP.text)t.focus()}
 if(!keepPos){var b=el.querySelector('.iconbtn');if(b)b.focus()}
}
function openImport(){IMPT++;IMP={step:'pick'};impRender()}
function impAct(v){
 var p=v.split(':'),k=p[0];
 if(k==='method'){IMP.method=p[1];IMP.step='input';if(p[1]==='type')IMP.text='';impRender(1);return}
 if(k==='back'){IMPT++;IMP.step=IMP.step==='review'?'input':'pick';impRender(1);return}
 if(k==='sample'){IMP.text=IMPSAMPLE;impRender(1);return}
 if(k==='read'){
  var mth=IMP.method;
  if((mth==='paste'||mth==='type')&&!(IMP.text||'').trim()){toast(mth==='type'?'Type the recipe first':'Paste some text first');return}
  if(mth==='web'&&!(IMP.url||'').trim()){toast('Paste a link first');return}
  if(mth==='type'){IMP.draft=impParse(IMP.text,IMPM.type.k,'by you');IMP.step='review';impRender(1);return}
  IMP.step='reading';impRender(1);var tk=++IMPT;
  setTimeout(function(){if(tk!==IMPT||!document.querySelector('#sheet .impsheet'))return;IMP.draft=mth==='paste'?impParse(IMP.text,IMPM.paste.k,'your clipboard'):impSample(mth);IMP.step='review';impRender(1)},900);return}
 if(k==='save'){DRAFTS.unshift(IMP.draft);IMP.step='done';impRender(1);if(S.screen==='library')keepUnder();return}
 if(k==='again'){openImport();return}
 if(k==='lib'){closeSheet();go('library');return}
 if(k==='open'){IMPT++;IMP={step:'review',draft:DRAFTS[+p[1]],saved:+p[1]};impRender();return}
 if(k==='del'){DRAFTS.splice(+p[1],1);closeSheet();toast('Draft removed');if(S.screen==='library')keep(render);return}
}
function draftsSection(){
 if(!DRAFTS.length)return '';
 return '<section class="card acard" style="gap:4px"><div class="between"><span class="kicker">Imported drafts</span><span class="muted" style="font-size:12px">Only you see these</span></div>'+DRAFTS.map(function(d,i){return '<button class="plink" data-imp="open:'+i+'"><span class="ptxt"><b>'+esc(d.title)+'</b><span>'+esc(d.kicker)+' · '+d.ings.length+' ingredients · '+d.steps.length+' steps'+(d.flags.length?' · '+d.flags.length+' to check':'')+'</span></span>'+SVG.arrow+'</button>'}).join('')+'</section>';
}
var libraryView0=libraryView;
libraryView=function(){var h=libraryView0(),mk='<section class="card acard" style="gap:12px"><div class="between" style="gap:12px;align-items:flex-start"><div><span class="kicker">Still on paper</span>',j=h.indexOf(mk);return j<0?h:h.slice(0,j)+draftsSection()+h.slice(j)};
initMark2();
