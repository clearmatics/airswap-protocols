//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/Math.sol";

contract Staking is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  struct Stake {
    uint256 cliff;
    uint256 periodLength;
    uint256 percentPerPeriod;
    uint256 initialBalance;
    uint256 currentBalance;
    uint256 blockNumber;
  }

  IERC20 public immutable stakingToken;
  uint256 public cliff;
  uint256 public periodLength;
  uint256 public percentPerPeriod;
  mapping(address => Stake[]) public stakes;

  constructor(
    IERC20 _stakingToken,
    uint256 _cliff,
    uint256 _periodLength,
    uint256 _percentPerPeriod
  ) {
    stakingToken = _stakingToken;
    cliff = _cliff;
    periodLength = _periodLength;
    percentPerPeriod = _percentPerPeriod;
  }

  function setVestingSchedule(
    uint256 _cliff,
    uint256 _periodLength,
    uint256 _percentPerPeriod
  ) external onlyOwner {
    cliff = _cliff;
    periodLength = _periodLength;
    percentPerPeriod = _percentPerPeriod;
  }

  function stake(uint256 amount) external {
    stakeFor(msg.sender, amount);
  }

  function stakeFor(address account, uint256 amount) public {
    stakes[account].push(
      Stake(cliff, periodLength, percentPerPeriod, amount, amount, block.number)
    );
    stakingToken.safeTransferFrom(account, address(this), amount);
  }

  function addToStake(uint256 index, uint256 amount) external {
    addToStakeFor(index, msg.sender, amount);
  }

  function addToStakeFor(
    uint256 index,
    address account,
    uint256 amount
  ) public {
    Stake storage stakeData = stakes[msg.sender][index];

    uint256 newInitialBalance = stakeData.initialBalance.add(amount);
    uint256 newCurrentBalance = stakeData.currentBalance.add(amount);
    uint256 newBlockNumber =
      stakeData.blockNumber +
        amount.mul(block.number.sub(stakeData.blockNumber)).div(
          newInitialBalance
        );

    stakes[msg.sender][index] = Stake(
      cliff,
      periodLength,
      percentPerPeriod,
      newInitialBalance,
      newCurrentBalance,
      newBlockNumber
    );

    stakingToken.safeTransferFrom(account, address(this), amount);
  }

  function unstake(uint256 index, uint256 amount) external {
    Stake storage stakeData = stakes[msg.sender][index];
    require(
      block.number.sub(stakeData.blockNumber) >= stakeData.cliff,
      "CLIFF_NOT_REACHED"
    );
    uint256 withdrawableAmount = availableToUnstake(index, msg.sender);
    require(amount <= withdrawableAmount, "AMOUNT_EXCEEDS_AVAILABLE");
    stakeData.currentBalance = stakeData.currentBalance.sub(amount);
    if (stakeData.currentBalance == 0) {
      // remove stake element if claimable amount goes to 0
      Stake[] storage accountStakes = stakes[msg.sender];
      Stake storage lastStake = accountStakes[accountStakes.length.sub(1)];
      // replace stake at index with last stake
      stakeData.cliff = lastStake.cliff;
      stakeData.periodLength = lastStake.periodLength;
      stakeData.percentPerPeriod = lastStake.percentPerPeriod;
      stakeData.initialBalance = lastStake.initialBalance;
      stakeData.currentBalance = lastStake.currentBalance;
      stakeData.blockNumber = lastStake.blockNumber;
      // remove last stake
      stakes[msg.sender].pop();
    }
    stakingToken.transfer(msg.sender, amount);
  }

  function vested(uint256 index, address account)
    public
    view
    returns (uint256)
  {
    Stake storage stakeData = stakes[account][index];
    uint256 numPeriods =
      (block.number.sub(stakeData.blockNumber)).div(stakeData.periodLength);

    // Divide by 10000 to allow two-place percentage precision.
    return
      (stakeData.percentPerPeriod.mul(numPeriods).mul(stakeData.initialBalance))
        .div(10000);
  }

  function availableToUnstake(uint256 index, address account)
    public
    view
    returns (uint256)
  {
    uint256 vestedAmount = vested(index, account);
    uint256 currentBalance = 0;
    Stake memory stakeData = stakes[account][index];
    if (block.number.sub(stakeData.blockNumber) >= stakeData.cliff) {
      currentBalance = stakeData.currentBalance;
    }
    return Math.min(vestedAmount, currentBalance);
  }

  function balanceOf(address account) external view returns (uint256) {
    Stake[] memory accountStakes = stakes[account];
    uint256 stakedBalance = 0;
    for (uint256 i = 0; i < accountStakes.length; i++) {
      stakedBalance = stakedBalance.add(accountStakes[i].currentBalance);
    }
    return stakedBalance;
  }

  function getStakes(address account)
    external
    view
    returns (Stake[] memory accountStakes)
  {
    uint256 length = stakes[account].length;
    accountStakes = new Stake[](length);
    for (uint256 i = 0; i < length; i++) {
      Stake memory stakeData = stakes[account][i];
      accountStakes[i] = stakeData;
    }
    return accountStakes;
  }
}
