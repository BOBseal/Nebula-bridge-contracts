// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./LZO/contracts/lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract LZOEtherBridgeV1 is NonblockingLzApp {
    constructor(address endPoint)NonblockingLzApp(endPoint){
    }

    function _estimateEthFee(
        uint16 _dstChainId,
        bool _useZro,
        bytes memory _adapterParams,
        bytes memory PAYLOAD
    ) internal virtual view returns (uint a) {
        if(_dstChainId != lzEndpoint.getChainId()){
        (a , )=lzEndpoint.estimateFees(_dstChainId, address(this), PAYLOAD, _useZro, _adapterParams);
        }
        return (a);
    }

    // returns total amount eth to send with the function
    function _ethTotalCost(
        uint16 _dstChainId,
        bool _useZro,
        uint256 amount,
        address sendTo,
        uint256 dstGas
    ) internal virtual view returns (uint a,uint b) {
        bytes memory _adapterParams = abi.encodePacked(uint16(2), dstGas, amount , sendTo);
        bytes memory PAYLOAD = abi.encode(sendTo, amount);
        if(_dstChainId != lzEndpoint.getChainId()){
        (a , b)=lzEndpoint.estimateFees(_dstChainId, address(this), PAYLOAD, _useZro, _adapterParams);
        }
        return (a + amount,b);
    }

    //fee in ether not lzo 
    function _bridgeEth(
        uint16 toChainId , 
        address to , 
        uint256 amount,
        uint256 dstGas,
        bool useZro,
        address zroPAddr // zro payment address
       ) internal virtual returns(bool){
        //adapter params -- version => 2 , GASDROP METHOD with arb logic -- dependent on query from relayer max value --- dest chains must have eth as gas token
        //V2 solution suggestion=> send cctp with logic and swap on dst to avoid slippage and sick fee by lzo
        bytes memory adapterParams = abi.encodePacked(uint16(2), dstGas, amount , to);
        // dst data for amount , reciever
        bytes memory payload = abi.encode(to, amount);
        (uint256 f) = _estimateEthFee(toChainId, useZro , adapterParams , payload);
        _lzSend(toChainId, payload, payable(msg.sender), zroPAddr, adapterParams, amount + f);
        return true;
    }

    function withdrawFee(uint256 amount) public onlyOwner{
        payable(msg.sender).transfer(amount);
    }

    function _trustAddress(address remoteAddress , uint16 chainId) public onlyOwner{
        trustedRemoteLookup[chainId] = abi.encodePacked(remoteAddress, address(this));
    }

    function _distrustAddress(uint16 chainId) public onlyOwner{
       delete trustedRemoteLookup[chainId];
    }

    receive() external payable {}
}