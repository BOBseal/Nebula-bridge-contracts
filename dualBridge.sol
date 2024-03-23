// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;
/*
Holesky: 
Manta: 
Sepolia:
*/
import {ERC20Bridge, Ownable, IERC20} from "./erc20Bridge.sol";
import {LZOEtherBridgeV1} from "./ethNativeBridge.sol";
import {Structs, Inputs} from "./lib.d.sol";

contract DUALBRIDGE is ERC20Bridge, LZOEtherBridgeV1{
    address internal grayzone;
    uint8 internal grayshare = 10;
    uint256 internal baseFee;
    uint256 public tBridgeIndex; // value to used for recent txs

    Structs.BridgeData internal states;

    mapping(address => Structs.User) internal users;
    mapping(address => uint256)internal fee;
    mapping(uint256 => Structs.LatestBridge) public LatestBridges;

    constructor(
        address _layerZroEndPoint,
        address _owner,
        address _grayzone
    )
    Ownable(_owner)
    LZOEtherBridgeV1(_layerZroEndPoint)
    {
        grayzone = _grayzone;
    }
    // module initializer for wormhole based functions
    function initWorm(
        address _wormholeRelayer,
        address _wormholeTokenBridge,
        address _wormholeCore
        ) public onlyOwner{
        _initWorm(_wormholeRelayer, _wormholeTokenBridge, _wormholeCore);
    }
    // global setter to activate bridge at all
    function _set_States_(
        uint256 pointPerTx,
        uint256 totalPoints,
        bool isActive,
        uint256 bridgeFeeEther,
        uint256 percentFee
    ) public onlyOwner{
        Structs.BridgeData memory data = Structs.BridgeData({
            pointPerTx:pointPerTx,
            totalPoints: totalPoints,
            isActive: isActive,
            bridgeFeeEther: bridgeFeeEther,
            percentFee: percentFee
        });
        states = data;
    }

    function getStates() public view returns(Structs.BridgeData memory){
        return states;
    }
    // returns the structs 
    /*
    UserData => returns base user data such as counts and nonces and referal related data
    */
    function getUserData(address user) public view returns(Structs.UserData memory , Structs.Referals memory){
        return (users[user].data , users[user].referalData);
    }

    function getAccruedFee(address token) public view returns(uint256){
        return fee[token];
    }
    // get's a user's total eth volume bridgedOut
    function getUserEthVol(address user , uint16 toLzChain) public view returns(uint256){
        return users[user].maps.outVolEth[toLzChain];
    }
    // get's user's total token value for a token bridged oout
    function getUserTknVol(address user , address token , uint16 toWormId) public view returns(uint256){
        return users[user].maps.outVolToken[token][toWormId];
    }
    // get's the token bridge out data struct ,
    /*
    outNonce => user's bridge out count index
    toWormchain=> wormhole id of dest chain
    */
    function getTKNBridgeOut(address user , uint256 outNonce, uint16 toWormChain)public view returns(Structs.TokenBridge memory){
        return users[user].maps.tokenBridgeOuts[outNonce][toWormChain];
    }
    // get's the delivery hash of a token bridge IN for a specific index of user's bridge Ins
    function getTKNDelivHash(address user , uint256 bridgeInNonce , uint16 frmWormChain) public view returns(bytes32){
        return users[user].maps.hashes[bridgeInNonce][frmWormChain];
    }
    // get's the tokenBridge data struct , DeliveryHash => got from calling getTKNDelivHash()
    function getTKNBridgeIn(address user , bytes32 deliveryHash) public view returns(Structs.TokenBridge memory){
        return users[user].maps.tokenBridgeIns[deliveryHash];
    }
    // in == true
    //out  == false
    //Nonce => Index of user's eth bridgeIn or Out 
    function getEthBridge(address user , uint256 Nonce, uint16 LzChain, bool inOrOut) public view returns(Structs.EthBridge memory){
        if(!inOrOut){
            return users[user].maps.ethBridgesOut[Nonce][LzChain];
        } else return users[user].maps.ethBridgesIn[Nonce][LzChain];
    }
    
    // eth reciever
    function _nonblockingLzReceive(
        uint16 frmCh,
        bytes memory,
        uint64 ,
        bytes memory payload
    ) internal override{
        //uint n = users[msg.sender].data.bridgeIn;
        (address to , uint amount ) = abi.decode(payload,(address , uint256));
        
        Structs.EthBridge memory data = Structs.EthBridge({
            _lzSrcCh: frmCh,
            _lzDstChId:lzEndpoint.getChainId(),
            amount: amount,
            dstReciver:to,
            timeStamp: block.timestamp,
            delivered: true
        });

        Structs.LatestBridge storage bridge = LatestBridges[tBridgeIndex];
        bridge.isEth = true;
        bridge.ethbridge = data;
        users[to].maps.ethBridgesIn[users[to].data.ethBridgeIn][frmCh] = data;
        users[to].data.ethBridgeIn +=1;
        tBridgeIndex += 1;
    }

    // erc20 reciever
    function receivePayloadAndTokens(
        bytes memory payload,
        Structs.TokenReceived[] memory receivedTokens,
        bytes32 srcA, // sourceAddress
        uint16 ch,
        bytes32 dh,// deliveryHash
        bytes[] memory additionalVaas
    ) internal override onlyWormholeRelayer{
        
        super.receivePayloadAndTokens(payload,receivedTokens, srcA, ch, dh, additionalVaas);
        (address to ) = abi.decode(payload,(address));
        Structs.TokenBridge memory data = Structs.TokenBridge({
            _wormSrcCh: ch,
            _wormDstChId: wormhole.chainId(),
            token:receivedTokens[0].tokenAddress,
            amount:receivedTokens[0].amount,
            dstReciver:to,
            timeStamp: block.timestamp,
            delivered:true
        });
        Structs.LatestBridge storage bridge__ = LatestBridges[tBridgeIndex];
        bridge__.isEth = true;
        bridge__.tokenbridge = data;
        bridge__.additionalVaas = additionalVaas;
        tBridgeIndex += 1;
        users[to].maps.tokenBridgeIns[dh] = data;
        users[to].maps.hashes[users[to].data.tokenBridgeIn][ch] = dh;
        users[to].data.tokenBridgeIn +=1;
    }

    //only grayzone can set the address to which they recieve profit sharing 
    function setGrayzoneAddr(address addr, uint8 num) public {
        require(msg.sender == grayzone && num < 11);
        grayshare = num;
        grayzone = addr;
    }

    // get total cost in ether fee to send with bridge function for erc 20 bridges => uses wormhole
    function getErc20Cost(uint16 wormholeId,uint256 gasUnits) public view returns(uint256){
        (uint cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            wormholeId,
            0,
            gasUnits
        );
        return (cost + states.bridgeFeeEther + wormhole.messageFee());
    }

    // get total cost in ether fee + amount eth to send with bridge function for native Eth bridges => uses lz0
    function getEthCost(
        uint16 _dstLzId,
        bool _useZro,
        uint256 amount,
        address sendTo,
        uint256 gasUnits
    ) public view returns(uint256 cost){
        (uint256 a , )=_ethTotalCost(_dstLzId, _useZro, amount, sendTo, gasUnits);
        cost = a + states.bridgeFeeEther;
    }

    // bridges Erc20 
    /*
    IMPORTANT => this uses wormhole ids for chainsids , and dev must put limits to client app for only supported tokens 
    */
    function bridgeErc20(
        Inputs.ERC20INPUT memory params // check library Inputs for the data structure
    ) public payable returns(uint64 z){
        uint256 amount = params.amt;
        if((wormEndpoints[params.targetChain] == address(0) && amount == 0 && params.token == address(0))||
            (msg.value < getErc20Cost(params.targetChain,params.dstGas))
        ){
            revert Structs.WrongFeeOrParams();
        }
        
        uint256 fee_= states.percentFee ; 
        bool x = IERC20(params.token).transferFrom(msg.sender, address(this), amount);
        if(!x){revert("");}
        if(states.bridgeFeeEther>0){_processPartner(states.bridgeFeeEther);}
        if(fee_>0){
            amount = params.amt - (params.amt * fee_/1000);
            fee[params.token] += params.amt * fee_/1000;
        }
        bytes memory payload = abi.encode(params.recipient);
        
        z = sendTokenWithPayloadToEvm(
            params.targetChain,
            wormEndpoints[params.targetChain], // address (on targetChain) to send token and payload to
            payload,
            0,
            params.dstGas, // gas units
            params.token, // address of IERC20 token contract
            amount, // amount
            wormhole.chainId(), // refund to sending chain
            msg.sender // refund to sender 
        );
        
        baseFee += (states.bridgeFeeEther) - (states.bridgeFeeEther * (grayshare / 100));

        //refund user incase of failed delivery attempt to relayer
        if(z == uint64(0)){
            IERC20(params.token).transfer(msg.sender, amount);
        } else {
            Structs.TokenBridge memory data = Structs.TokenBridge({
                _wormSrcCh: wormhole.chainId(),
                _wormDstChId: params.targetChain,
                token:params.token,
                amount:amount,
                dstReciver:params.recipient,
                timeStamp: block.timestamp,
                delivered:true
            });

            users[msg.sender].maps.tokenBridgeOuts[users[msg.sender].data.tokenBridgeOut][params.targetChain] = data;
            users[msg.sender].data.points += states.pointPerTx;
            states.totalPoints += states.pointPerTx ;
            users[msg.sender].data.tokenBridgeOut += 1;
            users[msg.sender].maps.outVolToken[params.token][params.targetChain] += amount;
            _processRef(msg.sender,params.referal);
        }
    }

    function bridgeEth(
        Inputs.ETHINPUT memory params
    ) public payable{
        uint256 amount = params.amt;
        if((amount ==0 && params.to == address(0))||( msg.value < getEthCost(params.toChainId, params.useZro, amount, params.to, params.dstGas))){
            revert Structs.WrongFeeOrParams();
        }
        uint256 f = states.bridgeFeeEther;
        uint256 fee_= states.percentFee; 
        if(f>0){(f,) = _processPartner(f);}
        if(fee_>0){
            amount = params.amt - (params.amt * fee_/1000);
        }
        bool z =_bridgeEth(params.toChainId, params.to, amount, params.dstGas, params.useZro, params.zroPAddr);
        if(!z){
            revert("");
        }
        fee[address(0)] += params.amt * fee_/1000;
        baseFee += f ;
        Structs.EthBridge memory data = Structs.EthBridge({
            _lzSrcCh: lzEndpoint.getChainId(),
            _lzDstChId:params.toChainId,
            amount: amount,
            dstReciver:params.to,
            timeStamp: block.timestamp,
            delivered: true
        });
        users[msg.sender].data.points += states.pointPerTx;
        states.totalPoints+=states.pointPerTx;
        users[msg.sender].maps.ethBridgesOut[users[msg.sender].data.ethBridgeOut][params.toChainId] = data;
        users[msg.sender].data.ethBridgeOut +=1;
        users[msg.sender].maps.outVolEth[params.toChainId] += amount;
        _processRef(msg.sender,params.referal);
    }


    ///processes
    // internal process function to handle partner shares 
    function _processPartner(uint256 f) internal returns(uint256 , uint256){
        uint256 rf = f * uint256(grayshare) / 100;
        payable(grayzone).transfer(rf);
        return(f - rf , rf);
    }

    function _processRef (address refered , address ref) internal {
        if(((users[refered].data.ethBridgeIn==0 && users[refered].data.ethBridgeOut == 0)||(users[refered].data.tokenBridgeIn==0 && users[refered].data.tokenBridgeOut == 0)) && !users[refered].referalData.refered){
            users[refered].referalData.refered = true;
            users[refered].referalData.referer = ref;
            users[ref].data.totalRef +=1; 
        }
        if(users[refered].referalData.referer !=address(0)){
            users[users[refered].referalData.referer].data.points += states.pointPerTx;    
        }
    }

    // fee withdrawal functions

    function withdrawAccruedFee(address token , uint256 amount) public onlyOwner{
        require(fee[token] >=amount);
            fee[token] -= amount;
            IERC20(token).transfer(msg.sender,amount);
    }

    function withdrawAccruedFeeEth(uint256 amount) public onlyOwner{
        require(fee[address(0)] >=amount);
        fee[address(0)] -= amount;
        payable(msg.sender).transfer(amount);
    }
    // directly sent ether is considered to fee pool
    
    receive() external payable {
        fee[address(0)] += msg.value;
    }
} 