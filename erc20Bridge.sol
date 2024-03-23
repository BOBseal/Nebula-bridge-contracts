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

    function receivePayloadAndTokens(
        bytes memory payload,
        Structs.TokenReceived[] memory receivedTokens,
        bytes32 srcAddress, // sourceAddress
        uint16 ch,// source chain
        bytes32 dh,// deliveryHash,
        bytes[] memory // additional vaas
     ) internal virtual override 
     {
        require(_delivered[ch][dh]== false);
        require(receivedTokens.length == 1);
        require(wormholeEndpoints[ch][fromWormholeFormat(srcAddress)]== true);
        (
            address recipient
        ) = abi.decode(payload, (address));
        bool x = IERC20(receivedTokens[0].tokenAddress).transfer(recipient,receivedTokens[0].amount);
        _delivered[ch][dh] = x;
    }
    
}