/* eslint-disable no-console */
const fs = require('fs')
const prettier = require('prettier')
const Confirm = require('prompt-confirm')
const { ethers, run } = require('hardhat')
const { getReceiptUrl } = require('@airswap/utils')
const { displayDeployerInfo } = require('../../../scripts/deployer-info')
const deploys = require('../deploys.js')

async function main() {
  await run('compile')
  const [deployer] = await ethers.getSigners()
  const chainId = await deployer.getChainId()
  await displayDeployerInfo(deployer)

  const prompt = new Confirm('Proceed to deploy?')
  if (await prompt.run()) {
    const prettierConfig = await prettier.resolveConfig('../deploys.js')
    const factory = await ethers.getContractFactory('ERC20')
    const contract = await factory.deploy('Mock AST', 'AST')
    console.log(
      'Deploying...',
      getReceiptUrl(chainId, contract.deployTransaction.hash)
    )
    await contract.deployed()

    deploys[chainId] = contract.address
    fs.writeFileSync(
      './deploys.js',
      prettier.format(
        `module.exports = ${JSON.stringify(deploys, null, '\t')}`,
        { ...prettierConfig, parser: 'babel' }
      )
    )

    block = (await contract.deployTransaction.wait()).blockNumber
    console.log(`Deployed: ${deploys[chainId]} @ ${block}`)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
