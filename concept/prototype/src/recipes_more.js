/* ================= MORE OF ASHLEY'S CARDS ================= */
function IG(id,name,color,edge,g,w,v,cal,cost,amt,eq,icon,aisle,macro,extra){var o={id:id,name:name,color:color,g:g,weight:w,volume:v,calories:cal,cost:cost,amt:amt,eq:eq,icon:icon,aisle:aisle,macro:macro};if(edge)o.edge=edge;if(extra){for(var k in extra)o[k]=extra[k]}return o}
function SN(center,branches,traits,rows){return {center:center,branches:branches,traits:traits,leaves:rows.map(function(x){var e=x[6]||{};e.nut=x[5];return L(x[0],x[1],x[2],x[3],x[4],e)})}}
var SALT_LINE=function(q,g){return {name:'Salt',noun:'salt',color:'#8A8A85',icon:'salt',opts:[[q,'fine salt'],[g,'grams']]}};
var PEP_LINE=function(q){return {name:'Pepper',noun:'pepper',color:'#3A3A38',icon:'salt',opts:[[q,'ground'],['a few grinds','fresh']]}};
ICON.potato='<ellipse cx="14" cy="15" rx="10" ry="8" fill="#D9B26A" stroke="#A9833A" stroke-width="1.2" transform="rotate(-15 14 15)"/><circle cx="10" cy="13" r="1" fill="#A9833A"/><circle cx="16" cy="17" r="1" fill="#A9833A"/><circle cx="18" cy="12" r=".8" fill="#A9833A"/>';
ICON.celery='<path d="M9 26c-1-8 0-15 3-21M14 26c0-8 0-15 1-22M19 26c1-8 0-14-2-20" stroke="#9CBF5A" stroke-width="3.4" fill="none" stroke-linecap="round"/><path d="M11 5c-2-1-4 0-5 2M16 4c2-2 5-1 6 1" stroke="#2E9E4F" stroke-width="2" fill="none" stroke-linecap="round"/>';
ICON.ham='<rect x="5" y="9" width="10" height="10" rx="2" fill="#E89AA0" stroke="#C56A72" stroke-width="1.2"/><rect x="13" y="13" width="10" height="10" rx="2" fill="#F0B1B6" stroke="#C56A72" stroke-width="1.2"/><rect x="12" y="4" width="8" height="8" rx="2" fill="#E89AA0" stroke="#C56A72" stroke-width="1.2"/>';
ICON.carrot='<path d="M9 9l12 6-14 9c-2-5-1-11 2-15z" fill="#F58A1F"/><path d="M9 9c0-3 2-5 4-6M9 9c-2-2-5-2-6-1M9 9c1-3 0-5-1-6" stroke="#2E9E4F" stroke-width="2" fill="none" stroke-linecap="round"/><path d="M11 14l3 1M10 18l3 1" stroke="#C96A0A" stroke-width="1"/>';
ICON.pie='<ellipse cx="14" cy="16" rx="11" ry="7" fill="#D9A55B" stroke="#A9773A" stroke-width="1.3"/><ellipse cx="14" cy="14.5" rx="8.5" ry="4.8" fill="#EBC27E"/><path d="M11 13l1 3M14 12.5v3.5M17 13l-1 3" stroke="#A9773A" stroke-width="1.2" stroke-linecap="round"/>';
ICON.drop='<path d="M14 3c4 6 8 10 8 15a8 8 0 0 1-16 0c0-5 4-9 8-15z" fill="#BFD9E8" stroke="#7FA9C2" stroke-width="1.3"/><path d="M10 18a4 4 0 0 0 3 4" stroke="#fff" stroke-width="1.6" fill="none" stroke-linecap="round"/>';

RECIPES.hamsoup={
 id:'hamsoup',short:'Ham soup',title:'Ham & Potato Soup',kicker:'Lunch · From Ashley’s cards',base:6,
 desc:'Diced potatoes, celery, onion and ham simmered until tender, then thickened with a quick butter, flour and milk sauce.',
 tags:[['Comfort food',1],['Weeknight'],['Kid friendly']],
 stats:[['10 min','Prep'],['25 min','Cook'],['260','kcal / serving'],['9 g','protein / serving']],
 meta:'35 min · Easy',plate:'Ham and potato soup',
 card:{source:'Printed recipe',credit:'Makes about 6 bowls. The card does not give a yield.',photos:1,questions:[]},
 ING:[
  IG('potato','Potatoes','#D9B26A','#A9833A',0,525,830,400,1.50,'3½ cups','peeled and diced, about 4 medium',[['potato',4]],'Produce',[10,91,.5]),
  IG('celery','Celery','#9CBF5A',null,0,35,80,5,.30,'⅓ cup','diced, about 1 stalk',[['celery',1]],'Produce',[.2,1,0]),
  IG('onion','Onion','#7A4BB5',null,0,50,80,20,.20,'⅓ cup','finely chopped, about ½ small',[['onion',1]],'Produce',[.5,4.5,0]),
  IG('ham','Cooked ham','#E89AA0','#C56A72',0,105,180,150,2.50,'¾ cup','diced',[['ham',1]],'Meat and seafood',[21,1.5,6]),
  IG('water','Water','#BFD9E8','#7FA9C2',0,770,770,0,0,'3¼ cups','from the tap',[['drop',1]],'Pantry',[0,0,0]),
  IG('bouillon','Chicken bouillon','#F58A1F',null,0,24,30,40,.40,'2 tbsp','granules',[['jar',1]],'Pantry',[2,5,1]),
  IG('butter','Butter','#F7D23A','#C9A800',1,70,75,500,.90,'5 tbsp','a little over half a stick',[['butter',2]],'Dairy and eggs',[.6,0,57]),
  IG('flour','Flour','#E8DFC9','#A89C7E',1,40,75,145,.10,'5 tbsp','all-purpose',[['flour',1]],'Pantry',[4,30,.4]),
  IG('milk','Milk','#F3EEDF','#A89C7E',1,490,480,300,1.00,'2 cups','any kind',[['jug',2]],'Dairy and eggs',[16,24,16])
 ],
 have:{water:1,bouillon:1,butter:1,flour:1,milk:1,onion:1},
 GROUPS:[{name:'Pot',color:'#D9B26A',op:.3},{name:'Milk sauce',color:'#F3EEDF',op:.7}],
 INS:{weight:['Water, potatoes and milk are 85% of the pot.','The ham is only 5% by weight but carries most of the flavour.'],
  volume:['Potatoes are a third of the volume.','Dice them evenly so they cook in the same 10 to 15 minutes.'],
  cost:['Ham is about 36% of the cost.','It is a good home for leftover ham.'],
  calories:['Butter is 3% of the weight but 32% of the calories.','Use 3 tbsp butter and 3 tbsp flour for a lighter, thinner soup.']},
 LINE:{
  potato:{ing:'potato',noun:'diced potatoes',opts:[['3½ cups','peeled and diced'],['525 g','grams'],['4 medium','potatoes','p','potatoes, diced']]},
  celery:{ing:'celery',noun:'diced celery',opts:[['⅓ cup','diced'],['35 g','grams'],['1 stalk','celery','p','celery, diced']]},
  onion:{ing:'onion',noun:'chopped onion',opts:[['⅓ cup','finely chopped'],['50 g','grams']]},
  ham:{ing:'ham',noun:'diced cooked ham',opts:[['¾ cup','diced'],['105 g','grams'],['3.7 oz','ounces']]},
  water:{ing:'water',noun:'water',opts:[['3¼ cups','cups'],['770 ml','millilitres']]},
  bouillon:{ing:'bouillon',noun:'chicken bouillon granules',opts:[['2 tbsp','granules'],['24 g','grams'],['6 cubes','crumbled','p','bouillon cubes']]},
  salt:SALT_LINE('½ tsp','3 g'),pepper:PEP_LINE('1 tsp'),
  butter:{ing:'butter',noun:'butter',opts:[['5 tbsp','tablespoons'],['70 g','grams'],['⅓ cup','scant']]},
  flour:{ing:'flour',noun:'flour',opts:[['5 tbsp','tablespoons'],['40 g','grams'],['⅓ cup','scant']]},
  milk:{ing:'milk',noun:'milk',opts:[['2 cups','cups'],['480 ml','millilitres'],['16 fl oz','US fluid ounces']]}
 },
 STEPS:[
  {title:'Boil the vegetables',secs:780,on:5,label:'Potatoes',lines:['Put {potato}, {celery}, {onion} and {ham} in a stockpot.','Add {water} and bring to a boil.','Cook over medium heat until the potatoes are tender, 10 to 15 minutes.']},
  {title:'Season',secs:0,on:1,lines:['Stir in {bouillon}, {salt} and {pepper}.']},
  {title:'Make the roux',secs:60,on:2,label:'Roux',lines:['Melt {butter} in a saucepan over medium-low heat.','Whisk in {flour} with a fork.','Cook, stirring constantly, until thick, about 1 minute.']},
  {title:'Add the milk',secs:270,on:5,label:'Milk sauce',lines:['Slowly stir in {milk}, avoiding lumps.','Stir over medium-low heat until thick, 4 to 5 minutes.']},
  {title:'Combine and serve',secs:0,on:2,lines:['Stir the milk mixture into the stockpot.','Heat through and serve right away.']}
 ],
 SETS:{
  ham:SN('Cooked ham',['Closest','No pork'],['Smoky','Salty','Meaty'],[
   ['bacon','Bacon','6 slices, cooked','Smokier and crisp. Crumble it in at the end.',[5,4,3],[260,18,1,20]],
   ['kielbasa','Kielbasa','¾ cup, sliced','Garlicky and rich. Brown it first.',[4,4,5],[330,14,3,29]],
   ['smturkey','Smoked turkey','¾ cup','Leaner, same smoky note.',[3,3,4],[115,20,1,3]],
   ['wbeans','White beans','1 can','Meat-free and creamy.',[1,1,3],[300,20,54,1]]]),
  milk:SN('Milk',['Closest','Dairy-free'],['Richness','Body','Sweet'],[
   ['halfhalf2','Half-and-half','1 : 1','Richer and silkier.',[4,4,2],[630,14,20,56]],
   ['evap2','Evaporated milk','1 : 1','Creamy from the pantry.',[3,4,3],[640,33,48,36]],
   ['oatmilk','Oat milk','1 : 1','Unsweetened. Naturally a little sweet.',[2,3,4],[240,6,32,10]],
   ['almondmilk','Almond milk','1 : 1','Light, but made from almonds.',[1,1,2],[80,2,3,6],{allergen:'Tree nuts'}]]),
  potato:SN('Potatoes',['Closest','Lighter'],['Creamy','Holds shape','Sweet'],[
   ['yukon','Yukon Gold','1 : 1','Buttery and creamy. No need to peel.',[5,3,2],[400,10,91,.5]],
   ['redpot','Red potatoes','1 : 1','Hold their shape. Leave the skins on.',[3,5,2],[370,10,84,.5]],
   ['sweetp','Sweet potato','1 : 1','Sweeter. Cooks a few minutes faster.',[4,2,5],[450,8,105,.3]],
   ['cauli2','Cauliflower','1 : 1','Much lighter. Cook 8 minutes.',[2,2,1],[130,10,26,1.5]]]),
  butter:SN('Butter',['Closest','Dairy-free'],['Flavour','Heat limit','Richness'],[
   ['marg2','Margarine','1 : 1','Works the same in the roux.',[2,3,4],[500,0,0,56]],
   ['bacfat','Bacon fat','1 : 1','Smoky and savoury.',[5,4,5],[620,0,0,70]],
   ['oo3','Olive oil','4 tbsp','Makes a looser roux. Whisk well.',[3,3,3],[480,0,0,54]],
   ['vegb2','Vegan butter','1 : 1','Melts and thickens like butter.',[3,3,4],[490,0,0,55]]]),
  bouillon:SN('Chicken bouillon',['Closest','Vegetarian'],['Savoury','Salt','Depth'],[
   ['brothw','Chicken broth','3¼ cups, in place of the water','Skip the granules and the water.',[4,3,4],[35,4,3,1]],
   ['btb','Bouillon paste','1 tbsp','Rounder flavour than granules.',[5,4,5],[30,2,3,1]],
   ['vegbou','Vegetable bouillon','2 tbsp','Lighter and meat-free.',[3,4,3],[35,1,6,1]],
   ['misob','White miso','2 tbsp','Savoury and mellow. Stir in at the end.',[4,3,4],[70,4,9,2]]])
 }
};

RECIPES.potpie={
 id:'potpie',short:'Pot pie',title:'Delicious Chicken Pot Pie',kicker:'Dinner · From Ashley’s cards',base:6,
 desc:'Sautéed vegetables and cooked chicken in a creamy sauce, poured into a casserole dish, topped with pie crust and baked until golden.',
 tags:[['Serves a crowd',1],['Comfort food'],['Make ahead'],['Kid friendly']],
 stats:[['1 hr','Prep'],['45 min','Bake'],['645','kcal / serving'],['35 g','protein / serving']],
 meta:'1 hr 45 · Medium',plate:'Chicken pot pie',
 card:{source:'Printed recipe',credit:'vincy bramblett, Aug 2001. Serves 6 to 8. Prep 1 hour, total 1 hour 45 min.',photos:1,questions:[]},
 ING:[
  IG('onion','Onions','#7A4BB5',null,0,160,240,64,.50,'1 cup','diced, about 1 medium',[['onion',1]],'Produce',[1.8,15,0]),
  IG('celery','Celery','#9CBF5A',null,0,100,240,16,.50,'1 cup','diced, about 3 stalks',[['celery',3]],'Produce',[.7,3,0]),
  IG('carrot','Carrots','#F58A1F',null,0,130,240,53,.40,'1 cup','diced, about 2 medium',[['carrot',2]],'Produce',[1.2,12,0]),
  IG('potato','Potatoes','#D9B26A','#A9833A',0,150,240,115,.40,'1 cup','diced, about 1 medium',[['potato',1]],'Produce',[3,26,0]),
  IG('margarine','Margarine','#F7D23A','#C9A800',0,75,80,540,.60,'⅓ cup','melted',[['butter',1]],'Dairy and eggs',[0,0,60]),
  IG('flour','Flour','#E8DFC9','#A89C7E',0,60,120,220,.10,'½ cup','all-purpose',[['flour',1]],'Pantry',[6,46,.6]),
  IG('broth','Chicken broth','#B8A27A',null,1,480,480,20,1.50,'2 cups','half a carton',[['carton',1]],'Canned',[2,2,.5]),
  IG('halfhalf','Half-and-half','#F3EEDF','#A89C7E',1,240,240,315,1.20,'1 cup','or light cream',[['jug',1]],'Dairy and eggs',[7,10,28]),
  IG('chicken','Cooked chicken','#E9B98C','#B9875A',2,560,950,925,8.00,'4 cups','cooked and chopped',[['chicken',3]],'Meat and seafood',[172,0,20]),
  IG('crust','Pie crusts','#D9A55B','#A9773A',3,400,500,1600,4.00,'2','store-bought or your own',[['pie',2]],'Dairy and eggs',[16,160,100])
 ],
 have:{margarine:1,flour:1,broth:1,onion:1,potato:1},
 GROUPS:[{name:'Vegetables',color:'#F58A1F',op:.2},{name:'Sauce',color:'#F3EEDF',op:.7},{name:'Chicken',color:'#E9B98C',op:.35},{name:'Crust',color:'#D9A55B',op:.3}],
 INS:{weight:['Chicken and sauce are 54% of the pie.','The four vegetables together are less than a quarter, so there is room to add more.'],
  volume:['Chicken is a third of the volume.','A shallow 2-quart dish is the right size. A deeper one needs longer in the oven.'],
  cost:['Chicken is 46% of the cost.','Leftover roast chicken or turkey works just as well.'],
  calories:['The two crusts are 41% of the calories.','Use one crust on top only and each serving drops by about 130 kcal.']},
 LINE:{
  onion:{ing:'onion',noun:'diced onions',opts:[['1 cup','diced'],['160 g','grams'],['1 medium','onion','p','onion, diced']]},
  celery:{ing:'celery',noun:'diced celery',opts:[['1 cup','diced'],['100 g','grams'],['3 stalks','celery','p','celery, diced']]},
  carrot:{ing:'carrot',noun:'diced carrots',opts:[['1 cup','diced'],['130 g','grams'],['2 medium','carrots','p','carrots, diced']]},
  potato:{ing:'potato',noun:'diced potatoes',opts:[['1 cup','diced'],['150 g','grams'],['1 medium','potato','p','potato, diced']]},
  margarine:{ing:'margarine',noun:'margarine',opts:[['⅓ cup','melted'],['75 g','grams'],['5 tbsp','tablespoons']]},
  flour:{ing:'flour',noun:'flour',opts:[['½ cup','cup'],['60 g','grams'],['8 tbsp','tablespoons']]},
  broth:{ing:'broth',noun:'chicken broth',opts:[['2 cups','cups'],['480 ml','millilitres'],['16 fl oz','US fluid ounces']]},
  halfhalf:{ing:'halfhalf',noun:'half-and-half',opts:[['1 cup','cup'],['240 ml','millilitres'],['8 fl oz','US fluid ounces']]},
  salt:SALT_LINE('1 tsp','6 g'),pepper:PEP_LINE('¼ tsp'),
  chicken:{ing:'chicken',noun:'cooked, chopped chicken',opts:[['4 cups','chopped'],['560 g','grams'],['1¼ lb','pounds']]},
  crust:{ing:'crust',noun:'pie crusts',opts:[['2','9-inch crusts','p']]}
 },
 STEPS:[
  {title:'Heat the oven',secs:0,on:1,lines:['Heat the oven to 400°F (200°C).']},
  {title:'Sauté the vegetables',secs:600,on:10,label:'Vegetables',lines:['Warm {margarine} in a large pan.','Add {onion}, {celery}, {carrot} and {potato}.','Sauté for 10 minutes.']},
  {title:'Thicken',secs:60,on:2,label:'Flour',lines:['Add {flour} and stir well.','Cook 1 minute, stirring constantly.']},
  {title:'Make the sauce',secs:0,on:6,lines:['Combine {broth} and {halfhalf}.','Stir gradually into the vegetables.','Cook over medium heat, stirring, until thick and bubbly.']},
  {title:'Add the chicken',secs:0,on:2,lines:['Stir in {salt} and {pepper}.','Add {chicken} and stir well.']},
  {title:'Top and bake',secs:2700,on:5,label:'Pie baking',lines:['Pour into a shallow 2-quart casserole dish.','Top with {crust} and cut slits for steam.','Bake 40 to 50 minutes, until golden and bubbly.']}
 ],
 SETS:{
  chicken:SN('Cooked chicken',['Closest','Meat-free'],['Tender','Flavour','Protein'],[
   ['rotisserie','Rotisserie chicken','1 whole bird','The shortcut. Shred it while warm.',[5,5,5],[1000,165,0,38]],
   ['turkeyc','Cooked turkey','1 : 1','The day-after-holiday version.',[4,4,5],[880,170,0,18]],
   ['chickp','Chickpeas','2 cans','Hearty and meat-free. Use vegetable broth too.',[3,3,3],[790,42,130,13]],
   ['mushp','Mushrooms','500 g, browned','Meaty and savoury.',[4,4,1],[110,15,16,2],{dislike:'Mushrooms'}]]),
  crust:SN('Pie crusts',['Closest','No pastry'],['Flaky','Crisp','Effort'],[
   ['puff','Puff pastry','1 sheet, top only','Lighter and very flaky. Bake 30 to 35 minutes.',[5,4,1],[1100,16,90,76]],
   ['onecrust','One crust','1, top only','Half the pastry. The filling does the work.',[4,4,1],[800,8,80,50]],
   ['biscuit','Biscuit topping','8 biscuits','Drop them on top. Bake until browned.',[3,3,2],[1300,24,170,56]],
   ['mash','Mashed potato','3 cups','Turns it into a cottage-style pie.',[1,2,3],[640,12,105,20]]]),
  halfhalf:SN('Half-and-half',['Closest','Dairy-free'],['Richness','Body','Tang'],[
   ['wmilk','Whole milk','1 : 1','Lighter. Simmer a minute longer to thicken.',[2,2,1],[150,8,12,8]],
   ['hcream','Heavy cream','1 : 1','Richer and silkier.',[5,5,1],[800,5,7,87]],
   ['evap3','Evaporated milk','1 : 1','Creamy from the pantry.',[3,4,2],[320,16,24,18]],
   ['cocomilk','Coconut milk','1 : 1','Dairy-free with a faint coconut note.',[4,4,1],[450,5,7,48]]]),
  margarine:SN('Margarine',['Closest','Oil'],['Flavour','Heat limit','Richness'],[
   ['butterp','Butter','1 : 1','More flavour. Keep the heat at medium.',[5,2,5],[540,.6,0,61]],
   ['gheepp','Ghee','1 : 1','Buttery and will not burn.',[4,5,5],[650,0,0,74]],
   ['oo4','Olive oil','¼ cup','Lighter and fruity.',[3,3,3],[480,0,0,54]],
   ['avo4','Avocado oil','¼ cup','Neutral.',[1,5,3],[495,0,0,56]]]),
  potato:SN('Potatoes',['Closest','Green'],['Creamy','Sweet','Colour'],[
   ['sweetp2','Sweet potato','1 : 1','Sweeter and softer.',[4,5,5],[130,2,30,0]],
   ['parsnip','Parsnip','1 : 1','Earthy and sweet.',[3,4,2],[110,2,26,.4]],
   ['peas','Peas','1 cup, frozen','Stir in with the chicken. No need to sauté.',[2,4,5],[115,8,21,.6]],
   ['corn','Corn','1 cup','Sweet pops of colour.',[2,5,4],[130,5,29,2]]])
 }
};

RECIPES.scampi={
 id:'scampi',short:'Scampi',title:'Lemon Shrimp Scampi',kicker:'Dinner · From Ashley’s cards',base:4,
 desc:'Shrimp cooked in butter with garlic, lemon zest and juice and red pepper flakes, finished with parsley and tossed with angel hair and Parmesan.',
 tags:[['30 min or less',1],['One skillet'],['Date night'],['Spicy']],
 stats:[['10 min','Prep'],['10 min','Cook'],['708','kcal / serving'],['62 g','protein / serving']],
 meta:'20 min · Easy',plate:'Shrimp scampi',
 card:{source:'Handwritten card',credit:'With angel hair. The card gives no amounts for the pasta or Parmesan.',photos:1,questions:['Is the butter ⅓ cup?','Is the other lemon juice amount ⅓ cup?','How much angel hair and Parmesan do you use?']},
 ING:[
  IG('butter','Butter','#F7D23A','#C9A800',0,75,80,540,.90,'⅓ cup','about 5 tbsp',[['butter',2]],'Dairy and eggs',[.6,0,61]),
  IG('greenonion','Green onions','#2E9E4F',null,0,30,40,10,.60,'2','sliced',[['greenonion',2]],'Produce',[.5,2,0]),
  IG('garlic','Garlic','#C9BFA6',null,0,18,30,27,.40,'2 tbsp','minced, about 6 cloves',[['garlic',6]],'Produce',[1,6,0]),
  IG('flakes','Red pepper flakes','#E5392B',null,0,4,10,12,.20,'2 tsp','this is quite hot',[['chilli',1]],'Pantry',[.5,2,.6]),
  IG('zest','Lemon peel','#F7D23A','#C9A800',0,6,15,3,.20,'1 tbsp','zest of 1 lemon',[['lemon',1]],'Produce',[0,1,0]),
  IG('juice','Lemon juice','#F2C200','#C9A800',0,120,120,27,1.00,'½ cup','about 3 lemons',[['lemon',3]],'Produce',[.4,8,0]),
  IG('shrimp','Shrimp','#F28C6B',null,1,900,1000,900,18.00,'2 lb','peeled',[['shrimp',4]],'Meat and seafood',[190,4,10],{safe:'seafood'}),
  IG('pasta','Angel hair','#E9D8A6','#B89B5E',2,340,700,1200,1.50,'12 oz','not on the card',[['linguine',1]],'Dry goods',[44,252,5]),
  IG('parsley','Parsley','#3DB862',null,3,15,60,5,1.00,'¼ cup','fresh, chopped',[['herb',1]],'Produce',[.4,1,.1]),
  IG('parm','Parmesan','#F2D98A','#C9A800',3,25,50,110,1.20,'¼ cup','not on the card',[['wedge',1]],'Dairy and eggs',[9,1,7])
 ],
 have:{butter:1,garlic:1,flakes:1,pasta:1,parm:1},
 GROUPS:[{name:'Sauce',color:'#F7D23A',op:.35},{name:'Shrimp',color:'#F28C6B',op:.3},{name:'Pasta',color:'#E9D8A6',op:.45},{name:'Finish',color:'#3DB862',op:.25}],
 INS:{weight:['Shrimp is 59% of the dish.','Two pounds is generous for four. It stretches to six with more pasta.'],
  volume:['Shrimp and pasta are 85% of the volume.','Use your widest pan so the shrimp cook in one layer.'],
  cost:['Shrimp is about 72% of the cost.','Frozen raw shrimp, thawed, is cheaper and works well.'],
  calories:['Pasta is 42% of the calories and shrimp 32%.','Butter is only 5% of the weight but 19% of the calories.']},
 LINE:{
  pasta:{ing:'pasta',noun:'angel hair pasta',check:'The card says “angel hair pasta” with no amount. 12 oz serves four.',opts:[['12 oz','ounces'],['340 g','grams'],['¾ box','of a 1 lb box']]},
  butter:{ing:'butter',noun:'butter',check:'The card says “1/3 butter” with no unit. Read as ⅓ cup.',opts:[['⅓ cup','cup'],['75 g','grams'],['5 tbsp','tablespoons']]},
  greenonion:{ing:'greenonion',noun:'green onions',opts:[['2','sliced','p'],['30 g','grams'],['¼ cup','sliced']]},
  garlic:{ing:'garlic',noun:'minced garlic',opts:[['2 tbsp','minced'],['6 cloves','whole','p','garlic cloves, minced'],['18 g','grams']]},
  zest:{ing:'zest',noun:'lemon peel',opts:[['1 tbsp','grated'],['1 lemon','zested','p','lemon, zested']]},
  juice:{ing:'juice',noun:'lemon juice',check:'The card says ½ cup, with “1/3” in brackets beside it.',opts:[['½ cup','cup'],['120 ml','millilitres'],['3 lemons','juiced','p','lemons, juiced']]},
  flakes:{ing:'flakes',noun:'red pepper flakes',opts:[['2 tsp','teaspoons'],['4 g','grams']]},
  shrimp:{ing:'shrimp',noun:'shrimp',opts:[['2 lb','pounds, peeled'],['900 g','grams'],['about 50','large shrimp','p']]},
  salt:{name:'Salt',noun:'salt',color:'#8A8A85',icon:'salt',opts:[['to taste','start with ½ tsp']]},
  pepper:{name:'Pepper',noun:'lots of pepper',color:'#3A3A38',icon:'salt',opts:[['to taste','the card says “lots”']]},
  parsley:{ing:'parsley',noun:'fresh parsley',opts:[['¼ cup','chopped'],['15 g','grams'],['a handful','loosely']]},
  parm:{ing:'parm',noun:'Parmesan',check:'The card says “Parm cheese” with no amount. ¼ cup is a starting point.',opts:[['¼ cup','grated'],['25 g','grams']]}
 },
 STEPS:[
  {title:'Boil the pasta',secs:300,on:2,label:'Angel hair',flag:'The card does not include a pasta step. Angel hair cooks in 4 to 5 minutes.',lines:['Boil {pasta} until just tender.','Drain.']},
  {title:'Start the sauce',secs:120,on:3,label:'Sauce',lines:['Melt {butter} in a large pan.','Add {greenonion}, {garlic}, {zest}, {juice} and {flakes}.','Cook 2 minutes, stirring the entire time.']},
  {title:'Cook the {shrimp!}',protein:'shrimp',secs:0,on:5,flag:'The card says “cook until cooked”. No time is given.',lines:['Reduce the heat.','Add {shrimp}.','Cook until done.']},
  {title:'Season',secs:0,on:1,lines:['Season with {salt} and {pepper}.','Add {parsley}.']},
  {title:'Toss',secs:0,on:2,lines:['Toss with the pasta.','Add {parm}.']}
 ],
 SETS:{
  shrimp:SN('Shrimp',['Seafood','Other'],['Tender','Sweetness','Protein'],[
   ['scal3','Scallops','1 : 1','Sear 90 seconds a side, then add to the sauce.',[5,5,4],[1000,184,30,8],{safe:'seafood'}],
   ['lobster','Lobster tail','1 : 1','A treat. Cut into chunks.',[5,5,4],[800,170,0,8],{safe:'seafood'}],
   ['chstrips','Chicken strips','1 : 1','Thin strips. Cook 5 to 6 minutes.',[4,2,5],[1480,278,0,32],{safe:'poultry'}],
   ['wbeans2','White beans','2 cans','Meat-free. Warm through in the sauce.',[3,2,3],[600,40,108,2],{safe:'none'}]]),
  pasta:SN('Angel hair',['Closest','Lighter'],['Bite','Holds sauce','Fibre'],[
   ['spag2','Spaghetti','1 : 1','Sturdier. Boil 9 to 10 minutes.',[4,3,2],[1200,44,252,5]],
   ['ling2','Linguine','1 : 1','Classic with scampi.',[4,4,2],[1200,44,252,5]],
   ['gfah','GF spaghetti','1 : 1','Rinse briefly after draining.',[3,3,2],[1220,24,264,8]],
   ['zood2','Zucchini noodles','600 g','Warm in the sauce for 1 minute.',[1,2,3],[100,8,18,2]]]),
  butter:SN('Butter',['Closest','Dairy-free'],['Flavour','Heat limit','Richness'],[
   ['halfb','Butter + olive oil','3 tbsp + 2 tbsp','Fruitier, and less likely to brown.',[4,3,4],[540,.3,0,61]],
   ['ghee5','Ghee','1 : 1','Buttery and tolerant of heat.',[4,5,5],[650,0,0,74]],
   ['oo5','Olive oil','¼ cup','The dairy-free classic.',[3,3,3],[480,0,0,54]],
   ['vegb5','Vegan butter','1 : 1','Melts like butter.',[3,3,4],[530,0,0,58]]]),
  flakes:SN('Red pepper flakes',['Milder','Different'],['Heat','Fruit','Colour'],[
   ['half1','Half the flakes','1 tsp','Still has a kick.',[3,1,3],[6,.3,1,.3]],
   ['aleppo2','Aleppo pepper','2 tsp','Fruity and much gentler.',[2,5,4],[12,.5,2,.6]],
   ['freshch','Fresh chilli','1, sliced','Brighter heat.',[4,3,4],[6,.3,1,0]],
   ['noflakes','Leave them out','—','Lemon and garlic carry it.',[0,0,0],[0,0,0,0]]]),
  juice:SN('Lemon juice',['Closest','Rounder'],['Sour','Aroma','Sweet'],[
   ['third','⅓ cup juice','⅓ cup','The amount in brackets on the card. Less sharp.',[3,3,2],[18,.3,5,0]],
   ['meyer2','Meyer lemon','1 : 1','Sweeter and gentler.',[3,5,4],[30,.4,9,0]],
   ['wine','White wine + lemon','¼ cup each','The restaurant version.',[3,4,3],[65,.2,5,0]],
   ['limej','Lime juice','1 : 1','Sharper and more floral.',[5,4,2],[30,.5,10,0]]]),
  parm:SN('Parmesan',['Closest','Dairy-free'],['Salty','Nutty','Melts'],[
   ['pec3','Pecorino','1 : 1','Sharper and saltier.',[5,3,3],[97,8,1,7]],
   ['grana3','Grana Padano','1 : 1','Milder.',[3,3,4],[98,8,0,7]],
   ['yeast3','Nutritional yeast','2 tbsp','Cheesy and dairy-free.',[2,4,1],[40,5,3,.5]],
   ['crumbs3','Toasted breadcrumbs','¼ cup','Crunch instead of cheese.',[1,2,1],[110,4,20,1.5]]])
 }
};
RECIPE_ORDER=['cajun','scampi','thai','hamsoup','piccata','potpie'];
