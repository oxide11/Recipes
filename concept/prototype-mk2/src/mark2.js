/* ================= MARK 2: features from the review ================= */
var ONHAND={},EXP={},PROMO={},QA={};
function initMark2(){
 ONHAND={};PROMO={};QA={};EXP={};
 // sample data: the second swap in every map is treated as already in the kitchen
 RECIPE_ORDER.forEach(function(id){var sets=RECIPES[id].SETS;Object.keys(sets).forEach(function(k){var l=sets[k].leaves[1];if(l&&!l.allergen&&!l.dislike)ONHAND[l.id]=1})});
 // sample data: a few things on hand are close to their date
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
   return '<div class="pmeal"><button class="pmopen" data-open="'+id+'" aria-label="Open '+esc(r.title)+'"><span class="libfp">'+fpBar(r,60)+'</span><span class="libtxt" style="padding:11px 52px 11px 14px"><b style="font-size:17px">'+esc(r.title)+'</b><span class="muted">'+(t.yours?'':'~')+fmtMin(t.m)+' for you · '+(miss?miss+' to buy':'everything on hand')+'</span></span></button><button class="iconbtn pdel" data-plandel="'+i+':'+j+'" aria-label="Remove '+esc(r.title)+' from '+D0[0]+'">'+SVG.close+'</button></div>'}).join('');
  var head='<div class="pdhead"><span class="kicker" style="color:#111">'+(today?'Tonight':D0[0])+(prep?' · prep day':'')+'</span>'+(prep?'<span class="muted" style="font-size:12px">'+list.length+' recipes · '+fmtS(pm.end)+'</span>':'')+'</div>';
  return '<div class="pday'+(prep?' prep':'')+'">'+date+'<div class="pdcol">'+head+meals+
   '<div class="pdfoot">'+(prep?'<button class="primary" style="height:44px;font-size:14px;width:auto;padding:0 18px" data-prep="'+i+'">Open prep session</button>':'')+'<button class="linkbtn" style="font-size:13px" data-planadd="'+i+'" aria-label="Add another recipe for '+D0[0]+'">+ Add another</button></div></div></div>'}).join('');
 var buy='<section class="card acard" style="gap:12px"><div class="between"><span class="kicker">To buy for this week</span><span style="font-size:13px"><b>'+needs.length+'</b> item'+(needs.length===1?'':'s')+'</span></div>'+
  (needs.length?'<div style="display:flex;flex-direction:column">'+needs.slice(0,pad?99:6).map(function(x){return '<div class="row" style="gap:10px;min-height:44px;border-bottom:1px solid #ECECE8">'+icon(x.it.icon[0][0],28)+'<span style="flex:1;min-width:0;font-size:15px;font-weight:600;padding-left:8px;border-left:4px solid '+(x.it.edge||x.it.color)+'">'+esc(x.it.name)+'</span><span class="muted" style="font-size:12px;text-align:right">'+esc(x.for.join(', '))+'</span></div>'}).join('')+'</div>'+(!pad&&needs.length>6?'<span class="muted" style="font-size:13px">and '+(needs.length-6)+' more</span>':''):'<span style="font-size:14px">Nothing. The pantry covers the whole week.</span>')+
  (needs.length?'<button class="secondary" style="height:44px;font-size:14px" data-go="shopall">Open the shopping list</button>':'')+'</section>';
 return '<div class="pad">'+
  '<div><p class="muted" style="margin:0 0 4px;font-size:'+(pad?14:13)+'px">November 16 to 22</p><h1 class="t" style="font-size:'+(pad?40:30)+'px">Plan</h1></div>'+
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
initMark2();
