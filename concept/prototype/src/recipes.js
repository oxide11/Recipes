/* ================= RECIPES (seeded from Ashley's recipe cards) ================= */
var RECIPES={};

var CHICKEN_SET={center:'Chicken',branches:['Closest','Seafood','Plant-based'],traits:['Tender','Flavour','Protein'],leaves:[
 L('thighs','Chicken thighs','1 : 1','Juicier and harder to overcook. Add 2 minutes.',[5,4,4]),
 L('turkey','Turkey cutlets','1 : 1','Leaner. Pound thin so they cook evenly.',[3,3,5]),
 L('shrimp2','Shrimp','1 : 1 by weight','Cooks in 2 to 3 minutes. Add near the end.',[4,4,4],{safe:'seafood'}),
 L('scallops','Scallops','1 : 1 by weight','Sear hard, 90 seconds a side.',[5,4,3],{safe:'seafood'}),
 L('tofu2','Firm tofu','1 : 1','Press for 15 minutes, then cube.',[3,2,3],{safe:'none'}),
 L('chickpeas3','Chickpeas','1 can per breast','Pan-fry until blistered.',[2,3,3],{safe:'none'})]};

RECIPES.cajun={
 id:'cajun',short:'Cajun',title:'Creamy Cajun Chicken Pasta',kicker:'Dinner · From Ashley’s cards',base:2,
 desc:'Spiced chicken strips in a rich cream sauce with sun-dried tomatoes, tossed through linguine with Parmesan.',
 tags:[['30 min or less',1],['One skillet'],['Weeknight'],['Rich']],
 stats:[['10 min','Prep'],['15 min','Cook'],['1,300','kcal / serving'],['79 g','protein / serving']],
 meta:'25 min · Easy',plate:'Cajun chicken pasta',
 card:{source:'Printed sheet, 2 of 3',credit:'Lorac, Sept 2002. Prep 10 min, total 25 min.',photos:2,questions:[]},
 ING:[
  {id:'chicken',macro:[124,0,14],name:'Chicken',color:'#E9B98C',edge:'#B9875A',g:0,weight:400,volume:450,calories:660,cost:7.00,amt:'2 breasts',safe:'poultry',eq:'boneless, skinless, cut into thin strips',icon:[['chicken',2]],aisle:'Meat and seafood'},
  {id:'cajun',macro:[0.5,2,0.3],name:'Cajun seasoning',color:'#F58A1F',g:0,weight:6,volume:10,calories:15,cost:0.30,amt:'2 tsp',eq:'store-bought or your own blend',icon:[['jar',1]],aisle:'Pantry'},
  {id:'butter',macro:[0,0,23],name:'Butter',color:'#F7D23A',edge:'#C9A800',g:1,weight:28,volume:30,calories:200,cost:0.40,amt:'2 tbsp',eq:'or margarine',icon:[['butter',1]],aisle:'Dairy and eggs'},
  {id:'greenonion',macro:[0.3,1,0],name:'Green onion',color:'#2E9E4F',g:1,weight:15,volume:20,calories:5,cost:0.30,amt:'1',eq:'thinly sliced',icon:[['greenonion',1]],aisle:'Produce'},
  {id:'cream',macro:[7,10,130],name:'Heavy cream',color:'#E8DFC9',edge:'#A89C7E',g:1,weight:360,volume:360,calories:1200,cost:3.00,amt:'1½ cups',eq:'the card says 1 to 2 cups',icon:[['jug',1]],aisle:'Dairy and eggs'},
  {id:'sundried',macro:[2,7,0.5],name:'Sun-dried tomatoes',color:'#B3261E',g:1,weight:15,volume:30,calories:20,cost:0.80,amt:'2 tbsp',eq:'chopped',icon:[['sundried',1]],aisle:'Canned'},
  {id:'herbs',macro:[0,0.5,0],name:'Seasonings',color:'#6FA37A',g:1,weight:3,volume:5,calories:3,cost:0.20,amt:'1 tsp',eq:'basil, salt, garlic powder and pepper',icon:[['herbs',1]],aisle:'Pantry'},
  {id:'linguine',macro:[15,84,2],name:'Linguine',color:'#E9D8A6',edge:'#B89B5E',g:2,weight:113,volume:200,calories:400,cost:0.60,amt:'4 oz',eq:'cooked al dente',icon:[['linguine',1]],aisle:'Dry goods'},
  {id:'parm',macro:[9,1,7],name:'Parmesan',color:'#F2D98A',edge:'#C9A800',g:2,weight:25,volume:50,calories:110,cost:1.20,amt:'¼ cup',eq:'grated',icon:[['wedge',1]],aisle:'Dairy and eggs'}
 ],
 have:{cajun:1,butter:1,herbs:1,linguine:1,parm:1},
 GROUPS:[{name:'Chicken',color:'#E9B98C',op:.35},{name:'Sauce',color:'#E8DFC9',op:.45},{name:'Pasta',color:'#E9D8A6',op:.45}],
 INS:{weight:['Chicken and cream are 79% of the dish.','The card allows 1 to 2 cups of cream, so that is the easiest dial for a lighter plate.'],
  volume:['Cream is 31% of the volume.','Use a wide skillet so the sauce can reduce a little.'],
  calories:['Cream is 37% of the weight but 46% of the calories.','Use 1 cup instead of 1½ and each plate drops by about 200 kcal.'],
  cost:['Chicken is half the cost.','Thighs cost less and stay juicier.']},
 LINE:{
  chicken:{ing:'chicken',noun:'chicken breasts',opts:[['2','boneless, skinless breasts','p'],['400 g','grams'],['14 oz','ounces']]},
  cajun:{ing:'cajun',noun:'Cajun seasoning',opts:[['2 tsp','teaspoons'],['6 g','grams'],['⅔ tbsp','tablespoon']]},
  linguine:{ing:'linguine',noun:'linguine',opts:[['4 oz','ounces'],['113 g','grams'],['1 cup','dry, loosely packed']]},
  butter:{ing:'butter',noun:'butter',opts:[['2 tbsp','tablespoons'],['28 g','grams'],['¼ stick','US stick']]},
  greenonion:{ing:'greenonion',noun:'green onion',opts:[['1','whole green onion','p'],['15 g','grams'],['2 tbsp','sliced']]},
  cream:{ing:'cream',noun:'heavy cream',check:'The card says 1 to 2 cups. Ashley uses 1½.',opts:[['1½ cups','cups'],['360 ml','millilitres'],['12 fl oz','US fluid ounces']]},
  sundried:{ing:'sundried',noun:'sun-dried tomatoes',opts:[['2 tbsp','chopped'],['15 g','grams']]},
  basil:{ing:'herbs',name:'Dried basil',noun:'dried basil',color:'#6FA37A',icon:'herbs',opts:[['¼ tsp','teaspoon'],['0.3 g','grams']]},
  salt:{ing:'herbs',name:'Salt',noun:'salt',color:'#8A8A85',icon:'salt',opts:[['¼ tsp','fine salt'],['1.5 g','grams']]},
  garlicpowder:{ing:'herbs',name:'Garlic powder',noun:'garlic powder',color:'#6FA37A',icon:'herbs',opts:[['⅛ tsp','teaspoon'],['0.4 g','grams']]},
  pepper:{ing:'herbs',name:'Black pepper',noun:'black pepper',color:'#3A3A38',icon:'herbs',opts:[['⅛ tsp','ground'],['a few grinds','fresh']]},
  parm:{ing:'parm',noun:'grated Parmesan',opts:[['¼ cup','grated'],['25 g','grams'],['0.9 oz','ounces']]}
 },
 STEPS:[
  {title:'Season the chicken',secs:0,on:4,lines:['Cut {chicken} into thin strips.','Toss with {cajun} in a bowl.']},
  {title:'Cook the {linguine!}',secs:600,on:1,label:'Pasta',lines:['Boil {linguine} until al dente.','Drain and keep warm.']},
  {title:'Sauté the chicken',protein:'chicken',secs:360,on:6,label:'Chicken',lines:['Melt {butter} in a large skillet over medium heat.','Sauté the chicken until tender, about 5 to 7 minutes.']},
  {title:'Make the sauce',secs:0,on:3,lines:['Reduce the heat.','Add {greenonion}, {cream} and {sundried}.','Add {basil}, {salt}, {garlicpowder} and {pepper}.','Heat through.']},
  {title:'Toss and serve',secs:0,on:2,lines:['Pour over the hot linguine.','Toss with {parm}.']}
 ],
 SETS:{
  chicken:CHICKEN_SET,
  linguine:{center:'Linguine',branches:['Closest','Gluten-free','Lighter'],traits:['Bite','Holds sauce','Fibre'],leaves:[
   L('penne','Penne','1 : 1','Catches the cream sauce in the tubes. Ashley’s usual swap.',[4,5,2]),
   L('fettuccine','Fettuccine','1 : 1','Wider ribbons for a richer bite.',[4,4,2]),
   L('gflinguine','GF linguine','1 : 1','Cook 1 minute less and rinse quickly.',[3,3,2]),
   L('ricenoodle','Rice noodles','1 : 1','Soak, do not boil. Lighter and silky.',[2,3,1]),
   L('zoodles','Zucchini noodles','300 g','Warm them in the sauce for 1 minute.',[1,2,3]),
   L('spaghettisquash','Spaghetti squash','½ squash','Roast first, then fork into strands.',[2,3,4])]},
  cream:{center:'Heavy cream',branches:['Closest','Lighter','Dairy-free'],traits:['Richness','Body','Tang'],leaves:[
   L('halfhalf','Half-and-half','1 : 1','Lighter. Do not let it boil or it may split.',[3,3,1]),
   L('cookingcream','Cooking cream','1 : 1','Holds up to heat without splitting.',[4,4,1]),
   L('milkflour','Milk + flour','1½ cups + 1 tbsp','Whisk the flour into the butter first.',[2,3,1]),
   L('cream1','Cream, 1 cup','1 cup','The card’s lighter end. Same sauce, less rich.',[3,3,1]),
   L('coconutcream','Coconut cream','1 : 1','Rich, with a gentle coconut note.',[5,4,1]),
   L('cashewcream','Cashew cream','1 : 1','Silky, but made from cashews.',[4,4,1],TN)]},
  sundried:{center:'Sun-dried tomatoes',branches:['Closest','Fresh'],traits:['Sweet','Tang','Chew'],leaves:[
   L('roastedpep','Roasted red pepper','2 tbsp','Sweeter and softer.',[4,2,2]),
   L('tomatopaste','Tomato paste','1 tbsp','Stir into the cream for colour and depth.',[3,4,1]),
   L('cherrytom','Cherry tomatoes','6, halved','Fresher and juicier.',[3,4,1]),
   L('freshtom','Fresh tomato','1 small, diced','Light and bright.',[2,3,1])]},
  parm:{center:'Parmesan',branches:['Closest','Dairy-free'],traits:['Salty','Nutty','Melts'],leaves:[
   L('pecorino','Pecorino','1 : 1','Sharper and saltier. Skip the added salt.',[5,3,3]),
   L('grana','Grana Padano','1 : 1','Milder and cheaper.',[3,3,4]),
   L('yeast','Nutritional yeast','2 tbsp','Cheesy and savoury, dairy-free.',[2,4,1]),
   L('miso2','White miso','1 tsp','Salty depth, no dairy.',[4,2,1])]},
  butter:{center:'Butter',branches:['Closest','Dairy-free'],traits:['Flavour','Heat limit','Richness'],leaves:[
   L('margarine','Margarine','1 : 1','The card lists it as an option.',[2,3,4]),
   L('ghee','Ghee','1 : 1','Butter flavour that tolerates high heat.',[4,5,5]),
   L('oliveoil','Olive oil','1½ tbsp','Fruity and lighter.',[3,3,3]),
   L('avocado','Avocado oil','1½ tbsp','Neutral and handles high heat.',[1,5,3])]}
 }
};

RECIPES.thai={
 id:'thai',short:'Thai',title:'Thai Coconut Soup',kicker:'Dinner · From Ashley’s cards',base:6,
 desc:'Ginger, lemongrass and red curry paste bloomed in oil, simmered with broth and coconut milk, finished with lime and cilantro.',
 tags:[['Dairy-free',1],['One pot'],['Weeknight'],['Spicy'],['Serves a crowd']],
 stats:[['10 min','Prep'],['25 min','Cook'],['520','kcal / serving'],['21 g','protein / serving']],
 meta:'35 min · Easy',plate:'Thai coconut soup',
 card:{source:'Handwritten card',credit:'Serves about 6. The card does not give a yield.',photos:1,questions:['Is the coconut milk 3 cans of 13.5 oz each, and is the cilantro ¼ cup?','How long do you cook the shrimp or chicken?']},
 ING:[
  {id:'oil',macro:[0,0,14],name:'Vegetable oil',color:'#8C9A2B',g:0,weight:14,volume:15,calories:120,cost:0.10,amt:'1 tbsp',eq:'any neutral oil',icon:[['spoon',1]],aisle:'Pantry'},
  {id:'ginger',macro:[0.2,2,0],name:'Ginger',color:'#D9A55B',edge:'#A9773A',g:0,weight:12,volume:30,calories:10,cost:0.40,amt:'2 tbsp',eq:'about a thumb, grated',icon:[['ginger',1]],aisle:'Produce'},
  {id:'lemongrass',macro:[0.3,5,0],name:'Lemongrass',color:'#9CBF5A',g:0,weight:20,volume:40,calories:5,cost:0.80,amt:'1 stalk',eq:'bruised and chopped',icon:[['lemongrass',1]],aisle:'Produce'},
  {id:'curry',macro:[0.5,2,0.5],name:'Red curry paste',color:'#C8321F',g:0,weight:12,volume:10,calories:15,cost:0.60,amt:'2 tsp',eq:'more if you like heat',icon:[['paste',1]],aisle:'Pantry'},
  {id:'broth',macro:[5,4,1],name:'Chicken broth',color:'#B8A27A',g:1,weight:950,volume:950,calories:40,cost:3.00,amt:'4 cups',eq:'1 carton, about 1 L',icon:[['carton',1]],aisle:'Canned'},
  {id:'fish',macro:[3,2,0],name:'Fish sauce',color:'#7A4E2D',g:1,weight:54,volume:45,calories:30,cost:0.50,amt:'3 tbsp',eq:'salty and savoury',icon:[['fishsauce',1]],aisle:'Pantry'},
  {id:'sugar',macro:[0,13,0],name:'Brown sugar',color:'#A0703C',g:1,weight:13,volume:15,calories:50,cost:0.10,amt:'1 tbsp',eq:'packed',icon:[['sugar',1]],aisle:'Pantry'},
  {id:'coconut',macro:[24,36,250],name:'Coconut milk',color:'#F3EEDF',edge:'#A89C7E',g:1,weight:1200,volume:1200,calories:2400,cost:6.00,amt:'3 cans',eq:'13.5 oz cans',icon:[['coconut',3]],aisle:'Canned'},
  {id:'shrimp',macro:[95,2,5],name:'Shrimp',color:'#F28C6B',g:2,weight:450,volume:500,calories:450,cost:9.00,amt:'1 lb',safe:'seafood',eq:'or chicken, the card allows either',icon:[['shrimp',3]],aisle:'Meat and seafood'},
  {id:'lime',macro:[0,3,0],name:'Lime juice',color:'#6CBF3A',g:3,weight:30,volume:30,calories:8,cost:0.40,amt:'2 tbsp',eq:'about 1 lime',icon:[['lime',1]],aisle:'Produce'},
  {id:'cilantro',macro:[0.1,0.2,0],name:'Cilantro',color:'#2E9E4F',g:3,weight:5,volume:15,calories:1,cost:1.00,amt:'¼ cup',eq:'roughly chopped',icon:[['herb',1]],aisle:'Produce'}
 ],
 have:{oil:1,curry:1,broth:1,fish:1,sugar:1,coconut:1},
 GROUPS:[{name:'Aromatics',color:'#D9A55B',op:.3},{name:'Broth',color:'#F3EEDF',op:.6},{name:'Shrimp',color:'#F28C6B',op:.3},{name:'Finish',color:'#6CBF3A',op:.3}],
 INS:{weight:['Coconut milk and broth are 78% of the pot.','Everything else is flavour, so taste before you add more fish sauce.'],
  volume:['Coconut milk is 42% of the volume.','Use a big pot. This makes about 2.8 litres.'],
  calories:['Coconut milk is 77% of the calories.','Light coconut milk cuts about 1,300 kcal across the pot.'],
  cost:['Shrimp is 41% of the cost.','Chicken thighs work too, and the card allows either.']},
 LINE:{
  oil:{ing:'oil',noun:'vegetable oil',opts:[['1 tbsp','tablespoon'],['15 ml','millilitres'],['3 tsp','teaspoons']]},
  ginger:{ing:'ginger',noun:'grated ginger',opts:[['2 tbsp','grated'],['12 g','grams'],['1 thumb','piece, about 5 cm','p','ginger']]},
  lemongrass:{ing:'lemongrass',noun:'lemongrass',opts:[['1 stalk','bruised and chopped','p'],['20 g','grams'],['2 tbsp','paste, from a tube','','lemongrass paste']]},
  curry:{ing:'curry',noun:'red curry paste',opts:[['2 tsp','teaspoons'],['12 g','grams'],['⅔ tbsp','tablespoon']]},
  broth:{ing:'broth',noun:'chicken broth',opts:[['4 cups','cups'],['950 ml','millilitres'],['32 fl oz','US fluid ounces']]},
  fish:{ing:'fish',noun:'fish sauce',opts:[['3 tbsp','tablespoons'],['45 ml','millilitres'],['9 tsp','teaspoons']]},
  sugar:{ing:'sugar',noun:'brown sugar',opts:[['1 tbsp','packed'],['13 g','grams'],['3 tsp','teaspoons']]},
  coconut:{ing:'coconut',noun:'coconut milk',check:'The card says “3 (13.5)”. Read as three 13.5 oz cans.',opts:[['3 cans','13.5 oz each','p'],['1.2 L','litres'],['5 cups','cups'],['40 fl oz','US fluid ounces']]},
  shrimp:{ing:'shrimp',noun:'shrimp',opts:[['1 lb','pound, peeled'],['450 g','grams'],['about 25','large shrimp','p']]},
  lime:{ing:'lime',noun:'lime juice',opts:[['2 tbsp','juice'],['30 ml','millilitres'],['1','lime, juiced','p','lime, juiced']]},
  cilantro:{ing:'cilantro',noun:'cilantro',check:'The card says “1/4 cilantro” with no unit. Read as ¼ cup.',opts:[['¼ cup','chopped'],['5 g','grams'],['a small handful','loosely']]}
 },
 STEPS:[
  {title:'Bloom the aromatics',secs:60,on:2,label:'Aromatics',lines:['Heat {oil} over medium heat.','Add {ginger}, {lemongrass} and {curry}.','Cook, stirring, for 1 minute.']},
  {title:'Simmer the broth',secs:900,on:1,label:'Broth simmer',lines:['Add {broth}, {fish} and {sugar}.','Simmer for 15 minutes.']},
  {title:'Add coconut and {shrimp!}',protein:'shrimp',secs:0,on:2,flag:'The card does not say how long to cook the shrimp or chicken.',lines:['Add {coconut}.','Add {shrimp}.','Cook until done.']},
  {title:'Finish',secs:0,on:1,lines:['Stir in {lime}.','Garnish with {cilantro}.']}
 ],
 SETS:{
  shrimp:{center:'Shrimp',branches:['Card says','Seafood','Plant-based'],traits:['Tender','Sweetness','Protein'],leaves:[
   L('chickencard','Chicken','1 lb','The card offers it. Slice thin and simmer until cooked through.',[4,2,5],{safe:'poultry'}),
   L('thighs2','Chicken thighs','1 lb','Juicier than breast and forgiving.',[5,3,5],{safe:'poultry'}),
   L('scallops2','Scallops','1 lb','Sweet and tender. Add for the last 2 minutes.',[5,5,4]),
   L('whitefish','White fish','1 lb','Cubes of cod or haddock. Poach gently.',[4,3,4]),
   L('tofu3','Firm tofu','1 block','Cube it and add with the coconut milk.',[3,2,3],{safe:'none'}),
   L('mushrooms3','Mushrooms','300 g','Earthy and meaty.',[3,2,1],{dislike:'Mushrooms'})]},
  coconut:{center:'Coconut milk',branches:['Closest','Lighter'],traits:['Richness','Sweetness','Body'],leaves:[
   L('lightcoconut','Light coconut milk','1 : 1','Same flavour, about half the calories.',[3,3,3]),
   L('coconutcream2','Coconut cream','2 cans + water','Richer. Thin with 1 cup water.',[5,4,5]),
   L('twocans','2 cans','2 cans','Brothier and lighter.',[3,2,2]),
   L('evap','Evaporated milk','1 : 1','Creamy, not dairy-free.',[3,3,4])]},
  broth:{center:'Chicken broth',branches:['Closest','Vegetarian'],traits:['Savoury','Body','Salt'],leaves:[
   L('stockcube','Stock cube','1 cube per 2 cups','The pantry standby. Taste before adding fish sauce.',[3,2,5]),
   L('seafoodstock','Seafood stock','1 : 1','Deeper with shrimp.',[4,3,4]),
   L('vegbroth','Vegetable broth','1 : 1','Lighter and vegetarian.',[3,2,3]),
   L('mushbroth','Mushroom broth','1 : 1','Deep and earthy.',[5,3,3],{dislike:'Mushrooms'})]},
  fish:{center:'Fish sauce',branches:['Closest','Vegetarian'],traits:['Salty','Funk','Sweet'],leaves:[
   L('soysauce','Soy sauce','1 : 1','Saltier, less funky.',[5,2,2]),
   L('tamari','Tamari','1 : 1','Gluten-free soy sauce.',[5,2,2]),
   L('vegfish','Vegan fish sauce','1 : 1','Seaweed based.',[4,3,2]),
   L('misowater','Miso + water','1 tbsp + 2 tbsp','Savoury depth without fish.',[4,2,1])]},
  lemongrass:{center:'Lemongrass',branches:['Closest','Pantry'],traits:['Citrus','Aroma','Fresh'],leaves:[
   L('lgpaste','Lemongrass paste','1 tbsp','From a tube. Stir straight in.',[4,4,3]),
   L('lgfrozen','Frozen lemongrass','1 tbsp','Keeps for months.',[4,4,4]),
   L('limezest','Lime zest','1 lime','Bright citrus, different aroma.',[5,3,5]),
   L('lemonzest','Lemon zest','½ lemon','Softer citrus note.',[4,3,5])]},
  curry:{center:'Red curry paste',branches:['Closest','Milder'],traits:['Heat','Aroma','Colour'],leaves:[
   L('greencurry','Green curry paste','1 : 1','Brighter, often hotter.',[4,5,3]),
   L('yellowcurry','Yellow curry paste','1 : 1','Milder and warmer.',[2,4,4]),
   L('halfcurry','Half the paste','1 tsp','Gentle heat for kids.',[1,3,2]),
   L('sriracha','Sriracha','1 tbsp','Simple heat and garlic.',[4,2,4])]},
  cilantro:{center:'Cilantro',branches:['Closest','No cilantro'],traits:['Fresh','Aroma','Colour'],leaves:[
   L('thaibasil','Thai basil','1 : 1','Aniseed and sweet.',[4,5,4]),
   L('mint','Mint','1 : 1','Cool and bright.',[5,4,4]),
   L('greenonion2','Green onion','2, sliced','Mild and oniony.',[3,2,4]),
   L('parsley2','Parsley','1 : 1','Clean and green.',[3,2,4])]}
 }
};

RECIPES.piccata={
 id:'piccata',short:'Piccata',title:'Chicken Piccata',kicker:'Dinner · From Ashley’s cards',base:2,
 desc:'Butterflied chicken dredged and pan-fried, then finished in a bright pan sauce of lemon, capers and stock.',
 tags:[['30 min or less',1],['One skillet'],['Date night'],['Bright']],
 stats:[['10 min','Prep'],['20 min','Cook'],['1,010','kcal / serving'],['65 g','protein / serving']],
 meta:'30 min · Medium',plate:'Chicken piccata',
 card:{source:'Handwritten card',credit:'Card shorthand: “2 & 2 … again” for the second batch.',photos:1,questions:['Are the stock ½ cup and the capers ¼ cup?','When do you add the last 2 tbsp butter?']},
 ING:[
  {id:'chicken',macro:[124,0,14],name:'Chicken',color:'#E9B98C',edge:'#B9875A',g:0,weight:400,volume:450,calories:660,cost:7.00,amt:'2 breasts',safe:'poultry',eq:'butterflied',icon:[['chicken',2]],aisle:'Meat and seafood'},
  {id:'flour',macro:[3,23,0.3],name:'Flour',color:'#E8DFC9',edge:'#A89C7E',g:0,weight:30,volume:60,calories:110,cost:0.10,amt:'¼ cup',eq:'for dredging',icon:[['flour',1]],aisle:'Pantry'},
  {id:'butter',macro:[0.7,0,69],name:'Butter',color:'#F7D23A',edge:'#C9A800',g:1,weight:85,volume:90,calories:610,cost:1.20,amt:'6 tbsp',eq:'¾ of a US stick',icon:[['butter',3]],aisle:'Dairy and eggs'},
  {id:'oil',macro:[0,0,70],name:'Olive oil',color:'#8C9A2B',g:1,weight:70,volume:75,calories:600,cost:1.20,amt:'5 tbsp',eq:'extra-virgin',icon:[['bottle',1]],aisle:'Pantry'},
  {id:'lemon',macro:[0.3,5,0],name:'Lemon juice',color:'#F2C200',edge:'#C9A800',g:2,weight:80,volume:80,calories:18,cost:0.80,amt:'⅓ cup',eq:'about 2 lemons',icon:[['lemon',2]],aisle:'Produce'},
  {id:'stock',macro:[0.6,0.5,0.1],name:'Chicken stock',color:'#B8A27A',g:2,weight:120,volume:120,calories:5,cost:0.50,amt:'½ cup',eq:'low sodium is best',icon:[['carton',1]],aisle:'Canned'},
  {id:'capers',macro:[0.8,1.7,0.3],name:'Capers',color:'#5E7D3A',g:2,weight:35,volume:60,calories:8,cost:1.50,amt:'¼ cup',eq:'brined, rinsed',icon:[['capers',1]],aisle:'Canned'},
  {id:'parsley',macro:[0.4,1,0.1],name:'Parsley',color:'#2E9E4F',g:3,weight:15,volume:80,calories:5,cost:1.00,amt:'⅓ cup',eq:'fresh, chopped',icon:[['herb',1]],aisle:'Produce'}
 ],
 have:{flour:1,butter:1,oil:1,stock:1,capers:1},
 GROUPS:[{name:'Chicken',color:'#E9B98C',op:.35},{name:'Pan',color:'#F7D23A',op:.35},{name:'Sauce',color:'#F2C200',op:.3},{name:'Finish',color:'#2E9E4F',op:.25}],
 INS:{weight:['Chicken is 48% of the plate.','The sauce is mostly lemon and stock, so use fresh lemons.'],
  volume:['The sauce is a quarter of the volume.','Spoon it over just before serving so the coating stays crisp.'],
  calories:['Butter and oil are 18% of the weight but 60% of the calories.','Use half the fat for the second batch to save about 250 kcal.'],
  cost:['Chicken is 53% of the cost.','Thighs work well here and cost less.']},
 LINE:{
  chicken:{ing:'chicken',noun:'chicken breasts',opts:[['2','butterflied breasts','p'],['400 g','grams'],['14 oz','ounces']]},
  saltpepper:{name:'Salt and pepper',noun:'salt and pepper',color:'#8A8A85',icon:'salt',opts:[['to taste','both sides'],['½ tsp each','a starting point']]},
  flour:{ing:'flour',noun:'flour',check:'The card says “Flour” with no amount. About ¼ cup covers 2 breasts.',opts:[['¼ cup','for dredging'],['30 g','grams']]},
  butter1:{ing:'butter',name:'Butter',noun:'butter',opts:[['2 tbsp','tablespoons'],['28 g','grams']]},
  oil1:{ing:'oil',name:'Olive oil',noun:'olive oil',opts:[['3 tbsp','tablespoons'],['45 ml','millilitres']]},
  butter2:{ing:'butter',name:'Butter',noun:'butter',check:'The card says “2 & 2 … again”. Read as 2 tbsp butter and 2 tbsp oil.',opts:[['2 tbsp','tablespoons'],['28 g','grams']]},
  oil2:{ing:'oil',name:'Olive oil',noun:'olive oil',opts:[['2 tbsp','tablespoons'],['30 ml','millilitres']]},
  butter3:{ing:'butter',name:'Butter',noun:'butter',check:'The card does not say where the last 2 tbsp go. Whisking them into the sauce is the classic finish.',opts:[['2 tbsp','tablespoons'],['28 g','grams']]},
  lemon:{ing:'lemon',noun:'lemon juice',opts:[['⅓ cup','juice'],['80 ml','millilitres'],['2','lemons, juiced','p','lemons, juiced']]},
  capers:{ing:'capers',noun:'capers',check:'The card says “1/4 brined capers” with no unit. Read as ¼ cup.',opts:[['¼ cup','rinsed'],['35 g','grams'],['4 tbsp','tablespoons']]},
  stock:{ing:'stock',noun:'chicken stock',check:'The card says “1/2 chicken stock” with no unit. Read as ½ cup.',opts:[['½ cup','cup'],['120 ml','millilitres'],['4 fl oz','US fluid ounces']]},
  parsley:{ing:'parsley',noun:'fresh parsley',opts:[['⅓ cup','chopped'],['15 g','grams'],['a big handful','loosely']]}
 },
 STEPS:[
  {title:'Season and dredge',secs:0,on:5,lines:['Season {chicken} with {saltpepper}.','Dredge in {flour}.']},
  {title:'Fry the first batch',protein:'chicken',secs:240,on:2,label:'First batch',lines:['Heat {butter1} and {oil1} in a large pan.','Cook half the chicken until golden, then lift it out.']},
  {title:'Fry the second batch',protein:'chicken',secs:240,on:2,label:'Second batch',lines:['Add {butter2} and {oil2}.','Cook the rest of the chicken, then lift it out.']},
  {title:'Make the sauce',protein:'chicken',secs:300,on:2,label:'Chicken in sauce',lines:['Add {lemon}, {capers} and {stock} to the pan.','Return the chicken for 5 minutes.']},
  {title:'Finish',secs:0,on:2,flag:'The card does not say where the last 2 tbsp butter go.',lines:['Whisk {butter3} into the sauce.','Spoon the sauce over the chicken.','Finish with {parsley}.']}
 ],
 SETS:{
  chicken:CHICKEN_SET,
  flour:{center:'Flour',branches:['Closest','Gluten-free'],traits:['Crisp','Browning','Neutral'],leaves:[
   L('wondra','Instant flour','1 : 1','Finer, for a thinner, crisper coat.',[5,4,5]),
   L('cornstarch','Cornstarch','1 : 1','Crisp and gluten-free.',[5,2,5]),
   L('ricefl','Rice flour','1 : 1','Light and gluten-free.',[4,3,5]),
   L('almondfl','Almond flour','1 : 1','Nutty and low-carb, but made from almonds.',[3,4,2],TN)]},
  butter:{center:'Butter',branches:['Closest','Dairy-free'],traits:['Flavour','Heat limit','Richness'],leaves:[
   L('ghee','Ghee','1 : 1','Butter flavour that will not burn.',[4,5,5]),
   L('halfbutter','Half the butter','3 tbsp','Lighter. Keep the last 2 tbsp for the sauce.',[3,2,3]),
   L('vegbutter','Vegan butter','1 : 1','Melts and browns like butter.',[3,3,4]),
   L('oliveoil2','Olive oil','1 : 1','Fruity. The sauce will be thinner.',[3,3,2])]},
  lemon:{center:'Lemon',branches:['Closest','Sharper','Pantry'],traits:['Sour','Aroma','Sweet'],leaves:[
   L('meyer','Meyer lemon','1 : 1','Sweeter and gentler.',[3,5,4]),
   L('bottled','Bottled juice','1 : 1','Fine in a pinch. No aroma.',[4,1,2]),
   L('lime','Lime','1 : 1','Sharper and more floral.',[5,4,2]),
   L('whitewine','White wine + lemon','¼ cup + 2 tbsp','The restaurant version. Rounder and less sour.',[3,4,3]),
   L('vinegar','White wine vinegar','2 tbsp','Sharp. Add slowly and taste.',[5,1,1]),
   L('zestonly','Zest + stock','1 lemon zest','All aroma, gentle sour.',[2,5,3])]},
  capers:{center:'Capers',branches:['Closest','Milder'],traits:['Briny','Salty','Pop'],leaves:[
   L('olives','Green olives','2 tbsp, chopped','Briny and meaty.',[4,4,2]),
   L('caperberries','Caper berries','8, halved','Bigger and milder.',[4,3,4]),
   L('halfcapers','Half the capers','2 tbsp','Less salty.',[3,3,4]),
   L('pickles','Chopped pickles','2 tbsp','Tangy and crunchy.',[3,2,4])]},
  stock:{center:'Chicken stock',branches:['Closest','Other'],traits:['Savoury','Body','Salt'],leaves:[
   L('stockcube2','Stock cube','½ cube + ½ cup water','Taste before salting.',[3,2,5]),
   L('vegstock','Vegetable stock','1 : 1','Lighter.',[3,2,3]),
   L('whitewine2','White wine','1 : 1','Classic and bright.',[3,3,1]),
   L('water2','Water + butter','½ cup + 1 tbsp','Leans on the lemon and capers.',[1,3,1])]},
  parsley:{center:'Parsley',branches:['Closest','Different'],traits:['Fresh','Aroma','Colour'],leaves:[
   L('chives3','Chives','1 : 1','Mild and oniony.',[3,3,4]),
   L('basil2','Basil','1 : 1','Sweet and aromatic.',[4,5,4]),
   L('dill','Dill','2 tbsp','Bright with lemon.',[4,5,3]),
   L('noparsley','Leave it out','—','Just a little lemon zest instead.',[1,2,1])]}
 }
};
/* Estimated nutrition for each swap, for the base recipe amount: [kcal, protein g, carbs g, fat g] */
var NUT={
 cajun:{
  chicken:{thighs:[840,96,0,48],turkey:[540,116,0,6],shrimp2:[400,84,2,4],scallops:[440,82,13,3],tofu2:[580,62,12,34],chickpeas3:[790,42,130,13]},
  linguine:{penne:[400,15,84,2],fettuccine:[400,15,84,2],gflinguine:[410,8,88,3],ricenoodle:[410,4,91,1],zoodles:[50,4,9,1],spaghettisquash:[125,3,28,2]},
  cream:{halfhalf:[470,11,16,41],cookingcream:[700,9,14,68],milkflour:[250,13,23,12],cream1:[800,5,7,87],coconutcream:[1190,13,24,125],cashewcream:[900,28,48,70]},
  sundried:{roastedpep:[8,0,2,0],tomatopaste:[13,1,3,0],cherrytom:[18,1,4,0],freshtom:[16,1,3.5,0]},
  parm:{pecorino:[97,8,1,7],grana:[98,8,0,7],yeast:[40,5,3,.5],miso2:[12,1,1.5,.3]},
  butter:{margarine:[200,0,0,22],ghee:[250,0,0,28],oliveoil:[180,0,0,20],avocado:[185,0,0,21]}},
 thai:{
  shrimp:{chickencard:[740,139,0,16],thighs2:[945,108,0,54],scallops2:[500,92,15,4],whitefish:[370,80,0,3],tofu3:[580,62,12,34],mushrooms3:[66,9,10,1]},
  coconut:{lightcoconut:[900,9,18,84],coconutcream2:[2640,29,53,278],twocans:[1600,16,24,167],evap:[1600,82,120,91]},
  broth:{stockcube:[30,2,3,1],seafoodstock:[40,6,2,1],vegbroth:[45,1,10,0],mushbroth:[40,2,8,0]},
  fish:{soysauce:[25,4,2,0],tamari:[27,5,2,0],vegfish:[25,1,5,0],misowater:[35,2,5,1]},
  lemongrass:{lgpaste:[15,0,3,0],lgfrozen:[5,0,1,0],limezest:[3,0,1,0],lemonzest:[2,0,.5,0]},
  curry:{greencurry:[15,.5,2,.5],yellowcurry:[18,.5,2,1],halfcurry:[8,.3,1,.3],sriracha:[15,0,3,0]},
  cilantro:{thaibasil:[1,.1,.2,0],mint:[2,.1,.4,0],greenonion2:[8,.5,2,0],parsley2:[1,.1,.2,0]}},
 piccata:{
  flour:{wondra:[110,3,23,0],cornstarch:[115,0,27,0],ricefl:[110,2,24,.5],almondfl:[170,6,6,15]},
  butter:{ghee:[750,0,0,85],halfbutter:[305,.4,0,35],vegbutter:[600,0,0,66],oliveoil2:[750,0,0,85]},
  lemon:{meyer:[20,.3,6,0],bottled:[18,0,5,0],lime:[20,.3,6,0],whitewine:[55,0,3,0],vinegar:[6,0,0,0],zestonly:[3,0,1,0]},
  capers:{olives:[25,0,1,2.5],caperberries:[10,.5,2,0],halfcapers:[4,.4,.9,.1],pickles:[4,0,1,0]},
  stock:{stockcube2:[5,.3,.5,.2],vegstock:[6,0,1.3,0],whitewine2:[100,0,3,0],water2:[100,0,0,11]},
  parsley:{chives3:[5,.5,.7,.1],basil2:[4,.5,.4,.1],dill:[1,0,.2,0],noparsley:[0,0,0,0]}}
};
/* Swap sets for the smaller ingredients, so every ingredient can be swapped */
function S4(center,branches,traits,rows){return {center:center,branches:branches,traits:traits,leaves:rows.map(function(x){return L(x[0],x[1],x[2],x[3],x[4])})}}
function addSet(rid,iid,set,nut){RECIPES[rid].SETS[iid]=set;NUT[rid][iid]=nut}
addSet('cajun','greenonion',S4('Green onion',['Closest','Sweeter'],['Sharp','Sweet','Fresh'],[
 ['chives','Chives','2 tbsp','Milder and grassy. Stir in at the very end.',[2,2,5]],
 ['redonion','Red onion','2 tbsp, minced','Sharper. Cook it for a minute in the butter first.',[4,3,3]],
 ['shallotg','Shallot','1 small','Sweet and gentle. Soften it before the cream goes in.',[2,5,3]],
 ['leekg','Leek','¼ cup, sliced','Soft and sweet. Use the pale part.',[1,4,3]]]),
 {chives:[2,.2,.3,0],redonion:[8,.2,2,0],shallotg:[20,.7,4.5,0],leekg:[14,.3,3,0]});
addSet('cajun','cajun',S4('Cajun seasoning',['Closest','Pantry'],['Heat','Smoke','Salt'],[
 ['creole','Creole seasoning','1 : 1','More herbs, a little less heat.',[3,2,4]],
 ['blackened','Blackening spice','1 : 1','Smokier, with more paprika.',[4,4,3]],
 ['paprikacay','Paprika + cayenne','1½ tsp + ¼ tsp','Add a pinch of garlic powder and salt.',[4,3,1]],
 ['oldbay','Old Bay','2 tsp','Celery-salt forward. Skip the added salt.',[2,1,5]]]),
 {creole:[15,.5,2,.3],blackened:[15,.5,2,.3],paprikacay:[14,.6,2.5,.5],oldbay:[5,0,1,0]});
addSet('thai','oil',S4('Vegetable oil',['Closest','Richer'],['Flavour','Heat limit','Richness'],[
 ['avocadoo','Avocado oil','1 : 1','Neutral and handles high heat well.',[1,5,3]],
 ['peanut','Peanut oil','1 : 1','Classic for Thai cooking. A peanut, not a tree nut.',[3,5,3]],
 ['coconutoil','Coconut oil','1 : 1','Echoes the coconut milk.',[4,3,4]],
 ['gheeo','Ghee','1 : 1','Buttery and tolerant of heat.',[4,4,5]]]),
 {avocadoo:[124,0,0,14],peanut:[119,0,0,14],coconutoil:[121,0,0,14],gheeo:[125,0,0,14]});
addSet('thai','ginger',S4('Ginger',['Closest','Pantry'],['Heat','Citrus','Fresh'],[
 ['galangal','Galangal','1 : 1','The traditional choice. Sharper and more citrusy.',[3,5,4]],
 ['frozenginger','Frozen ginger','1 : 1','Grate it straight from the freezer.',[4,3,4]],
 ['gingerpaste','Ginger paste','1 tbsp','From a tube or jar.',[3,2,2]],
 ['groundginger','Ground ginger','½ tsp','Warmer and flatter. Add it with the broth.',[3,1,1]]]),
 {galangal:[9,.1,2,0],frozenginger:[10,.2,2,0],gingerpaste:[10,.2,2,0],groundginger:[3,.1,.6,0]});
addSet('thai','sugar',S4('Brown sugar',['Closest','Liquid'],['Sweet','Caramel','Dissolves'],[
 ['palm','Palm sugar','1 : 1','The traditional choice. Deeper and less sharp.',[4,5,3]],
 ['white','White sugar','1 : 1','Clean sweetness, no caramel note.',[5,1,5]],
 ['honey','Honey','2 tsp','Floral. Stir in at the end.',[5,2,5]],
 ['maple','Maple syrup','1 tbsp','Round and mellow.',[4,4,5]]]),
 {palm:[48,0,12,0],white:[49,0,13,0],honey:[43,0,12,0],maple:[52,0,13,0]});
addSet('thai','lime',S4('Lime juice',['Closest','Pantry'],['Sour','Aroma','Sweet'],[
 ['lemonj','Lemon juice','1 : 1','Softer and less floral.',[4,3,2]],
 ['bottledlime','Bottled lime juice','1 : 1','Fine in a pinch.',[4,1,2]],
 ['ricevin','Rice vinegar','1 tbsp','Sour without the citrus. Add slowly.',[4,1,2]],
 ['tamarind','Tamarind paste','1 tsp','Fruity and tangy.',[4,3,4]]]),
 {lemonj:[7,0,2,0],bottledlime:[8,0,3,0],ricevin:[3,0,0,0],tamarind:[12,0,3,0]});
addSet('piccata','oil',S4('Olive oil',['Closest','Lighter'],['Flavour','Heat limit','Richness'],[
 ['avocadop','Avocado oil','1 : 1','Neutral and handles the frying heat well.',[1,5,3]],
 ['gheep','Ghee','1 : 1','Buttery, and it will not burn.',[4,4,5]],
 ['rapeseedp','Rapeseed oil','1 : 1','Clean, neutral and inexpensive.',[1,4,3]],
 ['sprayp','Oil spray','a light coat','Much lighter. Lean on the butter for flavour.',[1,3,1]]]),
 {avocadop:[620,0,0,70],gheep:[625,0,0,70],rapeseedp:[620,0,0,70],sprayp:[30,0,0,3]});
NUT.piccata.chicken=NUT.cajun.chicken;
Object.keys(NUT).forEach(function(rid){Object.keys(NUT[rid]).forEach(function(iid){var set=RECIPES[rid].SETS[iid];if(!set)return;set.leaves.forEach(function(l){if(NUT[rid][iid][l.id])l.nut=NUT[rid][iid][l.id]})})});
var RECIPE_ORDER=['cajun','thai','piccata'];
