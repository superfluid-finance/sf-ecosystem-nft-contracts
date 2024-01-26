// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "ds-test/test.sol";

import "../src/GdaNFTContract.sol";
import {ISuperfluid, ISuperToken, ISuperApp } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { TestGovernance, Superfluid, ConstantFlowAgreementV1, InstantDistributionAgreementV1, IDAv1Library, SuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeploymentSteps.sol";
import { SuperfluidFrameworkDeployer } from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {ISETH} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ISETH.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";

contract GdaNFTContractTest is Test {

    using SuperTokenV1Library for ISETH;

    GdaNFTContract public gdaNFTContract;
    ISuperfluid public host;
    ISETH public seth;
    address public account1;
    address public account2;
    address public account3;
    ISuperfluidPool public pool;

    struct Framework {
        TestGovernance governance;
        Superfluid host;
        ConstantFlowAgreementV1 cfa;
        InstantDistributionAgreementV1 ida;
        IDAv1Library.InitData idaLib;
        SuperTokenFactory superTokenFactory;
    }

    SuperfluidFrameworkDeployer.Framework public sf;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        SuperfluidFrameworkDeployer sfd = new SuperfluidFrameworkDeployer();
        sfd.deployTestFramework();
        sf = sfd.getFramework();
        account1 = vm.addr(1);
        account2 = vm.addr(2);
        account3 = vm.addr(3);

        seth = sfd.deployNativeAssetSuperToken("fETHx", "FETHX");

        vm.deal(account1, 100000000000000000000000000000);
        gdaNFTContract = new GdaNFTContract("GdaNFT", "GdaNFT", "",seth,1000000000000,100000);
        pool= gdaNFTContract.pool();
    }

    function testMint() public {
        uint tokenPrice = gdaNFTContract.tokenPrice();
        gdaNFTContract.gdaMint{value: tokenPrice}(account1, 1);
        assertEq(gdaNFTContract.balanceOf(account1), 1);
    }

    function testMemberUnits() public {
        uint tokenPrice = gdaNFTContract.tokenPrice();
        gdaNFTContract.gdaMint{value: tokenPrice}(account1, 1);
        gdaNFTContract.gdaMint{value: 4*tokenPrice}(account1, 4);
        vm.startPrank(account1);
        seth.connectPool(pool);
        vm.stopPrank();
        console.log(pool.getUnits(account1));
        assertEq(pool.getUnits(account1), 5);
    }

    function testTotalUnits() public {
        uint tokenPrice = gdaNFTContract.tokenPrice();
        gdaNFTContract.gdaMint{value: tokenPrice}(account1, 1);
        gdaNFTContract.gdaMint{value: 4*tokenPrice}(account1, 4);
        assertEq(pool.getTotalUnits(), 5);
    }

    function testFlowRate() public {
        uint tokenPrice = gdaNFTContract.tokenPrice();
        gdaNFTContract.gdaMint{value: tokenPrice}(account1, 1);
        gdaNFTContract.gdaMint{value: tokenPrice}(account2, 1);
        vm.startPrank(account1);
        seth.connectPool(pool);
        vm.stopPrank();
        vm.startPrank(account2);
        seth.connectPool(pool);
        vm.stopPrank();
        int96 flowRate1 = pool.getMemberFlowRate(account1);
        console.logInt(flowRate1);
        int96 flowRate2 = pool.getMemberFlowRate(account2);
        console.logInt(flowRate2);
        assertEq(flowRate1, flowRate2);
    }

    function testAdvancedFlowRate() public {
        uint tokenPrice = gdaNFTContract.tokenPrice();
        gdaNFTContract.gdaMint{value: tokenPrice}(account1, 1);
        gdaNFTContract.gdaMint{value: 4*tokenPrice}(account2, 4);
        gdaNFTContract.gdaMint{value: 5*tokenPrice}(account3, 5);
        vm.startPrank(account1);
        seth.connectPool(pool);
        vm.stopPrank();
        vm.startPrank(account2);
        seth.connectPool(pool);
        vm.stopPrank();
        vm.startPrank(account3);
        seth.connectPool(pool);
        vm.stopPrank();
        int96 flowRate1 = pool.getMemberFlowRate(account1);
        int96 flowRate2 = pool.getMemberFlowRate(account2);
        int96 flowRate3 = pool.getMemberFlowRate(account3);
        console.logInt(flowRate1);
        console.logInt(flowRate2);
        console.logInt(flowRate3);
        int96 totalFlowRate = seth.getFlowDistributionFlowRate(
            address(gdaNFTContract),
            pool
        );
        assertApproxEqAbs(flowRate1+flowRate2+flowRate3, totalFlowRate, 10);
    }

    /*function testFuzzFlowRate(uint96 _amount1, uint96 _amount2) public{
        uint tokenPrice = gdaNFTContract.tokenPrice();
        //avoid divide by 0
        uint96 amount1 = _amount1+1;
        uint96 amount2 = _amount2+1;
        gdaNFTContract.gdaMint{value: amount1*tokenPrice}(account1, amount1);
        gdaNFTContract.gdaMint{value: amount2*tokenPrice}(account2, amount2);
        int96 ratio=int96(amount1/amount2);
        vm.startPrank(account1);
        seth.connectPool(pool);
        vm.stopPrank();
        vm.startPrank(account2);
        seth.connectPool(pool);
        vm.stopPrank();
        int96 flowRate1 = pool.getMemberFlowRate(account1);
        int96 flowRate2 = pool.getMemberFlowRate(account2);
        assertApproxEqAbs(flowRate1, ratio*flowRate2, 10);
    }*/
    
}
