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
        emit MarketResolved(mid, outcome, m.yesPool, m.noPool);
    }

    function claimWinnings(uint256 mid) external nonReentrant {
        Market storage m = markets[mid];
        require(m.resolved, "Not resolved");
        uint256 winningPool = m.outcome == 1 ? m.yesPool : m.noPool;
        if (winningPool == 0) return;
        uint256 totalPaid = 0;
        uint256[] memory pids = marketPositions[mid];
        for (uint256 i = 0; i < pids.length; i++) {
            Position storage p = positions[pids[i]];
            if (p.user != msg.sender || p.claimed) continue;
            bool won = (m.outcome == 1 && p.isYes) || (m.outcome == 2 && !p.isYes);
            p.claimed = true;
            if (!won) continue;
            uint256 lossPool = m.outcome == 1 ? m.noPool : m.yesPool;
            uint256 payout = p.amount + (p.amount * lossPool / winningPool);
            totalPaid += payout;
            payable(msg.sender).transfer(payout);
            emit WinningsClaimed(mid, pids[i], msg.sender, payout);
        }
        require(totalPaid > 0, "Nothing to claim");
    }

    function marketInfo(uint256 mid) external view returns (address creator, string memory question, uint256 deadline, bool resolved, uint8 outcome, uint256 yesPool, uint256 noPool, uint256 positionCount) {
        Market storage m = markets[mid];
        return (m.creator, m.question, m.deadline, m.resolved, m.outcome, m.yesPool, m.noPool, m.positions);
    }

    function marketCount() external view returns (uint256) { return markets.length; }
    function positionCount() external view returns (uint256) { return positions.length; }
}
