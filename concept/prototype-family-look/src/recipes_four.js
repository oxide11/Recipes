/* ================= RECIPES ADDED BY MOUSSA ================= */
RECIPES.roast={
 id:'roast',short:'Braised roast',title:'Red Wine Braised Sirloin Roast with Whipped Mashed Potatoes',kicker:'Dinner · Moussa’s recipe',base:6,
 desc:'A sirloin roast seared, then braised low in red wine and beef broth with carrots, served over butter-and-cream whipped potatoes with the reduced pan sauce.',
 tags:[['Comfort food',1],['Serves a crowd'],['Dutch oven'],['Date night']],
 stats:[['20 min','Prep'],['3 hr','Cook'],['720','kcal/serving'],['47 g','protein/serving']],
 meta:'3 hr 20 · Medium',plate:'Braised roast',
 card:{own:true,source:'Typed recipe',credit:'Added by Moussa. About 6 servings from a 1.2 kg roast.',photos:0,questions:[]},
 ING:[
  IG('roast','Sirloin roast','#9C4A3C','#6E2F26',0,1200,1150,1900,22.00,'1.2 kg','patted completely dry',[['roast',1]],'Meat and seafood',[250,0,90],{safe:'beefroast'}),
  IG('paprika','Smoked paprika','#B5452A','#7E2C18',0,2,5,6,.10,'1 tsp','',[['cajun',1]],'Pantry',[.3,1.2,.3]),
  IG('garlicpowder','Garlic powder','#E8DCC0','#B8A77E',0,3,5,10,.10,'1 tsp','',[['jar',1]],'Pantry',[.5,2.2,0]),
  IG('oil','Vegetable oil','#E8C84A','#B89A1E',0,28,30,240,.20,'2 tbsp','for searing',[['bottle',1]],'Pantry',[0,0,28]),
  IG('onion','Onion','#7A4BB5',null,0,150,240,60,.40,'½ large','sliced',[['onion',1]],'Produce',[1.5,14,0]),
  IG('garlic','Garlic','#EFE6D2','#B8A77E',0,12,15,18,.30,'4 cloves','minced',[['garlic',2]],'Produce',[.8,4,0]),
  IG('paste','Tomato paste','#C8442F','#8E2A1B',0,16,15,13,.25,'1 tbsp','',[['paste',1]],'Canned',[.7,3,.1]),
  IG('wine','Red wine','#6B1F3A','#4A1027',0,250,250,210,4.00,'1 cup','dry, 250 ml',[['wine',1]],'Pantry',[.2,6.5,0]),
  IG('broth','Beef broth','#B98A5A','#8A6238',0,250,250,15,.80,'1 cup','250 ml',[['carton',1]],'Canned',[2.5,1,.5]),
  IG('bay','Bay leaves','#6E8F4E','#4C6A33',0,1,3,0,.10,'2','',[['bayleaf',2]],'Pantry',[0,0,0]),
  IG('thyme','Thyme','#7FA35A','#567A38',0,3,8,3,.75,'3 sprigs','fresh',[['herb',1]],'Produce',[.2,.7,0]),
  IG('carrot','Carrots','#F08A2E','#B95C06',0,180,300,75,.60,'3 medium','cut into 2-inch chunks',[['carrot',3]],'Produce',[1.7,17,.4]),
  IG('potato','Potatoes','#D9B26A','#A9833A',1,1000,1600,770,3.00,'1 kg','Yukon Gold, peeled and cubed',[['potato',4]],'Produce',[20,175,1]),
  IG('butter','Butter','#F7D23A','#C9A800',1,85,90,610,1.10,'6 tbsp','',[['butter',1]],'Dairy and eggs',[.7,0,69]),
  IG('cream','Heavy cream','#F3EEDF','#A89C7E',1,120,125,410,1.20,'½ cup','warmed, 125 ml',[['cream',1]],'Dairy and eggs',[3.4,3.4,43])
 ],
 have:{paprika:1,garlicpowder:1,oil:1,onion:1,garlic:1,bay:1,potato:1,butter:1},
 GROUPS:[{name:'Braise',color:'#9C4A3C',op:.22},{name:'Whipped mash',color:'#D9B26A',op:.3}],
 INS:{weight:['The roast and the potatoes are three quarters of everything in the pot and on the plate.','The braising liquid is half wine, half broth. It reduces to a few spoonfuls of sauce per plate.'],
  volume:['Potatoes take the most space; the roast shrinks by about a quarter as it braises.','Use a Dutch oven the roast fits snugly, so the liquid comes about halfway up.'],
  cost:['The roast is about two thirds of the cost.','A chuck roast braises just as well for less.'],
  calories:['The roast is under half the calories. Butter and cream in the mash are nearly a quarter.','Half the butter and milk instead of cream takes about 110 kcal off each serving.']},
 LINE:{
  roast:{ing:'roast',noun:'sirloin roast',opts:[['1.2 kg','kilograms'],['2⅔ lb','pounds']]},
  saltrub:SALT_LINE('1 tsp','6 g'),
  pepper:PEP_LINE('1 tsp'),
  paprika:{ing:'paprika',noun:'smoked paprika',opts:[['1 tsp','teaspoon'],['2 g','grams']]},
  garlicpowder:{ing:'garlicpowder',noun:'garlic powder',opts:[['1 tsp','teaspoon'],['3 g','grams']]},
  oil:{ing:'oil',noun:'oil',opts:[['2 tbsp','tablespoons'],['30 ml','millilitres']]},
  onion:{ing:'onion',noun:'onion, sliced',opts:[['½ large','onion'],['1 cup','sliced'],['150 g','grams']]},
  garlic:{ing:'garlic',noun:'garlic, minced',opts:[['4 cloves','cloves'],['4 tsp','minced'],['12 g','grams']]},
  paste:{ing:'paste',noun:'tomato paste',opts:[['1 tbsp','tablespoon'],['16 g','grams']]},
  wine:{ing:'wine',noun:'red wine',opts:[['1 cup','cup'],['250 ml','millilitres']]},
  broth:{ing:'broth',noun:'beef broth',opts:[['1 cup','cup'],['250 ml','millilitres']]},
  bay:{ing:'bay',noun:'bay leaves',opts:[['2','leaves']]},
  thyme:{ing:'thyme',noun:'fresh thyme',opts:[['3 sprigs','sprigs'],['1 tsp','dried']]},
  carrot:{ing:'carrot',noun:'carrots, cut into 2-inch chunks',opts:[['3 medium','carrots'],['180 g','grams']]},
  potato:{ing:'potato',noun:'Yukon Gold potatoes, peeled and cubed',opts:[['1 kg','kilogram'],['2¼ lb','pounds']]},
  butter:{ing:'butter',noun:'butter',opts:[['6 tbsp','tablespoons'],['85 g','grams'],['¾ stick','US stick']]},
  cream:{ing:'cream',noun:'warm heavy cream',opts:[['½ cup','cup'],['125 ml','millilitres']]},
  saltmash:SALT_LINE('1 tsp','6 g'),
  whitepepper:{name:'White pepper',noun:'white pepper',color:'#8A8A85',icon:'salt',opts:[['½ tsp','ground'],['1 g','grams']]}
 },
 STEPS:[
  {title:'Heat the oven and season the {roast!}',secs:0,on:5,lines:['Heat the oven to 325°F (160°C).','Pat {roast} completely dry with paper towel.','Season all sides with {saltrub}, {pepper}, {paprika} and {garlicpowder}.']},
  {title:'Sear',secs:0,on:20,lines:['Heat {oil} in a Dutch oven over medium-high.','Sear the roast 3 to 4 minutes per side, all sides including the ends.','Remove and set aside.']},
  {title:'Build the base',secs:0,on:6,lines:['Reduce to medium heat.','Add {onion} and cook 3 minutes.','Add {garlic} and cook 1 minute.','Add {paste} and stir 1 minute.']},
  {title:'Deglaze',secs:0,on:3,lines:['Pour in {wine} and scrape up all the brown bits.','Add {broth}.','Add {bay} and {thyme}.']},
  {title:'Braise',protein:'beefroast',secs:5400,on:1,label:'Braise',lines:['Nestle the roast back in.','Lid on, into the oven for 1½ hours.']},
  {title:'Add the {carrot!}',secs:3600,on:3,label:'Braise with carrots',lines:['At the 1½ hour mark, add {carrot}.','Lid back on, and back in the oven for 1 more hour.']},
  {title:'Whip the {potato!}',secs:1200,on:15,label:'Potatoes',lines:['Start this 45 minutes before serving.','Boil {potato} in salted water until fork tender, about 20 minutes.','Drain completely and return to the pot.','Add {butter} and {cream}.','Whip with a hand mixer until smooth.','Season with {saltmash} and {whitepepper}.']},
  {title:'Finish and serve',secs:600,on:10,label:'Roast resting',lines:['Remove the roast and rest it 10 minutes before slicing.','Reduce the braising liquid on the stovetop 5 to 10 minutes for a pan sauce.','Plate the roast over the mash and spoon the sauce over top.']}
 ],
 SETS:{
  roast:SN('Sirloin roast',['Closest','Meat-free'],['Tender','Rich','Protein'],[
   ['rwchuck','Chuck roast','1 : 1','More marbling, so it braises softer. Skim the sauce before reducing.',[5,5,4],[2900,220,0,220],{safe:'beefroast'}],
   ['rwround','Bottom round roast','1 : 1','Leaner and slices neatly. Give it 20 minutes longer.',[3,3,5],[1800,255,0,75],{safe:'beefroast'}],
   ['rwcauli','Whole cauliflower','2 heads','Sear cut side down, then braise 45 minutes in total.',[3,2,1],[300,23,60,3]],
   ['rwmush','King oyster mushrooms','1 kg','Meaty when seared and braised 40 minutes.',[4,3,2],[350,33,60,4],{dislike:'Mushrooms'}]]),
  wine:SN('Red wine',['Closest','No alcohol'],['Depth','Acidity','Sweet'],[
   ['rwport','Dry vermouth','1 : 1','Lighter in colour, more herbal.',[3,4,2],[300,0,30,0]],
   ['rwbrothbal','Beef broth and balsamic','1 cup + 1 tbsp','More broth for the liquid, balsamic vinegar for the acidity.',[3,3,2],[30,2.5,5,.5]],
   ['rwpom','Pomegranate juice','1 : 1','Fruity and tart. Leave out any added sugar elsewhere.',[3,4,5],[135,.4,33,.7]],
   ['rwnawine','Alcohol-free red wine','1 : 1','Closest in flavour without the alcohol.',[4,3,3],[60,.5,14,0]]]),
  cream:SN('Heavy cream',['Closest','Dairy-free'],['Richness','Fluffy','Tang'],[
   ['rwmilk','Whole milk','1 : 1','Lighter mash. Warm it first.',[2,4,1],[75,4,6,4]],
   ['rwsour','Sour cream','1 : 1','Tangy and thick. Fold it in at the end.',[4,3,5],[240,3,6,23]],
   ['rwoatcream','Oat cream','1 : 1','Neutral and close in body.',[3,3,1],[190,1.2,8,17]],
   ['rwbrothmash','Warm broth and olive oil','⅓ cup + 2 tbsp','Savoury instead of rich.',[2,3,1],[245,1,0,27]]]),
  potato:SN('Potatoes',['Closest','Lighter'],['Creamy','Fluffy','Sweet'],[
   ['rwrusset','Russet potatoes','1 : 1','Fluffier and drier. They take a little more cream.',[3,5,1],[790,21,180,1]],
   ['rwsweet','Sweet potatoes','1 : 1','Sweeter, and good against the wine sauce.',[4,3,5],[860,16,200,.5]],
   ['rwcaulimash','Cauliflower','1 : 1','Steam instead of boiling so it is not watery.',[3,3,2],[250,19,50,3]],
   ['rwceleriac','Celery root','1 : 1','Earthy and lighter. Boil 5 minutes longer.',[4,2,2],[420,15,92,3]]]),
  butter:SN('Butter',['Closest','Dairy-free'],['Flavour','Richness','Silky'],[
   ['rwbrownb','Browned butter','1 : 1','Nutty and deeper.',[5,4,4],[610,.7,0,69]],
   ['rwghee','Ghee','5 tbsp','Rich, with almost no lactose.',[4,5,4],[620,0,0,70]],
   ['rwolive','Olive oil','4 tbsp','Fruity and silky.',[3,3,5],[480,0,0,54]],
   ['rwvegb','Vegan butter','1 : 1','Behaves like butter.',[3,3,3],[590,0,0,66]]])
 }
};
RECIPE_ORDER.push('roast');
