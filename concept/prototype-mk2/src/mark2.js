/* ================= MARK 2: features from the review ================= */
var ONHAND={},EXP={},PROMO={},QA={};
function initMark2(){
 ONHAND={};PROMO={};QA={};EXP={};
 // sample data: the second swap in every map is treated as already in the kitchen
 RECIPE_ORDER.forEach(function(id){var sets=RECIPES[id].SETS;Object.keys(sets).forEach(function(k){var l=sets[k].leaves[1];if(l&&!l.allergen&&!l.dislike)ONHAND[l.id]=1})});
 // sample data: a few things on hand are close to their date
 var n=0;[['milk',2],['egg',4],['green onion',2],['parmesan',3],['potato',5],['lemon',3],['cheddar',4],['butter',6]].forEach(function(e){if(PAN[e[0]]&&n<4){EXP[e[0]]=e[1];n++}});
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
 var keys=Object.keys(EXP).filter(function(k){return PAN[k]}).sort(function(a,b){return EXP[a]-EXP[b]});if(!keys.length||S.tag)return '';
 var cat={};catalog().forEach(function(c){cat[c.key]=c.it});
 var best=null;RECIPE_ORDER.forEach(function(id){var r=RECIPES[id],hit=r.ING.filter(function(it){return EXP[pKey(it)]&&PAN[pKey(it)]}),c=coverage(id),sc=hit.length*10+c[0]/c[1];if(hit.length&&(!best||sc>best.sc))best={id:id,sc:sc,hit:hit,miss:c[1]-c[0]}});
 return '<section class="useup"><div class="between"><p class="kicker" style="color:#111">Use it up</p><button class="linkbtn" style="font-size:13px" data-go="pantry">Pantry</button></div>'+
  '<div style="display:flex;gap:8px;flex-wrap:wrap">'+keys.map(function(k){var it=cat[k];return it?'<span class="uchip'+(EXP[k]<=2?' soon':'')+'">'+icon(it.icon[0][0],24)+'<b>'+esc(it.name)+'</b><em>'+EXP[k]+' day'+(EXP[k]>1?'s':'')+'</em></span>':''}).join('')+'</div>'+
  (best?'<button class="upick" data-open="'+best.id+'"><span><b>'+esc(RECIPES[best.id].title)+'</b><small>uses '+best.hit.map(function(it){return it.name.toLowerCase()}).join(' and ')+' · '+(best.miss?best.miss+' to buy':'everything on hand')+'</small></span>'+SVG.arrow+'</button>':'')+'</section>';
}

/* ---- F3 cook two recipes together (plan only) ---- */
function plainTitle(r,st){return st.title.replace(/\{(\w+)!?\}/g,function(_,k){var li=r.LINE[k],it=li&&li.ing?r.ING.filter(function(x){return x.id===li.ing})[0]:r.ING.filter(function(x){return x.id===k})[0];return it?it.name.toLowerCase():k})}
function mergePlan(A0,B0){
 var Q=[{r:A0,i:0,ready:0},{r:B0,i:0,ready:0}],busy=0,rows=[];
 function left(q){var s=0;for(var j=q.i;j<q.r.STEPS.length;j++){var t=stepTime(q.r.STEPS[j]);s+=t.on+t.wait}return s}
 while(Q[0].i<Q[0].r.STEPS.length||Q[1].i<Q[1].r.STEPS.length){
  var c=Q.filter(function(q){return q.i<q.r.STEPS.length});
  c.sort(function(x,y){var sx=Math.max(busy,x.ready),sy=Math.max(busy,y.ready);return sx-sy||left(y)-left(x)});
  var q=c[0],st=q.r.STEPS[q.i],t=stepTime(st),s=Math.max(busy,q.ready);
  rows.push({at:s,lane:Q.indexOf(q),r:q.r,n:q.i+1,title:plainTitle(q.r,st),on:t.on,wait:t.wait});
  busy=s+t.on;q.ready=s+t.on+t.wait;q.i++;
 }
 var tot=function(r){return r.STEPS.reduce(function(s,st){var t=stepTime(st);return s+t.on+t.wait},0)};
 return {rows:rows,end:Math.max(Q[0].ready,Q[1].ready,busy),apart:tot(A0)+tot(B0)};
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
initMark2();
