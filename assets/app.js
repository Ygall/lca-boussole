// Boussole LCA - comportement de la page.
// Données injectées à la génération (R/page.R) : MM, PM (arbres markmap), PD (notions du réseau),
// PH (phases), FI (fiches récap).

// Onglets
const tabs=[['t1','p1'],['t2','p2'],['t3','p3'],['t4','p4']];
function show(k){tabs.forEach(([t,p])=>{const on=t===k;document.getElementById(t).setAttribute('aria-selected',on);document.getElementById(p).hidden=!on;});if(k==='t1'&&mm)mm.fit();if(k==='t2'){if(!pm)initPm();else pm.fit();}}
tabs.forEach(([t])=>document.getElementById(t).onclick=()=>show(t));

// Carte mentale des notions (markmap)
const COL={R:'#5F5E5A',A:'#534AB7',B:'#0F6E56',C:'#993C1D',D:'#185FA5'};
function setFold(n,depth,mode){if(n.children){n.payload.fold=(mode==='dom'&&depth===2)?1:0;n.children.forEach(c=>setFold(c,depth+1,mode));}}
let mm=null;
try{mm=markmap.Markmap.create('#mm',{color:n=>COL[(n.payload||{}).cat]||'#5F5E5A',duration:300,maxWidth:0,spacingVertical:6,paddingX:10},MM);}catch(e){document.getElementById('mmbox').textContent='La carte mentale n’a pas pu être affichée.';}
document.getElementById('mmAll').onclick=()=>{setFold(MM,0,'all');mm.setData(MM);mm.fit();};
document.getElementById('mmDom').onclick=()=>{setFold(MM,0,'dom');mm.setData(MM);mm.fit();};
document.getElementById('mmFit').onclick=()=>mm.fit();

// Carte mentale du parcours (construite à la première ouverture de l'onglet)
let pm=null;
function phFold(n,depth,mode){if(n.children){n.payload.fold=(mode==='ph'&&depth===2)?1:0;n.children.forEach(c=>phFold(c,depth+1,mode));}}
function initPm(){phFold(PM,0,'ph');try{pm=markmap.Markmap.create('#pm',{color:n=>COL[(n.payload||{}).cat]||'#5F5E5A',duration:300,maxWidth:0,spacingVertical:6,paddingX:10},PM);}catch(e){document.getElementById('pm').parentNode.textContent='La carte du parcours n’a pas pu être affichée.';}}
document.getElementById('pmAll').onclick=()=>{phFold(PM,0,'all');pm.setData(PM);pm.fit();};
document.getElementById('pmPh').onclick=()=>{phFold(PM,0,'ph');pm.setData(PM);pm.fit();};
document.getElementById('pmFit').onclick=()=>pm.fit();

// Réseau des dépendances
const svg=document.getElementById('net');const vb=svg.viewBox.baseVal;
const nodes={},pred={},succ={},edges=[];
svg.querySelectorAll('g.node').forEach(g=>{const id=g.querySelector('title').textContent.trim();nodes[id]=g;pred[id]=[];succ[id]=[];});
// Graphviz écrit le port dans le titre des arêtes (n001:e->n002:w) : on le retire.
svg.querySelectorAll('g.edge').forEach(g=>{const [a,b]=g.querySelector('title').textContent.trim().split('->').map(x=>x.split(':')[0]);edges.push({a,b,g});succ[a].push(b);pred[b].push(a);});
svg.querySelectorAll('a').forEach(a=>a.removeAttribute('xlink:title'));
function zoom(){const z=document.getElementById('zoom').value/100;svg.setAttribute('width',vb.width*z);svg.setAttribute('height',vb.height*z);}
document.getElementById('zoom').oninput=zoom;zoom();
function closure(id,m,full){const s=new Set();const st=[...m[id]];while(st.length){const x=st.pop();if(s.has(x))continue;s.add(x);if(full)st.push(...m[x]);}return s;}
let cur=null;
function clear(){Object.values(nodes).forEach(g=>g.classList.remove('dim','sel'));edges.forEach(e=>e.g.classList.remove('dim','hl-a','hl-d','hl-p'));}
function li(ids){return [...ids].sort().map(i=>`<li data-id="${i}">${PD[i].num}. ${PD[i].t} <span style="color:var(--muted)">[${PD[i].c}]</span></li>`).join('')||'<li style="list-style:none;margin-left:-18px;color:var(--muted)">aucune</li>';}
function select(id){if(!nodes[id])return;cur=id;clear();
const full=document.getElementById('scope').value==='all',dir=document.getElementById('dir').value;
const A=dir!=='desc'?closure(id,pred,full):new Set(),De=dir!=='anc'?closure(id,succ,full):new Set();
Object.entries(nodes).forEach(([k,g])=>{if(k!==id&&!A.has(k)&&!De.has(k))g.classList.add('dim');});
nodes[id].classList.add('sel');
edges.forEach(e=>{const inA=A.has(e.a)&&(A.has(e.b)||e.b===id),inD=(e.a===id||De.has(e.a))&&De.has(e.b);
if(inA)e.g.classList.add('hl-a');else if(inD)e.g.classList.add('hl-d');else e.g.classList.add('dim');});
const d=PD[id];document.getElementById('info').innerHTML=`<h2>${d.num}. ${d.t}</h2><p style="margin:0 0 8px;color:var(--muted)">[${d.c}], phase ${d.p}, ${d.lvl}</p><strong>Prérequis directs</strong><ul>${li(pred[id])}</ul><strong>Dépendances directes</strong><ul>${li(succ[id])}</ul>`+(full?`<p style="color:var(--muted);margin:0">Chaîne complète : ${A.size} prérequis, ${De.size} dépendances.</p>`:'');
document.querySelectorAll('#info li[data-id]').forEach(l=>l.onclick=()=>{select(l.dataset.id);center(l.dataset.id);});
document.getElementById('num').value=parseInt(d.num,10);}
function center(id){const f=document.getElementById('fig'),r=nodes[id].getBoundingClientRect(),fr=f.getBoundingClientRect();f.scrollBy({left:r.left-fr.left-fr.width/2+r.width/2,top:r.top-fr.top-fr.height/2+r.height/2,behavior:'smooth'});}
Object.entries(nodes).forEach(([k,g])=>g.addEventListener('click',ev=>{ev.stopPropagation();phSel.value='';select(k);}));
document.getElementById('num').onchange=e=>{phSel.value='';const id='n'+String(e.target.value).padStart(3,'0');select(id);center(id);};
['scope','dir'].forEach(i=>document.getElementById(i).onchange=()=>cur&&select(cur));
const phSel=document.getElementById('phase');
PH.forEach(p=>{const o=document.createElement('option');o.value=p.k;o.textContent=p.l;phSel.appendChild(o);});
function selectPhase(k){const p=PH.find(x=>String(x.k)===String(k));if(!p)return;cur=null;clear();document.getElementById('num').value='';
const S=new Set(p.ids),Ext=new Set();p.ids.forEach(i=>pred[i].forEach(a=>{if(!S.has(a))Ext.add(a);}));
Object.entries(nodes).forEach(([k2,g])=>{if(S.has(k2))g.classList.add('sel');else if(!Ext.has(k2))g.classList.add('dim');});
edges.forEach(e=>{if(S.has(e.a)&&S.has(e.b))e.g.classList.add('hl-p');else if(Ext.has(e.a)&&S.has(e.b))e.g.classList.add('hl-a');else e.g.classList.add('dim');});
document.getElementById('info').innerHTML=`<h2>${p.l}</h2><p style="margin:0 0 8px;color:var(--muted)">${p.an}, ${p.ids.length} notions</p><strong>Notions de la phase</strong><ul>${li(p.ids)}</ul><strong>Prérequis issus d’autres phases</strong><ul>${li(Ext)}</ul>`;
document.querySelectorAll('#info li[data-id]').forEach(l=>l.onclick=()=>{phSel.value='';select(l.dataset.id);center(l.dataset.id);});
center(p.ids[0]);}
phSel.onchange=e=>{if(e.target.value)selectPhase(e.target.value);else document.getElementById('reset').click();};
document.getElementById('reset').onclick=()=>{cur=null;clear();phSel.value='';document.getElementById('info').innerHTML='<h2>Aucune notion sélectionnée</h2>';};

// Fiches récap
const fsel=document.getElementById('fsel');
FI.forEach((f,i)=>{const o=document.createElement('option');o.value=i;o.textContent=f.titre;fsel.appendChild(o);});
document.getElementById('fcount').textContent=FI.length+' fiche'+(FI.length>1?'s':'')+' disponible'+(FI.length>1?'s':'');
function showFiche(i){document.getElementById('fiche').innerHTML=FI[i]?FI[i].html:'<p>Aucune fiche disponible.</p>';}
fsel.onchange=e=>showFiche(e.target.value);showFiche(0);
