// SPDX-License-Identifier: Apache-2.0

// Auto-generated

import {} from "../types/abi-interfaces/Abi";
import { Mint } from "../types";
import { TokenMintedLog } from "../types/abi-interfaces/Abi";

export async function handleMinted(log: TokenMintedLog): Promise<void> {
  logger.info(`New token Minted transaction log at block ${log.blockNumber}`);
  const mintRecord = Mint.create({
    id: log.transactionHash,
    tokenID: log.args?.amount.toBigInt(),
    timestamp: log.block.timestamp,
    from: log.args?.to,
  });
  await mintRecord.save();
}
