/* ================= ICONS ================= */
var ICON={
 tomato:'<circle cx="14" cy="15.5" r="10.5" fill="#E5392B"/><ellipse cx="10" cy="12" rx="3" ry="2" fill="#F07A6E"/><path d="M14 6.5l1.6 2.6 3-.8-1.8 2.3 2.4 1.6-3 .3L14 15l-1.2-2.8-3-.3 2.4-1.6-1.8-2.3 3 .8z" fill="#2E9E4F"/><path d="M14 6.5V3.5" stroke="#1E7F3E" stroke-width="1.8" stroke-linecap="round"/>',
 pepper:'<path d="M14 7c-3-2-8-1-8.5 4-.4 4 .5 9 3 12 1.5 1.8 3.5 1.2 4.5 0 .5.6 1.5.6 2 0 1 1.2 3 1.8 4.5 0 2.5-3 3.4-8 3-12C22 6 17 5 14 7z" fill="#2E9E4F"/><path d="M14 8v14" stroke="#1E7F3E" stroke-width="1.2" stroke-linecap="round" opacity=".6"/><path d="M14 7c0-2 .8-3.6 2.6-4.2" stroke="#1E7F3E" stroke-width="2" fill="none" stroke-linecap="round"/>',
 onion:'<path d="M14 3c1 3 9 6 9 13a9 9 0 0 1-18 0c0-7 8-10 9-13z" fill="#7A4BB5"/><path d="M14 6c-2 4-5 6-5 10.5S11 24 14 24.5M14 6c2 4 5 6 5 10.5S17 24 14 24.5" stroke="#B79AD9" stroke-width="1.2" fill="none"/><path d="M12 25.5l-1 1.5M14 25.5v2M16 25.5l1 1.5" stroke="#5E3790" stroke-width="1.2" stroke-linecap="round"/>',
 aubergine:'<path d="M9 9c3-3 8-2 11 2 4 5 5 12 1 14.5-4 2.5-10-1-12.5-6S6 12 9 9z" fill="#4B2E83"/><ellipse cx="14" cy="15" rx="2" ry="4" fill="#7A5AB0" transform="rotate(-35 14 15)"/><path d="M8 10c-1-2 0-4 2-5 1 1.5 3 2 5 1.5-1 2-4 4-7 3.5z" fill="#2E9E4F"/><path d="M9 6L7 3" stroke="#1E7F3E" stroke-width="1.8" stroke-linecap="round"/>',
 spoon:'<ellipse cx="10" cy="10" rx="7" ry="5.5" fill="#E4E4E0" transform="rotate(-35 10 10)"/><ellipse cx="10" cy="10" rx="5" ry="3.6" fill="#8C9A2B" transform="rotate(-35 10 10)"/><path d="M14.5 13.5L25 24" stroke="#BDBDB8" stroke-width="3" stroke-linecap="round"/>',
 garlic:'<path d="M14 4c3 3 7 8 6 14-.6 4-3.5 6-6 6s-5.4-2-6-6c-1-6 3-11 6-14z" fill="#FBF6EA" stroke="#C9BFA6" stroke-width="1.4"/><path d="M14 9c-1 4-1 9 0 13" stroke="#DCD3BD" stroke-width="1.2" fill="none"/>',
 jar:'<rect x="7" y="4" width="14" height="5" rx="1.5" fill="#3A3A38"/><rect x="6" y="9" width="16" height="16" rx="3" fill="#F58A1F"/><rect x="9" y="13" width="10" height="6" rx="1" fill="#fff" opacity=".85"/>',
 egg:'<path d="M14 3c4.5 0 8.5 7 8.5 13a8.5 8.5 0 0 1-17 0C5.5 10 9.5 3 14 3z" fill="#FFF8E8" stroke="#D9CBA8" stroke-width="1.4"/><ellipse cx="11" cy="10" rx="2" ry="3" fill="#fff"/>',
 cube:'<path d="M14 4l9 4.5v10L14 23l-9-4.5v-10z" fill="#F3EEDF" stroke="#A89C7E" stroke-width="1.3" stroke-linejoin="round"/><path d="M5 8.5L14 13l9-4.5M14 13v10" stroke="#A89C7E" stroke-width="1.3" fill="none" stroke-linejoin="round"/><circle cx="10" cy="15" r=".9" fill="#C9BFA6"/><circle cx="18" cy="16" r=".9" fill="#C9BFA6"/>',
 squash:'<path d="M11 4h6v6c4 2 6 6 6 9a9 7 0 0 1-18 0c0-3 2-7 6-9z" fill="#F58A1F"/><path d="M11 4h6v3h-6z" fill="#D9CDB8"/><path d="M14 2v3" stroke="#6B5A3E" stroke-width="2" stroke-linecap="round"/><ellipse cx="14" cy="19" rx="3" ry="2.5" fill="#F7A85A"/>',
 carton:'<path d="M8 8l3-5h6l3 5v17H8z" fill="#D9CDB8" stroke="#A89C7E" stroke-width="1.2" stroke-linejoin="round"/><path d="M8 8h12" stroke="#A89C7E" stroke-width="1.2"/><rect x="10.5" y="12" width="7" height="7" rx="1" fill="#fff" opacity=".85"/>',
 jug:'<path d="M8 6h12v16a3 3 0 0 1-3 3h-6a3 3 0 0 1-3-3z" fill="#FBF6EA" stroke="#A89C7E" stroke-width="1.3"/><path d="M20 10h2a2 2 0 0 1 0 6h-2" fill="none" stroke="#A89C7E" stroke-width="1.3"/><path d="M8 6l-1.5-2.5" stroke="#A89C7E" stroke-width="1.3" stroke-linecap="round"/><path d="M8 11h12" stroke="#E8DFC9" stroke-width="3"/>',
 leaf:'<path d="M6 22C6 12 13 5 23 5c0 10-7 17-17 17z" fill="#6FA37A"/><path d="M6 22L18 10" stroke="#3F6B47" stroke-width="1.3" stroke-linecap="round"/>',
 chilli:'<path d="M7 9c2-1 4 0 5 2 3 5 7 9 12 11-6 2-12 0-15-4-2-3-3-6-2-9z" fill="#E5392B"/><path d="M7 9c-1-2 0-4 2-5" stroke="#2E9E4F" stroke-width="2" fill="none" stroke-linecap="round"/>',
 penne:'<path d="M5 9l9-4 2 5-9 4z" fill="#E8DFC9" stroke="#A89C7E" stroke-width="1.2" stroke-linejoin="round"/><path d="M9 16l9-4 2 5-9 4z" fill="#E8DFC9" stroke="#A89C7E" stroke-width="1.2" stroke-linejoin="round"/><path d="M14 22l8-3.5 1.5 4-8 3.5z" fill="#E8DFC9" stroke="#A89C7E" stroke-width="1.2" stroke-linejoin="round"/>',
 basil:'<path d="M14 25V12" stroke="#1E7F3E" stroke-width="1.8" stroke-linecap="round"/><path d="M14 13c-6 0-9-4-8-9 5 0 8 3 8 9z" fill="#2E9E4F"/><path d="M14 16c5 0 8-3 8-8-5 0-8 3-8 8z" fill="#3DB862"/><path d="M14 21c-4 0-7-2-7-5 4 0 7 2 7 5z" fill="#2E9E4F"/>',
 seeds:'<path d="M8 5c2.5 2 3.5 5 2.5 8.5-2.5-1-4.5-4.5-2.5-8.5z" fill="#B8A27A" stroke="#8C7B65" stroke-width=".8"/><path d="M17 8c2.5 2 3.5 5 2.5 8.5-2.5-1-4.5-4.5-2.5-8.5z" fill="#B8A27A" stroke="#8C7B65" stroke-width=".8"/><path d="M11 15c2.5 2 3.5 5 2.5 8.5-2.5-1-4.5-4.5-2.5-8.5z" fill="#B8A27A" stroke="#8C7B65" stroke-width=".8"/>',
 wedge:'<path d="M4 20L24 9v11z" fill="#F2D98A" stroke="#C9A800" stroke-width="1.3" stroke-linejoin="round"/><path d="M4 20h20v3H4z" fill="#E6C66A" stroke="#C9A800" stroke-width="1.3" stroke-linejoin="round"/><circle cx="17" cy="16" r="1.4" fill="#E6C66A"/><circle cx="20.5" cy="18" r="1" fill="#E6C66A"/>',
 lemon:'<ellipse cx="14" cy="15" rx="10" ry="8" fill="#F7D23A" transform="rotate(-20 14 15)"/><path d="M4.5 18.5l-2 1M23.5 11.5l2-1" stroke="#C9A800" stroke-width="2" stroke-linecap="round"/><ellipse cx="11" cy="12" rx="3" ry="1.6" fill="#FBE68A" transform="rotate(-20 11 12)"/>',
 bottle:'<path d="M12 3h4v4l2 3v14a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1V10l2-3z" fill="#8C9A2B"/><rect x="12" y="2" width="4" height="2.5" rx=".8" fill="#3A3A38"/><rect x="11" y="13" width="6" height="6" rx="1" fill="#fff" opacity=".85"/>',
 salt:'<path d="M9 9h10l1 15H8z" fill="#fff" stroke="#8A8A85" stroke-width="1.3" stroke-linejoin="round"/><path d="M10 9V6a4 4 0 0 1 8 0v3" fill="#D6D6D1" stroke="#8A8A85" stroke-width="1.3"/><circle cx="12.5" cy="6" r=".8" fill="#595954"/><circle cx="15.5" cy="6" r=".8" fill="#595954"/>'

 ,chicken:'<path d="M6 16c0-6 5-10 11-10 4 0 7 3 7 7 0 6-6 10-12 10-4 0-6-3-6-7z" fill="#E9B98C" stroke="#B9875A" stroke-width="1.2"/><path d="M10 15c3-3 7-4 10-3" stroke="#F4D3B0" stroke-width="1.6" fill="none" stroke-linecap="round"/>',
 linguine:'<ellipse cx="14" cy="16" rx="10" ry="7" fill="#E9D8A6" stroke="#B89B5E" stroke-width="1.2"/><path d="M6 15c4-3 12-3 16 0M7 18c4-2 10-2 14 0M9 13c3-2 7-2 10 0" stroke="#B89B5E" stroke-width="1" fill="none"/>',
 butter:'<path d="M5 13l6-4h12v8l-6 4H5z" fill="#F7D23A" stroke="#C9A800" stroke-width="1.2" stroke-linejoin="round"/><path d="M5 13h12l6-4M17 13v8" stroke="#C9A800" stroke-width="1.2" fill="none" stroke-linejoin="round"/>',
 greenonion:'<path d="M14 26V12" stroke="#F3EEDF" stroke-width="5" stroke-linecap="round"/><path d="M12 13l-4-10M14 12V2M16 13l4-10" stroke="#2E9E4F" stroke-width="2.4" stroke-linecap="round"/>',
 sundried:'<path d="M6 12c3-5 13-6 16 0 2 5-3 10-9 10S4 17 6 12z" fill="#B3261E"/><path d="M9 13c3-2 7-2 10 0" stroke="#E5392B" stroke-width="1.4" fill="none"/>',
 herbs:'<rect x="7" y="4" width="14" height="5" rx="1.5" fill="#3A3A38"/><rect x="6" y="9" width="16" height="16" rx="3" fill="#6FA37A"/><rect x="9" y="13" width="10" height="6" rx="1" fill="#fff" opacity=".85"/>',
 ginger:'<path d="M5 15c0-3 3-4 5-3 1-3 4-4 6-2 2-2 6-1 7 2 1 3-1 6-4 6H9c-3 0-4-1-4-3z" fill="#D9A55B" stroke="#A9773A" stroke-width="1.2"/><path d="M12 12v-3M18 11l1-3" stroke="#A9773A" stroke-width="1.2" stroke-linecap="round"/>',
 lemongrass:'<path d="M10 26L14 3M14 26L16 4M18 26l1-21" stroke="#9CBF5A" stroke-width="3" stroke-linecap="round"/><path d="M9 22h12" stroke="#E9EFD3" stroke-width="5" stroke-linecap="round"/>',
 paste:'<rect x="7" y="4" width="14" height="5" rx="1.5" fill="#3A3A38"/><rect x="6" y="9" width="16" height="16" rx="3" fill="#C8321F"/><rect x="9" y="13" width="10" height="6" rx="1" fill="#fff" opacity=".85"/>',
 fishsauce:'<path d="M12 3h4v4l2 3v14a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1V10l2-3z" fill="#7A4E2D"/><rect x="12" y="2" width="4" height="2.5" rx=".8" fill="#E5392B"/><rect x="11" y="13" width="6" height="6" rx="1" fill="#fff" opacity=".85"/>',
 sugar:'<path d="M4 22c2-6 6-9 10-9s8 3 10 9z" fill="#A0703C"/><circle cx="11" cy="18" r=".9" fill="#C8955C"/><circle cx="16" cy="17" r=".9" fill="#C8955C"/><circle cx="13" cy="20" r=".9" fill="#C8955C"/>',
 coconut:'<rect x="6" y="5" width="16" height="19" rx="2" fill="#D6D6D1"/><rect x="6" y="9" width="16" height="11" fill="#F3EEDF" stroke="#A89C7E" stroke-width=".8"/><circle cx="14" cy="14.5" r="3" fill="#7A5A3A"/>',
 shrimp:'<path d="M20 7c-6-2-13 2-13 9 0 4 3 7 7 7 3 0 5-2 5-4" fill="none" stroke="#F28C6B" stroke-width="5" stroke-linecap="round"/><path d="M19 19l4 3M19 19l3-4" stroke="#E5392B" stroke-width="2" stroke-linecap="round"/><circle cx="18" cy="9" r="1" fill="#111"/>',
 lime:'<circle cx="14" cy="15" r="9" fill="#6CBF3A"/><circle cx="14" cy="15" r="6.5" fill="#C9E7A6"/><path d="M14 8.5v13M7.5 15h13M9.5 10.5l9 9M18.5 10.5l-9 9" stroke="#6CBF3A" stroke-width="1"/>',
 herb:'<path d="M14 26V14" stroke="#1E7F3E" stroke-width="1.6" stroke-linecap="round"/><circle cx="10" cy="11" r="4.5" fill="#2E9E4F"/><circle cx="18" cy="11" r="4.5" fill="#3DB862"/><circle cx="14" cy="6" r="4.5" fill="#2E9E4F"/><circle cx="14" cy="15" r="3.5" fill="#3DB862"/>',
 flour:'<path d="M7 9l2-5h10l2 5v15H7z" fill="#F3EEDF" stroke="#A89C7E" stroke-width="1.2" stroke-linejoin="round"/><path d="M7 9h14" stroke="#A89C7E" stroke-width="1.2"/><path d="M11 15c1.5-2 4.5-2 6 0" stroke="#C9BFA6" stroke-width="1.4" fill="none"/>',
 capers:'<circle cx="9" cy="12" r="3.2" fill="#5E7D3A"/><circle cx="16" cy="10" r="3.2" fill="#6F8F47"/><circle cx="13" cy="17" r="3.2" fill="#5E7D3A"/><circle cx="20" cy="16" r="3.2" fill="#6F8F47"/>'
};

/* ================= SHARED SWAP SETS ================= */
function L(id,name,ratio,note,t,extra){var o={id:id,name:name,ratio:ratio,note:note,t:t};if(extra){for(var k in extra)o[k]=extra[k]}return o}
var TN={allergen:'Tree nuts'};
var OIL_SET={center:'Olive oil',branches:['Closest','Richer','Lighter'],traits:['Flavour','Heat limit','Richness'],leaves:[
 L('avocado','Avocado oil','1 : 1','Neutral and handles high heat well.',[1,5,3]),
 L('rapeseed','Rapeseed oil','1 : 1','Clean and inexpensive.',[1,4,3]),
 L('butter','Butter','1 : 1','Rich and nutty but burns easily. Keep the heat at medium.',[4,2,5]),
 L('ghee','Ghee','1 : 1','Butter flavour that tolerates high heat.',[4,4,5]),
 L('spray','Oil spray','a light coat','Cuts most of the fat. Add a splash of water if things catch.',[1,3,1]),
 L('stock','Stock splash','2 tbsp','Sweat in stock instead of fat.',[2,3,1])]};
var ONION_SET=function(center){return {center:center,branches:['Closest','Milder','Allium-free'],traits:['Sweet','Sharp','Bulk'],leaves:[
 L('shallot','Shallots','1 : 1','Finer and sweeter. Two to three shallots match one onion.',[4,2,3]),
 L('white','White onion','1 : 1','Sharper. Cook a minute longer to mellow it.',[2,4,3]),
 L('leek','Leek','1 : 1','Use the white and pale green parts. Softer and gentler.',[3,1,3]),
 L('spring','Spring onion','1 : 1','Add the whites early and the greens at the end.',[2,2,2]),
 L('fennel2','Fennel','1 : 1','Bulk and sweetness without any onion. Cook it slowly.',[3,1,4]),
 L('hing','Asafoetida','a pinch','A tiny pinch fried in the oil brings an onion-like note.',[1,3,1])]}};
var GARLIC_SET={center:'Garlic',branches:['Closest','Milder','Garlic-free'],traits:['Punch','Sweetness','Aroma'],leaves:[
 L('roastgarlic','Roasted garlic','1 head','Sweet and mellow. Squeeze it in at the end.',[2,5,4]),
 L('garlicpowder','Garlic powder','1 tsp','Handy and even.',[3,1,3]),
 L('shallot3','Shallot','1 small','Gentle and sweet.',[2,4,3]),
 L('chives','Chives','2 tbsp','Fresh and mild.',[1,2,3]),
 L('garlicoil','Garlic oil','1 tbsp','Garlic flavour without the cloves.',[3,1,4]),
 L('hing3','Asafoetida','a pinch','Fried in the oil, it fills the gap.',[3,1,3])]};

