const { ChainIds } = require('@airswap/utils')

module.exports = {
  [ChainIds.MAINNET]: {
    protocolFee: 5,
    protocolFeeLight: 5,
    bonusScale: 10,
    bonusMax: 100,
  },
  [ChainIds.DEVNET]: {
    protocolFee: 0,
    protocolFeeLight: 0,
    bonusScale: 10,
    bonusMax: 100,
  },
}
