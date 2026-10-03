const DEF=[
{id:1,name:"Santal Impérial d'Orient",cat:"Extrait de parfum",img:"santal.jpg",tag:"Édition limitée",desc:"Santal royal crémeux, ambre gris marin & vanille bourbon. Une signature solaire et enveloppante.",sizes:[["50 ml",16500],["100 ml",24500],["Coffret 100 ml",31000]],notes:["Bergamote, poivre rose, safran","Santal de Mysore, iris, jasmin","Ambre gris, cuir doré, musc blanc"],stock:true},
{id:2,name:"Rose de Damas Dorée",cat:"Eau de parfum",img:"rose.jpg",tag:"Best seller",desc:"Infusion de rose bulgare cueillie à l'aube et pistils de safran pur.",sizes:[["50 ml",12900],["80 ml",18900]],notes:["Rose bulgare, safran","Rose de Damas, pivoine","Musc, bois blond"],stock:true},
{id:3,name:"Oud Noir Céleste",cat:"Extrait de parfum",img:"oud.jpg",tag:"Rare millésime",desc:"Oud cambodgien vieilli 12 ans, vanille noire fumée et résine d'encens.",sizes:[["50 ml",32000]],notes:["Encens, cardamome","Oud cambodgien, rose","Vanille noire, ambre"],stock:true},
{id:4,name:"Collier Porte-Parfum Or 18K",cat:"Accessoires",img:"collier.jpg",tag:"Orfèvrerie or 18K",desc:"Pendentif fiole ciselée à la main pour emporter son extrait fétiche partout.",sizes:[["Unique",14200]],notes:[],stock:true},
{id:5,name:"Ambre Majestueux & Cuir",cat:"Extrait de parfum",img:"ambre.jpg",tag:"Coup de cœur",desc:"Cuir blanc tanné à l'ancienne, ambre résineux et fève tonka grillée.",sizes:[["100 ml",27500]],notes:["Bergamote, pimentade","Cuir, ambre","Tonka, bois de cèdre"],stock:true}];
const WIL="Adrar,Chlef,Laghouat,Oum El Bouaghi,Batna,Béjaïa,Biskra,Béchar,Blida,Bouira,Tamanrasset,Tébessa,Tlemcen,Tiaret,Tizi Ouzou,Alger,Djelfa,Jijel,Sétif,Saïda,Skikda,Sidi Bel Abbès,Annaba,Guelma,Constantine,Médéa,Mostaganem,M'Sila,Mascara,Ouargla,Oran,El Bayadh,Illizi,Bordj Bou Arréridj,Boumerdès,El Tarf,Tindouf,Tissemsilt,El Oued,Khenchela,Souk Ahras,Tipaza,Mila,Aïn Defla,Naâma,Aïn Témouchent,Ghardaïa,Relizane,Timimoun,Bordj Badji Mokhtar,Ouled Djellal,Béni Abbès,In Salah,In Guezzam,Touggourt,Djanet,El M'Ghair,El Meniaa".split(",");
const MB={
get(k,d){try{const v=JSON.parse(localStorage.getItem('mb_'+k));return v==null?d:v}catch(e){return d}},
set(k,v){try{localStorage.setItem('mb_'+k,JSON.stringify(v))}catch(e){alert('Stockage plein')}},
products(){return this.get('products',DEF)},orders(){return this.get('orders',[])},
da:n=>Math.round(n).toLocaleString('fr-FR').replace(/[\u202f\u00a0]/g,' ')+'\u00a0DA',
src:p=>p.img&&p.img.startsWith('data:')?p.img:'/assets/p/'+p.img,
esc:s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
theme(){const t=this.get('t','night');document.documentElement.dataset.t=t},
flip(){this.set('t',this.get('t','night')==='night'?'day':'night');this.theme()}};
MB.theme();
const CFG=window.MB_CONFIG||{};
Object.assign(MB,{S:{store:{phone:'',whatsapp:'',instagram:'',facebook:'',email:'',announcement:'',free_ship_from:0,free_ship_min_items:0,ship_fee:600,hero_images:[]},loyalty:{enabled:true,earn_per_100da:1,redeem_cost:100,redeem_percent:10}},P:[],D:[],ST:[],sb:null,
async load(){if(CFG.url&&CFG.key&&CFG.key.length>80&&window.supabase){const sb=this.sb=supabase.createClient(CFG.url,CFG.key),[s,c,p,d,y]=await Promise.all([sb.from('settings').select('*'),sb.from('categories').select('*').order('position'),sb.from('products').select('*').eq('active',true).order('position'),sb.from('discounts').select('*').eq('active',true),sb.from('stories').select('*').eq('published',true).order('position')]);
(s.data||[]).forEach(r=>this.S[r.key]={...this.S[r.key],...r.value});const cn=Object.fromEntries((c.data||[]).map(x=>[x.id,x.name]));this.D=d.data||[];this.ST=y.data||[];
this.P=(p.data||[]).map(x=>({id:x.id,cid:x.category_id,name:x.name,cat:cn[x.category_id]||'Divers',tag:x.badge,desc:x.tagline||'',story:x.story||'',comp:x.composition||{},sizes:(x.sizes||[]).map(s=>[s.label,s.price]),images:(x.images||[]).slice(0,5)}))}
else{this.ST=[{id:1,kicker:'Un parfum, une histoire',title:"Santal Impérial d'Orient",body:"Né d'un voyage à Mysore, ce flacon capture la chaleur des santals centenaires.\n\nChaque extrait repose plusieurs semaines avant d'être scellé à la cire dorée, puis numéroté à la main.",image:'/assets/p/santal.jpg',product_id:1}];this.P=DEF.map(p=>({...p,images:['/assets/p/'+p.img],story:p.desc,comp:{top:p.notes[0],heart:p.notes[1],base:p.notes[2]}}))}},
pct(p){const n=Date.now();return Math.max(0,...this.D.filter(d=>(!d.starts_at||+new Date(d.starts_at)<=n)&&(!d.ends_at||+new Date(d.ends_at)>=n)&&((d.product_ids||[]).includes(p.id)||(d.category_id&&d.category_id===p.cid))).map(d=>d.percent))},
pr(p,i){return Math.round(p.sizes[i][1]*(100-this.pct(p))/100)},img:u=>/^(https?:|data:|\/)/.test(u)?u:'/assets/p/'+u});
