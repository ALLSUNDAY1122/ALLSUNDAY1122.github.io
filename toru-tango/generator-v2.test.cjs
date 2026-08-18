const assert = require('node:assert/strict');
require('./generator-v2.js');

const source = `人類史のはじまり
最古の人類、ルーシーの骨（複製）
人類は、数百万年前にアフリカ大陸で誕生した、とされている。
約540万年前アフリカ大陸で、現在のところ最古の猿人とよばれるアウストラロピテクスが登場した。これが最初の人類とされている。東アフリカのタンザニアで、猿人の一種である、ジンジャントロプス（Zinjanthropus、en:Paranthropus boisei）の化石が発見された。
エチオピア北東部ハダール村付近では、318万年前のアウストラロピテクス・アファレンシス（アファール猿人、en:Australopithecus afarensis）の化石骨が1974年11月24日に発見され、「ルーシー」と名付けられた。
200万年前から100万年前、アフリカ大陸の北側から、陸地づたいに、地中海東岸方面へ生活の場を広げ、ユーラシアを西方（ヨーロッパ方面）へ進む者と、東方（中央アジア、東アジア方面）へ進む者に分かれて広がっていった、と考えられている。`;

const questions = globalThis.ToruTangoGeneratorV2.generateQuestionsV2(source, 10, 'mix', 'normal');
const joined = questions.join('\n');

console.log(JSON.stringify({ count: questions.length, questions }, null, 2));

assert.ok(questions.length >= 6, `expected at least 6 meaningful questions, got ${questions.length}`);
assert.match(joined, /人類は.*どこで誕生.*｜アフリカ大陸|人類は、数百万年前に（　　）で誕生.*｜アフリカ大陸/);
assert.match(joined, /アウストラロピテクスが登場したのは.*｜約540万年前/);
assert.match(joined, /ジンジャントロプスの化石が発見された場所.*｜東アフリカのタンザニア/);
assert.match(joined, /ルーシー.*発見されたのはいつ.*｜1974年11月24日/);
assert.doesNotMatch(joined, /「人類史の」について/);
assert.doesNotMatch(joined, /｜人類史の(?:\n|$)/);
assert.doesNotMatch(joined, /「Zinjanthropus」について/);
assert.equal(new Set(questions).size, questions.length, 'duplicate questions must not be emitted');

console.log(`generator-v2 regression passed: ${questions.length} questions`);
