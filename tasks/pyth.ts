import { getAddress, ParamChainName } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { IPyth__factory } from "../typechain-types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const network = hre.network.name as ParamChainName;

  if (!/zeta_(testnet|mainnet)/.test(network)) {
    throw new Error(
      '🚨 Please use either "zeta_testnet" or "zeta_mainnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();
  if (signer === undefined) {
    throw new Error(
      `Wallet not found. Please, run "npx hardhat account --save" or set PRIVATE_KEY env variable (for example, in a .env file)`
    );
  }

  const contract = IPyth__factory.connect("0x0708325268dF9F66270F1401206434524814508b", signer)

  const res = await contract.getPrice(args.priceId)
  console.log(`res: ${res}`)
};

task("pyth-price", "call the ratio endpoint", main)
  .addParam("priceId", "pyth price id to pull",);
