// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    bool private _nonReentrant;
    constructor() { _nonReentrant = false; }
    modifier nonReentrant() {
        require(!_nonReentrant, "ReentrancyGuard: reentrant call");
        _nonReentrant = true;
        _;
        _nonReentrant = false;
    }
}

contract PredictionMarkets is ReentrancyGuard {
    struct Market {
        address creator;
        address oracle;
        string question;
        uint256 deadline;
        uint256 yesPool;
        uint256 noPool;
        uint8 outcome; // 0 unresolved, 1 yes, 2 no
        bool resolved;
        uint256 positions;
    }

    struct Position {
        address user;
        uint256 marketId;
        bool isYes;
        uint256 amount;
        bool claimed;
    }

    Market[] public markets;
    Position[] public positions;
    mapping(uint256 => uint256[]) public marketPositions;

    uint256 public totalVolume;
    mapping(uint256=>mapping(address=>uint256[])) public userMarketPositions;
    mapping(uint256=>uint256) public yesPositionCount;
    mapping(uint256=>uint256) public noPositionCount;
    mapping(uint256=>uint256) public remainingWinners;
    mapping(uint256=>uint256) public settledAmount;

    event MarketCreated(uint256 indexed mid, address indexed creator, string question, uint256 deadline, address oracle);
    event PositionOpened(uint256 indexed mid, uint256 indexed pid, address indexed user, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed mid, uint8 outcome, uint256 yesPool, uint256 noPool);
    event WinningsClaimed(uint256 indexed mid, uint256 indexed pid, address indexed user, uint256 payout);

    function createMarket(string calldata question, uint256 durationSeconds, address oracle) external returns (uint256) {
        require(oracle != address(0), "Zero oracle");
        require(durationSeconds > 0, "Zero duration");
        Market storage m = markets.push();
        m.creator = msg.sender;
        m.oracle = oracle;
        m.question = question;
        m.deadline = block.timestamp + durationSeconds;
        uint256 mid = markets.length - 1;
        emit MarketCreated(mid, msg.sender, question, m.deadline, oracle);
        return mid;
    }

    function _open(uint256 mid, bool isYes) internal nonReentrant {
        Market storage m = markets[mid];
        require(!m.resolved, "Already resolved");
        require(block.timestamp < m.deadline, "Market closed");
        require(msg.value > 0, "Zero stake");
        if (isYes) { m.yesPool += msg.value; } else { m.noPool += msg.value; }
        positions.push(Position(msg.sender, mid, isYes, msg.value, false));
        uint256 pid = positions.length - 1;
        marketPositions[mid].push(pid);
        userMarketPositions[mid][msg.sender].push(pid);
        if(isYes)yesPositionCount[mid]++;else noPositionCount[mid]++;
        m.positions += 1;
        totalVolume += msg.value;
        emit PositionOpened(mid, pid, msg.sender, isYes, msg.value);
    }

    function buyYes(uint256 mid) external payable { _open(mid, true); }
    function buyNo(uint256 mid) external payable { _open(mid, false); }

    function resolve(uint256 mid, uint8 outcome) external {
        Market storage m = markets[mid];
        require(msg.sender == m.oracle, "Not oracle");
        require(!m.resolved, "Already resolved");
        require(block.timestamp >= m.deadline, "Market still open");
        require(outcome == 1 || outcome == 2, "Bad outcome");
        m.resolved = true;
        m.outcome = outcome;
        remainingWinners[mid]=outcome==1?yesPositionCount[mid]:noPositionCount[mid];
        emit MarketResolved(mid, outcome, m.yesPool, m.noPool);
    }

    function claimWinnings(uint256 mid) external nonReentrant {
        _claim(mid,0,100);
    }
    function claimRange(uint256 mid,uint256 offset,uint256 count) external nonReentrant {
        require(count>0&&count<=100,"Maximum 100 positions");
        _claim(mid,offset,count);
    }
    function _claim(uint256 mid,uint256 offset,uint256 count) private {
        Market storage m = markets[mid];
        require(m.resolved, "Not resolved");
        uint256 winningPool = m.outcome == 1 ? m.yesPool : m.noPool;
        uint256 totalPaid = 0;
        uint256[] storage pids = userMarketPositions[mid][msg.sender];
        require(offset<=pids.length,"Invalid offset");
        uint256 end=offset+count;if(end>pids.length)end=pids.length;
        for (uint256 i = offset; i < end; i++) {
            Position storage p = positions[pids[i]];
            if (p.claimed) continue;
            bool won = (m.outcome == 1 && p.isYes) || (m.outcome == 2 && !p.isYes);
            p.claimed = true;
            if (!won&&winningPool>0) continue;
            uint256 payout;
            if(winningPool==0)payout=p.amount;
            else {
                uint256 lossPool = m.outcome == 1 ? m.noPool : m.yesPool;
                remainingWinners[mid]--;
                payout=remainingWinners[mid]==0?m.yesPool+m.noPool-settledAmount[mid]:p.amount+(p.amount*lossPool/winningPool);
            }
            settledAmount[mid]+=payout;
            totalPaid += payout;
            emit WinningsClaimed(mid, pids[i], msg.sender, payout);
        }
        require(totalPaid > 0, "Nothing to claim");
        (bool ok,)=msg.sender.call{value:totalPaid}("");require(ok,"Payout failed");
    }

    function marketInfo(uint256 mid) external view returns (address creator, string memory question, uint256 deadline, bool resolved, uint8 outcome, uint256 yesPool, uint256 noPool, uint256 positionCount) {
        Market storage m = markets[mid];
        return (m.creator, m.question, m.deadline, m.resolved, m.outcome, m.yesPool, m.noPool, m.positions);
    }

    function marketCount() external view returns (uint256) { return markets.length; }
    function positionCount() external view returns (uint256) { return positions.length; }
}
