// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Bread - An ERC20 stablecoin fully collateralized by Gnosis Chain xDAI
// which earns yield via Gnosis Chain sDAI (aka sexyDAI)
// and points this yield to the Breadchain Ecosystem
// implemented by: kassandra.eth
import {IBread} from "./interfaces/IBread.sol";
import {
    SafeERC20,
    IERC20
} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    OwnableUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {
    ERC20VotesUpgradeable
}
from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IWXDAI} from "./interfaces/IWXDAI.sol";
import {ISXDAI} from "./interfaces/ISXDAI.sol";

contract Bread is
    ERC20VotesUpgradeable,
    OwnableUpgradeable,
    IBread
{
    using SafeERC20 for IERC20;
    
    address public yieldClaimer;
    error MintZero();
    error BurnZero();
    error ClaimZero();
    error YieldInsufficient();
    error IsCollateral();
    error NativeTransferFailed();
    error OnlyClaimers();
    error MismatchArray();
    error MismatchAmount();

    IWXDAI public immutable wxDai;
    ISXDAI public immutable sexyDai;

    event Minted(address receiver, uint256 amount);
    event Burned(address receiver, uint256 amount);
    event YieldClaimerSet(address yieldClaimer);
    event ClaimedYield(uint256 amount);

    constructor(
        address _wxDai,
        address _sexyDai
    ) {
        wxDai = IWXDAI(_wxDai);
        sexyDai = ISXDAI(_sexyDai);
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
    }

    function setYieldClaimer(address _yieldClaimer) external onlyOwner {
        yieldClaimer = _yieldClaimer;
        emit YieldClaimerSet(_yieldClaimer);
    }

    function mint(address receiver) external payable {
        uint256 val = msg.value;
        if (val == 0) revert MintZero();

        wxDai.deposit{value: val}();
        IERC20(address(wxDai)).safeIncreaseAllowance(address(sexyDai), val);
        sexyDai.deposit(val, address(this));

        _mint(receiver, val);
        if (this.delegates(receiver) == address(0)) _delegate(receiver, receiver);
    }

    function mint(address receiver, uint256 amount) external {
        if (amount == 0) revert MintZero();

        IERC20(address(wxDai)).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(address(wxDai)).safeIncreaseAllowance(address(sexyDai), amount);
        sexyDai.deposit(amount, address(this));

        _mint(receiver, amount);
        if (this.delegates(receiver) == address(0)) _delegate(receiver, receiver);
    }

    function burn(uint256 amount, address receiver) external {
        if (amount == 0) revert BurnZero();
        _burn(msg.sender, amount);
        
        sexyDai.withdraw(amount, address(this), address(this));
        wxDai.withdraw(amount);
        _nativeTransfer(receiver, amount);

        emit Burned(receiver, amount);
    }

    function claimYield(uint256 amount, address receiver) external {
        if (msg.sender != owner() && msg.sender != yieldClaimer) revert OnlyClaimers();
        if (amount == 0) revert ClaimZero();
        uint256 yield = _yieldAccrued();
        if (yield < amount) revert YieldInsufficient();

        _mint(receiver, amount);
        if (this.delegates(receiver) == address(0)) _delegate(receiver, receiver);

        emit ClaimedYield(amount);
    }

    function rescueToken(address tok, uint256 amount) external onlyOwner {
        if (tok == address(sexyDai)) revert IsCollateral();
        IERC20(tok).safeTransfer(owner(), amount);
    }

    function yieldAccrued() external view returns (uint256) {
        return _yieldAccrued();
    }

    function _yieldAccrued() internal view returns (uint256) {
        uint256 bal = IERC20(address(sexyDai)).balanceOf(address(this));
        uint256 assets = sexyDai.convertToAssets(bal);
        uint256 supply = totalSupply();
        return assets > supply ? assets - supply : 0;
    }

    function _nativeTransfer(address to, uint256 amount) internal {
        bool success;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (!success) revert NativeTransferFailed();
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        super.transfer(recipient, amount);
        if (this.delegates(recipient) == address(0)) _delegate(recipient, recipient);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        super.transferFrom(from, to, value);
        if (this.delegates(to) == address(0)) _delegate(to, to);
        return true;
    }

}
