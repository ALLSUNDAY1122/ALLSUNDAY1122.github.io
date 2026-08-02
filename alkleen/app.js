const menu=document.getElementById('menu');
const nav=document.getElementById('nav');
menu.addEventListener('click',()=>nav.classList.toggle('open'));
nav.querySelectorAll('a').forEach(a=>a.addEventListener('click',()=>nav.classList.remove('open')));
document.getElementById('form').addEventListener('submit',event=>{
  event.preventDefault();
  document.getElementById('result').style.display='block';
});
