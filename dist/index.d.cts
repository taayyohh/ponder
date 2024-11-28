declare const ponderfactoryAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [{
        readonly name: "_feeToSetter";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "INIT_CODE_PAIR_HASH";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "allPairs";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "allPairsLength";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "createPair";
    readonly inputs: readonly [{
        readonly name: "tokenA";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "tokenB";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "pair";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "feeTo";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "feeToSetter";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getPair";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "migrator";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "setFeeTo";
    readonly inputs: readonly [{
        readonly name: "_feeTo";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setFeeToSetter";
    readonly inputs: readonly [{
        readonly name: "_feeToSetter";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMigrator";
    readonly inputs: readonly [{
        readonly name: "_migrator";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "PairCreated";
    readonly inputs: readonly [{
        readonly name: "token0";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "token1";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pair";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "Forbidden";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "IdenticalAddresses";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "PairExists";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ZeroAddress";
    readonly inputs: readonly [];
}];

declare const ponderpairAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "DOMAIN_SEPARATOR";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINIMUM_LIQUIDITY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "PERMIT_TYPEHASH";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "allowance";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "balanceOf";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "burn";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "amount0";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "decimals";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "factory";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getKLast";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getReserves";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "_reserve0";
        readonly type: "uint112";
        readonly internalType: "uint112";
    }, {
        readonly name: "_reserve1";
        readonly type: "uint112";
        readonly internalType: "uint112";
    }, {
        readonly name: "_blockTimestampLast";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_token0";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_token1";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "kLast";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "mint";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "nonces";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "permit";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "v";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }, {
        readonly name: "r";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "s";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "price0CumulativeLast";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "price1CumulativeLast";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "skim";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swap";
    readonly inputs: readonly [{
        readonly name: "amount0Out";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1Out";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "symbol";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "sync";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "token0";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "token1";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfer";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferFrom";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Approval";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Burn";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount0";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Mint";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount0";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Swap";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount0In";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1In";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount0Out";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount1Out";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Sync";
    readonly inputs: readonly [{
        readonly name: "reserve0";
        readonly type: "uint112";
        readonly indexed: false;
        readonly internalType: "uint112";
    }, {
        readonly name: "reserve1";
        readonly type: "uint112";
        readonly indexed: false;
        readonly internalType: "uint112";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Transfer";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "InsufficientInputAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientLiquidity";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientOutputAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidTo";
    readonly inputs: readonly [];
}];

declare const ponderrouterAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [{
        readonly name: "_factory";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_WETH";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "receive";
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "WETH";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "addLiquidity";
    readonly inputs: readonly [{
        readonly name: "tokenA";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "tokenB";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amountADesired";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountBDesired";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountAMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountBMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountA";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountB";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "addLiquidityETH";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amountTokenDesired";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountTokenMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountETHMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountToken";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountETH";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "factory";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract IPonderFactory";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAmountIn";
    readonly inputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "getAmountOut";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "getAmountsIn";
    readonly inputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAmountsOut";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getReserves";
    readonly inputs: readonly [{
        readonly name: "tokenA";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "tokenB";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "reserveA";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveB";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "quote";
    readonly inputs: readonly [{
        readonly name: "amountA";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveA";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "reserveB";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountB";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "removeLiquidity";
    readonly inputs: readonly [{
        readonly name: "tokenA";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "tokenB";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountAMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountBMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountA";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountB";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "removeLiquidityETH";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountTokenMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountETHMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountToken";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountETH";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "removeLiquidityETHSupportingFeeOnTransferTokens";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "liquidity";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountTokenMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountETHMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amountETH";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "sortTokens";
    readonly inputs: readonly [{
        readonly name: "tokenA";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "tokenB";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "token0";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "token1";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "swapETHForExactTokens";
    readonly inputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "swapExactETHForTokens";
    readonly inputs: readonly [{
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "swapExactETHForTokensSupportingFeeOnTransferTokens";
    readonly inputs: readonly [{
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "swapExactTokensForETH";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swapExactTokensForETHSupportingFeeOnTransferTokens";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swapExactTokensForTokens";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swapExactTokensForTokensSupportingFeeOnTransferTokens";
    readonly inputs: readonly [{
        readonly name: "amountIn";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountOutMin";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swapTokensForExactETH";
    readonly inputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountInMax";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "swapTokensForExactTokens";
    readonly inputs: readonly [{
        readonly name: "amountOut";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "amountInMax";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "path";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "amounts";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "error";
    readonly name: "ExcessiveInputAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExpiredDeadline";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "IdenticalAddresses";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientAAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientBAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientInputAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientLiquidity";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientOutputAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidPath";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ZeroAddress";
    readonly inputs: readonly [];
}];

declare const pondertokenAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "DOMAIN_SEPARATOR";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAXIMUM_SUPPLY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTING_END";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "PERMIT_TYPEHASH";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "acceptOwnership";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "allowance";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "balanceOf";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "decimals";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deploymentTime";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "mint";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "minter";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "nonces";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "owner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pendingOwner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "permit";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "deadline";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "v";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }, {
        readonly name: "r";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "s";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMinter";
    readonly inputs: readonly [{
        readonly name: "_minter";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "symbol";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfer";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferFrom";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferOwnership";
    readonly inputs: readonly [{
        readonly name: "newOwner";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Approval";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MinterUpdated";
    readonly inputs: readonly [{
        readonly name: "previousMinter";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newMinter";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferStarted";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferred";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Transfer";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "Forbidden";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MintingDisabled";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SupplyExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ZeroAddress";
    readonly inputs: readonly [];
}];

declare const pondermasterchefAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [{
        readonly name: "_ponder";
        readonly type: "address";
        readonly internalType: "contract PonderToken";
    }, {
        readonly name: "_factory";
        readonly type: "address";
        readonly internalType: "contract IPonderFactory";
    }, {
        readonly name: "_treasury";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_ponderPerSecond";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_startTime";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "add";
    readonly inputs: readonly [{
        readonly name: "_allocPoint";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_lpToken";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_depositFeeBP";
        readonly type: "uint16";
        readonly internalType: "uint16";
    }, {
        readonly name: "_boostMultiplier";
        readonly type: "uint16";
        readonly internalType: "uint16";
    }, {
        readonly name: "_withUpdate";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "boostStake";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "boostUnstake";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "deposit";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "emergencyWithdraw";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "factory";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract IPonderFactory";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "massUpdatePools";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "owner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pendingOwner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pendingPonder";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_user";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "pending";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "ponder";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract PonderToken";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "ponderPerSecond";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "poolInfo";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "lpToken";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "allocPoint";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "lastRewardTime";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "accPonderPerShare";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalStaked";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "depositFeeBP";
        readonly type: "uint16";
        readonly internalType: "uint16";
    }, {
        readonly name: "boostMultiplier";
        readonly type: "uint16";
        readonly internalType: "uint16";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "poolLength";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "set";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_allocPoint";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_withUpdate";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTreasury";
    readonly inputs: readonly [{
        readonly name: "_treasury";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "startTime";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalAllocPoint";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "treasury";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "updatePool";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "userInfo";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "rewardDebt";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "ponderStaked";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "withdraw";
    readonly inputs: readonly [{
        readonly name: "_pid";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "BoostStake";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "BoostUnstake";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Deposit";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "EmergencyWithdraw";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PoolAdded";
    readonly inputs: readonly [{
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "lpToken";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "allocPoint";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PoolUpdated";
    readonly inputs: readonly [{
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "allocPoint";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TreasuryUpdated";
    readonly inputs: readonly [{
        readonly name: "oldTreasury";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newTreasury";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Withdraw";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "pid";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "Forbidden";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidPair";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidPool";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ZeroAmount";
    readonly inputs: readonly [];
}];

export { ponderfactoryAbi, pondermasterchefAbi, ponderpairAbi, ponderrouterAbi, pondertokenAbi };
