//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.20;

library Structs {

    error WrongFeeOrParams();

    struct EthBridge{
        uint16 _lzSrcCh;// ins
        uint16 _lzDstChId; // outs
        uint256 amount;
        address dstReciver;
        uint256 timeStamp;
        bool delivered;
    }

    struct TokenBridge{
        uint16 _wormSrcCh;// bridge ins
        uint16 _wormDstChId; // bridge outs
        address token;
        uint256 amount;
        address dstReciver;
        uint256 timeStamp;
        bool delivered;
    }

    struct LatestBridge{
        bool isEth; // if isEth == true , then the bridge ethbridge data will be available , if false then tokenBridge
        EthBridge ethbridge; // eth bridge data = destructure with ethBridge struct, is blank data if a token transfer
        TokenBridge tokenbridge;
        bytes[] additionalVaas; // if it is token bridge this data is available 
    } 

    struct UserData{
        uint256 ethBridgeOut; // eth bridge OUT nonces/indices
        uint256 ethBridgeIn; // ""  ""      IN         "" ""
        uint256 tokenBridgeOut; // Token Bridge OUT     "" ""
        uint256 tokenBridgeIn; // token Bridge IN       "" ""
        uint256 totalRef;
        uint256 points;
    }

    struct Referals{
        bool refered;
        address referer;
    }

    struct User{
        UserData data;
        UserMaps maps;
        Referals referalData;
    }

    struct UserMaps{
        mapping(uint16=> uint256) outVolEth;
        mapping(address=> mapping(uint16=> uint256)) outVolToken;
        //wormhole maps
        mapping(bytes32=>TokenBridge) tokenBridgeIns;
        mapping(uint256 => mapping(uint16=> TokenBridge)) tokenBridgeOuts;
        mapping(uint256=>mapping(uint16 =>bytes32)) hashes;
        //lzMaps
        mapping(uint256=>mapping(uint16 =>EthBridge)) ethBridgesOut;
        mapping(uint256=>mapping(uint16 =>EthBridge)) ethBridgesIn;
    }

    struct BridgeData{
        uint256 pointPerTx;
        uint256 totalPoints;
        bool isActive;
        uint256 bridgeFeeEther;
        uint256 percentFee;
    }
    // misc
    struct TokenReceived {
        bytes32 tokenHomeAddress;
        uint16 tokenHomeChain;
        address tokenAddress; // wrapped address if tokenHomeChain !== this chain, else tokenHomeAddress (in evm address format)
        uint256 amount;
        uint256 amountNormalized; // if decimals > 8, normalized to 8 decimal places
    }
}

library Inputs {
    
    // this struct is the input param of function bridgeErc20()

    struct ERC20INPUT {
        uint16 targetChain;
        address recipient;
        uint256 amt;
        address token;
        uint256 dstGas;
        address referal;
    }
    // same as the above but for the eth bridge function
    struct ETHINPUT{
        uint16 toChainId; 
        address to; 
        uint256 amt;
        uint256 dstGas;
        bool useZro;
        address zroPAddr;
        address referal;
    }
}