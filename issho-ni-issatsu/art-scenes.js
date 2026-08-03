/* =========================================================================
   いっしょに一冊 — 場面別 挿絵
   1ページにつき1枚、そのページの本文に対応した構図を個別に組み立てる。
   ========================================================================= */
var ART = (function (A) {
  "use strict";

  var G = A.G, ell = A.ell, cir = A.cir, pth = A.pth, rect = A.rect,
      line = A.line, curve = A.curve, seeded = A.seeded,
      eye = A.eye, mouth = A.mouth, blush = A.blush,
      SKY = A.SKY, ground = A.ground, snowGround = A.snowGround,
      snowFall = A.snowFall, stars = A.stars, mountains = A.mountains,
      tree = A.tree, snowTree = A.snowTree, grass = A.grass, flower = A.flower,
      fox = A.fox, frog = A.frog, mouse = A.mouse,
      sunFace = A.sunFace, cloudFace = A.cloudFace, windFace = A.windFace, wallFace = A.wallFace;

  /* =====================================================================
     追加の小道具
     ===================================================================== */

  // 米俵
  function bale(x, y, s) {
    var inner = ell(0, 0, 26, 17, "#D9BE7E") +
      ell(0, 0, 26, 17, "none", ' stroke="#B99B5E" stroke-width="2"') +
      line(-16, -13, -16, 13, "#B99B5E", 2.4) +
      line(0, -16, 0, 16, "#B99B5E", 2.4) +
      line(16, -13, 16, 13, "#B99B5E", 2.4) +
      ell(-26, 0, 5, 8, "#C7A96A") + ell(26, 0, 5, 8, "#C7A96A");
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  // お倉の内側（板壁と梁）
  function storeInterior() {
    var s = rect(0, 0, 400, 300, "#C9A97C");
    s += rect(0, 0, 400, 300, "#B8956A");
    for (var i = 0; i < 9; i++) s += line(i * 46, 0, i * 46, 230, "#A9855C", 2);
    s += rect(0, 0, 400, 34, "#8E6C46");
    s += rect(0, 26, 400, 10, "#7B5C3B");
    s += pth("M0 230 L400 230 L400 300 L0 300 Z", "#8E6C46");
    s += line(0, 236, 400, 236, "#7B5C3B", 3);
    // 小窓の光
    s += rect(292, 58, 58, 46, "#FBE7B4", 4);
    s += rect(292, 58, 58, 46, "none", ' stroke="#8E6C46" stroke-width="4"');
    s += line(321, 58, 321, 104, "#8E6C46", 3);
    s += pth("M292 104 L350 104 L392 210 L318 210 Z", "#FBE7B4", ' opacity="0.34"');
    return s;
  }

  // ちいさな家（灯りつき）
  function house(x, y, s, lit) {
    var inner = pth("M-44 0 L-44 -34 L0 -60 L44 -34 L44 0 Z", "#C4785A");
    inner += pth("M-52 -32 L0 -68 L52 -32 Z", "#8E4F3C");
    inner += rect(-14, -28, 28, 28, lit ? "#FFE49B" : "#6B5140", 3);
    inner += rect(-14, -28, 28, 28, "none", ' stroke="#7A4A38" stroke-width="3"');
    inner += line(0, -28, 0, 0, "#7A4A38", 2.6);
    inner += line(-14, -14, 14, -14, "#7A4A38", 2.6);
    if (lit) inner += pth("M-14 0 L14 0 L34 44 L-34 44 Z", "#FFE49B", ' opacity="0.30"');
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  // 帽子屋（大きなシルクハットの看板）
  function hatShop(x, y, s, doorOpen) {
    var inner = rect(-60, -80, 120, 80, "#B8886A", 4);
    inner += pth("M-70 -80 L70 -80 L58 -100 L-58 -100 Z", "#8A5B45");
    // 看板
    inner += rect(-22, -136, 44, 8, "#6E4632", 2);
    inner += line(0, -128, 0, -104, "#6E4632", 3);
    inner += ell(0, -122, 26, 7, "#3E3A46");
    inner += rect(-13, -150, 26, 30, "#3E3A46", 3);
    inner += rect(-13, -132, 26, 6, "#C0503F");
    // 戸
    inner += rect(-20, -56, 40, 56, "#7A4E38", 2);
    if (doorOpen) {
      inner += rect(-20, -56, 15, 56, "#FFE49B", 1);
      inner += pth("M-20 0 L-5 0 L14 46 L-40 46 Z", "#FFE49B", ' opacity="0.45"');
    }
    inner += line(10, -30, 10, -24, "#4A2E20", 3);
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  // 霜柱
  function frostPillars(y) {
    var s = "", r = seeded(21);
    for (var i = 0; i < 26; i++) {
      var x = 6 + i * 15.4, h = 10 + r() * 16;
      s += pth("M" + x + " " + y + " L" + (x + 4) + " " + (y - h) + " L" + (x + 8) + " " + y + " Z", "#DCEEF7");
      s += line(x + 4, y, x + 4, y - h * 0.8, "#FFFFFF", 1.6);
    }
    return s;
  }

  // 土の断面（地中）
  function soilCross(topY) {
    var s = pth("M0 " + topY + " Q100 " + (topY - 12) + " 210 " + (topY - 2) + " Q310 " + (topY + 8) + " 400 " + (topY - 6) + " L400 300 L0 300 Z", "#7A5236");
    s += pth("M0 " + (topY + 26) + " Q120 " + (topY + 14) + " 250 " + (topY + 30) + " Q330 " + (topY + 38) + " 400 " + (topY + 24) + " L400 300 L0 300 Z", "#5E3E28");
    var r = seeded(11);
    for (var i = 0; i < 22; i++) {
      s += ell(r() * 400, topY + 20 + r() * 90, 3 + r() * 5, 2 + r() * 3, "#4A3020", ' opacity="0.5"');
    }
    return s;
  }

  // 池
  function pond(cx, cy, rx, ry) {
    var s = ell(cx, cy, rx, ry, "#6FB6CE");
    s += ell(cx, cy, rx, ry, "none", ' stroke="#4F97AF" stroke-width="3"');
    s += ell(cx, cy - ry * 0.3, rx * 0.72, ry * 0.5, "#93CBDD", ' opacity="0.75"');
    for (var i = 0; i < 3; i++) {
      s += curve("M" + (cx - rx * 0.5 + i * 22) + " " + (cy + i * 6 - 4) + " q10 -4 20 0", "#C8E6EF", 2.2);
    }
    return s;
  }

  // 波紋
  function ripple(cx, cy, n) {
    var s = "";
    for (var i = 1; i <= (n || 3); i++) {
      s += ell(cx, cy, 12 * i, 4.2 * i, "none", ' stroke="#DCF0F6" stroke-width="2" opacity="' + (0.85 - i * 0.2) + '"');
    }
    return s;
  }

  // 吹き出し（セリフ）
  function bubble(x, y, w, h, text, tailDir) {
    var inner = rect(-w / 2, -h / 2, w, h, "#FFFFFF", h / 2.6, ' opacity="0.95"');
    var td = tailDir || 1;
    inner += pth("M" + (td * w * 0.16) + " " + (h / 2 - 2) + " L" + (td * w * 0.30) + " " + (h / 2 + 14) +
      " L" + (td * w * 0.02) + " " + (h / 2 - 2) + " Z", "#FFFFFF", ' opacity="0.95"');
    inner += '<text x="0" y="' + (h * 0.16) + '" text-anchor="middle" font-size="' + (h * 0.52) +
      '" fill="#5B4636" font-family="inherit" font-weight="700">' + text + "</text>";
    return G(inner, { x: x, y: y });
  }

  // きらきら
  function sparkle(x, y, s, color) {
    var c = color || "#FFF3B8";
    var inner = pth("M0 -12 L3 -3 L12 0 L3 3 L0 12 L-3 3 L-12 0 L-3 -3 Z", c);
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  // 音符
  function note(x, y, s, color) {
    var c = color || "#FFFFFF";
    var inner = ell(0, 8, 6, 4.6, c, ' transform="rotate(-18 0 8)"') +
      pth("M5 8 L5 -12 L8 -12 L8 8 Z", c) +
      pth("M8 -12 q10 2 10 9 q-4 -5 -10 -4 Z", c);
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  // 手ぶくろ（小道具）
  function mitten(x, y, s, rot) {
    var inner = pth("M-11 -14 q11 -5 22 0 l3 22 q-14 6 -28 0 Z", "#E15F4F");
    inner += pth("M11 -4 q10 2 8 11 q-6 3 -9 -3 Z", "#E15F4F");
    inner += rect(-12, -18, 25, 7, "#F4E3D2", 3);
    inner += curve("M-6 0 q8 3 16 0", "#F4E3D2", 2.4);
    return G(inner, { x: x, y: y, s: s || 1, rot: rot });
  }

  // 白銅貨
  function coin(x, y, s) {
    var inner = cir(0, 0, 9, "#D7DCE0") + cir(0, 0, 9, "none", ' stroke="#A9B2B8" stroke-width="2"') +
      cir(0, 0, 3.4, "#B7BEC4");
    return G(inner, { x: x, y: y, s: s || 1 });
  }

  /* =====================================================================
     ねずみのおよめさん（2〜3歳・12場面）
     ===================================================================== */
  var NEZUMI = [
    // 1 お倉の中の家族
    function () {
      var s = storeInterior();
      s += bale(70, 214, 1) + bale(150, 220, 0.9) + bale(112, 182, 0.85);
      s += bale(330, 216, 0.95);
      s += mouse({ x: 196, y: 236, s: 1, kind: "father", expr: "happy" });
      s += mouse({ x: 262, y: 240, s: 0.92, kind: "mother", expr: "happy", flip: true });
      s += mouse({ x: 232, y: 262, s: 0.72, kind: "daughter", expr: "happy" });
      return s;
    },
    // 2 かわいい むすめ
    function () {
      var s = storeInterior();
      s += bale(56, 226, 0.9) + bale(348, 230, 0.9);
      s += G(sparkle(0, 0, 1.1), { x: 130, y: 96 }) + sparkle(286, 84, 0.9) + sparkle(310, 140, 0.7);
      s += mouse({ x: 200, y: 240, s: 1.7, kind: "daughter", expr: "happy", mouth: "smile" });
      return s;
    },
    // 3 おとうさんの ねがい
    function () {
      var s = storeInterior();
      s += bale(64, 228, 0.9);
      s += bubble(206, 92, 250, 38, "せかいで いちばん つよい ひとを", 1);
      s += mouse({ x: 150, y: 248, s: 1.15, kind: "father", expr: "normal", mouth: "talk", arm: "up" });
      s += mouse({ x: 250, y: 252, s: 1, kind: "mother", expr: "happy", flip: true });
      s += mouse({ x: 310, y: 266, s: 0.75, kind: "daughter", expr: "normal", flip: true });
      return s;
    },
    // 4 おひさまの ところへ
    function () {
      var s = SKY.day("nz4");
      s += cloudFace({ x: 92, y: 210, s: 0.7, expr: "closed", mouth: "smile" });
      s += sunFace({ x: 268, y: 96, s: 1.25, expr: "happy" });
      s += ground(252, "#9CC97C", "#86B667");
      s += mouse({ x: 120, y: 268, s: 0.95, kind: "father", arm: "up", expr: "surprised", mouth: "talk" });
      s += mouse({ x: 66, y: 272, s: 0.85, kind: "mother", expr: "surprised" });
      return s;
    },
    // 5 おひさま「くもには かなわない」
    function () {
      var s = SKY.day("nz5");
      s += sunFace({ x: 150, y: 108, s: 1.05, expr: "normal", mouth: "talk" });
      s += cloudFace({ x: 276, y: 126, s: 1.05, expr: "happy" });
      s += bubble(206, 216, 218, 34, "くもの ほうが つよいよ", -1);
      s += ground(266, "#9CC97C", "#86B667");
      s += mouse({ x: 84, y: 282, s: 0.8, kind: "father", expr: "surprised" });
      return s;
    },
    // 6 くもの ところへ
    function () {
      var s = SKY.day("nz6");
      s += cloudFace({ x: 210, y: 120, s: 1.5, expr: "happy", mouth: "talk" });
      s += cloudFace({ x: 58, y: 208, s: 0.55, expr: "closed" });
      s += ground(268, "#9CC97C", "#86B667");
      s += mouse({ x: 300, y: 284, s: 0.9, kind: "father", arm: "up", expr: "normal", flip: true });
      s += mouse({ x: 352, y: 288, s: 0.8, kind: "mother", expr: "happy", flip: true });
      return s;
    },
    // 7 くも「かぜには かなわない」
    function () {
      var s = SKY.day("nz7");
      s += windFace({ x: 74, y: 96, s: 0.95, expr: "normal", mouth: "open" });
      s += cloudFace({ x: 286, y: 132, s: 1.1, expr: "surprised", mouth: "open" });
      s += bubble(214, 224, 206, 34, "かぜの ほうが つよいよ", 1);
      s += ground(270, "#9CC97C", "#86B667");
      s += mouse({ x: 110, y: 286, s: 0.78, kind: "father", expr: "surprised" });
      return s;
    },
    // 8 かぜの ところへ
    function () {
      var s = SKY.day("nz8");
      s += windFace({ x: 118, y: 112, s: 1.35, expr: "happy", mouth: "open" });
      for (var i = 0; i < 4; i++) {
        s += curve("M180 " + (150 + i * 26) + " Q260 " + (140 + i * 26) + " 350 " + (162 + i * 26),
          "#FFFFFF", 3.4, ' opacity="0.7"');
      }
      s += ground(268, "#9CC97C", "#86B667");
      s += grass(330, 268, 1.1, "#7FAF66");
      s += mouse({ x: 268, y: 284, s: 0.95, kind: "father", expr: "surprised", mouth: "open", flip: true });
      s += mouse({ x: 330, y: 288, s: 0.85, kind: "mother", expr: "surprised", flip: true });
      return s;
    },
    // 9 かぜ「かべは びくとも しない」
    function () {
      var s = SKY.day("nz9");
      s += ground(258, "#9CC97C", "#86B667");
      s += wallFace({ x: 296, y: 176, s: 0.92, expr: "normal", mouth: "flat" });
      s += windFace({ x: 92, y: 150, s: 1, expr: "angry", mouth: "open" });
      s += bubble(196, 62, 200, 34, "かべは うごかせない", -1);
      s += mouse({ x: 130, y: 276, s: 0.75, kind: "father", expr: "surprised" });
      return s;
    },
    // 10 かべ「ねずみが あなを あける」
    function () {
      var s = SKY.dusk("nz10");
      s += ground(256, "#A8B87A", "#8FA466");
      s += wallFace({ x: 214, y: 168, s: 1.12, expr: "happy", mouth: "smile", hole: true });
      s += bubble(214, 46, 214, 34, "ねずみが あなを あけるよ", 1);
      s += mouse({ x: 322, y: 244, s: 0.8, kind: "father", expr: "surprised", mouth: "open" });
      s += mouse({ x: 366, y: 250, s: 0.72, kind: "mother", expr: "surprised" });
      return s;
    },
    // 11 いちばん つよいのは ねずみ
    function () {
      var s = SKY.dusk("nz11");
      s += ground(244, "#A8B87A", "#8FA466");
      s += sparkle(120, 92, 1.2) + sparkle(286, 78, 1) + sparkle(320, 132, 0.8);
      s += bubble(200, 66, 236, 36, "いちばん つよいのは ねずみ！", -1);
      s += mouse({ x: 138, y: 250, s: 1.25, kind: "father", expr: "happy", mouth: "open", arm: "up" });
      s += mouse({ x: 248, y: 256, s: 1.1, kind: "mother", expr: "happy", flip: true });
      return s;
    },
    // 12 なかよく くらしました
    function () {
      var s = SKY.morning("nz12");
      s += ground(238, "#9CC97C", "#86B667");
      s += tree(48, 244, 0.72, "#7FB169");
      s += tree(356, 246, 0.66, "#88BA72");
      s += flower(96, 268, 1) + flower(124, 280, 0.85, "#F7C7A0") + flower(300, 272, 0.9, "#F6A8C0");
      s += grass(180, 274, 1) + grass(268, 280, 0.9);
      for (var i = 0; i < 5; i++) s += sparkle(70 + i * 66, 60 + (i % 2) * 24, 0.7, "#FFE9A8");
      s += mouse({ x: 168, y: 250, s: 1.15, kind: "daughter", expr: "happy" });
      s += mouse({ x: 244, y: 250, s: 1.15, kind: "groom", expr: "happy", flip: true });
      return s;
    }
  ];

  /* =====================================================================
     二ひきのかえる（3〜4歳・14場面）
     ===================================================================== */
  var KAERU = [
    // 1 はたけで ばったり
    function () {
      var s = SKY.autumn("kr1");
      s += mountains(196, "#B6C9AE", "#A4BC9C");
      s += ground(212, "#B98F5E", "#A67C4E");
      for (var i = 0; i < 6; i++) s += curve("M" + (10 + i * 68) + " 236 q30 -10 60 0", "#A67C4E", 3);
      s += grass(40, 232, 0.9, "#8DA85E") + grass(368, 240, 0.9, "#8DA85E");
      s += frog({ x: 132, y: 254, s: 1, color: "green", expr: "surprised", mouth: "open" });
      s += frog({ x: 274, y: 254, s: 1, color: "yellow", expr: "surprised", mouth: "open", flip: true });
      return s;
    },
    // 2 みどり「きたない いろだ」
    function () {
      var s = SKY.autumn("kr2");
      s += ground(214, "#B98F5E", "#A67C4E");
      s += bubble(120, 92, 194, 36, "きみの きいろ、へんだよ", 1);
      s += frog({ x: 118, y: 256, s: 1.14, color: "green", expr: "angry", mouth: "talk" });
      s += frog({ x: 286, y: 258, s: 1, color: "yellow", expr: "sad", mouth: "frown", flip: true });
      return s;
    },
    // 3 きいろ「なんだって」
    function () {
      var s = SKY.autumn("kr3");
      s += ground(214, "#B98F5E", "#A67C4E");
      s += bubble(286, 92, 194, 36, "みどりの ほうが へんだ", -1);
      s += frog({ x: 116, y: 258, s: 1, color: "green", expr: "surprised", mouth: "open" });
      s += frog({ x: 288, y: 256, s: 1.14, color: "yellow", expr: "angry", mouth: "talk", flip: true });
      return s;
    },
    // 4 けんかを はじめました
    function () {
      var s = SKY.autumn("kr4");
      s += ground(216, "#B98F5E", "#A67C4E");
      // 砂ぼこり
      s += ell(200, 250, 76, 30, "#E4D2B0", ' opacity="0.75"');
      s += ell(160, 240, 40, 20, "#EFE0C4", ' opacity="0.7"');
      s += ell(244, 244, 36, 18, "#EFE0C4", ' opacity="0.7"');
      for (var i = 0; i < 5; i++) {
        var a = (i / 5) * 6.28;
        s += line(200 + Math.cos(a) * 70, 246 + Math.sin(a) * 30,
          200 + Math.cos(a) * 92, 246 + Math.sin(a) * 40, "#C9AE84", 3);
      }
      s += frog({ x: 158, y: 250, s: 0.98, color: "green", expr: "angry", mouth: "wide", pose: "jump" });
      s += frog({ x: 246, y: 250, s: 0.98, color: "yellow", expr: "angry", mouth: "wide", pose: "jump", flip: true });
      return s;
    },
    // 5 つめたい かぜ
    function () {
      var s = SKY.autumn("kr5");
      s += ground(218, "#B98F5E", "#A67C4E");
      for (var i = 0; i < 5; i++) {
        s += curve("M-10 " + (70 + i * 30) + " Q120 " + (56 + i * 30) + " 260 " + (78 + i * 30) +
          " Q330 " + (88 + i * 30) + " 410 " + (72 + i * 30), "#DCEDF5", 4, ' opacity="0.85"');
      }
      s += pth("M330 150 q14 -12 26 2 q-6 14 -22 8 Z", "#D9A05E");
      s += pth("M92 176 q12 -10 22 2 q-6 12 -20 6 Z", "#C98F52");
      s += frog({ x: 146, y: 258, s: 1, color: "green", expr: "surprised", mouth: "open" });
      s += frog({ x: 262, y: 258, s: 1, color: "yellow", expr: "surprised", mouth: "open", flip: true });
      return s;
    },
    // 6 もう ふゆが くる
    function () {
      var s = SKY.autumn("kr6");
      s += mountains(186, "#AEC0B4", "#9DB2A6");
      s += pth("M-10 186 L70 116 L140 186 Z", "#E8F0F4");
      s += ground(214, "#B08551", "#9A7244");
      s += tree(56, 216, 0.62, "#C9873F", "#7C5A3C");
      s += tree(348, 218, 0.56, "#B87A3E", "#7C5A3C");
      s += snowFall(24, 9);
      s += frog({ x: 160, y: 256, s: 0.98, color: "green", expr: "sad", mouth: "frown" });
      s += frog({ x: 254, y: 256, s: 0.98, color: "yellow", expr: "sad", mouth: "frown", flip: true });
      return s;
    },
    // 7 はるに しよう（やくそく）
    function () {
      var s = SKY.dusk("kr7");
      s += ground(218, "#A87F4E", "#946E42");
      s += bubble(200, 84, 236, 36, "けんかは はるに しよう", 1);
      s += frog({ x: 152, y: 258, s: 1.02, color: "green", expr: "normal", mouth: "talk" });
      s += frog({ x: 254, y: 258, s: 1.02, color: "yellow", expr: "normal", mouth: "smile", flip: true });
      // 握手のように前足を寄せる
      s += ell(203, 268, 10, 6, "#8FA85E", ' opacity="0.0"');
      return s;
    },
    // 8 つちに もぐる
    function () {
      var s = SKY.autumn("kr8");
      s += rect(0, 0, 400, 150, "#CFE0EA");
      s += soilCross(150);
      // 掘った穴
      s += ell(120, 158, 34, 14, "#5E3E28");
      s += ell(280, 158, 34, 14, "#5E3E28");
      s += frog({ x: 120, y: 178, s: 0.92, color: "green", expr: "closed", mouth: "smile" });
      s += frog({ x: 280, y: 178, s: 0.92, color: "yellow", expr: "closed", mouth: "smile", flip: true });
      // 土けむり
      s += ell(120, 146, 26, 9, "#8A6244", ' opacity="0.6"');
      s += ell(280, 146, 26, 9, "#8A6244", ' opacity="0.6"');
      return s;
    },
    // 9 ゆきの したで ぐっすり
    function () {
      var s = SKY.snowDay("kr9");
      s += snowFall(40, 4);
      s += rect(0, 96, 400, 26, "#FFFFFF");
      s += pth("M0 96 Q100 84 200 94 Q300 104 400 90 L400 122 L0 122 Z", "#FFFFFF");
      s += frostPillars(122);
      s += soilCross(126);
      s += ell(112, 196, 44, 30, "#6A4630");
      s += ell(288, 196, 44, 30, "#6A4630");
      s += frog({ x: 112, y: 206, s: 0.86, color: "green", expr: "sleep", mouth: "smile", pose: "sit" });
      s += frog({ x: 288, y: 206, s: 0.86, color: "yellow", expr: "sleep", mouth: "smile", pose: "sit", flip: true });
      s += '<text x="146" y="176" font-size="17" fill="#E4D8C8" font-weight="700">zzz</text>';
      s += '<text x="322" y="176" font-size="17" fill="#E4D8C8" font-weight="700">zzz</text>';
      return s;
    },
    // 10 はる・みどりが おきる
    function () {
      var s = SKY.spring("kr10");
      s += sunFace({ x: 340, y: 56, s: 0.66, expr: "happy" });
      s += ground(198, "#8FBE6A", "#7BAB58");
      s += flower(64, 226, 0.9) + flower(342, 232, 0.85, "#F7C7A0");
      s += grass(120, 224, 1) + grass(300, 230, 0.9);
      s += ell(176, 212, 26, 11, "#6A4630");
      s += frog({ x: 176, y: 218, s: 1.05, color: "green", expr: "surprised", mouth: "open", arm: "up" });
      s += bubble(232, 116, 176, 34, "おおい、はるだよ", -1);
      return s;
    },
    // 11 きいろも でてくる
    function () {
      var s = SKY.spring("kr11");
      s += ground(200, "#8FBE6A", "#7BAB58");
      s += flower(52, 230, 0.85) + flower(356, 236, 0.85, "#F6A8C0");
      s += grass(96, 228, 0.95);
      s += frog({ x: 136, y: 240, s: 1.02, color: "green", expr: "happy", mouth: "smile" });
      s += ell(268, 214, 26, 11, "#6A4630");
      s += frog({ x: 268, y: 222, s: 1.02, color: "yellow", expr: "sleep", mouth: "smile", flip: true });
      // 泥
      s += ell(262, 214, 12, 5, "#8A6244", ' opacity="0.8"');
      return s;
    },
    // 12 「あらってから」
    function () {
      var s = SKY.spring("kr12");
      s += ground(202, "#8FBE6A", "#7BAB58");
      s += bubble(268, 104, 220, 36, "からだを あらってから", -1);
      // 泥だらけの二ひき
      s += frog({ x: 138, y: 244, s: 1.04, color: "green", expr: "normal", mouth: "talk" });
      s += ell(138, 236, 16, 7, "#8A6244", ' opacity="0.7"');
      s += ell(150, 250, 9, 5, "#8A6244", ' opacity="0.6"');
      s += frog({ x: 262, y: 244, s: 1.04, color: "yellow", expr: "normal", mouth: "talk", flip: true });
      s += ell(262, 236, 16, 7, "#8A6244", ' opacity="0.7"');
      s += ell(250, 250, 9, 5, "#8A6244", ' opacity="0.6"');
      return s;
    },
    // 13 いけで あらう
    function () {
      var s = SKY.spring("kr13");
      s += ground(176, "#8FBE6A", "#7BAB58");
      s += pond(200, 226, 150, 62);
      s += grass(46, 200, 0.9) + grass(356, 204, 0.9);
      s += flower(74, 188, 0.8, "#F6A8C0");
      s += ripple(140, 224, 3) + ripple(266, 236, 2);
      s += frog({ x: 140, y: 216, s: 0.95, color: "green", expr: "happy", mouth: "smile", pose: "swim" });
      s += frog({ x: 266, y: 228, s: 0.95, color: "yellow", expr: "happy", mouth: "smile", pose: "swim", flip: true });
      s += sparkle(180, 186, 0.8) + sparkle(232, 198, 0.65);
      return s;
    },
    // 14 きれいだね（なかなおり）
    function () {
      var s = SKY.spring("kr14");
      s += sunFace({ x: 348, y: 50, s: 0.6, expr: "happy" });
      s += ground(196, "#8FBE6A", "#7BAB58");
      s += pond(210, 250, 130, 44);
      s += flower(56, 220, 0.95) + flower(88, 234, 0.8, "#F7C7A0") + flower(342, 224, 0.9, "#F6A8C0");
      s += grass(140, 226, 0.9) + grass(300, 232, 0.85);
      for (var i = 0; i < 6; i++) s += sparkle(60 + i * 58, 70 + (i % 3) * 22, 0.62, "#FFF0BC");
      s += bubble(200, 118, 210, 34, "きみの いろ、きれいだね", 1);
      s += frog({ x: 152, y: 236, s: 1.06, color: "green", expr: "happy", mouth: "smile" });
      s += frog({ x: 250, y: 236, s: 1.06, color: "yellow", expr: "happy", mouth: "smile", flip: true });
      return s;
    }
  ];

  /* =====================================================================
     手ぶくろを買いに（5〜6歳・16場面）
     ===================================================================== */
  var TEBUKURO = [
    // 1 寒い冬が森へ
    function () {
      var s = SKY.snowDay("tb1");
      s += mountains(180, "#C3D4E0", "#B2C6D4");
      s += pth("M-10 180 L70 106 L140 180 Z", "#FFFFFF");
      s += pth("M230 180 L310 118 L400 180 Z", "#FFFFFF");
      s += snowGround(204);
      s += snowTree(58, 214, 0.95) + snowTree(128, 226, 0.72) + snowTree(340, 218, 0.88) + snowTree(276, 230, 0.62);
      s += snowFall(46, 5);
      // ほら穴
      s += ell(206, 250, 44, 30, "#6B5340");
      s += ell(206, 254, 34, 22, "#4A3728");
      return s;
    },
    // 2 「目に なにか ささったよう」
    function () {
      var s = SKY.snowDay("tb2");
      s += snowGround(196);
      s += snowTree(52, 208, 0.8) + snowTree(354, 212, 0.75);
      // ほら穴（大きめ）
      s += ell(210, 236, 96, 66, "#6B5340");
      s += ell(210, 242, 82, 54, "#3F2F22");
      s += snowFall(28, 8);
      s += fox({ x: 176, y: 262, s: 0.86, kind: "child", expr: "surprised", mouth: "open", pose: "sit", arm: "up", flip: true });
      s += fox({ x: 262, y: 268, s: 1, kind: "mother", expr: "normal", mouth: "smile", pose: "sit" });
      return s;
    },
    // 3 まぶしい ゆきだった
    function () {
      var s = SKY.morning("tb3");
      s += snowGround(190);
      s += snowTree(48, 202, 0.85) + snowTree(348, 206, 0.8);
      // まぶしい朝日
      s += cir(316, 74, 34, "#FFE9A6", ' opacity="0.9"');
      s += cir(316, 74, 50, "#FFF3C8", ' opacity="0.45"');
      for (var i = 0; i < 10; i++) {
        var a = (i / 10) * 6.28;
        s += line(316 + Math.cos(a) * 40, 74 + Math.sin(a) * 40,
          316 + Math.cos(a) * 66, 74 + Math.sin(a) * 66, "#FFEFB4", 3.4, ' opacity="0.8"');
      }
      s += sparkle(120, 214, 1) + sparkle(212, 232, 0.85) + sparkle(280, 208, 0.7);
      s += fox({ x: 152, y: 254, s: 0.9, kind: "child", expr: "happy", mouth: "smile", pose: "sit" });
      s += fox({ x: 232, y: 258, s: 1.05, kind: "mother", expr: "happy", mouth: "smile", pose: "sit" });
      return s;
    },
    // 4 ゆきの うえで あそぶ
    function () {
      var s = SKY.snowDay("tb4");
      s += snowGround(184);
      s += snowTree(44, 198, 0.8) + snowTree(360, 200, 0.75);
      s += snowFall(34, 12);
      // ころげた跡
      s += ell(130, 250, 40, 12, "#DCEAF4");
      s += ell(198, 262, 46, 13, "#DCEAF4");
      s += ell(272, 250, 38, 11, "#DCEAF4");
      s += fox({ x: 214, y: 240, s: 1.05, kind: "child", expr: "happy", mouth: "open", pose: "run" });
      // まいあがる雪
      s += cir(150, 214, 5, "#FFFFFF") + cir(168, 200, 4, "#FFFFFF") + cir(286, 208, 5, "#FFFFFF") + cir(300, 224, 3.6, "#FFFFFF");
      return s;
    },
    // 5 手が まっ赤
    function () {
      var s = SKY.snowDay("tb5");
      s += snowGround(198);
      s += ell(206, 244, 92, 62, "#6B5340");
      s += ell(206, 250, 78, 50, "#3F2F22");
      s += fox({ x: 186, y: 272, s: 1.02, kind: "child", expr: "sad", mouth: "frown", pose: "sit", arm: "out", flip: true });
      // まっ赤な手
      s += ell(150, 262, 11, 9, "#E4705E");
      s += curve("M138 246 q4 -8 2 -14", "#F4A79A", 2.4);
      s += curve("M148 242 q3 -8 1 -14", "#F4A79A", 2.4);
      s += fox({ x: 268, y: 274, s: 1.06, kind: "mother", expr: "sad", mouth: "flat", pose: "sit" });
      return s;
    },
    // 6 「手ぶくろを 買ってやろう」
    function () {
      var s = SKY.dusk("tb6");
      s += snowGround(196);
      s += snowTree(56, 208, 0.8) + snowTree(342, 212, 0.76);
      s += ell(206, 244, 88, 58, "#6B5340");
      s += ell(206, 250, 74, 46, "#3F2F22");
      s += bubble(220, 76, 250, 36, "あたたかい 手ぶくろを 買おう", -1);
      s += mitten(88, 122, 1.1, -14);
      s += mitten(324, 116, 1.05, 16);
      s += fox({ x: 246, y: 272, s: 1.14, kind: "mother", expr: "normal", mouth: "smile", pose: "sit" });
      s += fox({ x: 166, y: 278, s: 0.86, kind: "child", expr: "happy", mouth: "smile", pose: "sit", flip: true });
      return s;
    },
    // 7 日が くれて 町の 明かり
    function () {
      var s = SKY.night("tb7");
      s += stars(46, 6);
      s += cir(64, 56, 20, "#FBF0C4");
      s += cir(58, 50, 17, "#2E3D63");
      s += snowGround(214);
      s += snowTree(40, 226, 0.7);
      // 遠くの町
      s += house(268, 216, 0.5, true) + house(320, 220, 0.44, true) + house(364, 214, 0.4, true);
      s += ell(316, 200, 90, 34, "#FFE49B", ' opacity="0.20"');
      s += fox({ x: 118, y: 268, s: 1.05, kind: "mother", expr: "normal", mouth: "flat" });
      s += fox({ x: 176, y: 276, s: 0.8, kind: "child", expr: "happy", mouth: "smile" });
      return s;
    },
    // 8 おかあさんの 足が とまる
    function () {
      var s = SKY.night("tb8");
      s += stars(38, 14);
      s += snowGround(216);
      s += house(304, 216, 0.5, true) + house(358, 220, 0.42, true);
      s += ell(320, 202, 96, 34, "#FFE49B", ' opacity="0.18"');
      // 母の不安（にじむ影）
      s += ell(128, 268, 62, 16, "#1F2A46", ' opacity="0.35"');
      s += fox({ x: 128, y: 262, s: 1.16, kind: "mother", expr: "sad", mouth: "frown" });
      s += fox({ x: 200, y: 276, s: 0.82, kind: "child", expr: "normal", mouth: "smile" });
      // ふるえ
      s += curve("M96 232 q-8 -6 -4 -14", "#8FA0C4", 2.4);
      s += curve("M112 224 q-6 -8 0 -15", "#8FA0C4", 2.4);
      return s;
    },
    // 9 かたほうの手を 人間の手に
    function () {
      var s = SKY.night("tb9");
      s += stars(30, 18);
      s += snowGround(220);
      s += cir(206, 236, 56, "#FFF3C8", ' opacity="0.30"');
      s += cir(206, 236, 34, "#FFF7DA", ' opacity="0.42"');
      for (var i = 0; i < 8; i++) {
        var a = (i / 8) * 6.28;
        s += sparkle(206 + Math.cos(a) * 52, 236 + Math.sin(a) * 40, 0.55, "#FFF0B4");
      }
      s += fox({ x: 130, y: 272, s: 1.08, kind: "mother", expr: "normal", mouth: "smile", arm: "out" });
      s += fox({ x: 286, y: 276, s: 0.92, kind: "child", expr: "surprised", mouth: "open", arm: "out", humanHand: true, flip: true });
      return s;
    },
    // 10 「この手を 出すんだよ」
    function () {
      var s = SKY.night("tb10");
      s += stars(26, 22);
      s += snowGround(222);
      s += bubble(206, 72, 268, 36, "こっちの手を 出すんだよ", -1);
      s += fox({ x: 132, y: 276, s: 1.1, kind: "mother", expr: "normal", mouth: "talk", arm: "out" });
      s += fox({ x: 288, y: 278, s: 0.94, kind: "child", expr: "normal", mouth: "flat", arm: "out", humanHand: true, flip: true });
      s += coin(212, 232, 1) + coin(228, 240, 0.9);
      return s;
    },
    // 11 ひとりで 雪の道
    function () {
      var s = SKY.night("tb11");
      s += stars(42, 26);
      s += cir(52, 48, 18, "#FBF0C4");
      s += snowGround(210);
      s += snowTree(34, 224, 0.62);
      // 雪の道と足あと
      s += pth("M120 300 Q170 244 214 206 L262 206 Q210 250 190 300 Z", "#F2F8FC");
      var r = seeded(31);
      for (var i = 0; i < 7; i++) {
        s += ell(156 + i * 8 + r() * 6, 292 - i * 13, 4.6, 3.2, "#D7E6F0");
      }
      s += hatShop(300, 200, 0.72, false);
      s += fox({ x: 178, y: 252, s: 0.86, kind: "child", expr: "normal", mouth: "flat", pose: "run" });
      return s;
    },
    // 12 とんとん・まぶしい光
    function () {
      var s = SKY.night("tb12");
      s += stars(20, 33);
      s += snowGround(232);
      s += hatShop(214, 226, 1.05, true);
      // 戸のすきまから漏れる光
      s += pth("M186 226 L206 226 L246 300 L142 300 Z", "#FFE9A8", ' opacity="0.45"');
      s += cir(196, 190, 26, "#FFF3C8", ' opacity="0.5"');
      s += sparkle(180, 172, 0.9) + sparkle(216, 166, 0.7);
      // まちがえて きつねの手
      s += fox({ x: 300, y: 268, s: 0.94, kind: "child", expr: "surprised", mouth: "open", arm: "out", humanHand: false, flip: true });
      return s;
    },
    // 13 手ぶくろを のせてくれた
    function () {
      var s = SKY.night("tb13");
      s += snowGround(238);
      s += hatShop(196, 232, 1.05, true);
      s += pth("M168 232 L188 232 L228 300 L124 300 Z", "#FFE9A8", ' opacity="0.40"');
      // 店の人の手
      s += ell(238, 214, 20, 13, "#F6D2B4", ' transform="rotate(14 238 214)"');
      s += line(250, 208, 262, 202, "#F6D2B4", 5.4);
      s += line(254, 216, 268, 214, "#F6D2B4", 5.4);
      s += rect(210, 200, 26, 16, "#7A5A46", 3);
      s += mitten(268, 214, 0.95, 10);
      s += fox({ x: 320, y: 272, s: 0.94, kind: "child", expr: "happy", mouth: "open", arm: "out", flip: true });
      return s;
    },
    // 14 帰り道の 子守歌
    function () {
      var s = SKY.night("tb14");
      s += stars(40, 41);
      s += cir(340, 52, 19, "#FBF0C4");
      s += snowGround(216);
      s += house(112, 218, 0.72, true);
      s += pth("M98 218 L126 218 L156 288 L68 288 Z", "#FFE49B", ' opacity="0.26"');
      s += note(160, 150, 1, "#FFF0B8") + note(186, 122, 0.85, "#FFF0B8") + note(212, 148, 0.7, "#FFF0B8");
      s += fox({ x: 286, y: 268, s: 0.94, kind: "child", expr: "closed", mouth: "smile", mittens: true, flip: true });
      return s;
    },
    // 15 「こわく なかったよ」
    function () {
      var s = SKY.night("tb15");
      s += stars(34, 47);
      s += snowGround(220);
      s += snowTree(44, 232, 0.7) + snowTree(356, 236, 0.66);
      s += bubble(212, 76, 268, 36, "人間、こわくなかったよ", 1);
      s += fox({ x: 148, y: 274, s: 0.96, kind: "child", expr: "happy", mouth: "open", mittens: true, arm: "up" });
      s += fox({ x: 268, y: 272, s: 1.12, kind: "mother", expr: "happy", mouth: "smile", flip: true });
      return s;
    },
    // 16 「ほんとうに 人間は いいものかしら」
    function () {
      var s = SKY.night("tb16");
      s += stars(52, 53);
      s += cir(320, 58, 22, "#FBF0C4");
      s += cir(320, 58, 30, "#FBF0C4", ' opacity="0.28"');
      s += snowGround(226);
      s += snowTree(52, 240, 0.7);
      s += snowFall(18, 61);
      // 寄りそう親子
      s += fox({ x: 236, y: 278, s: 1.18, kind: "mother", expr: "normal", mouth: "flat", pose: "sit", flip: true });
      s += fox({ x: 170, y: 284, s: 0.84, kind: "child", expr: "closed", mouth: "smile", pose: "curl", mittens: true });
      // つぶやき（小さく）
      s += G(rect(-96, -17, 192, 34, "#FFFFFF", 17, ' opacity="0.82"') +
        '<text x="0" y="6" text-anchor="middle" font-size="15" fill="#5B4636" font-weight="700">ほんとうに いいものかしら</text>',
        { x: 214, y: 84 });
      return s;
    }
  ];

  /* =====================================================================
     公開
     ===================================================================== */
  var SCENES = {
    "nezumi-no-oyomesan": NEZUMI,
    "nihiki-no-kaeru": KAERU,
    "tebukuro-wo-kai-ni": TEBUKURO
  };

  function render(bookId, index) {
    var list = SCENES[bookId];
    if (!list || !list[index]) {
      return '<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">' +
        rect(0, 0, 400, 300, "#F1E7D8") + "</svg>";
    }
    return '<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg" ' +
      'preserveAspectRatio="xMidYMid meet" role="img">' + list[index]() + "</svg>";
  }

  function count(bookId) {
    return SCENES[bookId] ? SCENES[bookId].length : 0;
  }

  return { render: render, count: count, SCENES: SCENES };
})(ARTCORE);
