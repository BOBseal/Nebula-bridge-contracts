// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./src/Utils.sol";
import {IWETH} from "./src/interfaces/IWETH.sol";
import {TokenBase, TokenReceiver, TokenSender} from "./src/TokenBase.sol";
import "./src/interfaces/IWormholeReceiver.sol";
import "./src/interfaces/IWormholeRelayer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // use oz < 5.0
import "./lib.d.sol";


abstract contract ERC20Bridge is TokenSender , TokenReceiver, Ownable{ 
    mapping(uint16 => mapping(address => bool)) internal wormholeEndpoints;
    mapping(uint16 => address) internal wormEndpoints;
    mapping(uint16 => mapping(bytes32 => bool)) internal _delivered;

    function _initWorm(
        address _wormholeRelayer, // wormhole relayer address
        address _tokenBridge, // wormhole token bridge address
        address _wormhole // wormhole core address
    
    ) internal virtual{
        _initTokenBase(_wormholeRelayer, _tokenBridge, _wormhole);
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
        uint256 gasUnits
    ) internal view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            wormholeTargetId,
            0,
            gasUnits
        );
        // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
        cost = cost + wormhole.messageFee();
    }

    // returns wormhole sequence for successful transfers
    function _bridgeErc20(
        uint16 targetChain,
        address targetBridge,
        address recipient,
        uint256 amount,
        address token,
        uint256 dstGas
    ) internal virtual returns(bool) {
        (uint256 cost) = _erc20FeeQuote(targetChain ,dstGas);
        if(msg.value < cost) {revert("");}
        
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

    function receivePayloadAndTokens(
        bytes memory payload,
        Structs.TokenReceived[] memory receivedTokens,
        bytes32 srcA, // sourceAddress
        uint16 ch,
        bytes32 dh,// deliveryHash,
        bytes[] memory
     ) internal virtual override 
     {
        require(receivedTokens.length == 1);
        address bridge = fromWormholeFormat(srcA);
        require(wormholeEndpoints[ch][bridge]== true);
        require(_delivered[ch][dh]== false);
        (
            address recipient
        ) = abi.decode(payload, (address));
        
        uint256 tokenAmt = receivedTokens[0].amount;
        bool x = IERC20(receivedTokens[0].tokenAddress).transfer(recipient,tokenAmt);
        _delivered[ch][dh]= x ? true : false;
    }
    
}