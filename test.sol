// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "./dualBridge.sol";
import "./lib.d.sol";


interface BRIDGE {

    function bridgeErc20(
        Inputs.ERC20INPUT memory params
    ) external payable returns(bool z);
}

contract FF {
    address public  bridge;

    constructor (address b) {
        bridge = b;
    }

    function bridgeCall(
        uint16 targetChain,
        address recipient,
        uint256 amt,
        address token,
        uint256 dstGas,
        address referal
    ) public payable {
        Inputs.ERC20INPUT memory params = Inputs.ERC20INPUT({
            targetChain: targetChain,
            recipient: recipient,
            amt: amt,
            token: token,
            dstGas:dstGas,
            referal:referal
        });
        IERC20(token).transferFrom(msg.sender, address(this), amt);
        IERC20(token).approve(bridge , amt);
        BRIDGE(bridge).bridgeErc20{value:msg.value}(params);
    }
}