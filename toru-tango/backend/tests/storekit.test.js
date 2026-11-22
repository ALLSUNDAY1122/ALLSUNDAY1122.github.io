import assert from 'node:assert/strict';
import test from 'node:test';
import { verifyStoreKitTransaction } from '../src/storekit.js';

test('rejects malformed and unsigned transactions', async()=>{
  for(const jws of ['', 'a.b.c', 'eyJhbGciOiJFUzI1NiJ9.eyJleHBpcmVzRGF0ZSI6OTk5OTk5OTk5OTk5OX0.AAAA'])
    await assert.rejects(verifyStoreKitTransaction(jws));
});
test('rejects oversized JWS before parsing certificate data',async()=>{
  await assert.rejects(verifyStoreKitTransaction('a'.repeat(24001)));
});
