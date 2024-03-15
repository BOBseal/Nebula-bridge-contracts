// SPDX-License-Identifier: MIT
/*
Version wont properly work without customized relayer , without it it will have always a change of failing delivery

*/
pragma solidity ^0.8.20;

import "./src/Utils.sol";
import {IWETH} from "./src/interfaces/IWETH.sol";
import "./src/interfaces/IWormholeReceiver.sol";
import "./src/interfaces/IWormholeRelayer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // use oz < 5.0
import {CCTPAndTokenBase, CCTPAndTokenReceiver, CCTPAndTokenSender} from "./src/CCTPAndTokenBase.sol";

contract USDCCORE is CCTPAndTokenReceiver , CCTPAndTokenSender, Ownable{
    
    mapping(uint16 => mapping(address => bool)) public wormholeEndpoints;
    mapping(uint16 => address) internal wormEndpoints;
    mapping(uint16 => mapping(bytes32 => bool)) internal _delivered;

    constructor()Ownable(msg.sender){}

    function _initCore(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole,
        address _circleMessageTransmitter,
        address _circleTokenMessenger,
        address _USDC
    ) public onlyOwner{
       _initCCTP(
        _wormholeRelayer,
        _tokenBridge,
        _wormhole,
        _circleMessageTransmitter,
        _circleTokenMessenger,
        _USDC
        );
    }
     // setters

    function _setWormholeEndpoint(uint16 wormholeId, address contractAddress) public onlyOwner{
        wormholeEndpoints[wormholeId][contractAddress] = true;
        wormEndpoints[wormholeId] = contractAddress;
    }

    //to allow recieve from endChain
    function _removeWormholeEndpoint(uint16 wormholeId, address contractAddress) public onlyOwner{
        wormholeEndpoints[wormholeId][contractAddress] = false;
        delete wormEndpoints[wormholeId];
    }

    function _erc20FeeQuote(
        uint16 wormholeTargetId,
        uint256 rcvVal,
        uint256 gasUnits
    ) internal view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            wormholeTargetId,
            rcvVal,
            gasUnits
        );
        // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
        cost = cost + wormhole.messageFee();
    }

    function _bridgeErc20(
        uint16 targetChain,
        address targetBridge,
        address recipient,
        uint256 amount,
        address token,
        uint256 rcvVal,
        uint256 dstGas
    ) internal virtual returns(bool) {
        (uint256 cost) = _erc20FeeQuote(targetChain, rcvVal,dstGas);
        if(msg.value < cost) {revert("");}

        bool x = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if(!x){revert("");}
        
        bytes memory payload = abi.encode(recipient);
        sendTokenWithPayloadToEvm(
            targetChain,
            targetBridge, // address (on targetChain) to send token and payload to
            payload,
            0,
            dstGas, // gas units
            token, // address of IERC20 token contract
            amount, // amount
            wormhole.chainId(), // refund to sending chain
            msg.sender // refund to sender 
        );
        return true;
    }

    // recievers

    function receivePayloadAndUSDC(
        bytes memory payload,
        uint256 amountUSDCReceived,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal virtual override{
    }

    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal virtual override{
    }
    
}