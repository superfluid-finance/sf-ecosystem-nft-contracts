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
import {BokkyPooBahsDateTimeLibrary} from "./BokkyPooBahsDateTimeLibrary.sol";

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
    string public ipfsURI;
    PoolConfig public poolConfig =
        PoolConfig({
            transferabilityForUnitsOwner: false,
            distributionFromAnyAddress: true
        });
    uint public tokenToMint;
    uint public lastMintTimestamp;
    struct Mint {
        address to;
        uint256 tokenId;
        uint timestamp;
    }
    mapping(address => Mint) public userMint;
    mapping(address => bool) public hasMinted;
    mapping (uint256=>address) public minter;


    event TokenMinted(address indexed to, uint256 tokenId);
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
        lastMintTimestamp=block.timestamp;
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
        minter[tokenId]=to;
        lastMintTimestamp = block.timestamp;
        _mint(to, tokenId);
        uint256 amountToUpgrade = (tokenPrice / 100) * 95;
        nativeToken.upgradeByETH{value: amountToUpgrade}();
        int96 newFlowRate = int96(
            uint96(nativeToken.balanceOf(address(this))) / flowDuration
        );
        nativeToken.updateMemberUnits(pool, to, 1);
        nativeToken.distributeFlow(address(this), pool, newFlowRate);
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
     * @dev Function to set the token price
     * @param _tokenPrice Price to set
     */

    function setTokenPrice(uint96 _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
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

    function calcHash(uint256 _tokenId) public view returns (string memory) {
        return
            Strings.toString(
                uint32(
                    uint256(keccak256(abi.encodePacked(_tokenId, minter[_tokenId])))
                )
            );
    }

    function setIPFSURI(string memory _ipfsuri) public onlyOwner {
        ipfsURI = _ipfsuri;
    }

    function calcURI(uint256 _tokenId) public view returns (string memory) {
        return
            string.concat(
                ipfsURI,
                calcHash(_tokenId)
            );
    }

    function generateJSON(
        uint256 _tokenId
    ) private view returns (string memory) {
        // Using the BokkyPooBahsDateTimeLibrary to convert the timestamp to a date
        // This library stops working beyond the year 2345
        // The question remails : is assuming your code will break in 300 years ethereum aligned?

        (uint year, uint month, uint day, , ,) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(lastMintTimestamp + flowDuration);
        string memory fullDate = string.concat(
            Strings.toString(year),
            "-",
            Strings.toString(month),
            "-",
            Strings.toString(day)
        );

        string memory stringFlowRate = string.concat(
            Strings.toString(
            uint96(
                pool.getMemberFlowRate(minter[_tokenId])
            )
        ),
        "wei/s"
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"Superfluid Ecosystem Rewards Pass",',
                            '"description":"An NFT to celebrate the launch of Superfluid Distribution Pools.",',
                            '"animation_url":"',
                            calcURI(_tokenId),
                            '",',
                            '"attributes":[',
                                '{',
                                    '"trait_type":"FlowRate",',
                                    '"value":"',
                                    stringFlowRate,
                                '"},', // Added a comma here to separate objects within the array
                                '{',
                                    '"trait_type":"EndOfFlowDate",',
                                    '"value":"',
                                    fullDate,
                                '"}',
                            ']}'
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
