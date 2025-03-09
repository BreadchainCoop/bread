// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Bread} from "../src/Bread.sol";
import {EIP173ProxyWithReceive} from "../src/proxy/EIP173ProxyWithReceive.sol";
import {IERC20} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
interface Depositable {
    function deposit() external payable;
}
interface IERC20Depositable is Depositable ,IERC20  {}

contract BreadTest is Test {
    EIP173ProxyWithReceive public breadProxy;
    Bread public breadToken;
    IERC20 public sexyDai;
    IERC20Depositable public wxDai;
    address public constant randomHolder =
        0x23b4f73FB31e89B27De17f9c5DE2660cc1FB0CdF; // random multisig
    address public constant randomEOA =
        0x4B5BaD436CcA8df3bD39A095b84991fAc9A226F1;
    address[] receivers;
    uint256[] amounts;
    address[] migration_addresses;
    uint256[] migration_amounts;

    function setUp() public {
        address breadImpl = address(
            new Bread(
                0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
                0xaf204776c7245bF4147c2612BF6e5972Ee483701
            )
        );

        breadProxy = new EIP173ProxyWithReceive(
            breadImpl,
            address(this),
            bytes("")
        );

        breadToken = Bread(address(breadProxy));

        breadToken.initialize("Breadchain Stablecoin", "BREAD", address(this));
        breadToken.setYieldClaimer(address(this));
        sexyDai = IERC20(0xaf204776c7245bF4147c2612BF6e5972Ee483701);
        wxDai = IERC20Depositable(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
        vm.roll(32661486);
        /// @dev we mint one BREAD and burn it to simulate what we'll do in reality
        /// this helps us avoid inflation attacks and underflow issues if burn totalSupply() in some cases
        breadToken.mint{value: 1 ether}(
            0x0000000000000000000000000000000000000001
        );
        vm.roll(32661487);
        vm.deal(randomHolder, 10000000000000000000000000000 ether);
        vm.prank(randomHolder);
        wxDai.deposit{value: 1000000000000000 ether}();
        
    }

    function test_basic_deposits() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 contractBalBefore = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);
        assertGt(contractBalBefore, 0);
        assertLt(contractBalBefore, 1 ether);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyBefore + 1 ether);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        contractBalBefore = contractBalAfter;
        supplyBefore = supplyAfter;
        balBefore = balAfter;

        uint256 randomHolderBalBefore = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalBefore, 0);

        breadToken.mint{value: 5 ether}(randomHolder);

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, supplyBefore + 5 ether);
        balAfter = breadToken.balanceOf(address(this));
        assertEq(balAfter, balBefore);
        contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyBefore + 5 ether);

        uint256 randomHolderBalAfter = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalAfter, 5 ether);

        uint256 randomHolderWXDAI = wxDai.balanceOf(randomHolder);
        assertGt(randomHolderWXDAI, 10000 ether);

        vm.roll(32661488);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661489);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_basic_withdraws() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);

        breadToken.mint{value: 1 ether}(address(this));

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, 0);
        assertLt(contractBalAfter, supplyAfter);

        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(32661490);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661491);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_burn() public {
        vm.roll(326615001);
        uint256 checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 0);
        vm.deal(randomHolder, 1 ether);
        vm.prank(randomHolder);
        breadToken.mint{value: 1 ether}(randomHolder);
        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 1);
        vm.roll(326615002);
        vm.prank(randomHolder);
        breadToken.burn(1 ether, randomHolder);
        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 2);
        vm.roll(326615003);
        vm.deal(address(this), 2 ether);
        uint256 balBefore = address(this).balance;
        breadToken.mint{value: 1 ether}(address(this));
        assertEq(address(this).balance, balBefore - 1 ether);
        balBefore = address(this).balance;
        uint256 supplyBefore = breadToken.totalSupply();
        vm.roll(326615004);
        breadToken.burn(0.5 ether, address(this));
        uint256 supplyAfter = breadToken.totalSupply();
        assertEq(balBefore + 0.5 ether, address(this).balance);
        assertEq(supplyAfter, supplyBefore - 0.5 ether);
    }

    function test_yield() public {
        vm.roll(32661496);
        uint256 supplyBefore = breadToken.totalSupply();
        assertEq(supplyBefore, 1 ether);
        uint256 yieldBefore = breadToken.yieldAccrued();

        breadToken.mint{value: 1 ether}(address(this));
        uint256 supplyAfter = breadToken.totalSupply();
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertGt(contractBalAfter, 0);

        yieldBefore = breadToken.yieldAccrued();
        assertEq(yieldBefore, 0);

        vm.roll(32661497);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661498);
        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);

        vm.roll(32661499);
        breadToken.setYieldClaimer(randomHolder);
        vm.roll(32661500);
        vm.prank(randomHolder);
        breadToken.claimYield(1, randomHolder);
        // uint256 bal = breadToken.balanceOf(address(this));
        // assertEq(bal, 1);
        // vm.roll(32661501);
        // vm.prank(randomEOA);
        // vm.expectRevert();
        // breadToken.claimYield(1 ether, randomEOA);
    }

    
    function test_transfer_from() public {
        breadToken.mint{value: 1 ether}(address(this));
        breadToken.approve(address(0x42), 1 ether);
        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);
        uint256 bal = breadToken.balanceOf(address(0x42));
        assertEq(bal, 1 ether);
    }
    function test_allowance() public {
        breadToken.mint{value: 1 ether}(address(this));
        breadToken.approve(address(0x42), 1 ether);
        uint256 allowance = breadToken.allowance(address(this), address(0x42));
        assertEq(allowance, 1 ether);
        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);
    }

    // Tests for mint(address, amount)

    function test_basic_deposits_newMint() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 contractBalBefore = sexyDai.balanceOf(address(breadToken));
        uint256 yieldBefore = breadToken.yieldAccrued();

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);
        assertGt(contractBalBefore, 0);
        assertLt(contractBalBefore, 1 ether);
        assertEq(yieldBefore, 0);

        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 100 ether);
        breadToken.mint(address(this), 1 ether);
        vm.stopPrank();

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));

        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertEq(balAfter, balBefore + 1 ether);
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyAfter);

        supplyBefore = supplyAfter;
        balBefore = balAfter;
        contractBalBefore = contractBalAfter;
        uint256 randomHolderBalBefore = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalBefore, 0);

        vm.startPrank(randomHolder);

        wxDai.approve(address(breadToken), 100 ether);
        breadToken.mint(randomHolder, 5 ether);
        vm.stopPrank();

        supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, supplyBefore + 5 ether);

        balAfter = breadToken.balanceOf(address(this));
        assertEq(balAfter, balBefore);

        contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertGt(contractBalAfter, contractBalBefore);
        assertLt(contractBalAfter, supplyAfter);

        uint256 randomHolderBalAfter = breadToken.balanceOf(randomHolder);
        assertEq(randomHolderBalAfter, 5 ether);

        // Trigger some yield by transferring wxDai directly to sexyDai
        vm.roll(32661488);
        vm.startPrank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.stopPrank();
        vm.roll(32661489);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_basic_withdraws_newMint() public {
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 balBefore = breadToken.balanceOf(address(this));
        uint256 yieldBefore = breadToken.yieldAccrued();

        assertEq(supplyBefore, 1 ether);
        assertEq(balBefore, 0);
        assertEq(yieldBefore, 0);

        // Approve and mint with the new function
        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 2 ether);
        breadToken.mint(address(this), 2 ether);
        vm.stopPrank();

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 balAfter = breadToken.balanceOf(address(this));
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertEq(supplyAfter, supplyBefore + 2 ether);
        assertEq(balAfter, balBefore + 2 ether);
        assertGt(contractBalAfter, 0);

        // Check yield accrual
        vm.roll(32661490);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661491);

        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);
    }

    function test_burn_newMint() public {
        vm.roll(326615001);
        uint256 checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 0);

        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 1 ether);
        breadToken.mint(randomHolder, 1 ether);
        vm.stopPrank();

        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 1);

        vm.roll(326615002);
        vm.prank(randomHolder);
        breadToken.burn(1 ether, randomHolder);
        checkpoint = breadToken.numCheckpoints(randomHolder);
        assertEq(checkpoint, 2);

        vm.roll(326615003);
        uint256 balBefore = address(this).balance;
        uint256 supplyBefore = breadToken.totalSupply();

        vm.startPrank(randomHolder);
        wxDai.transfer(address(this), 2 ether);
        vm.stopPrank();

        wxDai.approve(address(breadToken), 1 ether);
        breadToken.mint(address(this), 1 ether);

        vm.roll(326615004);
        breadToken.burn(0.5 ether, address(this));
        assertEq(balBefore + 0.5 ether, address(this).balance);

        uint256 supplyAfter = breadToken.totalSupply();
        assertEq(supplyAfter, supplyBefore + 1 ether - 0.5 ether);
    }

    function test_yield_newMint() public {
        vm.roll(32661496);
        uint256 supplyBefore = breadToken.totalSupply();
        uint256 yieldBefore = breadToken.yieldAccrued();
        assertEq(supplyBefore, 1 ether);
        assertEq(yieldBefore, 0);

        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 1 ether);
        breadToken.mint(address(this), 1 ether);
        vm.stopPrank();

        uint256 supplyAfter = breadToken.totalSupply();
        uint256 contractBalAfter = sexyDai.balanceOf(address(breadToken));
        assertEq(supplyAfter, supplyBefore + 1 ether);
        assertGt(contractBalAfter, 0);

        // Update yield
        vm.roll(32661497);
        vm.prank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.roll(32661498);
        uint256 yieldAfter = breadToken.yieldAccrued();
        assertGt(yieldAfter, yieldBefore);

        // Claim yield as yieldClaimer
        vm.roll(32661499);
        breadToken.setYieldClaimer(randomHolder);
        vm.roll(32661500);
        vm.prank(randomHolder);
        breadToken.claimYield(1, randomHolder);
    }

    function test_transfer_from_newMint() public {
        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 2 ether);
        breadToken.mint(address(this), 1 ether);
        vm.stopPrank();

        breadToken.approve(address(0x42), 1 ether);
        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);

        uint256 bal = breadToken.balanceOf(address(0x42));
        assertEq(bal, 1 ether);
    }

    function test_allowance_newMint() public {
        vm.startPrank(randomHolder);
        wxDai.approve(address(breadToken), 1 ether);
        breadToken.mint(address(this), 1 ether);
        vm.stopPrank();

        breadToken.approve(address(0x42), 1 ether);
        uint256 allowance = breadToken.allowance(address(this), address(0x42));
        assertEq(allowance, 1 ether);

        vm.prank(address(0x42));
        breadToken.transferFrom(address(this), address(0x42), 1 ether);
    }
    
    function test_claim_yield_delegation() public {
        // This test verifies the fix for a centralization risk in claimYield:
        // Previously, claimYield unconditionally set delegation for the receiver,
        // which would allow owner/yieldClaimer to override anyone's delegation by
        // claiming yield to their address. Now, it only sets delegation if none exists.

        // Setup
        vm.deal(address(this), 1 ether);
        breadToken.mint{value: 0.01 ether}(address(this));
        breadToken.setYieldClaimer(address(this));

        address userAddress = address(0x123);
        address customDelegate = address(0x456);
        
        vm.deal(address(this), 1 ether);
        breadToken.mint{value: 0.01 ether}(userAddress);
        
        vm.startPrank(userAddress);
        breadToken.delegate(customDelegate);
        vm.stopPrank();
        
        assertEq(breadToken.delegates(userAddress), customDelegate);
        
        vm.roll(block.number + 1000);
        vm.startPrank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.stopPrank();
        vm.roll(block.number + 100);
        
        uint256 yieldAvailable = breadToken.yieldAccrued();
        assertGt(yieldAvailable, 0);
        
        uint256 claimAmount = 0.00001 ether;
        assertLt(claimAmount, yieldAvailable);
        
        uint256 initialSupply = breadToken.totalSupply();
        breadToken.claimYield(claimAmount, userAddress);
        
        assertGt(breadToken.totalSupply(), initialSupply);
        // Key check: verify delegation wasn't changed by claimYield
        assertEq(breadToken.delegates(userAddress), customDelegate);
        
        address newUser = address(0x789);
        
        vm.roll(block.number + 100);
        vm.startPrank(randomHolder);
        wxDai.transfer(address(sexyDai), 10000 ether);
        vm.stopPrank();
        vm.roll(block.number + 100);
        
        assertEq(breadToken.delegates(newUser), address(0));
        breadToken.claimYield(claimAmount, newUser);
        // Check default behavior for new addresses is still intact
        assertEq(breadToken.delegates(newUser), newUser);
    }

    receive() external payable {}
}
