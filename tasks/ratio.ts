import { getAddress, ParamChainName } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { InvoiceManager__factory } from "../typechain-types";

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

  const contract = InvoiceManager__factory.connect("0xba9e82f6045A0eD0F6a07809A12F1C678C8a9340", signer)

  const ratio = await contract.getStableRatio("0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891");
  console.log(`stable ratio: ${ratio}`)
};

task("ratio", "call the ratio endpoint", main)
