export const ponderpriceoracleAbi = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_factory",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_ponderKubPair",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "MIN_UPDATE_INTERVAL",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PERIOD",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "consult",
    "inputs": [
      {
        "name": "pair",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "tokenIn",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amountIn",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "periodInSeconds",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [
      {
        "name": "amountOut",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "factory",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getLatestPrice",
    "inputs": [
      {
        "name": "pair",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "price0Average",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "price1Average",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "timestamp",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getPonderKubPrice",
    "inputs": [
      {
        "name": "periodInSeconds",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "lastUpdateTime",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "observationLength",
    "inputs": [
      {
        "name": "pair",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "observations",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "timestamp",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "price0Cumulative",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "price1Cumulative",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "price0Average",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "price1Average",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "ponderKubPair",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "update",
    "inputs": [
      {
        "name": "pair",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "PriceUpdated",
    "inputs": [
      {
        "name": "pair",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "price0Average",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "price1Average",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "timestamp",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "InsufficientHistory",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidPair",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidPeriod",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidToken",
    "inputs": []
  },
  {
    "type": "error",
    "name": "StalePrice",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UpdateTooFrequent",
    "inputs": []
  }
] as const;
