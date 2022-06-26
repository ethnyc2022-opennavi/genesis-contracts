const hre = require("hardhat");
async function main() {
  const NFT = await hre.ethers.getContractFactory("ONFT");
  const CONTRACT_ADDRESS = "0x8B0dd6D9eDCd63b9b3545742C0307a44C9eF8477"
  const contract = NFT.attach(CONTRACT_ADDRESS);
  const owner = await contract.ownerOf(1);
  console.log("Owner:", owner);
  const uri = await contract.tokenURI(1);
  console.log("URI: ", uri);
}
main().then(() => process.exit(0)).catch(error => {
  console.error(error);
  process.exit(1);
});
