/* ================= GLOBALS ================= */
var R,ING,GROUPS,LINE,STEPS,SETS;
var MODES={
 weight:{label:'Weight',cap:'Grams',fmt:function(v){return Math.round(v)+'g'}},
 volume:{label:'Volume',cap:'Millilitres, raw',fmt:function(v){return Math.round(v)+'ml'}},
 cost:{label:'Cost',cap:'Estimated, CAD',fmt:function(v){return '$'+v.toFixed(2)}},
 calories:{label:'Calories',cap:'kcal by macro',fmt:function(v){return Math.round(v)+' cal'}}
};
var POS=[[62,38],[205,46],[290,142],[290,330],[70,432],[200,430]];
var BPOS=[[100,118],[290,235],[100,352]];
var LEAFLINES=['M100,118 Q70,90 62,38','M100,118 Q190,110 205,46','M290,235 Q300,200 290,142','M290,235 Q300,280 290,330','M100,352 Q70,390 70,432','M100,352 Q190,370 200,430'];
var BLINES=['M175,235 Q120,200 100,118','M175,235 L290,235','M175,235 Q120,270 100,352'];
var SVG={
 share:'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12M7 8l5-5 5 5"/><path d="M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>',
 swap:'<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 8h13l-3-3M20 16H7l3 3"/></svg>',
 back:'<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>',
 close:'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>',
 warn:function(c){return '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="'+c+'" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.5"/></svg>'},
 tick:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
 arrow:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
 heart:'<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
 heartOn:'<svg width="20" height="20" viewBox="0 0 24 24" fill="#E5392B" stroke="#E5392B" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
 cst:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="3"/><circle cx="4" cy="6" r="1.6"/><circle cx="20" cy="6" r="1.6"/><circle cx="5" cy="19" r="1.6"/><circle cx="19" cy="18" r="1.6"/><path d="M5.3 7l4.5 3.5M18.7 7l-4.5 3.5M6.3 18l3.6-3.6M17.7 17l-3.6-3"/></svg>',
 convert:'<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 4L3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/></svg>',
 tabHome:'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/></svg>',
 tabBook:'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 21V5"/></svg>',
 tabJar:'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="7" width="12" height="14" rx="2"/><path d="M8 3h8v4H8z"/></svg>',
 tabCal:'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
 tabCart:'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><path d="M3 4h2l2.5 12h11L21 8H6.5"/><circle cx="9" cy="20" r="1"/><circle cx="18" cy="20" r="1"/></svg>'
};
function icon(t,size){return '<svg width="'+size+'" height="'+size+'" viewBox="0 0 28 28" aria-hidden="true">'+(ICON[t]||'')+'</svg>'}
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}

/* ================= STATE ================= */
var S;
var LOG={};
function seedLog(){LOG={
 cajun:[
  {date:'Oct 12',who:'Ashley',mins:29,rating:5,swapList:[],note:'',sample:1},
  {date:'Oct 24',who:'Moussa',mins:34,rating:4,swapList:[],note:'Chicken strips were too thick. Slice thinner.',sample:1},
  {date:'Nov 2',who:'Ashley',mins:31,rating:4,swapList:['Penne for linguine','1 cup cream for 1½ cups'],note:'Less cream next time.',sample:1},
  {date:'Nov 9',who:'Moussa',mins:27,rating:5,swapList:['Penne for linguine'],note:'Sauce reduced nicely. Keep the heat low once the cream goes in.',sample:1}],
 thai:[
  {date:'Nov 5',who:'Moussa',mins:38,rating:4,swapList:['Chicken for shrimp'],note:'The chicken needed 8 minutes in the broth.',sample:1}]
}}
seedLog();
var D={device:'phone',orient:'landscape'},SCALE=1;
function isPad(){return D.device==='ipad'}
function isLand(){return isPad()&&D.orient==='landscape'}
function freshGlobal(){S={screen:'home',speed:30,saved:{},dir:1};}
freshGlobal();
function loadRecipe(id){
 R=RECIPES[id];ING=R.ING;GROUPS=R.GROUPS;LINE=R.LINE;STEPS=R.STEPS;SETS=R.SETS;
 var sw={};ING.forEach(function(it){if(it.profile)sw[it.id]=it.profile});
 var have={};for(var k in R.have)have[k]=true;
 S.recipe=id;S.mode='weight';S.swaps=sw;S.have=have;S.focus=null;S.picked={};S.zoom=null;S.cart={};S.units={};S.struck={};
 S.servings=R.base;S.tab='overview';S.step=0;S.timers={};S.cookOpen=null;S.cooksAll=false;S.rating=0;S.photo=null;S.started=null;S.note='';S.share={format:'card',swaps:true,notes:false,card:true,scale:false};
}
loadRecipe('cajun');
function F(){return S.servings/R.base}
function ing(id){for(var i=0;i<ING.length;i++)if(ING[i].id===id)return ING[i];return null}
function leafOf(id,lid){var set=SETS[id];if(!set)return null;for(var i=0;i<set.leaves.length;i++)if(set.leaves[i].id===lid)return set.leaves[i];return null}
function shownName(it){var sw=S.swaps[it.id];return sw?leafOf(it.id,sw).name:it.name}
function colorOf(it){if(it.id==='mushroom'&&S.swaps.mushroom==='aubergine')return '#4B2E83';return it.color}
function edgeOf(it){return it.edge||it.color}
function blockedReason(l){if(l.allergen)return 'Contains '+l.allergen.toLowerCase();if(l.dislike)return 'You dislike '+l.dislike.toLowerCase();return ''}

/* ================= QUANTITIES ================= */
var FR=[[0,''],[.25,'¼'],[1/3,'⅓'],[.5,'½'],[2/3,'⅔'],[.75,'¾'],[1,'']];
function scaleQty(str,f,whole){
 if(f===1)return str;
 var m=/^(\d+(?:\.\d+)?)?([½¼¾⅓⅔])?(\s?)(.*)$/.exec(str);if(!m||(!m[1]&&!m[2]))return str;
 var fv={'½':.5,'¼':.25,'¾':.75,'⅓':1/3,'⅔':2/3}[m[2]]||0,v=(m[1]?parseFloat(m[1]):0)+fv,rest=m[3]+m[4];if(!v)return str;v*=f;
 if(/^ ?(g|ml)\b/.test(rest)||(whole&&!fv&&parseFloat(m[1])>=3))return Math.max(1,Math.round(v))+rest;
 if(/^ ?(oz|lb|kg|L|fl oz)\b/.test(rest))return (Math.round(v*10)/10)+rest;
 var w=Math.floor(v),fr=v-w,best=FR[0];FR.forEach(function(x){if(Math.abs(x[0]-fr)<Math.abs(best[0]-fr))best=x});
 if(best[0]===1){w+=1;best=FR[0]}
 var out=(w?String(w):'')+best[1];if(!out)out='¼';
 if(v>1.01){rest=rest.replace(/^ can\b/,' cans').replace(/^ bunch\b/,' bunches').replace(/^ lemon\b/,' lemons').replace(/^ clove\b/,' cloves')}
 return out+rest;
}
function lineInfo(key){
 if(key==='spices_sw'){var lf0=leafOf('spices',S.swaps.spices);return {key:key,name:lf0.name,noun:lf0.name.toLowerCase(),color:'#F58A1F',icon:'jar',opts:[[lf0.ratio,'in place of garlic, cumin and paprika']],u:0,qty:lf0.ratio}}
 var L0=LINE[key],it=L0.ing?ing(L0.ing):null,sw=it?S.swaps[it.id]:null,profile=it&&it.profile===sw;
 var color=L0.color||(it?colorOf(it):'#8A8A85'),ic=L0.icon||(it?it.icon[0][0]:null);
 var name=L0.name||(it?shownName(it):key),noun=L0.noun||name.toLowerCase(),opts=L0.opts;
 if(sw){var lf=leafOf(it.id,sw);name=lf.name;noun=lf.name.toLowerCase();
  if(L0.swapOpts&&L0.swapOpts[sw]){opts=L0.swapOpts[sw]}
  else if(lf.ratio==='1 : 1'){opts=L0.opts.filter(function(o){return o[2]!=='p'});if(!opts.length)opts=L0.opts}
  else{opts=[[lf.ratio,'in place of '+L0.opts[0][0]+' '+(L0.noun||it.name.toLowerCase())]]}}
 var scalable=!(sw&&!profile&&leafOf(it.id,sw).ratio!=='1 : 1'&&!(L0.swapOpts&&L0.swapOpts[sw]));
 if(scalable)opts=opts.map(function(o){return[scaleQty(o[0],F(),o[2]==='p'),o[1],o[2],o[3]]});
 var u=Math.min(S.units[key]||0,opts.length-1);
 if(opts[u][3])noun=opts[u][3];
 return {key:key,name:name,noun:noun,color:color,edge:L0.color||(it?edgeOf(it):color),icon:ic,opts:opts,u:u,qty:opts[u][0],check:sw?'':(L0.check||'')};
}
function stepSrc(st){var src=st.lines;if(st.swapLines){for(var k in st.swapLines)if(S.swaps[k])src=st.swapLines[k]}return src}
function stepLines(st){
 return stepSrc(st).map(function(t){return t.replace(/\{(\w+)\}/g,function(_,k){return A(k)})});
}
function stepTitle(st){return st.title.replace(/\{(\w+)!\}/g,function(_,k){var it=ing(k);return shownName(it).toLowerCase()})}
function A(key){
 var li=lineInfo(key),c=li.color,txt=li.qty&&li.qty!=='—'&&li.qty!=='to taste'?li.qty+' '+li.noun:li.noun;
 return '<span class="ingt'+(li.check?' q':'')+'" role="button" tabindex="0" data-conv="'+key+'" style="background:'+c+'26;box-shadow:inset 0 -4px 0 '+li.edge+'" aria-label="'+esc(txt+'. Change units')+'">'+esc(txt)+'</span>';
}

/* ================= SAFE TEMPERATURES ================= */
var SAFE={poultry:{f:165,c:74,note:'thickest part. The juices should run clear'},seafood:{f:145,c:63,note:'thickest piece. It should be opaque and firm all the way through'}};
var THERMO='<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 13.5V5a2 2 0 0 1 4 0v8.5a4.5 4.5 0 1 1-4 0z"/><path d="M12 9v8"/></svg>';
function safeFor(st){
 if(!st.protein)return null;var it=ing(st.protein);if(!it)return null;
 var sw=S.swaps[it.id],lf=sw?leafOf(it.id,sw):null,key=(lf&&lf.safe)||it.safe;
 if(!key||key==='none'||!SAFE[key])return null;
 return {name:shownName(it),f:SAFE[key].f,c:SAFE[key].c,note:SAFE[key].note};
}
function safeBadge(st,big){
 var s=safeFor(st);if(!s)return '';var it=ing(st.protein);
 return '<button class="safe'+(big?' big':'')+'" data-safe="'+STEPS.indexOf(st)+'" style="background:'+colorOf(it)+'40;border-color:'+edgeOf(it)+'" aria-label="Safe temperature for '+esc(s.name)+': '+s.f+' degrees Fahrenheit, '+s.c+' Celsius. Show details">'+THERMO+'<b>'+s.f+'°F</b><span>'+esc(s.name)+'</span></button>';
}
function openSafe(i){
 var st=STEPS[i],s=safeFor(st);if(!s)return;var it=ing(st.protein),el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Safe temperature for '+esc(s.name)+'">'+
  '<div class="between"><div class="row" style="gap:10px">'+icon(it.icon[0][0],34)+'<div><span class="kicker">Safe temperature</span><h2 class="h2" style="font-size:20px">'+esc(s.name)+'</h2></div></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  '<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px"><div class="tempbox" style="background:'+colorOf(it)+'40;border-color:'+edgeOf(it)+'"><b>'+s.f+'°F</b><span>Fahrenheit</span></div><div class="tempbox" style="background:'+colorOf(it)+'40;border-color:'+edgeOf(it)+'"><b>'+s.c+'°C</b><span>Celsius</span></div></div>'+
  '<p style="margin:0;font-size:15px;line-height:1.5">Measure the internal temperature at the '+esc(s.note)+'.</p>'+
  '<p class="muted" style="margin:0;font-size:13px;line-height:1.45">Step '+(i+1)+', “'+esc(stepTitle(st))+'”. USDA minimum internal temperature. Changes automatically if you swap the protein.</p>'+
 '</div></div>';
 var c=el.querySelector('.iconbtn');if(c)c.focus();
}

/* ================= SHELL ================= */
var scr=document.getElementById('screen');
function go(screen,dir){S.dir=dir||1;S.screen=screen;closeSheet();render(true);scr.scrollTop=0}
function toast(msg){var t=document.getElementById('toast');t.textContent=msg;t.classList.add('show');clearTimeout(toast._t);toast._t=setTimeout(function(){t.classList.remove('show')},2400)}
function header(backTo,title,sub,closeIcon){
 return '<div class="row"><button class="iconbtn" data-back="'+backTo+'" aria-label="'+(closeIcon?'Close':'Back')+'">'+(closeIcon?SVG.close:SVG.back)+'</button>'+
  (title?'<div style="display:flex;flex-direction:column;gap:2px;min-width:0"><h1 class="t" style="font-size:26px">'+esc(title)+'</h1>'+(sub?'<p class="muted" style="margin:0;font-size:13px">'+sub+'</p>':'')+'</div>':'')+'</div>';
}
function profileBar(){
 return '<div style="display:flex;flex-direction:column;gap:8px;padding:12px;border-radius:14px;background:var(--counter)"><span class="kicker" style="color:var(--ink)">Never suggested</span>'+
 '<div style="display:flex;gap:8px;flex-wrap:wrap"><span class="chip out">Mushrooms <span class="muted" style="font-weight:500">dislike</span></span>'+
 '<span class="chip out" style="border-width:1.5px">'+SVG.warn('#111')+'Tree nuts <span class="muted" style="font-weight:500">allergy</span></span></div></div>';
}
function fpBar(r,h){var tot=0;r.ING.forEach(function(it){tot+=it.weight});return '<div style="display:flex;height:'+h+'px;width:100%" aria-hidden="true">'+r.ING.map(function(it){return '<span style="flex:'+it.weight+';background:'+(it.profile==='aubergine'?'#4B2E83':it.color)+'"></span>'}).join('')+'</div>'}

/* ================= TAGS ================= */
function tagBadges(){return R.tags.map(function(t){return '<button class="badge'+(t[1]?' solid':'')+'" data-tag="'+esc(t[0])+'" aria-label="Show recipes tagged '+esc(t[0])+'">'+t[0]+'</button>'}).join('')}
function tagList(){return S.tag?RECIPE_ORDER.filter(function(id){return RECIPES[id].tags.some(function(t){return t[0]===S.tag})}):RECIPE_ORDER}
function tagBar(){
 if(!S.tag)return '';var n=tagList().length;
 return '<div class="row" style="gap:10px;flex-wrap:wrap;padding:10px 12px;border-radius:14px;background:var(--counter)"><span style="font-size:14px"><b>'+n+'</b> recipe'+(n===1?'':'s')+' tagged</span><span class="badge solid">'+esc(S.tag)+'</span><button class="linkbtn" data-act="cleartag" style="margin-left:auto">Show all</button></div>';
}

/* ================= HOME ================= */
function home(){
 var list=tagList(),feat=RECIPES[list[0]],others=list.slice(1);
 function cooked(id){var n=(LOG[id]||[]).length;return n?'<span class="badge solid" style="height:22px;font-size:11px">Cooked '+n+'×</span>':''}
 var pantry=Object.keys(feat.have).length;
 return '<div class="pad">'+
 '<div class="between"><div><p class="muted" style="margin:0 0 4px;font-size:13px">Monday evening</p><h1 class="t" style="font-size:30px">What\'s cooking?</h1></div>'+
 '<button class="iconbtn" style="background:#111;color:#fff;font-family:\'Space Grotesk\';font-weight:700;font-size:17px" aria-label="Profile" data-toast="Profile: avoids mushrooms, allergic to tree nuts">M</button></div>'+
 '<label class="row" style="height:48px;padding:0 16px;border-radius:14px;background:var(--counter);gap:10px"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#595954" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></svg><span class="sr">Search</span><input id="search" type="search" placeholder="Search recipes or ingredients" style="flex:1;border:none;background:transparent;font:inherit;font-size:15px;outline:none"></label>'+
 tagBar()+'<div style="display:flex;flex-direction:column;gap:10px"><p class="kicker">Cook with what you have</p><div style="display:flex;gap:8px;flex-wrap:wrap">'+
  [['#F2C200','Lemons','piccata'],['#9CBF5A','Lemongrass','thai'],['#2E9E4F','Green onion','cajun'],['#6CBF3A','Limes','thai']].map(function(c){return '<button class="chip" data-open="'+c[2]+'"><span class="dot" style="background:'+c[0]+'"></span>'+c[1]+'</button>'}).join('')+'</div></div>'+
 '<button class="rcard" data-open="'+feat.id+'" aria-label="Open '+esc(feat.title)+'">'+fpBar(feat,112)+
  '<div style="padding:16px 18px 18px;display:flex;flex-direction:column;gap:6px;width:100%"><div class="between"><span class="kicker" style="color:#111">'+(S.tag?'Best match':'Tonight\'s pick')+'</span>'+cooked(feat.id)+'</div>'+
  '<span style="font-family:\'Space Grotesk\';font-size:24px;font-weight:700;line-height:1.15">'+esc(feat.title)+'</span><span class="muted" style="font-size:14px">'+feat.meta+' · '+feat.base+' servings</span>'+
  '<span style="font-size:14px;font-weight:600;margin-top:2px">'+pantry+' of '+feat.ING.length+' ingredients already in your pantry</span></div></button>'+
 '<div style="display:flex;flex-direction:column;gap:10px"><p class="kicker">From Ashley’s recipe cards</p>'+
  others.map(function(id){var r=RECIPES[id];return '<button class="listrow" data-open="'+id+'"><div style="flex:1;display:flex;flex-direction:column;gap:8px;min-width:0"><div class="between"><span style="font-weight:700;font-size:16px">'+esc(r.title)+'</span>'+cooked(id)+'</div><div class="fp">'+fpBar(r,10)+'</div><span class="muted" style="font-size:13px">'+r.meta+' · '+r.base+' servings'+(r.card.questions.length?' · '+r.card.questions.length+' card question'+(r.card.questions.length>1?'s':''):'')+'</span></div>'+SVG.arrow+'</button>'}).join('')+
 '</div></div>'+
 '<nav class="tabbar" aria-label="Main">'+[['Home',SVG.tabHome,1],['Recipes',SVG.tabBook],['Pantry',SVG.tabJar],['Plan',SVG.tabCal],['Shop',SVG.tabCart]].map(function(t){return '<button class="'+(t[2]?'on':'')+'"'+(t[2]?' aria-current="page"':' data-toast="Only the cooking flow is wired up"')+'>'+t[1]+t[0]+'</button>'}).join('')+'</nav>';
}

/* ================= SANKEY ================= */
function nutOf(it,leafId){
 var lid=leafId===undefined?S.swaps[it.id]:leafId,lf=lid?leafOf(it.id,lid):null;
 if(lf&&lf.nut)return lf.nut;var m=it.macro||[0,0,0];return [it.calories,m[0],m[1],m[2]];
}
function dishNut(oid,oleaf){var t=[0,0,0,0];ING.forEach(function(it){var n=it.id===oid?nutOf(it,oleaf):nutOf(it);for(var i=0;i<4;i++)t[i]+=n[i]});return t.map(function(x){return x/R.base})}
function liveStats(){var n=dishNut();return R.stats.map(function(s){if(/^kcal/.test(s[1]))return [Math.round(n[0]).toLocaleString('en-US'),s[1]];if(/^protein/.test(s[1]))return [Math.round(n[1])+' g',s[1]];return s})}
function nutDelta(id,leafId){
 var lf=leafOf(id,leafId);if(!lf||!lf.nut)return '';
 var cur=S.swaps[id]||null,a=dishNut(),b=dishNut(id,leafId),L=['Calories','Protein','Carbs','Fat'],U=['',' g',' g',' g'];
 return '<div class="nutbox"><span class="kicker">'+(leafId===cur?'Per serving, as it is now':'Per serving, with this swap')+'</span><div class="nutgrid">'+L.map(function(l,i){var d=Math.round(b[i]-a[i]);
  return '<div><span>'+l+'</span><b>'+Math.round(b[i]).toLocaleString('en-US')+U[i]+'</b><i class="'+(d?'chg':'')+'">'+(d?(d<0?'▼ ':'▲ ')+Math.abs(d).toLocaleString('en-US')+U[i]:'no change')+'</i></div>'}).join('')+'</div></div>';
}
var MACROS=[{name:'Protein',color:'#3A3A38',op:.32},{name:'Carbs',color:'#8A8A85',op:.32},{name:'Fat',color:'#C9C9C4',op:.6}];
function skGroups(){return S.mode==='calories'?MACROS:GROUPS}
function skShares(it){
 if(S.mode!=='calories'){var z=GROUPS.map(function(){return 0});z[it.g]=1;return z}
 var nn=nutOf(it),m=[nn[1],nn[2],nn[3]],k=[m[0]*4,m[1]*4,m[2]*9],t=k[0]+k[1]+k[2];if(!t)return [0,1,0];return k.map(function(x){return x/t});
}
function skVal(gi,gv,sep){var M=MODES[S.mode];if(S.mode!=='calories')return M.fmt(gv);var g=0;ING.forEach(function(it){g+=nutOf(it)[gi+1]*F()});return Math.round(g)+' g'+sep+M.fmt(gv)}
function tapAttr(it){return SETS[it.id]?' tap" role="button" tabindex="0" data-focus="'+it.id+'" aria-label="'+esc('Swap '+shownName(it))+'"':'"'}
function sankey(){
 var M=MODES[S.mode],mode=S.mode,f=F();
 var vals=ING.map(function(i){return (mode==='calories'?nutOf(i)[0]:i[mode])*f});
 var total=vals.reduce(function(a,b){return a+b},0);
 var GAP=6,MGAP=18,BX=196,MX=262,PX=344,W=350;
 var iconSpec=ING.map(function(it){return it.icon.map(function(p){return[p[0],Math.max(1,Math.round(p[1]*f))]})});
 var counts=iconSpec.map(function(sp){return sp.reduce(function(a,p){return a+p[1]},0)});
 var sizes=counts.map(function(n){return n===1?56:Math.min(42,Math.floor(178/n))});
 var minH=sizes.map(function(z){return z+40});
 var H=Math.max(560,minH.reduce(function(a,b){return a+b},0)+GAP*(ING.length-1)+40);
 var SPAN=H*.7,hs,bh,bt;
 for(var k=0;k<60;k++){var sc=SPAN/total;hs=vals.map(function(v){return Math.max(1.5,v*sc)});bh=hs.map(function(h,i){return Math.max(minH[i],h)});bt=bh.reduce(function(a,b){return a+b},0)+GAP*(bh.length-1);if(bt<=H-8)break;SPAN-=10}
 var y=(H-bt)/2,bp=bh.map(function(h){var o={y0:y,y1:y+h};y+=h+GAP;return o});
 var G=skGroups(),SH=ING.map(skShares),gs=G.map(function(){return 0});ING.forEach(function(it,i){SH[i].forEach(function(sh,g){gs[g]+=hs[i]*sh})});
 var my=(H-(gs.reduce(function(a,b){return a+b},0)+MGAP*(gs.length-1)))/2,mids=gs.map(function(h){var o={y0:my,y1:my+h};my+=h+MGAP;return o});
 var ph=gs.reduce(function(a,b){return a+b},0),py=(H-ph)/2;
 function band(x0,a0,a1,x1,b0,b1){var c=(x0+x1)/2;function q(n){return n.toFixed(1)}return 'M'+x0+','+q(a0)+' C'+c+','+q(a0)+' '+c+','+q(b0)+' '+x1+','+q(b0)+' L'+x1+','+q(b1)+' C'+c+','+q(b1)+' '+c+','+q(a1)+' '+x0+','+q(a1)+' Z'}
 var cur=mids.map(function(m){return m.y0}),paths='',html='';
 ING.forEach(function(it,i){
  var b=bp[i],h=hs[i];var m=(b.y0+b.y1)/2,col=colorOf(it);
  var a0=m-h/2;SH[i].forEach(function(sh,g){if(sh<=0)return;var hh=h*sh;paths+='<path d="'+band(BX,a0,a0+hh,MX,cur[g],cur[g]+hh)+'" fill="'+col+'" fill-opacity="'+(/^#F[27]D/.test(col)?.6:.42)+'"/>';a0+=hh;cur[g]+=hh});
  var icons='';iconSpec[i].forEach(function(p){for(var n=0;n<p[1];n++)icons+=icon(p[0],sizes[i])});
  var sw=S.swaps[it.id];
  html+='<div class="blk'+tapAttr(it)+' style="top:'+b.y0.toFixed(1)+'px;height:'+(b.y1-b.y0).toFixed(1)+'px;width:'+(BX-6)+'px;background:'+col+'1F">'+
   '<div class="icons">'+icons+'</div><div class="lab"><b>'+esc(shownName(it))+'</b><span>'+M.fmt(vals[i])+'</span></div>'+
   (sw?'<span class="swaptag">for '+esc(it.name.toLowerCase())+'</span>':'')+'</div>'+
   '<div style="position:absolute;left:'+(BX-6)+'px;top:'+b.y0.toFixed(1)+'px;width:6px;height:'+(b.y1-b.y0).toFixed(1)+'px;background:'+edgeOf(it)+'"></div>';
 });
 var pc=py;
 mids.forEach(function(m,gi){var h=m.y1-m.y0;paths+='<path d="'+band(MX+6,m.y0,m.y1,PX,pc,pc+h)+'" fill="'+G[gi].color+'" fill-opacity="'+G[gi].op+'"/>';pc+=h;
  var gv=0;ING.forEach(function(it,i){gv+=vals[i]*SH[i][gi]});if(h<1)return;
  html+='<div style="position:absolute;left:'+MX+'px;top:'+m.y0.toFixed(1)+'px;width:6px;height:'+h.toFixed(1)+'px;background:#111"></div><div class="mid" style="left:'+(MX+12)+'px;top:'+((m.y0+m.y1)/2-15).toFixed(1)+'px">'+G[gi].name+'\n'+skVal(gi,gv,'\n')+'</div>'});
 html+='<div style="position:absolute;left:'+PX+'px;top:'+py.toFixed(1)+'px;width:6px;height:'+ph.toFixed(1)+'px;background:#111"></div><div class="mid" style="right:0;top:'+(py-20).toFixed(1)+'px">Plate</div>';
 var aria='Sankey chart by '+M.label.toLowerCase()+': '+ING.map(function(it,i){return shownName(it)+' '+M.fmt(vals[i])+' ('+it.eq+')'}).join(', ')+'. Total '+M.fmt(total);
 return {html:'<div class="sk" role="img" aria-label="'+esc(aria)+'" style="height:'+H+'px"><svg width="'+W+'" height="'+H+'" viewBox="0 0 '+W+' '+H+'" aria-hidden="true" style="position:absolute;left:0;top:0">'+paths+'</svg>'+html+'</div>',total:M.fmt(total)};
}

/* ================= RECIPE ================= */
function cardSection(){
 var c=R.card;if(!c)return '';
 return '<section class="card" style="padding:16px 18px;display:flex;flex-direction:column;gap:10px">'+
  '<div class="row" style="gap:14px;align-items:flex-start"><div class="cardthumb" aria-hidden="true"><i style="width:70%;height:5px;background:#8A8A85"></i><i></i><i style="width:80%"></i><i></i><i style="width:60%"></i></div>'+
  '<div style="display:flex;flex-direction:column;gap:4px;min-width:0"><span class="kicker">From Ashley’s card</span><b style="font-size:15px">'+esc(c.source)+'</b><span style="font-size:13px;line-height:1.4;color:#3A3A38">'+esc(c.credit)+'</span><button class="linkbtn" data-toast="The original photos open here in the app">View '+c.photos+' original photo'+(c.photos>1?'s':'')+'</button></div></div>'+
  (c.questions.length?'<div style="display:flex;flex-direction:column;gap:6px"><span class="kicker" style="color:#111">Still to check with Ashley</span>'+c.questions.map(function(q){return '<p class="cardnote" style="margin:0">'+esc(q)+'</p>'}).join('')+'</div>':'<p class="cardnote" style="margin:0">Fully transcribed. Nothing left to check.</p>')+
 '</section>';
}

function recipe(){
 var M=MODES[S.mode],tab=S.tab,body='',ins=R.INS[S.mode];
 if(tab==='overview'){var sk=sankey();
  body='<section class="card" style="padding:18px 10px 20px;margin:0 -10px;display:flex;flex-direction:column;gap:14px">'+
  '<div class="between" style="padding:0 8px"><h2 class="h2">Where it all goes</h2><span class="muted" style="font-size:12px;font-weight:600">'+M.cap+' · total '+sk.total+'</span></div>'+
  '<div class="seg" role="group" aria-label="Measure by" style="grid-template-columns:repeat(4,1fr)">'+Object.keys(MODES).map(function(k){return '<button data-mode="'+k+'" aria-pressed="'+(k===S.mode)+'">'+MODES[k].label+'</button>'}).join('')+'</div>'+
  '<span class="muted" style="font-size:12px;padding:0 8px;margin-top:-6px">Tap an ingredient to see its swaps.</span>'+sk.html+'<p class="insight"><strong>'+ins[0]+'</strong> '+ins[1]+'</p></section>'+cardSection()+cooksCard();
 } else if(tab==='ingredients'){
  var prof=ING.filter(function(it){return it.profile&&S.swaps[it.id]===it.profile});
  body='<section style="display:flex;flex-direction:column"><div class="between" style="padding-bottom:4px"><span class="kicker">For '+S.servings+' serving'+(S.servings>1?'s':'')+'</span><span class="muted" style="font-size:12px">Tap an amount to convert</span></div>'+
  ING.map(function(it){var li=LINE[it.id]?lineInfo(it.id):null,qty=li?li.qty:scaleQty(it.amt,F());return '<div class="row" style="gap:12px;padding:8px 0;border-bottom:1px solid #ECECE8">'+icon(it.icon[0][0],34)+
   '<span style="flex:1;display:flex;flex-direction:column;gap:1px;padding-left:8px;border-left:4px solid '+edgeOf(it)+';min-width:0"><b style="font-size:16px">'+esc(shownName(it))+'</b><span class="muted" style="font-size:12px">'+esc(it.eq)+'</span></span>'+
   (li?'<button class="qty'+(li.check?' q':'')+'" data-conv="'+it.id+'" aria-label="'+esc(qty+' '+li.name+'. Change units')+'">'+esc(qty)+SVG.convert+'</button>':'<span class="qty static">'+esc(qty)+'</span>')+'</div>'}).join('')+'</section>'+
  prof.map(function(it){return '<div class="row" style="gap:10px;padding:10px 12px;border-radius:12px;background:var(--counter);font-size:14px"><span class="muted" style="text-decoration:line-through">'+esc(it.name)+'</span>'+SVG.arrow+'<b>'+esc(shownName(it))+'</b><span class="muted" style="margin-left:auto;font-size:12px">your '+it.why+'</span></div>'}).join('');
 } else {
  body='<ol class="plan">'+STEPS.map(function(st,i){
   var keys=[];stepSrc(st).join(' ').replace(/\{(\w+)\}/g,function(_,k){if(keys.indexOf(k)<0)keys.push(k)});
   return '<li><span class="pnum">'+(i+1)+'</span><div style="display:flex;flex-direction:column;gap:6px;flex:1;min-width:0"><div class="between" style="gap:8px"><b style="font-family:\'Space Grotesk\';font-size:18px">'+esc(stepTitle(st))+'</b>'+'<span class="muted" style="font-size:12px;white-space:nowrap">'+(st.on?st.on+' min hands-on':'')+(st.secs?' · '+Math.round(st.secs/60)+' min timer':'')+'</span>'+'</div>'+
   safeBadge(st)+(keys.length?'<div style="display:flex;flex-wrap:wrap;gap:6px">'+keys.map(function(k){var li=lineInfo(k);return '<button class="chip" data-conv="'+k+'" style="height:30px;font-size:13px;font-weight:600;background:'+li.color+'1F;box-shadow:inset 0 -2px 0 '+li.edge+'">'+esc(li.qty+' '+li.noun)+'</button>'}).join('')+'</div>':'')+
   '<p style="margin:0;font-size:15px;line-height:1.5;color:#2B2B28">'+stepLines(st).join(' ').replace(/<[^>]+>/g,function(t){return t.indexOf('ingt')>-1||t==='</span>'?'':t})+'</p></div></li>'}).join('')+'</ol>';
 }
 var tabs=[['overview','Overview'],['ingredients','Ingredients'],['steps','Instructions']];
 var saved=!!S.saved[R.id];
 return '<div class="pad">'+
 '<div class="between"><button class="iconbtn" data-back="home" aria-label="Back">'+SVG.back+'</button><span class="row" style="gap:8px"><button class="iconbtn" aria-label="Share recipe" data-act="share">'+SVG.share+'</button><button class="iconbtn" aria-label="'+(saved?'Saved':'Save recipe')+'" aria-pressed="'+saved+'" data-act="save">'+(saved?SVG.heartOn:SVG.heart)+'</button></span></div>'+
 '<div style="display:flex;flex-direction:column;gap:10px"><p class="kicker">'+R.kicker+'</p><h1 class="t" style="font-size:36px">'+R.title+'</h1>'+
 '<div style="display:flex;gap:6px;flex-wrap:wrap">'+tagBadges()+'</div>'+
 '<p style="margin:0;font-size:15px;line-height:1.5;color:#2B2B28">'+R.desc+'</p>'+
 '<div class="stats">'+liveStats().map(function(s){return '<div><b>'+s[0]+'</b><span>'+s[1]+'</span></div>'}).join('')+'</div>'+
 '<div class="between" style="gap:10px"><div class="stepper" role="group" aria-label="Servings"><button data-serv="-1" aria-label="Fewer servings"'+(S.servings<=1?' disabled':'')+'>−</button><span aria-live="polite"><b>'+S.servings+'</b> serving'+(S.servings>1?'s':'')+'</span><button data-serv="1" aria-label="More servings"'+(S.servings>=12?' disabled':'')+'>+</button></div><span class="muted" style="font-size:13px">'+STEPS.length+' steps</span></div></div>'+
 '<div class="seg tabs" role="tablist" style="grid-template-columns:repeat(3,1fr)">'+tabs.map(function(t){return '<button role="tab" data-tab="'+t[0]+'" aria-pressed="'+(t[0]===tab)+'" aria-selected="'+(t[0]===tab)+'">'+t[1]+'</button>'}).join('')+'</div>'+
 body+'</div>'+
 '<div class="bottombar"><button class="secondary" style="flex:1;height:56px" data-go="ingredients">Ingredients &amp; swaps</button><button class="primary" style="flex:1.3" data-act="startcook">Start cooking</button></div>';
}

/* ================= INGREDIENTS ================= */
function starPos(i,n){var a=(-90+i*360/n)*Math.PI/180;return[Math.round(175+145*Math.cos(a)),Math.round(225+165*Math.sin(a))]}
function constellation(){
 var n=ING.length,ring='',spokes='';
 ING.forEach(function(it,i){var p=starPos(i,n);ring+=(i?' L':'M')+p[0]+','+p[1];spokes+='M175,225 L'+p[0]+','+p[1]+' '});
 var stars=ING.map(function(it,i){
  var p=starPos(i,n),d=Math.max(30,Math.round(4.2*Math.sqrt(it.weight*(it.weight>600?.35:1)))),sw=S.swaps[it.id],name=shownName(it),fill=colorOf(it);
  var sub=sw?'was '+it.name.toLowerCase():scaleQty(it.amt,F());
  return '<button class="star'+(sw?' sw':'')+'" data-focus="'+it.id+'" aria-label="'+esc(name+(sw?', swapped for '+it.name.toLowerCase():'')+'. Show swaps')+'" style="left:'+p[0]+'px;top:'+p[1]+'px;transform:translate(-50%,-'+Math.round(d/2+4)+'px)">'+
   '<span class="orb" style="width:'+d+'px;height:'+d+'px;background:'+fill+(it.edge?';border:1px solid '+it.edge:'')+'"></span><span class="nm">'+esc(name)+'</span><span class="sub">'+esc(sub)+'</span></button>';
 }).join('');
 return '<div class="cst '+(S.zoom==='out'?'zout':'')+'"><svg width="350" height="450" viewBox="0 0 350 450" aria-hidden="true" style="position:absolute;inset:0" fill="none"><path d="'+ring+' Z" stroke="#E4E4E0" stroke-width="1.5" stroke-dasharray="3 5"/><path d="'+spokes+'" stroke="#BDBDB8" stroke-width="1.5"/></svg>'+
 '<div class="hub"><span style="font-family:\'Space Grotesk\';font-size:16px;font-weight:700;line-height:1.1">'+esc(R.title)+'</span><span style="font-size:12px;color:#D9D9D4">'+n+' ingredients</span></div>'+stars+'</div>';
}
function gatherRows(){
 return ING.map(function(it){
  var sw=S.swaps[it.id],on=!!S.have[it.id],lf=sw?leafOf(it.id,sw):null;
  return '<div class="row" style="padding:10px 0;border-bottom:1px solid #ECECE8;align-items:center">'+
   '<button class="check" role="checkbox" aria-checked="'+on+'" aria-label="I have '+esc(shownName(it))+'" data-have="'+it.id+'">'+(on?SVG.tick:'')+'</button>'+
   icon(it.icon[0][0],30)+
   '<div style="flex:1;display:flex;flex-direction:column;gap:2px;min-width:0">'+
    '<span style="font-size:15px;font-weight:600">'+esc(shownName(it))+(sw?' <span class="muted" style="font-weight:500;text-decoration:line-through;font-size:13px">'+esc(it.name)+'</span>':'')+'</span>'+
    '<span class="muted" style="font-size:13px">'+esc(lf&&lf.ratio!=='1 : 1'?lf.ratio:scaleQty(it.amt,F())+' · '+it.eq)+'</span></div>'+
   (SETS[it.id]?'<button class="chip out" data-focus="'+it.id+'" style="height:32px">Swap</button>':'')+'</div>';
 }).join('');
}
function ingredients(){
 if(S.focus)return swapView();
 var ready=ING.filter(function(it){return S.have[it.id]}).length,rows=gatherRows();
 return '<div class="pad">'+header('recipe','This cook','Optional. Swap anything or tick what you have, then start.')+profileBar()+
 constellation()+
 '<section style="display:flex;flex-direction:column"><div class="between" style="padding-bottom:4px"><h2 class="h2">Gather</h2><span style="font-size:13px;font-weight:700">'+ready+' of '+ING.length+' ready</span></div>'+rows+'</section>'+
 (ready<ING.length?'<button class="secondary" data-go="shop">Shop for '+(ING.length-ready)+' missing</button>':'')+
 '</div><div class="bottombar"><button class="primary" data-act="startcook">Start cooking</button></div>';
}
function swapView(){
 var id=S.focus,it=ing(id),set=SETS[id],idx=ING.indexOf(it),p=starPos(idx,ING.length);
 var cur=S.swaps[id]||null,picked=S.picked[id]||cur||set.leaves[0].id;
 var lines=set.branches.map(function(b,i){return '<path d="'+BLINES[i]+'" stroke="#111" stroke-width="3"/>'}).join('')+set.leaves.map(function(l,i){return '<path d="'+LEAFLINES[i]+'" stroke="#BDBDB8" stroke-width="2"/>'}).join('');
 var leaves=set.leaves.map(function(l,i){
  var on=l.id===picked,why=blockedReason(l),isCur=l.id===cur;
  return '<button class="leaf'+(on?' on':'')+(why?' blk':'')+(isCur?' cur':'')+'" data-pick="'+l.id+'" aria-pressed="'+on+'" aria-label="'+esc(l.name+', '+(why||l.ratio))+'" style="left:'+POS[i][0]+'px;top:'+POS[i][1]+'px"><b>'+esc(l.name)+'</b><small>'+esc(why||l.ratio)+'</small></button>';
 }).join('');
 var branches=set.branches.map(function(b,i){return '<div class="branch" style="left:'+BPOS[i][0]+'px;top:'+BPOS[i][1]+'px">'+b+'</div>'}).join('');
 var s=leafOf(id,picked),why=blockedReason(s),isCur=picked===cur;
 var bars=set.traits.map(function(t,i){var b='';for(var n=0;n<5;n++)b+='<i class="'+(n<s.t[i]?'f':'')+'"></i>';return '<div style="display:flex;flex-direction:column;gap:6px"><span class="muted" style="font-size:12px;font-weight:600">'+t+'</span><div class="bars">'+b+'</div></div>'}).join('');
 var btn=why?'<button class="secondary" disabled style="width:100%;color:#595954">Not available for you</button>':
  (isCur?'<button class="secondary" disabled style="width:100%;color:#595954">In use</button>':'<button class="primary" data-act="use" style="height:50px;font-size:16px">Use '+esc(s.name)+'</button>');
 var revert=(cur&&!it.profile)?'<button class="secondary" data-act="revert" style="width:100%;height:44px;font-size:14px">Go back to '+esc(it.name.toLowerCase())+'</button>':'';
 var sub=it.profile?(it.why==='allergy'?'Your allergy profile swapped these out':'You dislike them, so a swap is already in'):'In '+esc(R.title)+' · '+esc(scaleQty(it.amt,F()));
 var map='<div class="zin" style="position:relative;width:350px;height:470px;margin:0 auto;transform-origin:'+p[0]+'px '+p[1]+'px">'+
  '<svg width="350" height="470" viewBox="0 0 350 470" aria-hidden="true" style="position:absolute;inset:0" fill="none" stroke-linecap="round">'+lines+'</svg>'+
  '<div class="hub2"><span class="dot" style="width:14px;height:14px;background:'+it.color+(it.edge?';border:1px solid '+it.edge:'')+'"></span><span style="font-family:\'Space Grotesk\';font-size:16px;font-weight:700;line-height:1.1">'+esc(set.center)+'</span><span class="muted" style="font-size:11px">'+esc(scaleQty(it.amt,F()))+'</span></div>'+
  branches+leaves+
  '<button class="chip out" data-act="home" style="position:absolute;right:0;bottom:0;height:40px;border-width:1.5px;font-weight:700">Whole recipe</button>'+
 '</div>';
 var detail='<section class="card" style="padding:16px 18px;display:flex;flex-direction:column;gap:10px">'+
  '<div class="between"><h2 class="h2" style="font-size:20px">'+esc(s.name)+'</h2><b style="font-size:14px">'+(why?'':esc(s.ratio))+'</b></div>'+
  (why?'<div class="row" style="gap:8px;padding:8px 12px;border-radius:10px;background:#111;color:#fff;font-size:13px;font-weight:600">'+SVG.warn('#fff')+esc(why)+'. Hidden from your suggestions.</div>':'')+
  '<p style="margin:0;font-size:14px;line-height:1.45;color:#2B2B28">'+esc(s.note)+'</p>'+
  '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">'+bars+'</div>'+nutDelta(id,picked)+btn+revert+
 '</section>';
 if(isPad())return '<div class="sheet swapmodal" role="dialog" aria-modal="true" aria-label="Swap '+esc(set.center)+'"><div class="between"><div><h2 class="h2" style="font-size:26px">Swap '+esc(set.center.toLowerCase())+'</h2><p class="muted" style="margin:2px 0 0;font-size:13px">'+sub+'</p></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div><div class="swapgrid">'+map+'<div style="display:flex;flex-direction:column;gap:12px;min-width:0">'+profileBar()+detail+'</div></div></div>';
 return '<div class="pad">'+header('ingredients','Swap '+set.center.toLowerCase(),sub)+
 '<nav aria-label="Breadcrumb" class="row" style="gap:6px"><button class="chip out" data-act="home" style="height:36px;border-width:1.5px;font-weight:700">'+SVG.cst+esc(R.title)+'</button><span aria-hidden="true" style="color:#8A8A85">›</span><b style="font-size:14px">'+esc(set.center)+'</b></nav>'+map+detail+'</div>';
}

/* ================= SHOP ================= */
var AISLES=['Produce','Dairy and eggs','Canned','Dry goods','Pantry'];
function shop(){
 var missing=ING.filter(function(it){return !S.have[it.id]});
 var inCart=missing.filter(function(it){return S.cart[it.id]}).length;
 var secs=AISLES.map(function(a){
  var items=missing.filter(function(it){return it.aisle===a});if(!items.length)return '';
  var left=items.filter(function(it){return !S.cart[it.id]}).length;
  return '<section style="display:flex;flex-direction:column;gap:10px"><div class="between" style="border-bottom:1.5px solid #111;padding-bottom:6px"><h2 class="h2">'+a+'</h2><span class="muted" style="font-size:12px;font-weight:600">'+(left?left+' to get':'All in cart')+'</span></div>'+
  '<div class="tiles">'+items.map(function(it){
   var g=!!S.cart[it.id],spec=it.icon.map(function(p){return[p[0],Math.max(1,Math.round(p[1]*F()))]}),n=spec.reduce(function(a,p){return a+p[1]},0),size=n===1?56:Math.min(36,Math.floor(140/n)),ic='';
   spec.forEach(function(p){for(var k=0;k<p[1];k++)ic+=icon(p[0],size)});
   var sw=S.swaps[it.id],lf=sw?leafOf(it.id,sw):null;
   return '<button class="tile'+(g?' got':'')+'" data-cart="'+it.id+'" aria-pressed="'+g+'" aria-label="'+esc(shownName(it)+', '+scaleQty(it.amt,F())+(g?', in cart':''))+'" style="background:'+(g?'#fff':colorOf(it)+'24')+'">'+
    '<span class="tchk">'+(g?SVG.tick:'')+'</span><span class="ticons">'+ic+'</span>'+
    '<b>'+esc(shownName(it))+'</b><span style="font-size:12px;color:#3A3A38">'+esc(lf&&lf.ratio!=='1 : 1'?lf.ratio:scaleQty(it.amt,F()))+'</span>'+
    (sw?'<span class="ttag">replaces '+esc(it.name.toLowerCase())+'</span>':'')+'</button>';
  }).join('')+'</div></section>';
 }).join('');
 var have=ING.filter(function(it){return S.have[it.id]}).map(function(it){return '<span class="chip" style="background:#fff;height:40px;padding:0 12px 0 6px;font-size:13px;font-weight:600">'+icon(it.icon[0][0],28)+esc(shownName(it))+'</span>'}).join('');
 var done=!missing.length||inCart===missing.length;
 return '<div class="pad">'+header(isPad()?'recipe':'ingredients','Shopping list','For '+esc(R.title)+' · grouped by aisle')+
 '<div style="display:flex;flex-direction:column;gap:8px"><b style="font-size:14px">'+inCart+' of '+missing.length+' in your cart</b><div class="prog"><i style="width:'+(missing.length?Math.round(100*inCart/missing.length):100)+'%"></i></div></div>'+
 (missing.length?secs:'<p class="insight">Nothing to buy. Everything is in your pantry.</p>')+
 (have?'<section style="display:flex;flex-direction:column;gap:10px;padding:14px;border-radius:18px;background:var(--counter)"><span class="kicker" style="color:#111">Already in your pantry</span><div style="display:flex;flex-wrap:wrap;gap:8px">'+have+'</div></section>':'')+
 '</div><div class="bottombar"><button class="primary" data-act="shopdone"'+(done?'':' disabled')+'>'+(done?(isPad()?'Back to recipe':'Back to ingredients'):'Tick items as you shop')+'</button></div>';
}

/* ================= COOK ================= */
function mix(a,b,k){function p(h){return[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)]}var x=p(a),y=p(b);return '#'+x.map(function(v,i){var n=Math.round(v+(y[i]-v)*k).toString(16);return n.length<2?'0'+n:n}).join('')}
function colorFor(f){var st=[[1,'#3A3A38'],[.5,'#8A8A85'],[.32,'#2E9E4F'],[.14,'#F2C200'],[0,'#E5392B']];for(var i=0;i<st.length-1;i++){if(f<=st[i][0]&&f>=st[i+1][0])return mix(st[i][1],st[i+1][1],(st[i][0]-f)/(st[i][0]-st[i+1][0]))}return f>1?st[0][1]:st[4][1]}
function pulseSecs(f){if(f<=0)return 1.6;if(f>.5)return 4;return 1.8+(f/.5)*2.2}
function clock(sec){var s=Math.ceil(sec),h=Math.floor(s/3600),m=Math.floor((s%3600)/60),r=s%60;return (h?h+':'+(m<10?'0':''):'')+m+':'+(r<10?'0':'')+r}
function timerOf(i){if(!S.timers[i])S.timers[i]={total:STEPS[i].secs,left:STEPS[i].secs,running:false,started:false};return S.timers[i]}
function playIcon(on){return on?'<svg width="20" height="20" viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/></svg>':'<svg width="20" height="20" viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><path d="M8 5l11 7-11 7z"/></svg>'}
function miniRing(size,col,f){var c=138.23;return '<svg width="'+size+'" height="'+size+'" viewBox="0 0 52 52" aria-hidden="true"><circle cx="26" cy="26" r="22" fill="#fff" stroke="#ECECE8" stroke-width="5"/><circle class="arc" cx="26" cy="26" r="22" fill="none" stroke="'+col+'" stroke-width="5" stroke-linecap="round" stroke-dasharray="'+c+'" stroke-dashoffset="'+(c*(1-f)).toFixed(2)+'" transform="rotate(-90 26 26)"/></svg>'}
function cook(){
 var i=S.step,st=STEPS[i];
 var bar='';for(var n=0;n<STEPS.length;n++)bar+='<i class="'+(n<i?'f':n===i?'c':'')+'"></i>';
 var ls=stepLines(st);
 var lines=ls.map(function(t,j){var dn=!!S.struck[i+':'+j];
  return '<li><div class="line'+(dn?' struck':'')+'" role="button" tabindex="0" data-strike="'+i+':'+j+'" aria-pressed="'+dn+'"><span class="num">'+(j+1)+'</span><span class="pl">'+t+'</span></div></li>'}).join('');
 var startCard='';
 if(st.secs){var t=timerOf(i);if(!t.started){startCard='<div class="startcard"><span class="row" style="gap:12px">'+miniRing(48,'#3A3A38',1)+'<span style="display:flex;flex-direction:column"><b style="font-family:\'Space Grotesk\';font-size:22px;font-variant-numeric:tabular-nums">'+clock(t.total)+'</b><span class="muted" style="font-size:13px">Timer for this step</span></span></span><button class="primary" data-act="tstart" style="width:auto;height:44px;padding:0 18px;font-size:15px;border-radius:12px">Start</button></div>'}}
 var allDone=ls.every(function(_,j){return S.struck[i+':'+j]});
 return (isLand()?'<div class="cookwrap">'+stepListPad():'')+'<div class="pad cookpad">'+
 '<div class="row"><button class="iconbtn" data-back="recipe" aria-label="Exit cooking mode">'+SVG.close+'</button><div style="flex:1;display:flex;flex-direction:column;gap:8px"><span style="font-size:13px;font-weight:700">Step '+(i+1)+' of '+STEPS.length+' · '+esc(R.title)+'</span><div class="stepbar" style="grid-template-columns:repeat('+STEPS.length+',1fr)" aria-hidden="true">'+bar+'</div></div></div>'+
 '<p class="kicker" style="color:#111">'+esc(stepTitle(st))+'</p>'+
 '<ol class="lines">'+lines+'</ol>'+safeBadge(st,true)+(st.flag?'<p class="cardnote"><b>Card note:</b> '+esc(st.flag)+'</p>':'')+startCard+
 '<p class="muted hint">'+(allDone?'<b style="color:#111">Step done.</b> On to the next one.':'Tap a line to cross it off. Tap an ingredient to change its units.')+'</p>'+
 '</div>'+(isLand()?'</div>':'')+'<div class="bottombar" style="flex-direction:column"><div id="dock" class="dock"></div><div class="row" style="gap:10px"><button class="secondary" style="flex:1" data-act="prev"'+(i===0?' disabled':'')+'>Previous</button><button class="primary'+(allDone?' glow':'')+'" style="flex:2;height:52px;font-size:15px" data-act="next">'+(i===STEPS.length-1?'Plate it':'Next step')+'</button></div></div>';
}
function timerView(t){var f=t.total>0?t.left/t.total:0,done=f<=0;return {f:f,done:done,col:done?'#FF2A12':colorFor(f),dur:pulseSecs(f).toFixed(2),moving:t.running||done}}
var dockSig='';
function activeTimers(){return Object.keys(S.timers).filter(function(k){var t=S.timers[k];return t.started&&!(t.left<=0&&t.ack)}).sort(function(a,b){return (+b===S.step)-(+a===S.step)||a-b})}
function updateTimerDom(){
 if(S.screen!=='cook')return;
 var dock=document.getElementById('dock');if(!dock)return;
 var keys=activeTimers();
 var n=keys.length;
 function open(k){var t=S.timers[k];return n===1||S.dockOpen===k||t.left<=0||t.left/t.total<=.25||t.left<=20}
 var sig=keys.map(function(k){var t=S.timers[k];return k+(t.running?'r':'p')+(t.left<=0?'d':'')+(open(k)?'o':'c')}).join(',')+'|'+S.step;
 if(sig!==dockSig||!dock.dataset.built){
  dockSig=sig;dock.dataset.built='1';setTimeout(fitSteps,0);
  dock.innerHTML=keys.map(function(k){var t=S.timers[k],v=timerView(t),here=+k===S.step,soon=!v.done&&(t.left/t.total<=.25||t.left<=20);
   if(!open(k))return '<button class="clockbtn" data-k="'+k+'" data-dockopen="'+k+'" aria-label="'+esc(STEPS[k].label+' timer, step '+(+k+1)+'. Show details')+'"><span class="mr mot">'+miniRing(56,v.col,v.f)+'</span><b class="clk2"></b></button>';
   return '<div class="dockrow'+(v.done?' done':'')+'" data-k="'+k+'">'+
    '<button class="ringbtn" data-dockopen="'+k+'" aria-label="Collapse timer"><span class="mr mot">'+miniRing(52,v.col,v.f)+'</span></button>'+
    '<span style="flex:1;display:flex;flex-direction:column;min-width:0"><span class="dk">'+(v.done?'Time is up':soon?'Almost done':t.running?'Running':'Paused')+' · step '+(+k+1)+'</span><b class="clk2" style="font-family:\'Space Grotesk\';font-size:24px;font-variant-numeric:tabular-nums;line-height:1.1"></b><span style="font-size:12px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">'+esc(STEPS[k].label)+' · '+esc(stepTitle(STEPS[k]))+'</span></span>'+
    (v.done?'<button class="dbtn" data-dismiss="'+k+'" aria-label="Dismiss timer" style="background:#fff;color:#111;width:auto;padding:0 16px;font-weight:700;font-size:14px">OK</button>':
    '<button class="dbtn light" data-tplus="'+k+'" aria-label="Add 30 seconds">+30</button><button class="dbtn" data-ttoggle="'+k+'" aria-label="'+(t.running?'Pause':'Resume')+' timer">'+playIcon(t.running)+'</button>')+'</div>'}).join('');
 }
 keys.forEach(function(k){var row=dock.querySelector('[data-k="'+k+'"]');if(!row)return;var t=S.timers[k],v=timerView(t);
  var arc=row.querySelector('.arc');arc.setAttribute('stroke',v.col);arc.setAttribute('stroke-dashoffset',(138.23*(1-v.f)).toFixed(2));
  row.querySelector('.clk2').textContent=v.done?'Done':clock(t.left);
  var mr=row.querySelector('.mr'),an=v.moving?'pulse '+v.dur+'s ease-in-out infinite':'none';if(mr.style.animation!==an)mr.style.animation=an;
 });
}
setInterval(function(){
 if(!S.timers)return;var step=.1*S.speed;
 Object.keys(S.timers).forEach(function(k){var t=S.timers[k];if(t.running){t.left=Math.max(0,t.left-step);if(t.left<=0){t.running=false;toast(STEPS[k].label+' is done')}}});
 updateTimerDom();
},100);
function fitSteps(){
 var ol=scr.querySelector('.lines');if(!ol||!scr.clientHeight)return;
 var bar=scr.querySelector('.bottombar'),hint=scr.querySelector('.hint');
 var start=(ol.getBoundingClientRect().top-scr.getBoundingClientRect().top)/SCALE+scr.scrollTop;
 var avail=scr.clientHeight-start-(bar?bar.offsetHeight:0)-(hint?hint.offsetHeight+28:28);
 var sc=scr.querySelector('.startcard');if(sc)avail-=sc.offsetHeight+18;var cn=scr.querySelector('.cookpad .cardnote');if(cn)avail-=cn.offsetHeight+18;var sb=scr.querySelector('.cookpad .safe');if(sb)avail-=sb.offsetHeight+18;
 if(avail<120)avail=120;
 var lo=22,hi=isPad()?68:36,best=lo;
 while(lo<=hi){var mid=(lo+hi)>>1;ol.style.setProperty('--fs',mid+'px');if(ol.scrollHeight<=avail){best=mid;lo=mid+1}else hi=mid-1}
 ol.style.setProperty('--fs',best+'px');
}
window.addEventListener('resize',function(){fit();if(S.screen==='cook')fitSteps()});
function wordify(){
 scr.querySelectorAll('.line .pl').forEach(function(pl,li){
  var n=0;
  function mk(t){var w=document.createElement('span');w.className='w v'+(n%3);var h=(li*7+n*13)%5;w.style.setProperty('--r',((h-2)*0.7).toFixed(1)+'deg');w.style.setProperty('--y',(((n*5+li)%3)-1)+'px');w.style.setProperty('--d',(n*35)+'ms');w.textContent=t;n++;return w}
  function split(node){var fr=document.createDocumentFragment();node.textContent.split(/(\s+)/).forEach(function(t){if(!t)return;fr.appendChild(/^\s+$/.test(t)?document.createTextNode(t):mk(t))});node.parentNode.replaceChild(fr,node)}
  Array.prototype.slice.call(pl.childNodes).forEach(function(k){if(k.nodeType===3)split(k);else if(k.classList&&k.classList.contains('ingt'))Array.prototype.slice.call(k.childNodes).forEach(function(t2){if(t2.nodeType===3)split(t2)})});
 });
}

/* ================= DONE ================= */
function done(){
 var swaps=ING.filter(function(it){return S.swaps[it.id]});
 var mins=S.started?Math.max(1,Math.round((Date.now()-S.started)/60000)):0;
 var timersUsed=Object.keys(S.timers).filter(function(k){return S.timers[k].started}).length;
 var starsH='';for(var n=1;n<=5;n++)starsH+='<button data-rate="'+n+'" aria-label="'+n+' star'+(n>1?'s':'')+'" aria-pressed="'+(S.rating===n)+'"><svg width="34" height="34" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z" fill="'+(n<=S.rating?'#111':'none')+'" stroke="#111" stroke-width="1.6" stroke-linejoin="round"/></svg></button>';
 return '<div class="pad donepad">'+header('cook','Plated',esc(R.plate)+' for '+S.servings)+
 '<div class="plate"><div class="in">'+(S.photo?'<img src="'+S.photo+'" alt="Your finished '+esc(R.plate.toLowerCase())+'">':'<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></svg><span style="font-family:\'Space Grotesk\';font-size:18px;font-weight:700">Your finished plate</span><span style="font-size:13px;color:#D9D9D4;max-width:180px">Choose a photo and it is cropped to the plate</span>')+
 '<label class="photobtn'+(S.photo?' on':'')+'">'+(S.photo?'Change photo':'Add photo')+'<input type="file" accept="image/*" id="photo" class="sr"></label></div></div>'+
 '<section style="display:flex;flex-direction:column;gap:10px;text-align:center"><h2 class="h2" style="font-size:20px">How did it turn out?</h2><div class="stars5">'+starsH+'</div></section>'+
 '<label style="display:flex;flex-direction:column;gap:6px"><span class="kicker">Note for next time</span><textarea id="note" rows="2" placeholder="Let it simmer longer, more chilli…" style="font:inherit;font-size:15px;padding:12px;border-radius:14px;border:1.5px solid var(--soft);resize:none">'+esc(S.note)+'</textarea></label>'+
 '<section class="card" style="padding:16px 18px;display:flex;flex-direction:column;gap:10px"><h2 class="h2">This cook</h2>'+
  '<div class="stats" style="grid-template-columns:repeat(3,1fr)"><div><b>'+(mins||'–')+(mins?' min':'')+'</b><span>start to plate</span></div><div><b>'+STEPS.length+'</b><span>steps</span></div><div><b>'+timersUsed+'</b><span>timers used</span></div></div>'+
  (swaps.length?swaps.map(function(it){return '<div class="row" style="gap:10px;font-size:14px"><span class="muted" style="text-decoration:line-through">'+esc(it.name)+'</span>'+SVG.arrow+'<b>'+esc(leafOf(it.id,S.swaps[it.id]).name)+'</b></div>'}).join(''):'<span class="muted">No swaps</span>')+
  '<span class="muted" style="font-size:13px">'+ING.filter(function(it){return S.have[it.id]}).length+' of '+ING.length+' ingredients came from your pantry.</span></section>'+
 '</div><div class="bottombar"><button class="primary" data-act="finish">Save to cooking log</button></div>';
}

/* ================= RENDER + EVENTS ================= */
var VIEWS={home:home,recipe:recipe,ingredients:ingredients,shop:shop,cook:cook,done:done};
var PADVIEWS={home:homePad,recipe:recipePad,ingredients:ingredientsPad};
function render(anim){
 document.getElementById('phone').classList.toggle('norail',S.screen==='cook');
 scr.innerHTML=((isPad()&&PADVIEWS[S.screen])||VIEWS[S.screen])();
 scr.classList.remove('anim','animb');if(anim){void scr.offsetWidth;scr.classList.add(S.dir<0?'animb':'anim')}
 document.querySelectorAll('#steps li').forEach(function(li){li.classList.toggle('on',li.dataset.s===S.screen)});
 document.getElementById('sideTitle').textContent=S.screen==='home'?'Recipe flow':R.title;
 if(S.screen==='cook'){dockSig='';updateTimerDom();wordify();fitSteps()}
 S.zoom=null;
 var ph=document.getElementById('photo');
 if(ph)ph.addEventListener('change',function(){var f=ph.files&&ph.files[0];if(!f)return;if(S.photo)URL.revokeObjectURL(S.photo);S.photo=URL.createObjectURL(f);render()});
 var nt=document.getElementById('note');if(nt)nt.addEventListener('input',function(){S.note=nt.value});
 var se=document.getElementById('search');if(se)se.addEventListener('keydown',function(e){if(e.key==='Enter'){var q=se.value.toLowerCase().trim();var hit=RECIPE_ORDER.filter(function(id){var r=RECIPES[id];return r.title.toLowerCase().indexOf(q)>-1||r.ING.some(function(it){return it.name.toLowerCase().indexOf(q)>-1})})[0];if(q&&hit){openRecipe(hit)}else if(q){toast('No recipe matches "'+q+'" yet')}}});
}
function keep(fn){var y=scr.scrollTop;fn();scr.scrollTop=y}
function openRecipe(id){if(S.recipe!==id||S.screen==='home')loadRecipe(id);go('recipe')}
function openSheet(k){
 var li=lineInfo(k),el=document.getElementById('sheet');
 el.innerHTML='<div class="sheetwrap" data-closesheet="1"><div class="sheet" role="dialog" aria-modal="true" aria-label="Convert '+esc(li.name)+'">'+
  '<div class="between"><div class="row" style="gap:10px">'+(li.icon?icon(li.icon,30):'')+'<h2 class="h2" style="font-size:20px">'+esc(li.name)+'</h2></div><button class="iconbtn" data-closesheet="1" aria-label="Close">'+SVG.close+'</button></div>'+
  (li.check?'<p class="cardnote"><b>From the card:</b> '+esc(li.check)+'</p>':'')+
  '<p class="muted" style="margin:0;font-size:13px">Same amount, shown the way you measure. Your choice sticks for this recipe.</p>'+
  li.opts.map(function(o,i){return '<button class="opt" data-unit="'+k+':'+i+'" aria-pressed="'+(i===li.u)+'"><b>'+esc(o[0])+'</b><span style="font-size:14px;opacity:.75">'+esc(o[1])+'</span></button>'}).join('')+
 '</div></div>';
 var first=el.querySelector('.opt[aria-pressed=true]')||el.querySelector('.opt');if(first)first.focus();
}
function closeSheet(){var el=document.getElementById('sheet');if(el)el.innerHTML='';if(isPad()&&S)S.focus=null}
function speedSeg(){document.getElementById('speedSeg').innerHTML=[1,10,30].map(function(n){return '<button data-speed="'+n+'" aria-pressed="'+(S.speed===n)+'">'+n+'x</button>'}).join('')}
function recipeSeg(){document.getElementById('recipeSeg').innerHTML=RECIPE_ORDER.map(function(id){return '<button data-open="'+id+'" aria-pressed="'+(S.screen!=='home'&&S.recipe===id)+'">'+RECIPES[id].title.split(' ')[0]+'</button>'}).join('')}
document.addEventListener('click',function(e){
 var el=e.target.closest('button,[data-go],[data-closesheet],[data-conv],[data-strike],[data-back],[data-open],[data-focus]');if(!el)return;
 var d=el.dataset;
 if(d.device||d.orient){if(d.device)D.device=d.device;if(d.orient)D.orient=d.orient;closeSheet();S.focus=null;devSeg();fit();keep(render);return}
 if(d.sharefmt){S.share.format=d.sharefmt;openShare(true);return}
 if(d.sharetog){S.share[d.sharetog]=!S.share[d.sharetog];openShare(true);return}
 if(d.jumpstep){S.dir=+d.jumpstep<S.step?-1:1;S.step=+d.jumpstep;dockSig='';render(true);return}
 if(d.closesheet&&(e.target===el||el.classList.contains('iconbtn'))){closeSheet();return}
 if(d.open){openRecipe(d.open);recipeSeg();return}
 if(d.back){if(d.back==='ingredients')S.focus=null;go(d.back,-1);recipeSeg();return}
 if(d.go){if(d.go==='ingredients')S.focus=null;go(d.go);recipeSeg();return}
 if(d.toast){toast(d.toast);return}
 if(d.strike){var on=S.struck[d.strike]=!S.struck[d.strike];el.classList.toggle('struck',on);el.setAttribute('aria-pressed',on);
  var ls=stepLines(STEPS[S.step]),all=ls.every(function(_,j){return S.struck[S.step+':'+j]});
  var nb=scr.querySelector('[data-act="next"]');if(nb)nb.classList.toggle('glow',all);var h=scr.querySelector('.hint');if(h)h.innerHTML=all?'<b style="color:#111">Step done.</b> On to the next one.':'Tap a line to cross it off. Tap an ingredient to change its units.';return}
 if(d.tag){S.tag=d.tag;go('home',-1);recipeSeg();toast('Showing recipes tagged '+d.tag);return}
 if(d.cook){S.cookOpen=S.cookOpen===+d.cook?null:+d.cook;keep(render);return}
 if(d.safe){openSafe(+d.safe);return}
 if(d.dockopen){S.dockOpen=S.dockOpen===d.dockopen?null:d.dockopen;updateTimerDom();return}
 if(d.ttoggle){var tt=S.timers[d.ttoggle];tt.running=!tt.running;updateTimerDom();return}
 if(d.tplus){var tp=S.timers[d.tplus];tp.left+=30;tp.total=Math.max(tp.total,tp.left);updateTimerDom();return}
 if(d.dismiss){S.timers[d.dismiss].ack=true;updateTimerDom();return}
 if(d.conv){openSheet(d.conv);return}
 if(d.unit){var pr=d.unit.split(':');S.units[pr[0]]=+pr[1];closeSheet();keep(render);return}
 if(d.tab){S.tab=d.tab;keep(render);return}
 if(d.serv){S.servings=Math.max(1,Math.min(12,S.servings+(+d.serv)));keep(render);return}
 if(d.mode){S.mode=d.mode;keep(render);return}
 if(d.speed){S.speed=+d.speed;speedSeg();return}
 if(d.focus){if(!SETS[d.focus]){toast('No swaps for '+shownName(ing(d.focus)).toLowerCase()+' yet');return}S.focus=d.focus;S.picked[d.focus]=S.swaps[d.focus]||null;if(isPad()){showSwapModal();return}if(S.screen==='recipe'){S.screen='ingredients';S.dir=1;render(true)}else render();scr.scrollTop=0;return}
 if(d.pick&&isPad()){S.picked[S.focus]=d.pick;showSwapModal(true);var zz=document.querySelector('#sheet .zin');if(zz)zz.classList.remove('zin');return}
 if(d.pick){S.picked[S.focus]=d.pick;keep(render);var z=scr.querySelector('.zin');if(z)z.classList.remove('zin');return}
 if(d.have){S.have[d.have]=!S.have[d.have];keep(render);var c=scr.querySelector('.cst');if(c)c.classList.remove('zout');return}
 if(d.cart){S.cart[d.cart]=!S.cart[d.cart];keep(render);return}
 if(d.rate){S.rating=+d.rate;keep(render);return}
 switch(d.act){
  case 'save':S.saved[R.id]=!S.saved[R.id];keep(render);toast(S.saved[R.id]?'Saved to your recipes':'Removed from saved');break;
  case 'cleartag':S.tag=null;keep(render);break;
  case 'cooksall':S.cooksAll=!S.cooksAll;keep(render);break;
  case 'share':openShare();break;
  case 'sharesend':closeSheet();toast('Sharing is mocked in this prototype');break;
  case 'sharecopy':toast('Copy link is mocked in this prototype');break;
  case 'home':if(isPad()){closeSheet();break}S.focus=null;S.zoom='out';render();scr.scrollTop=0;break;
  case 'use':{var id=S.focus,lf=leafOf(id,S.picked[id]);S.swaps[id]=lf.id;if(isPad()){closeSheet();keep(render);toast(ing(id).name+' → '+lf.name);break}S.focus=null;S.zoom='out';render();scr.scrollTop=0;toast(ing(id).name+' → '+lf.name);break}
  case 'revert':{var id2=S.focus;delete S.swaps[id2];S.picked[id2]=null;if(isPad()){closeSheet();keep(render);toast('Back to '+ing(id2).name.toLowerCase());break}S.focus=null;S.zoom='out';render();toast('Back to '+ing(id2).name.toLowerCase());break}
  case 'shopdone':ING.forEach(function(it){if(S.cart[it.id])S.have[it.id]=true});S.cart={};go(isPad()?'recipe':'ingredients',-1);toast('Shopping done. Everything is ready');break;
  case 'startcook':S.step=0;S.started=Date.now();S.struck={};go('cook');break;
  case 'tstart':{var ts=timerOf(S.step);ts.started=true;ts.running=true;S.dockOpen=null;var c0=scr.querySelector('.startcard');if(c0){c0.style.transition='all .3s';c0.style.transform='translateY(40px) scale(.6)';c0.style.opacity='0';setTimeout(function(){c0.remove();fitSteps()},300)}updateTimerDom();break}
  case 'prev':if(S.step>0){S.step--;dockSig='';S.dir=-1;render(true)}break;
  case 'next':{var cur=S.timers[S.step];if(cur&&cur.left<=0)cur.ack=true;dockSig='';if(S.step<STEPS.length-1){S.step++;S.dir=1;render(true)}else go('done');break}
  case 'finish':(LOG[R.id]=LOG[R.id]||[]).push({date:'Today',who:'You',mins:S.started?Math.max(1,Math.round((Date.now()-S.started)/60000)):0,rating:S.rating,swapList:ING.filter(function(it){return S.swaps[it.id]}).map(function(it){return shownName(it)+' for '+it.name.toLowerCase()}),note:S.note});Object.keys(S.timers).forEach(function(k){S.timers[k].running=false});toast('Saved to your cooking log');setTimeout(function(){go('home',-1);recipeSeg()},900);break;
 }
});
document.addEventListener('keydown',function(e){if(e.key==='Escape')closeSheet();var t=e.target;if((e.key==='Enter'||e.key===' ')&&t.dataset&&(t.dataset.strike||t.dataset.conv||t.dataset.focus)&&t.tagName!=='BUTTON'){e.preventDefault();t.click()}});
document.getElementById('restart').addEventListener('click',function(){closeSheet();seedLog();freshGlobal();loadRecipe('cajun');speedSeg();go('home',-1);recipeSeg()});
speedSeg();recipeSeg();devSeg();fit();render(true);
