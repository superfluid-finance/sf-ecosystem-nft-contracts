// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";

/**
 * @title GdaNFTContract
 * @author Superfluid
 * The GdaNFTContract provides an easy to use ERC721 contract that mints NFTs for a given price.
 * In the same transaction, the contract will also upgrade the native token to super token and
 * distribute the flow to the pool. The flow will be distributed the pool members, who are no other than
 * the NFT minters.
 */
contract GdaNFTContract is ERC721, Ownable {
    using SuperTokenV1Library for ISETH;

    ISuperfluidPool public pool;
    ISETH public nativeToken;
    uint96 public flowDuration;
    uint96 public tokenPrice;
    string public uri;
    PoolConfig public poolConfig =
        PoolConfig({
            transferabilityForUnitsOwner: true,
            distributionFromAnyAddress: true
        });
    uint public tokenToMint;

    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Contructor of the GdaNFTContract
     * @param name Name of the NFT
     * @param symbol Symbol of the NFT
     * @param _uri URI of the NFT
     * @param _nativeToken Address of the native super token
     * @param _tokenPrice Price of the NFT
     * @param _flowDuration Duration of the flow
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory _uri,
        ISETH _nativeToken,
        uint96 _tokenPrice,
        uint96 _flowDuration
    ) ERC721(name, symbol) {
        uri = _uri;
        nativeToken = _nativeToken;
        tokenPrice = _tokenPrice;
        flowDuration = _flowDuration;
        pool = SuperTokenV1Library.createPool(
            nativeToken,
            address(this),
            poolConfig
        );
        tokenToMint = 0;
    }

    /**
     * @dev Internal function that mints a NFT for the given address
     * @notice in the same transaction, the contract will also upgrade the native token to super token and
     * distribute the flow to the pool. The flow will be distributed the pool members, who are no other than
     * the NFT minters.
     * @param to Address of the NFT receiver
     * @param tokenId Id of the NFT
     */

    function _gdaMint(address to, uint256 tokenId) private {
        _mint(to, tokenId);
        nativeToken.upgradeByETH{value: tokenPrice}();
        int96 newFlowRate = int96(uint96(nativeToken.balanceOf(address(this))) / flowDuration);
        nativeToken.distributeFlow(
            address(this),
            pool,
            newFlowRate
        );
        nativeToken.updateMemberUnits(pool, to, pool.getUnits(to) + 1);
    }

    /**
     * @dev Public function that mints a NFT for the given address
     * @param to Address of the NFT receiver
     * @param amount Amount of NFTs to mint
     */

    function gdaMint(address to, uint256 amount) external payable {
        require(
            msg.value == amount * tokenPrice,
            "GdaNFTContract: not enough eth sent"
        );
        for (uint i = 0; i < amount; i++) {
            _gdaMint(to, tokenToMint);
            tokenToMint++;
        }
        emit TokensMinted(to, amount);
    }

    /**
     * @dev function overrides the ERC721 baseURI function to return the uri of the NFT
     * @return uri of the NFT
     */

    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    /**
     * @dev function that sets the uri of the NFT
     * @notice only the owner of the contract can call this function
     * @param _uri uri of the NFT
     */
    function setURI(string memory _uri) external onlyOwner {
        uri = _uri;
    }

    //example of uri: https://ipfs.
}
