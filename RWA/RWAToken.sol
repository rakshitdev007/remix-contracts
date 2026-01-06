// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICompliance {
    function canTransfer(address, address, uint256) external view returns (bool);
}

interface ILegalAgreement {
    function agreement()
        external
        view
        returns (
            bytes32,
            string memory,
            string memory,
            uint256,
            bool
        );
}

contract RWAToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    uint256 public totalSupply;
    address public issuer;

    ICompliance public compliance;
    ILegalAgreement public legalRegistry;

    mapping(address => uint256) private balances;
    mapping(address => bool) public frozen;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Frozen(address indexed user);
    event Unfrozen(address indexed user);
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount);

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Only issuer");
        _;
    }

    modifier notFrozen(address user) {
        require(!frozen[user], "Account frozen");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _compliance,
        address _legalRegistry
    ) {
        name = _name;
        symbol = _symbol;
        issuer = msg.sender;
        compliance = ICompliance(_compliance);
        legalRegistry = ILegalAgreement(_legalRegistry);
    }

    // ---------------- Read ----------------

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function legalAgreement()
        external
        view
        returns (
            bytes32 hash,
            string memory uri,
            string memory jurisdiction,
            uint256 effectiveDate,
            bool active
        )
    {
        return legalRegistry.agreement();
    }

    // ---------------- Transfers ----------------

    function transfer(address to, uint256 amount)
        external
        notFrozen(msg.sender)
        notFrozen(to)
        returns (bool)
    {
        require(
            compliance.canTransfer(msg.sender, to, amount),
            "Compliance failed"
        );
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ---------------- Issuer Powers ----------------

    function mint(address to, uint256 amount) external onlyIssuer {
        require(
            compliance.canTransfer(address(0), to, amount),
            "Recipient not compliant"
        );

        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyIssuer {
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    function freeze(address user) external onlyIssuer {
        frozen[user] = true;
        emit Frozen(user);
    }

    function unfreeze(address user) external onlyIssuer {
        frozen[user] = false;
        emit Unfrozen(user);
    }

    function forcedTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyIssuer {
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        balances[to] += amount;

        emit ForcedTransfer(from, to, amount);
    }
}
