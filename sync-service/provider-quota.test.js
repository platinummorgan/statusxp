import test from 'node:test';
import assert from 'node:assert/strict';
import { admitRecoverySync } from './provider-quota.js';
test('recovery uses server policy and fails closed on denial or outage', async () => {
  for (const result of [{data:{allowed:true}}, {data:{allowed:false}}, {error:{}}, {data:null}]) {
    const client={rpc: async (name,args)=>{
      assert.equal(name,'admit_provider_request');
      assert.deepEqual(args,{p_user_id:'user',p_provider:'sync_psn'});
      return result;
    }};
    assert.equal(await admitRecoverySync(client,'user','psn'),result.data?.allowed===true);
  }
  assert.equal(await admitRecoverySync({rpc:async()=>{throw new Error('offline');}},'user','steam'),false);
});
