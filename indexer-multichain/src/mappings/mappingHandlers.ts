import {} from "../types/abi-interfaces/Abi";
import { Mint } from "../types";
import { TokenMintedLog } from "../types/abi-interfaces/Abi";
import assert from "assert";

export async function handleMintedMumbai(e: TokenMintedLog): Promise<void> {
  await handleMinted(e, "mumbai");
}

export async function handleMintedSepolia(e: TokenMintedLog): Promise<void> {
  await handleMinted(e, "sepolia");
}

export async function handleMinted(
  log: TokenMintedLog,
  network: "mumbai" | "sepolia"
): Promise<void> {
  logger.info(`New token Minted transaction log at block ${log.blockNumber}`);
  const mintRecord = Mint.create({
    id: `${network}-${log.transactionHash}`,
    network: network,
    tokenID: log.args?.amount.toBigInt(),
    timestamp: log.block.timestamp,
    from: log.args?.to,
  });
  assert(mintRecord.from, "Account is not defined");

  await mintRecord.save();
}
