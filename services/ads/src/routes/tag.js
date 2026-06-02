/**
 * Serves the embeddable ad tag (mca.js) — the MyChannel equivalent of
 * adsbygoogle.js. Publishers drop one <script> + <ins> per ad unit, and this
 * library discovers slots, requests fills, renders creatives, and fires
 * impression / viewability / click tracking.
 */
export default async function registerTagRoutes(app) {
  app.get('/mca.js', async (req, reply) => {
    const apiBase = process.env.ADS_PUBLIC_BASE || ''
    reply.header('Content-Type', 'application/javascript; charset=utf-8')
    reply.header('Cache-Control', 'public, max-age=600')
    return reply.send(TAG_JS.replace('__API_BASE__', apiBase))
  })

  // ads.txt for our own domain so we are a valid authorized seller.
  app.get('/ads.txt', async (req, reply) => {
    reply.header('Content-Type', 'text/plain')
    const host = process.env.ADS_TXT_HOST || 'mychannel.com'
    const tag = process.env.ADS_TXT_TAGID || 'f1a2b3c4d5e6f7a8'
    return reply.send(`${host}, ${process.env.ADS_OWN_PUB || 'pub-0000000000000000'}, DIRECT, ${tag}\n`)
  })
}

const TAG_JS = `(function(){
  "use strict";
  var API = "__API_BASE__";
  window.adsbymychannel = window.adsbymychannel || [];

  function qp(name){ try { return new URL(document.currentScript.src).searchParams.get(name); } catch(e){ return null; } }
  var DEFAULT_CLIENT = qp("client");

  function renderInto(ins, data){
    if(!data || !data.fill){ ins.setAttribute("data-mca-status","unfilled"); return; }
    ins.setAttribute("data-mca-status","filled");
    var c = data.creative || {};
    var a = document.createElement("a");
    a.href = data.click; a.target = "_blank"; a.rel = "noopener sponsored";
    a.style.cssText = "display:block;text-decoration:none;color:inherit;width:100%;height:100%";

    if(c.html){
      a.innerHTML = c.html;
    } else if(c.imageUrl && (data.format==="display"||!c.headline)){
      var img = document.createElement("img");
      img.src = c.imageUrl; img.alt = c.advertiser || "Ad"; img.loading="eager";
      img.style.cssText = "display:block;width:100%;height:auto;border:0";
      a.appendChild(img);
    } else {
      // native / in-article / in-feed text+image card
      var card = document.createElement("div");
      card.style.cssText = "display:flex;gap:10px;align-items:center;font-family:Arial,Helvetica,sans-serif;padding:8px;border:1px solid #e0e0e0;border-radius:8px";
      if(c.imageUrl){
        var im = document.createElement("img");
        im.src = c.imageUrl; im.style.cssText="width:96px;height:96px;object-fit:cover;border-radius:6px;flex:0 0 auto";
        card.appendChild(im);
      }
      var txt = document.createElement("div");
      txt.innerHTML = '<div style="font-size:11px;color:#1a73e8;font-weight:600">'+(c.advertiser||"Sponsored")+'</div>'+
        '<div style="font-size:15px;font-weight:700;color:#202124;margin:2px 0">'+(c.headline||"")+'</div>'+
        '<div style="font-size:13px;color:#5f6368">'+(c.body||"")+'</div>';
      card.appendChild(txt);
      a.appendChild(card);
    }

    var badge = document.createElement("span");
    badge.textContent = "Ad";
    badge.style.cssText = "position:absolute;top:2px;right:2px;font:10px Arial;background:rgba(0,0,0,.55);color:#fff;padding:1px 4px;border-radius:3px;z-index:2";
    ins.style.position = "relative";
    ins.innerHTML = "";
    ins.appendChild(a);
    ins.appendChild(badge);

    // impression ping
    fireImg(data.impPing);
    // viewability: 50% visible for >=1s
    observeView(ins, data.viewPing);
  }

  function fireImg(url){ if(!url) return; var i=new Image(); i.src = url + (url.indexOf("?")>-1?"&":"?") + "t=" + Date.now(); }

  function observeView(el, viewPing){
    if(!("IntersectionObserver" in window)){ fireImg(viewPing); return; }
    var timer=null;
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(e){
        if(e.isIntersecting && e.intersectionRatio>=0.5){
          if(!timer) timer = setTimeout(function(){ fireImg(viewPing); io.disconnect(); }, 1000);
        } else { clearTimeout(timer); timer=null; }
      });
    }, { threshold:[0,0.5,1] });
    io.observe(el);
  }

  function fillSlot(ins){
    if(ins.getAttribute("data-mca-status")) return; // already processed
    ins.setAttribute("data-mca-status","requesting");
    var client = ins.getAttribute("data-mca-client") || DEFAULT_CLIENT;
    var slot = ins.getAttribute("data-mca-slot");
    if(!client || !slot){ ins.setAttribute("data-mca-status","misconfigured"); return; }
    var rect = ins.getBoundingClientRect();
    var u = API + "/pub/ad?client="+encodeURIComponent(client)+"&slot="+encodeURIComponent(slot)+
            "&url="+encodeURIComponent(location.href)+
            "&w="+Math.round(rect.width||0)+"&h="+Math.round(rect.height||0);
    fetch(u, { credentials:"omit" }).then(function(r){ return r.json(); })
      .then(function(d){ renderInto(ins, d); })
      .catch(function(){ ins.setAttribute("data-mca-status","error"); });
  }

  function scan(){
    var nodes = document.querySelectorAll("ins.adsbymychannel:not([data-mca-status])");
    for(var i=0;i<nodes.length;i++) fillSlot(nodes[i]);
  }

  // push() API mirrors (adsbygoogle=window.adsbygoogle||[]).push({})
  var realPush = function(){ scan(); };
  if(Array.isArray(window.adsbymychannel)){
    var pending = window.adsbymychannel.length;
    window.adsbymychannel.push = realPush;
    for(var k=0;k<pending;k++) realPush();
  } else {
    window.adsbymychannel = { push: realPush };
  }

  if(document.readyState==="loading") document.addEventListener("DOMContentLoaded", scan);
  else scan();
})();`
