import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure contract admin can set max cache entries",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('cache-manager', 'set-max-cache-entries', [types.uint(500)], deployer.address)
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Ensure transaction can be cached",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const txHash = 0x1234;
    const block = chain.mineBlock([
      Tx.contractCall('cache-manager', 'cache-transaction', [
        types.buff(txHash), 
        types.uint(1), 
        types.uint(100), 
        types.uint(50)
      ], deployer.address)
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Retrieve cached transaction details",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const txHash = 0x5678;
    const chainId = 1;
    const estimatedGas = 100;
    const expiryDuration = 50;

    const cacheBlock = chain.mineBlock([
      Tx.contractCall('cache-manager', 'cache-transaction', [
        types.buff(txHash), 
        types.uint(chainId), 
        types.uint(estimatedGas), 
        types.uint(expiryDuration)
      ], deployer.address)
    ]);

    const retrieveBlock = chain.mineBlock([
      Tx.contractCall('cache-manager', 'get-cached-transaction', [
        types.buff(txHash), 
        types.uint(chainId)
      ], deployer.address)
    ]);

    assertEquals(cacheBlock.receipts[0].result, '(ok true)');
    assertEquals(retrieveBlock.receipts[0].result.type, 'ok');
  }
});

Clarinet.test({
  name: "Prevent non-admin from changing max cache entries",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall('cache-manager', 'set-max-cache-entries', [types.uint(500)], wallet1.address)
    ]);

    assertEquals(block.receipts[0].result, '(err u100)');
  }
});