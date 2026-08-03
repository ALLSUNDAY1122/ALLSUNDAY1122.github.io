/* =========================================================================
   いっしょに一冊 — 挿絵エンジン コア
   場面ごとに構図を組み立てるための、背景・キャラクター・小道具の部品集。
   すべて手描きのSVGパスで構成し、外部画像・外部通信は使用しない。
   ========================================================================= */
var ARTCORE = (function () {
  "use strict";

  /* ---------- 基本ヘルパー ---------- */

  function G(inner, o) {
    o = o || {};
    var x = o.x || 0, y = o.y || 0, s = o.s == null ? 1 : o.s;
    var fx = o.flip ? -1 : 1;
    var r = o.rot ? " rotate(" + o.rot + ")" : "";
    return '<g transform="translate(' + x + ',' + y + ') scale(' + (s * fx) + ',' + s + ')' + r + '">' + inner + "</g>";
  }
  function ell(cx, cy, rx, ry, fill, extra) {
    return '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + rx + '" ry="' + ry + '" fill="' + fill + '"' + (extra || "") + "/>";
  }
  function cir(cx, cy, r, fill, extra) {
    return '<circle cx="' + cx + '" cy="' + cy + '" r="' + r + '" fill="' + fill + '"' + (extra || "") + "/>";
  }
  function pth(d, fill, extra) {
    return '<path d="' + d + '" fill="' + fill + '"' + (extra || "") + "/>";
  }
  function rect(x, y, w, h, fill, rx, extra) {
    return '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" fill="' + fill + '" rx="' + (rx || 0) + '"' + (extra || "") + "/>";
  }
  function line(x1, y1, x2, y2, stroke, w, extra) {
    return '<path d="M' + x1 + ' ' + y1 + ' L' + x2 + ' ' + y2 + '" stroke="' + stroke + '" stroke-width="' + w + '" stroke-linecap="round" fill="none"' + (extra || "") + "/>";
  }
  function curve(d, stroke, w, extra) {
    return '<path d="' + d + '" stroke="' + stroke + '" stroke-width="' + w + '" fill="none" stroke-linecap="round"' + (extra || "") + "/>";
  }
  function seeded(seed) {
    var v = seed;
    return function () { v = (v * 1103515245 + 12345) % 2147483648; return v / 2147483648; };
  }

  /* ---------- 表情パーツ ---------- */

  function eye(x, y, r, expr, dark) {
    dark = dark || "#3A2A20";
    switch (expr) {
      case "happy":
        return curve("M" + (x - r) + " " + (y + r * 0.3) + " Q" + x + " " + (y - r * 1.1) + " " + (x + r) + " " + (y + r * 0.3), dark, r * 0.62);
      case "closed":
      case "sleep":
        return curve("M" + (x - r) + " " + y + " Q" + x + " " + (y + r * 0.95) + " " + (x + r) + " " + y, dark, r * 0.6);
      case "surprised":
        return cir(x, y, r * 1.25, "#FFFFFF") + cir(x, y, r * 0.78, dark) + cir(x + r * 0.28, y - r * 0.32, r * 0.24, "#FFFFFF");
      case "sad":
        return curve("M" + (x - r) + " " + (y - r * 0.15) + " Q" + x + " " + (y + r * 0.75) + " " + (x + r) + " " + (y - r * 0.15), dark, r * 0.58);
      case "angry":
        return cir(x, y + r * 0.2, r * 0.8, dark) +
          line(x - r * 1.1, y - r * 1.15, x + r * 0.75, y - r * 0.45, dark, r * 0.5);
      default:
        return cir(x, y, r, dark) + cir(x + r * 0.3, y - r * 0.35, r * 0.3, "#FFFFFF");
    }
  }

  function mouth(x, y, w, type, dark) {
    dark = dark || "#3A2A20";
    switch (type) {
      case "open":
        return ell(x, y + w * 0.15, w * 0.45, w * 0.55, "#B5544C") + ell(x, y + w * 0.42, w * 0.28, w * 0.24, "#E58C86");
      case "wide":
        return pth("M" + (x - w) + " " + y + " Q" + x + " " + (y + w * 1.5) + " " + (x + w) + " " + y + " Z", "#B5544C");
      case "flat":
        return line(x - w * 0.6, y, x + w * 0.6, y, dark, w * 0.28);
      case "frown":
        return curve("M" + (x - w * 0.7) + " " + (y + w * 0.4) + " Q" + x + " " + (y - w * 0.35) + " " + (x + w * 0.7) + " " + (y + w * 0.4), dark, w * 0.28);
      case "talk":
        return ell(x, y, w * 0.4, w * 0.5, "#B5544C");
      default:
        return curve("M" + (x - w * 0.7) + " " + y + " Q" + x + " " + (y + w * 0.85) + " " + (x + w * 0.7) + " " + y, dark, w * 0.28);
    }
  }

  function blush(x, y, r, color) {
    return ell(x, y, r, r * 0.66, color || "#F4A0A0", ' opacity="0.55"');
  }

  /* キャラクターの足元が画面下(300)で切れないよう位置を補正する。
     bottom = キャラ原点から足先までの距離（拡大前）。 */
  function fitY(o, bottom) {
    var s = o.s == null ? 1 : o.s;
    var limit = 294 - bottom * s;
    if (o.y > limit) o.y = limit;
    return o;
  }

  /* ---------- 空・地面・天候 ---------- */

  function skyBox(topColor, bottomColor, id) {
    return '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1">' +
      '<stop offset="0%" stop-color="' + topColor + '"/>' +
      '<stop offset="100%" stop-color="' + bottomColor + '"/></linearGradient></defs>' +
      rect(0, 0, 400, 300, "url(#" + id + ")");
  }

  var SKY = {
    morning: function (id) { return skyBox("#BFE3F5", "#FFF0DC", id); },
    day: function (id) { return skyBox("#A9DCF2", "#E8F6E4", id); },
    dusk: function (id) { return skyBox("#F5B98A", "#FBE3C4", id); },
    night: function (id) { return skyBox("#2E3D63", "#5B6C93", id); },
    snowDay: function (id) { return skyBox("#CFE6F3", "#F4FAFD", id); },
    spring: function (id) { return skyBox("#BCE6F7", "#F3F8DC", id); },
    autumn: function (id) { return skyBox("#CFE4F0", "#F7EDCF", id); },
    underground: function (id) { return skyBox("#7A5236", "#4E3221", id); }
  };

  function ground(y, color, color2) {
    var s = pth("M0 " + y + " Q100 " + (y - 22) + " 200 " + (y - 6) + " Q300 " + (y + 10) + " 400 " + (y - 14) + " L400 300 L0 300 Z", color);
    if (color2) {
      s += pth("M0 " + (y + 16) + " Q120 " + (y + 2) + " 240 " + (y + 20) + " Q330 " + (y + 32) + " 400 " + (y + 14) + " L400 300 L0 300 Z", color2);
    }
    return s;
  }

  function snowGround(y) {
    return pth("M0 " + y + " Q90 " + (y - 20) + " 190 " + (y - 4) + " Q290 " + (y + 12) + " 400 " + (y - 10) + " L400 300 L0 300 Z", "#FFFFFF") +
      pth("M0 " + (y + 20) + " Q120 " + (y + 6) + " 250 " + (y + 24) + " Q330 " + (y + 34) + " 400 " + (y + 18) + " L400 300 L0 300 Z", "#E9F3FA");
  }

  function snowFall(n, seed) {
    var r = seeded(seed || 7), s = "";
    for (var i = 0; i < n; i++) {
      s += cir(r() * 400, r() * 300, 1.6 + r() * 2.6, "#FFFFFF", ' opacity="' + (0.55 + r() * 0.4) + '"');
    }
    return s;
  }

  function stars(n, seed) {
    var r = seeded(seed || 3), s = "";
    for (var i = 0; i < n; i++) {
      s += cir(r() * 400, r() * 150, 0.9 + r() * 1.5, "#FFF6D8", ' opacity="' + (0.5 + r() * 0.5) + '"');
    }
    return s;
  }

  function mountains(y, c1, c2) {
    return pth("M-10 " + y + " L70 " + (y - 70) + " L140 " + y + " Z", c1) +
      pth("M90 " + y + " L180 " + (y - 92) + " L275 " + y + " Z", c2 || c1) +
      pth("M230 " + y + " L310 " + (y - 62) + " L400 " + y + " Z", c1);
  }

  function tree(x, y, s, leafColor, trunkColor) {
    var inner = pth("M-7 0 L-4 -46 L4 -46 L7 0 Z", trunkColor || "#8A6242") +
      cir(0, -58, 30, leafColor || "#6FA45C") +
      cir(-22, -44, 21, leafColor || "#6FA45C") +
      cir(22, -46, 22, leafColor || "#6FA45C") +
      cir(-6, -76, 19, leafColor || "#7FB169");
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  function snowTree(x, y, s) {
    var inner = pth("M-6 0 L-4 -40 L4 -40 L6 0 Z", "#7A5A3E") +
      pth("M0 -78 L26 -40 L-26 -40 Z", "#5E8C6A") +
      pth("M0 -62 L32 -14 L-32 -14 Z", "#4F7C5C") +
      pth("M0 -78 L18 -50 L-18 -50 Z", "#FFFFFF") +
      pth("M0 -62 L23 -26 L-23 -26 Z", "#FFFFFF", ' opacity="0.9"');
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  function grass(x, y, s, color) {
    var inner = "";
    for (var i = -2; i <= 2; i++) {
      inner += curve("M" + (i * 7) + " 0 Q" + (i * 7 + 3) + " -12 " + (i * 7 + 7) + " -18", color || "#77A860", 3);
    }
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  function flower(x, y, s, petal) {
    var inner = "";
    for (var i = 0; i < 5; i++) {
      var a = (i / 5) * Math.PI * 2;
      inner += ell(Math.cos(a) * 6, Math.sin(a) * 6, 4.4, 4.4, petal || "#F6A8C0");
    }
    inner += cir(0, 0, 3.4, "#FFD97A");
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  /* ---------- きつね ---------- */
  function fox(o) {
    o = fitY(o || {}, 34);
    var expr = o.expr || "normal", mo = o.mouth || "smile";
    var pose = o.pose || "stand";
    var big = o.kind === "mother";
    var C = big
      ? { body: "#D9762F", light: "#FBE3C6", dark: "#B8571E" }
      : { body: "#EE9450", light: "#FFF0DC", dark: "#CC7333" };

    var inner = "";

    if (pose === "curl") {
      inner += pth("M-24 4 C-58 6 -66 -26 -40 -34 C-48 -16 -38 -6 -20 -6 Z", C.body);
      inner += pth("M-52 -30 C-64 -30 -66 -14 -54 -8 C-56 -18 -54 -26 -46 -32 Z", C.light);
    } else {
      inner += pth("M-26 -2 C-60 -8 -70 -42 -44 -50 C-52 -30 -42 -16 -22 -12 Z", C.body);
      inner += pth("M-56 -44 C-70 -44 -72 -28 -58 -22 C-60 -32 -58 -40 -48 -48 Z", C.light);
    }

    if (pose === "run") {
      inner += ell(-14, 20, 7, 12, C.dark, ' transform="rotate(-24 -14 20)"');
      inner += ell(16, 20, 7, 12, C.dark, ' transform="rotate(22 16 20)"');
    } else if (pose === "sit" || pose === "curl") {
      inner += ell(-8, 22, 13, 9, C.dark);
      inner += ell(14, 22, 12, 9, C.dark);
    } else {
      inner += ell(-13, 21, 7.5, 12, C.dark);
      inner += ell(15, 21, 7.5, 12, C.dark);
    }

    if (pose === "curl") inner += ell(0, 2, 32, 22, C.body);
    else if (pose === "sit") inner += ell(0, 2, 26, 24, C.body);
    else inner += ell(0, 0, 30, 22, C.body);
    inner += ell(9, 8, 15, 13, C.light);

    if (o.arm === "out") {
      inner += ell(34, 6, 13, 7, C.body, ' transform="rotate(-16 34 6)"');
      if (o.humanHand) {
        inner += ell(48, 0, 8, 9, "#F6D2B4");
        inner += line(45, -6, 44, -12, "#F6D2B4", 3.4);
        inner += line(49, -7, 49, -13, "#F6D2B4", 3.4);
        inner += line(53, -6, 55, -12, "#F6D2B4", 3.4);
      } else {
        inner += ell(48, 2, 8, 7, C.dark);
      }
    } else if (o.arm === "up") {
      inner += ell(26, -8, 7, 14, C.body, ' transform="rotate(-40 26 -8)"');
    }

    var hx = 28, hy = -22;
    inner += pth("M" + (hx - 14) + " " + (hy - 12) + " L" + (hx - 20) + " " + (hy - 34) + " L" + (hx - 2) + " " + (hy - 20) + " Z", C.body);
    inner += pth("M" + (hx + 8) + " " + (hy - 16) + " L" + (hx + 16) + " " + (hy - 36) + " L" + (hx + 20) + " " + (hy - 14) + " Z", C.body);
    inner += pth("M" + (hx - 13) + " " + (hy - 15) + " L" + (hx - 16) + " " + (hy - 28) + " L" + (hx - 5) + " " + (hy - 19) + " Z", "#F2B8B0");
    inner += pth("M" + (hx + 10) + " " + (hy - 18) + " L" + (hx + 15) + " " + (hy - 30) + " L" + (hx + 17) + " " + (hy - 17) + " Z", "#F2B8B0");
    inner += cir(hx, hy, 19, C.body);
    inner += ell(hx + 12, hy + 6, 14, 10, C.light);
    inner += ell(hx + 22, hy + 4, 4.6, 3.6, "#4A3226");
    inner += eye(hx - 6, hy - 3, 3.4, expr);
    inner += eye(hx + 8, hy - 3, 3.4, expr);
    if (expr !== "sad" && expr !== "angry") inner += blush(hx - 11, hy + 7, 5, "#F5A9A2");
    inner += mouth(hx + 14, hy + 9, 5, mo);

    if (o.mittens) {
      inner += ell(34, 8, 10, 8, "#E15F4F", ' transform="rotate(-14 34 8)"');
      inner += ell(-2, 12, 9, 7, "#E15F4F");
    }

    return G(inner, o);
  }

  /* ---------- かえる ---------- */
  function frog(o) {
    o = fitY(o || {}, 28);
    var expr = o.expr || "normal", mo = o.mouth || "smile", pose = o.pose || "stand";
    var C = o.color === "yellow"
      ? { body: "#E8C24A", light: "#F7E7A8", dark: "#C79E2E" }
      : { body: "#6FB35A", light: "#C6E4AE", dark: "#4F8C3F" };

    var inner = "";

    if (pose === "jump") {
      inner += ell(-26, 6, 10, 18, C.dark, ' transform="rotate(38 -26 6)"');
      inner += ell(26, 6, 10, 18, C.dark, ' transform="rotate(-38 26 6)"');
    } else if (pose === "swim") {
      inner += ell(-28, 10, 15, 8, C.dark, ' transform="rotate(-14 -28 10)"');
      inner += ell(28, 10, 15, 8, C.dark, ' transform="rotate(14 28 10)"');
    } else {
      inner += ell(-24, 16, 13, 10, C.dark);
      inner += ell(24, 16, 13, 10, C.dark);
      inner += ell(-30, 22, 9, 5, C.dark);
      inner += ell(30, 22, 9, 5, C.dark);
    }

    inner += ell(0, 2, 28, 24, C.body);
    inner += ell(0, 10, 18, 15, C.light);
    inner += ell(-17, 20, 7, 5, C.body);
    inner += ell(17, 20, 7, 5, C.body);

    inner += cir(-13, -22, 11, C.body);
    inner += cir(13, -22, 11, C.body);
    if (expr === "sleep" || expr === "closed") {
      inner += curve("M-19 -22 Q-13 -16 -7 -22", "#3A2A20", 2.4);
      inner += curve("M7 -22 Q13 -16 19 -22", "#3A2A20", 2.4);
    } else {
      inner += cir(-13, -22, 7, "#FFFFFF");
      inner += cir(13, -22, 7, "#FFFFFF");
      inner += eye(-13, -22, 4, expr);
      inner += eye(13, -22, 4, expr);
    }
    inner += mouth(0, -2, 8, mo);
    if (expr !== "angry") { inner += blush(-19, -4, 5, "#EE9C93"); inner += blush(19, -4, 5, "#EE9C93"); }

    return G(inner, o);
  }

  /* ---------- ねずみ ---------- */
  function mouse(o) {
    o = fitY(o || {}, 26);
    var expr = o.expr || "normal", mo = o.mouth || "smile";
    var k = o.kind || "father";
    var C = { body: "#A9A19B", light: "#E4DFDA", dark: "#8A827C" };
    if (k === "daughter") C = { body: "#C8BDB4", light: "#F3EDE6", dark: "#A79C93" };
    if (k === "groom") C = { body: "#9C8F86", light: "#DDD4CB", dark: "#7E736A" };
    if (k === "mother") C = { body: "#B4ABA4", light: "#EAE4DE", dark: "#948B84" };

    var inner = "";
    inner += curve("M-22 6 C-46 8 -52 -14 -36 -20", C.dark, 3.2);
    inner += ell(-9, 19, 7, 6, C.dark);
    inner += ell(11, 19, 7, 6, C.dark);
    inner += ell(0, 2, 24, 19, C.body);
    inner += ell(4, 8, 14, 12, C.light);
    inner += cir(14, -26, 10, C.body);
    inner += cir(14, -26, 6, "#F0BFC0");
    inner += cir(30, -24, 9, C.body);
    inner += cir(30, -24, 5.4, "#F0BFC0");
    inner += cir(23, -12, 15, C.body);
    inner += pth("M32 -10 L46 -6 L32 -1 Z", C.body);
    inner += cir(46, -6, 3, "#E58A8A");
    inner += eye(18, -14, 3.2, expr);
    inner += eye(29, -14, 3.2, expr);
    inner += mouth(36, -4, 4, mo);
    if (expr !== "sad") inner += blush(15, -6, 4.4, "#EFA6A6");
    inner += line(38, -6, 50, -10, "#6E645C", 0.9);
    inner += line(38, -4, 51, -3, "#6E645C", 0.9);
    if (k === "daughter") inner += flower(12, -32, 0.8, "#F4A6C2");
    if (o.arm === "up") inner += ell(20, -2, 5, 11, C.body, ' transform="rotate(-38 20 -2)"');
    return G(inner, o);
  }

  /* ---------- おひさま ---------- */
  function sunFace(o) {
    o = o || {};
    var expr = o.expr || "happy", mo = o.mouth || "smile";
    var inner = "";
    for (var i = 0; i < 12; i++) {
      var a = (i / 12) * Math.PI * 2;
      inner += pth("M" + (Math.cos(a) * 40) + " " + (Math.sin(a) * 40) +
        " L" + (Math.cos(a + 0.13) * 56) + " " + (Math.sin(a + 0.13) * 56) +
        " L" + (Math.cos(a + 0.26) * 40) + " " + (Math.sin(a + 0.26) * 40) + " Z", "#FBC94A");
    }
    inner += cir(0, 0, 40, "#FFD65E");
    inner += cir(0, 0, 33, "#FFE27E");
    inner += eye(-12, -5, 4.4, expr);
    inner += eye(12, -5, 4.4, expr);
    inner += mouth(0, 10, 9, mo);
    inner += blush(-20, 6, 6, "#F3A05F");
    inner += blush(20, 6, 6, "#F3A05F");
    return G(inner, o);
  }

  /* ---------- くも ---------- */
  function cloudFace(o) {
    o = o || {};
    var expr = o.expr || "normal", mo = o.mouth || "smile";
    var c = o.color || "#FFFFFF", sh = o.shadow || "#DCE6EE";
    var inner = "";
    inner += ell(-30, 8, 30, 20, sh) + ell(30, 8, 30, 20, sh) + ell(0, 2, 40, 26, sh);
    inner += ell(-28, 2, 28, 19, c) + ell(28, 2, 28, 19, c) + ell(0, -6, 38, 25, c);
    inner += ell(-12, -18, 22, 16, c) + ell(16, -16, 20, 15, c);
    inner += eye(-13, -6, 4, expr);
    inner += eye(13, -6, 4, expr);
    inner += mouth(0, 8, 8, mo);
    return G(inner, o);
  }

  /* ---------- かぜ ---------- */
  function windFace(o) {
    o = o || {};
    var expr = o.expr || "normal", mo = o.mouth || "open";
    var inner = "";
    inner += ell(0, 0, 40, 30, "#CFE3EE", ' opacity="0.85"');
    inner += ell(-14, -10, 22, 16, "#E4F0F7", ' opacity="0.9"');
    inner += eye(-13, -6, 4, expr);
    inner += eye(11, -6, 4, expr);
    inner += mouth(2, 8, 7, mo);
    for (var i = 0; i < 3; i++) {
      inner += curve("M22 " + (10 + i * 12) + " Q60 " + (2 + i * 12) + " 96 " + (16 + i * 12) +
        " Q108 " + (22 + i * 12) + " 100 " + (30 + i * 12), "#FFFFFF", 3, ' opacity="0.85"');
    }
    return G(inner, o);
  }

  /* ---------- かべ ---------- */
  function wallFace(o) {
    o = o || {};
    var expr = o.expr || "normal", mo = o.mouth || "flat";
    var inner = "";
    inner += rect(-70, -60, 140, 130, "#D9CDB6", 6);
    inner += rect(-70, -60, 140, 14, "#B9A98C", 4);
    for (var i = 0; i < 4; i++) inner += line(-70, -34 + i * 24, 70, -34 + i * 24, "#C3B69C", 2);
    for (var j = 0; j < 3; j++) inner += line(-36 + j * 36, -46, -36 + j * 36, 70, "#C3B69C", 2);
    inner += eye(-22, -4, 5, expr);
    inner += eye(22, -4, 5, expr);
    inner += mouth(0, 22, 11, mo);
    if (o.hole) {
      inner += ell(40, 52, 13, 10, "#4A3D2C");
      inner += ell(40, 52, 9, 7, "#2E251A");
    }
    return G(inner, o);
  }

  return {
    G: G, ell: ell, cir: cir, pth: pth, rect: rect, line: line, curve: curve, seeded: seeded,
    eye: eye, mouth: mouth, blush: blush,
    SKY: SKY, ground: ground, snowGround: snowGround, snowFall: snowFall, stars: stars,
    mountains: mountains, tree: tree, snowTree: snowTree, grass: grass, flower: flower,
    fox: fox, frog: frog, mouse: mouse, sunFace: sunFace, cloudFace: cloudFace,
    windFace: windFace, wallFace: wallFace
  };
})();
