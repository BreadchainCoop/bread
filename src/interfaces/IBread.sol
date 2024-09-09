pragma solidity ^0.8.20;

interface IBread{
    function claimYield(uint256 amount, address receiver) external ;
    function yieldAccrued() external view  returns (uint256);
    function setYieldClaimer(address _yieldClaimer) external ;

}