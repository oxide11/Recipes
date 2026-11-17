/* ================= THREE MORE OF ASHLEY'S CARDS ================= */
ICON.mince='<path d="M5 17c0-5 4-9 9-9s9 4 9 9c0 3-4 5-9 5s-9-2-9-5z" fill="#B5574A" stroke="#8A3A30" stroke-width="1.2"/><path d="M9 15c1-1 2-1 3 0M14 13c1-1 2-1 3 0M12 18c1-1 2-1 3 0M17 17c1-1 2-1 2 0" stroke="#8A3A30" stroke-width="1.2" fill="none" stroke-linecap="round"/>';
ICON.peas='<circle cx="9" cy="16" r="4.5" fill="#5DAA4A" stroke="#3B7F2E" stroke-width="1.1"/><circle cx="18" cy="13" r="4.5" fill="#6BBB57" stroke="#3B7F2E" stroke-width="1.1"/><rect x="13" y="18" width="7" height="6" rx="1.5" fill="#F58A1F" stroke="#C96A0A" stroke-width="1.1"/>';
ICON.choc='<path d="M14 6c1 4 7 6 7 11a7 7 0 0 1-14 0c0-5 6-7 7-11z" fill="#5A3A22" stroke="#3A2414" stroke-width="1.2"/><path d="M11 17a3 3 0 0 0 2 3" stroke="#8A6444" stroke-width="1.4" fill="none" stroke-linecap="round"/>';
ICON.cheddar='<path d="M4 20L24 9v11z" fill="#F2A93B" stroke="#C47F12" stroke-width="1.2" stroke-linejoin="round"/><circle cx="17" cy="16" r="1.4" fill="#C47F12"/><circle cx="12" cy="18" r="1" fill="#C47F12"/>';

RECIPES.shepherd={
 id:'shepherd',short:'Shepherd’s',title:'Shepherd’s Pie',kicker:'Dinner · From Ashley’s cards',base:6,
 desc:'Browned ground beef in gravy under a layer of peas and carrots, topped with cheesy mashed potatoes and baked until golden.',
 tags:[['Comfort food',1],['Serves a crowd'],['Make ahead'],['Kid friendly']],
 stats:[['25 min','Prep'],['45 min','Cook'],['420','kcal/serving'],['24 g','protein/serving']],
 meta:'1 hr 10 · Medium',plate:'Shepherd’s pie',
 card:{source:'Printed recipe with handwritten changes',credit:'Ashley crossed out the carrots and beef broth and wrote in gravy mix, Worcestershire and frozen peas and carrots.',photos:2,
  questions:['What unit goes with “¼ Worcestershire”? It is shown here as 1 tbsp to be safe.','Does “1 cup” mean prepared brown gravy, or gravy mix plus 1 cup water?','How much frozen peas and carrots? 2 cups is assumed.']},
 ING:[
  IG('potato','Potatoes','#D9B26A','#A9833A',0,1200,1900,920,2.40,'4 large','peeled and cubed',[['potato',4]],'Produce',[24,210,1]),
  IG('butter','Butter','#F7D23A','#C9A800',0,14,15,100,.20,'1 tbsp','for the mash',[['butter',1]],'Dairy and eggs',[.1,0,11]),
  IG('cheddar','Cheddar','#F2A93B','#C47F12',0,56,120,225,1.20,'½ cup','shredded, half in the mash and half on top',[['cheddar',1]],'Dairy and eggs',[14,1,19]),
  IG('onion','Onion','#7A4BB5',null,1,150,240,60,.50,'1 medium','chopped, with 1 tbsp kept fine for the mash',[['onion',1]],'Produce',[1.5,14,0]),
  IG('oil','Vegetable oil','#E8C84A','#B89A1E',1,14,15,120,.10,'1 tbsp','for the pan',[['bottle',1]],'Pantry',[0,0,14]),
  IG('beef','Lean ground beef','#B5574A','#8A3A30',1,454,480,800,6.50,'1 lb','lean',[['mince',2]],'Meat and seafood',[91,0,45],{safe:'beef'}),
  IG('flour','Flour','#E8DFC9','#A89C7E',1,16,30,58,.05,'2 tbsp','all-purpose',[['flour',1]],'Pantry',[1.6,12,.2]),
  IG('ketchup','Ketchup','#D8402F',null,1,17,15,17,.10,'1 tbsp','',[['bottle',1]],'Pantry',[.2,4.5,0]),
  IG('gravy','Brown gravy','#8A5A3A','#5E3B22',1,240,240,60,.80,'1 cup','prepared from gravy mix',[['jug',1]],'Pantry',[2,10,1.5]),
  IG('worcestershire','Worcestershire sauce','#4A2E22',null,1,17,15,13,.15,'1 tbsp','the card says “¼” with no unit',[['bottle',1]],'Pantry',[0,3,0]),
  IG('peas','Frozen peas and carrots','#5DAA4A','#3B7F2E',1,280,480,140,1.50,'2 cups','straight from the freezer',[['peas',2]],'Canned',[8,26,1])
 ],
 have:{butter:1,oil:1,flour:1,ketchup:1,worcestershire:1,onion:1},
 GROUPS:[{name:'Mash',color:'#D9B26A',op:.3},{name:'Beef layer',color:'#B5574A',op:.25}],
 INS:{weight:['Potatoes are half the dish by weight.','Four large ones make a thick topping for a 2-quart dish.'],
  volume:['The mash is nearly two thirds of the volume.','Spread it right to the edges so the gravy does not bubble over.'],
  cost:['Ground beef is about half the cost.','Lentils or ground turkey bring it down.'],
  calories:['Beef and potatoes are over two thirds of the calories.','Pouring off the fat after browning takes out more than the cheese adds.']},
 LINE:{
  potato:{ing:'potato',noun:'potatoes, peeled and cubed',opts:[['4 large','potatoes'],['1.2 kg','kilograms'],['2⅔ lb','pounds']]},
  butter:{ing:'butter',noun:'butter',opts:[['1 tbsp','tablespoon'],['14 g','grams']]},
  onionfine:{ing:'onion',noun:'finely chopped onion',opts:[['1 tbsp','finely chopped'],['10 g','grams']]},
  cheddarmash:{ing:'cheddar',noun:'shredded Cheddar',opts:[['¼ cup','shredded'],['28 g','grams'],['1 oz','ounce']]},
  salt:SALT_LINE('to taste','a pinch'),pepper:PEP_LINE('to taste'),
  oil:{ing:'oil',noun:'vegetable oil',opts:[['1 tbsp','tablespoon'],['15 ml','millilitres']]},
  onion:{ing:'onion',noun:'onion, chopped',opts:[['1','medium onion'],['1 cup','chopped'],['150 g','grams']]},
  beef:{ing:'beef',noun:'lean ground beef',opts:[['1 lb','pound'],['454 g','grams']]},
  flour:{ing:'flour',noun:'flour',opts:[['2 tbsp','tablespoons'],['16 g','grams']]},
  ketchup:{ing:'ketchup',noun:'ketchup',opts:[['1 tbsp','tablespoon'],['17 g','grams']]},
  gravy:{ing:'gravy',noun:'brown gravy',check:'The card says “1 cup” beside gravy mix and water. It could mean 1 cup of prepared gravy, or the mix plus 1 cup of water. Prepared gravy is assumed.',opts:[['1 cup','prepared'],['240 ml','millilitres']]},
  worcestershire:{ing:'worcestershire',noun:'Worcestershire sauce',check:'The card says “¼” with no unit. It is shown as 1 tbsp to be safe; ¼ cup is the other reading. Taste and add more.',opts:[['1 tbsp','tablespoon'],['15 ml','millilitres']]},
  peas:{ing:'peas',noun:'frozen peas and carrots',check:'The card gives no amount. 2 cups makes an even layer in a 2-quart dish.',opts:[['2 cups','frozen'],['280 g','grams']]},
  cheddartop:{ing:'cheddar',noun:'shredded Cheddar',opts:[['¼ cup','shredded'],['28 g','grams'],['1 oz','ounce']]}
 },
 STEPS:[
  {title:'Boil the {potato!}',secs:900,on:5,label:'Potatoes',lines:['Bring a large pot of salted water to a boil.','Cook {potato} until tender but still firm, about 15 minutes.','Drain and mash.']},
  {title:'Finish the mash',secs:0,on:3,lines:['Mix in {butter}, {onionfine} and {cheddarmash}.','Season with {salt} and {pepper}.','Set aside.']},
  {title:'Heat the oven',secs:0,on:1,lines:['Heat the oven to 375°F (190°C).']},
  {title:'Brown the {beef!}',protein:'beef',secs:0,on:10,lines:['Heat {oil} in a large frying pan.','Add {onion} and cook until clear.','Add {beef} and cook until well browned.','Pour off the excess fat.']},
  {title:'Make the gravy',secs:300,on:3,label:'Gravy simmer',lines:['Stir in {flour} and cook 1 minute.','Add {ketchup}, {gravy} and {worcestershire}.','Bring to a boil, then reduce the heat and simmer 5 minutes.']},
  {title:'Layer the dish',secs:0,on:3,lines:['Spread the beef evenly in a 2-quart casserole dish.','Add a layer of {peas}.']},
  {title:'Top with mash',secs:0,on:3,lines:['Top with the mashed potatoes.','Sprinkle with {cheddartop}.']},
  {title:'Bake',secs:1200,on:1,label:'Pie baking',lines:['Bake 20 minutes, or until golden brown.']}
 ],
 SETS:{
  beef:SN('Lean ground beef',['Closest','Meat-free'],['Rich','Savoury','Protein'],[
   ['lamb','Ground lamb','1 : 1','The traditional choice. Richer, so pour off the fat well.',[5,5,4],[1280,75,0,106],{safe:'beef'}],
   ['gturkey','Ground turkey','1 : 1','Leaner and milder. Add an extra splash of Worcestershire.',[2,3,5],[680,88,0,36],{safe:'poultry'}],
   ['lentils','Brown lentils','2 cans','Drained. Meat-free and hearty. Skip the browning; warm through in the gravy.',[2,3,3],[640,48,110,2],{safe:'none'}],
   ['mushmince','Chopped mushrooms','1 lb','Savoury and meat-free, but you avoid mushrooms.',[2,4,1],[100,14,15,1.5],{dislike:'Mushrooms',safe:'none'}]]),
  potato:SN('Potatoes',['Closest','Lighter'],['Creamy','Holds shape','Sweet'],[
   ['yukon','Yukon Gold','1 : 1','Buttery mash. No need to peel.',[5,3,2],[920,24,210,1]],
   ['sweetp','Sweet potato','1 : 1','Sweeter and softer. Boil 12 minutes.',[4,2,5],[1030,19,240,1]],
   ['cauli2','Cauliflower','1 large head','Much lighter mash. Drain it very well.',[2,1,1],[210,16,42,2.5]],
   ['halfcauli','Potato and cauliflower','1 : 1','Swap 2 of the potatoes for ½ head of cauliflower. Lighter, still tastes like mash.',[4,2,2],[565,20,126,2]]]),
  peas:SN('Frozen peas and carrots',['Closest','From the card'],['Sweet','Colour','Texture'],[
   ['corn','Frozen corn','1 : 1','Sweeter. The classic cottage pie layer.',[5,3,3],[250,9,58,2]],
   ['mixedveg','Frozen mixed vegetables','1 : 1','Adds green beans and corn.',[3,4,3],[180,9,36,1]],
   ['mashcarrot','Mashed carrots','2 cups','About 5 carrots, boiled and mashed. What the printed card called for before Ashley changed it.',[4,3,2],[125,3,29,.7]],
   ['greenbeans','Green beans','1 : 1','Less sweet, more bite.',[1,3,5],[90,5,20,.5]]]),
  gravy:SN('Brown gravy',['Closest','From the card'],['Savoury','Body','Salt'],[
   ['broth','Beef broth','¾ cup','What the printed card called for. Thinner, so simmer a little longer.',[3,2,3],[12,2,1,.4]],
   ['mushgravy','Mushroom gravy','1 : 1','Earthy and rich, but you avoid mushrooms.',[5,4,3],[80,2,10,4],{dislike:'Mushrooms'}],
   ['oniongravy','Onion gravy','1 : 1','Sweeter and deeper.',[4,4,3],[70,2,11,2]],
   ['vegbroth','Vegetable broth','¾ cup','Lighter and meat-free.',[2,2,2],[10,.5,2,0]]])
 }
};

RECIPES.cookies={
 id:'cookies',short:'Cookies',title:'Chocolate Chip Cookies',kicker:'Baking · From Ashley’s cards',base:24,
 desc:'Classic drop cookies: dry and wet ingredients mixed in separate bowls, combined, spooned onto a sheet and baked for about 10 minutes.',
 tags:[['Baking',1],['30 min or less'],['Kid friendly'],['Make ahead']],
 stats:[['15 min','Prep'],['10 min','Bake'],['235','kcal/serving'],['2 g','protein/serving']],
 meta:'25 min · Easy',plate:'Chocolate chip cookies',
 card:{source:'Handwritten card',credit:'Makes about 24 cookies, so one serving here is one cookie. The card does not give a yield.',photos:1,
  questions:['Are the flour and both sugars measured in cups? Cups are assumed.','Is the oven temperature 375°F? Fahrenheit is assumed.']},
 ING:[
  IG('flour','Flour','#E8DFC9','#A89C7E',0,280,530,1020,.60,'2¼ cups','all-purpose',[['flour',2]],'Dry goods',[29,214,3]),
  IG('soda','Baking soda','#D9D9D4','#8A8A85',0,5,5,0,.05,'1 tsp','',[['jar',1]],'Dry goods',[0,0,0]),
  IG('butter','Butter','#F7D23A','#C9A800',1,226,240,1620,2.40,'2 sticks','softened',[['butter',2]],'Dairy and eggs',[2,0,184]),
  IG('sugar','Sugar','#F3EEDF','#A89C7E',1,150,180,580,.30,'¾ cup','white, granulated',[['sugar',1]],'Dry goods',[0,150,0]),
  IG('brown','Brown sugar','#B8834A','#8A5E2E',1,165,180,630,.45,'¾ cup','packed',[['sugar',1]],'Dry goods',[0,162,0]),
  IG('vanilla','Vanilla','#5E3B22',null,1,4,5,12,.40,'1 tsp','extract',[['bottle',1]],'Dry goods',[0,.5,0]),
  IG('eggs','Eggs','#F4E3C1','#C9A86A',1,100,100,143,.70,'2','large',[['egg',2]],'Dairy and eggs',[12.5,.7,9.5],{safe:'none'}),
  IG('chips','Chocolate chips','#5A3A22','#3A2414',2,340,480,1630,3.50,'2 cups','semi-sweet',[['choc',3]],'Dry goods',[14,214,96])
 ],
 have:{flour:1,soda:1,sugar:1,vanilla:1,eggs:1},
 GROUPS:[{name:'Dry bowl',color:'#E8DFC9',op:.6},{name:'Wet bowl',color:'#F7D23A',op:.3},{name:'Chips',color:'#5A3A22',op:.25}],
 INS:{weight:['Chocolate chips are the single heaviest ingredient.','At 2 cups there are more chips than flour by weight.'],
  volume:['Flour is the biggest ingredient by volume.','Spoon it into the cup and level it so the cookies do not turn out dry.'],
  cost:['Chips and butter are about 70% of the cost.','Both are worth buying well; they are most of the flavour.'],
  calories:['Butter and chocolate chips are nearly 60% of the calories.','Using 1½ cups of chips takes about 17 kcal off each cookie.']},
 LINE:{
  flour:{ing:'flour',noun:'flour',check:'The card says “2¼ flour” with no unit. Cups are assumed.',opts:[['2¼ cups','all-purpose'],['280 g','grams']]},
  soda:{ing:'soda',noun:'baking soda',opts:[['1 tsp','teaspoon'],['5 g','grams']]},
  salt:SALT_LINE('1 tsp','6 g'),
  butter:{ing:'butter',noun:'butter',opts:[['2 sticks','US sticks'],['1 cup','softened'],['226 g','grams']]},
  sugar:{ing:'sugar',noun:'sugar',check:'The card says “¾ sugar” with no unit. Cups are assumed.',opts:[['¾ cup','granulated'],['150 g','grams']]},
  brown:{ing:'brown',noun:'brown sugar',check:'The card says “¾ brown sugar” with no unit. Cups are assumed.',opts:[['¾ cup','packed'],['165 g','grams']]},
  vanilla:{ing:'vanilla',noun:'vanilla',opts:[['1 tsp','teaspoon'],['5 ml','millilitres']]},
  eggs:{ing:'eggs',noun:'eggs',opts:[['2','large eggs'],['100 g','grams, shelled']]},
  chips:{ing:'chips',noun:'chocolate chips',opts:[['2 cups','semi-sweet'],['340 g','grams'],['12 oz','one standard bag']]}
 },
 STEPS:[
  {title:'Heat the oven',secs:0,on:1,flag:'The card says “375°” with no unit. Fahrenheit is assumed.',lines:['Heat the oven to 375°F (190°C).']},
  {title:'Mix the dry bowl',secs:0,on:2,lines:['Combine {flour}, {soda} and {salt} in one bowl.']},
  {title:'Mix the wet bowl',secs:0,on:4,lines:['In another bowl, mix {butter}, {sugar} and {brown}.','Add {vanilla} and {eggs}.']},
  {title:'Combine',secs:0,on:3,flag:'The card does not say when the chocolate chips go in. Stirring them in last is assumed.',lines:['Combine the wet and dry ingredients.','Stir in {chips}.']},
  {title:'Shape',secs:0,on:4,lines:['Form rounded spoonfuls on a baking sheet.']},
  {title:'Bake',secs:600,on:1,label:'Cookies',lines:['Bake 9 to 11 minutes.','Cool.']}
 ],
 SETS:{
  chips:SN('Chocolate chips',['Closest','Different'],['Sweet','Melt','Bite'],[
   ['darkchunks','Dark chocolate chunks','1 : 1','Less sweet, bigger pools of chocolate.',[2,5,3],[1700,20,160,130]],
   ['milkchips','Milk chocolate chips','1 : 1','Sweeter and creamier.',[5,4,2],[1820,26,202,102]],
   ['raisins','Raisins','1½ cups','Chewy and fruity. Much lighter.',[4,1,4],[650,7,172,1]],
   ['walnuts','Chopped walnuts','1 cup','Use alongside 1 cup of chips. Crunchy, but they are tree nuts.',[1,1,5],[1580,25,120,120],{allergen:'Tree nuts'}]]),
  butter:SN('Butter',['Closest','Dairy-free'],['Flavour','Spread','Richness'],[
   ['marg3','Margarine','1 : 1','Use sticks, not tub. Cookies spread a little more.',[2,4,4],[1600,0,0,180]],
   ['shortening','Shortening','1 : 1','Taller, softer cookies with less flavour.',[1,1,4],[2000,0,0,226]],
   ['vegb3','Vegan butter','1 : 1','Sticks bake most like butter.',[3,3,4],[1580,0,0,178]],
   ['coconutoil','Coconut oil','¾ cup','Use it solid. Crisper edges and a light coconut note.',[3,5,5],[1440,0,0,164]]]),
  eggs:SN('Eggs',['Closest','Egg-free'],['Binding','Lift','Moisture'],[
   ['flaxegg','Flax eggs','1 : 1','Each is 1 tbsp ground flax in 3 tbsp water, rested 5 minutes. Chewier.',[4,2,4],[75,2.5,4,6]],
   ['applesauce','Applesauce','½ cup','Softer, cakier cookies.',[2,2,5],[50,0,14,0]],
   ['yogurt','Plain yogurt','½ cup','Tender, with a slight tang.',[3,2,5],[75,4,6,4]],
   ['eggrep','Egg replacer','enough for 2 eggs of','Follow the box. Closest to the original texture.',[4,4,3],[30,0,8,0]]]),
  flour:SN('Flour',['Closest','Gluten-free'],['Structure','Chew','Flavour'],[
   ['breadflour','Bread flour','1 : 1','Chewier cookies.',[5,5,3],[1010,36,203,4]],
   ['halfww','Half whole wheat flour','1 : 1','Half all-purpose, half whole wheat. Nuttier and a little denser.',[4,3,5],[985,33,208,5]],
   ['gfblend','Gluten-free 1:1 blend','1 : 1','Rest the dough 20 minutes before baking.',[3,2,3],[1000,14,224,3]],
   ['oatflour','Oat flour','2½ cups','Softer and more crumbly.',[2,3,4],[1010,37,165,23]]])
 }
};

RECIPES.pancakes={
 id:'pancakes',short:'Pancakes',title:'Pancakes',kicker:'Breakfast · From Ashley’s cards',base:4,
 desc:'Milk soured with vinegar stands in for buttermilk, then gets mixed into a simple batter and cooked on a hot pan.',
 tags:[['Breakfast',1],['30 min or less'],['Kid friendly']],
 stats:[['10 min','Prep'],['10 min','Cook'],['235','kcal/serving'],['6 g','protein/serving']],
 meta:'20 min · Easy',plate:'Pancakes',
 card:{source:'Handwritten card',credit:'About 8 pancakes, 2 per serving. The card also has a highlighted smaller-batch column that is not an exact half; it is not shown here.',photos:1,
  questions:['Is the milk ¾ cup? The card gives no unit.','How are these cooked? The card only says “Cook”.','Please confirm the highlighted smaller-batch column: ½ milk, ¾ flour.']},
 ING:[
  IG('milk','Milk','#F3EEDF','#A89C7E',1,180,180,110,.35,'¾ cup','any kind',[['jug',1]],'Dairy and eggs',[6,9,6]),
  IG('vinegar','Vinegar','#DCE9C8','#9CBF5A',1,30,30,5,.05,'2 tbsp','white',[['bottle',1]],'Pantry',[0,0,0]),
  IG('flour','Flour','#E8DFC9','#A89C7E',0,125,240,455,.25,'1 cup','all-purpose',[['flour',1]],'Dry goods',[13,95,1]),
  IG('sugar','Sugar','#F3EEDF','#A89C7E',0,25,30,97,.05,'2 tbsp','',[['sugar',1]],'Dry goods',[0,25,0]),
  IG('bpowder','Baking powder','#D9D9D4','#8A8A85',0,5,5,2,.05,'1 tsp','',[['jar',1]],'Dry goods',[0,1,0]),
  IG('bsoda','Baking soda','#C9C9C4','#8A8A85',0,3,3,0,.03,'½ tsp','',[['jar',1]],'Dry goods',[0,0,0]),
  IG('egg','Egg','#F4E3C1','#C9A86A',1,50,50,72,.35,'1','large',[['egg',1]],'Dairy and eggs',[6.3,.4,4.8],{safe:'none'}),
  IG('butter','Butter','#F7D23A','#C9A800',1,28,30,200,.35,'2 tbsp','melted',[['butter',1]],'Dairy and eggs',[.2,0,23])
 ],
 have:{vinegar:1,flour:1,sugar:1,bpowder:1,bsoda:1,egg:1,butter:1},
 GROUPS:[{name:'Dry mix',color:'#E8DFC9',op:.6},{name:'Wet mix',color:'#F7D23A',op:.3}],
 INS:{weight:['Milk and flour are about 70% of the batter.','The ratio is what sets the thickness; add a splash of milk for thinner pancakes.'],
  volume:['Flour is the largest ingredient by volume.','Stir just until combined. Lumps are fine.'],
  cost:['The whole batch costs about $1.50.','Milk, egg and butter are most of it.'],
  calories:['Flour is nearly half the calories.','The butter is a fifth; cooking in a non-stick pan lets you leave some out.']},
 LINE:{
  milk:{ing:'milk',noun:'milk',check:'The card says “¾ milk” with no unit. A cup measure is assumed.',opts:[['¾ cup','cups'],['180 ml','millilitres'],['6 fl oz','US fluid ounces']]},
  vinegar:{ing:'vinegar',noun:'vinegar',opts:[['2 tbsp','tablespoons'],['30 ml','millilitres']]},
  flour:{ing:'flour',noun:'flour',opts:[['1 cup','all-purpose'],['125 g','grams']]},
  sugar:{ing:'sugar',noun:'sugar',opts:[['2 tbsp','tablespoons'],['25 g','grams']]},
  bpowder:{ing:'bpowder',noun:'baking powder',opts:[['1 tsp','teaspoon'],['5 g','grams']]},
  bsoda:{ing:'bsoda',noun:'baking soda',opts:[['½ tsp','teaspoon'],['3 g','grams']]},
  salt:SALT_LINE('½ tsp','3 g'),
  egg:{ing:'egg',noun:'egg',opts:[['1','large egg'],['50 g','grams, shelled']]},
  butter:{ing:'butter',noun:'butter, melted',opts:[['2 tbsp','tablespoons'],['28 g','grams'],['¼ stick','US stick']]}
 },
 STEPS:[
  {title:'Sour the {milk!}',secs:300,on:1,label:'Sour milk',lines:['Mix {milk} and {vinegar}.','Leave 5 minutes.']},
  {title:'Mix the dry',secs:0,on:2,lines:['Combine {flour}, {sugar}, {bpowder}, {bsoda} and {salt}.']},
  {title:'Make the batter',secs:0,on:3,flag:'The card lists butter but does not say where it goes. Stirring it into the wet ingredients, melted, is assumed.',lines:['Add {egg} to the sour milk.','Stir in {butter}.','Add the wet ingredients to the dry.']},
  {title:'Cook',secs:0,on:10,flag:'The card only says “Cook”. A hot, lightly greased pan and about 2 minutes a side is assumed.',lines:['Cook on a hot pan until golden on both sides.']}
 ],
 SETS:{
  milk:SN('Milk',['Closest','Dairy-free'],['Tang','Richness','Sweet'],[
   ['buttermilk','Buttermilk','1 : 1','What the soured milk stands in for. Leave out the vinegar and the wait.',[5,3,2],[75,6,9,1.5]],
   ['yogurtmilk','Thinned yogurt','1 : 1','Two parts yogurt to one part milk. Leave out the vinegar.',[4,4,2],[110,7,9,5]],
   ['oatmilk','Oat milk','1 : 1','Sours less, but still works with the vinegar.',[2,2,4],[90,2,12,4]],
   ['almondmilk','Almond milk','1 : 1','Light, but made from almonds.',[1,1,2],[30,1,1,2.5],{allergen:'Tree nuts'}]]),
  egg:SN('Egg',['Closest','Egg-free'],['Binding','Lift','Moisture'],[
   ['flaxegg1','Flax egg','1 : 1','1 tbsp ground flax in 3 tbsp water, rested 5 minutes. Slightly denser.',[4,2,4],[37,1.3,2,3]],
   ['banana','Mashed banana','½','Sweeter and softer. Browns faster.',[3,2,5],[52,.6,13,.2]],
   ['applesauce1','Applesauce','¼ cup','Tender, with a mild fruit note.',[2,2,5],[25,0,7,0]],
   ['eggwhites','Egg whites','2','Lighter and a bit fluffier.',[4,5,3],[34,7,.5,0]]]),
  flour:SN('Flour',['Closest','Gluten-free'],['Fluffy','Hearty','Flavour'],[
   ['halfww1','Half whole wheat flour','1 : 1','Half all-purpose, half whole wheat. Nuttier and more filling.',[3,4,4],[440,15,93,1.5]],
   ['spelt','Spelt flour','1 : 1','Slightly sweet and nutty.',[3,4,5],[420,18,88,3]],
   ['gfblend1','Gluten-free 1:1 blend','1 : 1','Rest the batter 10 minutes.',[3,2,3],[445,6,100,1.5]],
   ['oatflour1','Oat flour','1¼ cups','Tender and hearty.',[2,5,4],[505,18,82,11]]]),
  butter:SN('Butter',['Closest','Dairy-free'],['Flavour','Richness','Crisp edge'],[
   ['brownb','Browned butter','1 : 1','Nutty and deeper. Cool it slightly first.',[5,4,3],[200,.2,0,23]],
   ['vegoil','Vegetable oil','1 : 1','Neutral, and one less pan to melt.',[1,3,3],[240,0,0,28]],
   ['coconutoil1','Coconut oil','1 : 1','Crisper edges and a light coconut note.',[3,4,5],[235,0,0,27]],
   ['vegb4','Vegan butter','1 : 1','Behaves like butter.',[3,3,3],[195,0,0,22]]])
 }
};
RECIPE_ORDER=['cajun','scampi','thai','hamsoup','piccata','potpie','shepherd','cookies','pancakes'];
