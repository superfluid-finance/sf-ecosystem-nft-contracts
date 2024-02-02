import {
  EthereumProject,
  EthereumDatasourceKind,
  EthereumHandlerKind,
} from "@subql/types-ethereum";

// Can expand the Datasource processor types via the generic param
const project: EthereumProject = {
  specVersion: "1.0.0",
  version: "0.0.1",
  name: "polygon-mumbai-starter",
  description:
    "This project can be use as a starting point for developing your new polygon Mumbai SubQuery project",
  runner: {
    node: {
      name: "@subql/node-ethereum",
      version: ">=3.0.0",
    },
    query: {
      name: "@subql/query",
      version: "*",
    },
  },
  schema: {
    file: "./schema.graphql",
  },
  network: {
    /**
     * chainId is the EVM Chain ID, for Polygon this is 80001
     * https://chainlist.org/chain/80001
     */
    chainId: "80001",
    /**
     * These endpoint(s) should be public non-pruned archive node
     * We recommend providing more than one endpoint for improved reliability, performance, and uptime
     * Public nodes may be rate limited, which can affect indexing speed
     * When developing your project we suggest getting a private API key
     * If you use a rate limited endpoint, adjust the --batch-size and --workers parameters
     * These settings can be found in your docker-compose.yaml, they will slow indexing but prevent your project being rate limited
     */
    endpoint: ["https://polygon-mumbai.rpc.x.superfluid.dev"],
  },
  dataSources: [{
    kind: EthereumDatasourceKind.Runtime,
    startBlock: 45460081,
    options: {
      abi: 'Abi',
      address: '0x5644AE06901dd1d9cB5082685702B84B0B2d4Da6',
    },
    assets: new Map([['Abi', {file: './abis/abi.json'}]]),
    mapping: {
      file: './dist/index.js',
      handlers: [
        {
          kind: EthereumHandlerKind.Event,
          handler: "handleMinted",
          filter: {
            topics: [
              "TokenMinted(address indexed to, uint256 amount)",
            ],
          },
        }
      ]
    }
  },],
  repository: "https://github.com/subquery/ethereum-subql-starter",
};

// Must set default to the project instance
export default project;
