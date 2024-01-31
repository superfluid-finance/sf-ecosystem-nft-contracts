// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title GdaNFTContract
 * @author Superfluid
 * The GdaNFTContract provides an easy to use ERC721 contract that mints NFTs for a given price.
 * In the same transaction, the contract will also upgrade the native token to super token and
 * distribute the flow to the pool. The flow will be distributed the pool members, who are no other than
 * the NFT minters.
 */
contract GdaNFTContract is ERC721, Ownable, ReentrancyGuard {
    using SuperTokenV1Library for ISETH;

    ISuperfluidPool public pool;
    ISETH public nativeToken;
    uint96 public flowDuration;
    uint96 public tokenPrice;
    PoolConfig public poolConfig =
        PoolConfig({
            transferabilityForUnitsOwner: true,
            distributionFromAnyAddress: true
        });
    uint public tokenToMint;
    struct Mint {
        address to;
        uint256 tokenId;
        uint256 timestamp;
    }
    mapping(address => Mint) public userMint;
    mapping(address => bool) public hasMinted;

    event TokenMinted(address indexed to, uint256 amount);
    event BalanceRecovered(address indexed to, uint256 amount);

    /**
     * @dev Contructor of the GdaNFTContract
     * @param name Name of the NFT
     * @param symbol Symbol of the NFT
     * @param _nativeToken Address of the native super token
     * @param _tokenPrice Price of the NFT
     * @param _flowDuration Duration of the flow
     */
    constructor(
        string memory name,
        string memory symbol,
        ISETH _nativeToken,
        uint96 _tokenPrice,
        uint96 _flowDuration
    ) ERC721(name, symbol) {
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
     * @dev Modifier that checks if the account has already minted a NFT
     * @param account Address of the account
     */
    modifier didNotMint(address account) {
        require(
            hasMinted[account] == false,
            "GdaNFTContract: account already minted"
        );
        _;
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
        hasMinted[to] = true;
        userMint[to] = Mint(to, tokenId, block.timestamp);
        _mint(to, tokenId);
        uint256 amountToUpgrade = (tokenPrice / 100) * 95;
        nativeToken.upgradeByETH{value: amountToUpgrade}();
        int96 newFlowRate = int96(
            uint96(nativeToken.balanceOf(address(this))) / flowDuration
        );
        nativeToken.distributeFlow(address(this), pool, newFlowRate);
        nativeToken.updateMemberUnits(pool, to, 1);
    }

    /**
     * @dev Public function that mints a NFT for the given address
     */

    function gdaMint() external payable didNotMint(_msgSender()) nonReentrant {
        require(msg.value == tokenPrice, "GdaNFTContract: not enough eth sent");
        _gdaMint(_msgSender(), tokenToMint);
        tokenToMint++;
        emit TokenMinted(_msgSender(), tokenToMint);
    }

    /**
     * @dev Function to recover balance by the owner of the contract
     * @param to Address of send the balance
     * @param amount Amount to recover
     */

    function recoverBalance(address to, uint amount) external onlyOwner {
        payable(to).transfer(amount);
        emit BalanceRecovered(to, amount);
    }

    //**URI LOGIC *//

    function calcURI(uint256 _tokenId) public view returns (string memory) {
        string memory hash = Strings.toString(
            uint32(
                uint256(keccak256(abi.encodePacked(_tokenId + block.timestamp)))
            )
        );
        return
            string.concat(
                "ipfs://bafkreic6cj3uo5zhdip3cl5exl6hcokw4czwx7jp2sdllzit6xcqxarrsa?seed=",
                hash
            );
    }

    function generateJSON(
        uint256 _tokenId
    ) private view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"My WebGL NFT",',
                                '"description":"One of the best NFTs, by yours truly",',
                                '"animation_url":"',
                                calcURI(_tokenId),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    // token URI:
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return generateJSON(_tokenId);
    }
}
