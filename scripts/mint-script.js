const hre = require("hardhat");
async function main() {
  const NFT = await hre.ethers.getContractFactory("ONFT");
  const URI = "ipfs://QmYdqu4Hy3efY6Ey3Dh5FxMjyKVqGXzYaejRwkmzQxb1pq"
  const WALLET_ADDRESS = "0x322cD16e617287bd41f801445eC7d958B2739A89"
  const CONTRACT_ADDRESS = "0x8B0dd6D9eDCd63b9b3545742C0307a44C9eF8477"
  const contract = NFT.attach(CONTRACT_ADDRESS);
  await contract.mint(WALLET_ADDRESS, URI);
  console.log("NFT minted:", contract);
}
main().then(() => process.exit(0)).catch(error => {
  console.error(error);
  process.exit(1);
});
