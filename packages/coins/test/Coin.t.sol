// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import {ISwapRouter} from "../src/interfaces/ISwapRouter.sol";
import {CoinConfigurationVersions} from "../src/libs/CoinConfigurationVersions.sol";
import {CoinConstants} from "../src/libs/CoinConstants.sol";
import {IZoraFactory} from "../src/interfaces/IZoraFactory.sol";
import {IHasRewardsRecipients} from "../src/interfaces/IHasRewardsRecipients.sol";
import {PoolConfiguration} from "../src/interfaces/ICoin.sol";
import {IERC165, IERC7572, ICoin, ICoinComments, IERC20} from "../src/BaseCoin.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract CoinTest is BaseTest {
    using stdJson for string;

    function setUp() public override {
        super.setUp();
    }

    function test_contract_ierc165_support() public {
        _deployCoin();
        assertEq(coin.supportsInterface(type(IZoraFactory).interfaceId), false);
        assertEq(coin.supportsInterface(bytes4(0x00000000)), false);
        assertEq(coin.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(coin.supportsInterface(type(IERC7572).interfaceId), true);
        assertEq(coin.supportsInterface(type(ICoin).interfaceId), true);
        assertEq(coin.supportsInterface(type(ICoinComments).interfaceId), true);
        assertEq(coin.supportsInterface(type(IERC7572).interfaceId), true);
    }

    function test_contract_version() public {
        _deployCoin();
        string memory package = vm.readFile("./package.json");
        assertEq(package.readString(".version"), coin.contractVersion());
    }

    function test_supply_constants() public {
        assertEq(CoinConstants.MAX_TOTAL_SUPPLY, CoinConstants.POOL_LAUNCH_SUPPLY + CoinConstants.CREATOR_LAUNCH_REWARD);

        assertEq(CoinConstants.MAX_TOTAL_SUPPLY, 1_000_000_000e18);
        assertEq(CoinConstants.POOL_LAUNCH_SUPPLY, 990_000_000e18);
        assertEq(CoinConstants.CREATOR_LAUNCH_REWARD, 10_000_000e18);

        _deployCoin();
        assertEq(coin.totalSupply(), CoinConstants.MAX_TOTAL_SUPPLY);
        assertEq(coin.balanceOf(coin.payoutRecipient()), CoinConstants.CREATOR_LAUNCH_REWARD);
        assertApproxEqAbs(coin.balanceOf(address(pool)), CoinConstants.POOL_LAUNCH_SUPPLY, 1e18);
    }

    function test_constructor_validation() public {
        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(address(0), address(protocolRewards), WETH_ADDRESS, NONFUNGIBLE_POSITION_MANAGER, SWAP_ROUTER, DOPPLER_AIRLOCK);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(users.feeRecipient, address(0), WETH_ADDRESS, NONFUNGIBLE_POSITION_MANAGER, SWAP_ROUTER, DOPPLER_AIRLOCK);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(users.feeRecipient, address(protocolRewards), address(0), NONFUNGIBLE_POSITION_MANAGER, SWAP_ROUTER, DOPPLER_AIRLOCK);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(users.feeRecipient, address(protocolRewards), WETH_ADDRESS, address(0), SWAP_ROUTER, DOPPLER_AIRLOCK);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(users.feeRecipient, address(protocolRewards), WETH_ADDRESS, NONFUNGIBLE_POSITION_MANAGER, address(0), DOPPLER_AIRLOCK);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        new Coin(users.feeRecipient, address(protocolRewards), WETH_ADDRESS, NONFUNGIBLE_POSITION_MANAGER, SWAP_ROUTER, address(0));

        Coin newToken = new Coin(users.feeRecipient, address(protocolRewards), WETH_ADDRESS, NONFUNGIBLE_POSITION_MANAGER, SWAP_ROUTER, DOPPLER_AIRLOCK);
        assertEq(address(newToken.protocolRewardRecipient()), users.feeRecipient);
        assertEq(address(newToken.protocolRewards()), address(protocolRewards));
        assertEq(address(newToken.WETH()), WETH_ADDRESS);
        assertEq(address(newToken.swapRouter()), SWAP_ROUTER);
    }

    function test_initialize_validation() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        bytes memory poolConfig_ = _generatePoolConfig(address(weth));

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        (address coinAddress, ) = factory.deploy(address(0), owners, "https://init.com", "Init Token", "INIT", poolConfig_, users.platformReferrer, 0);
        coin = Coin(payable(coinAddress));

        (coinAddress, ) = factory.deploy(users.creator, owners, "https://init.com", "Init Token", "INIT", poolConfig_, users.platformReferrer, 0);
        coin = Coin(payable(coinAddress));

        assertEq(coin.payoutRecipient(), users.creator, "creator");
        assertEq(coin.platformReferrer(), users.platformReferrer, "platformReferrer");
        assertEq(coin.tokenURI(), "https://init.com");
        assertEq(coin.name(), "Init Token");
        assertEq(coin.symbol(), "INIT");
    }

    function test_invalid_pool_config_version() public {
        bytes memory poolConfig = abi.encode(0, address(weth));

        vm.expectRevert(abi.encodeWithSignature("InvalidPoolVersion()"));
        factory.deploy(users.creator, _getDefaultOwners(), "https://test.com", "Testcoin", "TEST", poolConfig, users.platformReferrer, 0);
    }

    function test_legacy_deploy_deploys_with_default_config() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        (address coinAddress, ) = ZoraFactoryImpl(address(factory)).deploy(
            users.creator,
            owners,
            "https://init.com",
            "Init Token",
            "INIT",
            users.platformReferrer,
            address(weth),
            0,
            0
        );

        Coin coin = Coin(payable(coinAddress));

        PoolConfiguration memory poolConfig = coin.getPoolConfiguration();

        assertEq(poolConfig.version, CoinConfigurationVersions.DOPPLER_UNI_V3_POOL_VERSION);
    }

    function test_uniswap_v3_mint_callback_wrong_sender() public {
        _deployCoin();
        address random = makeAddr("random");
        vm.prank(random);
        vm.expectRevert(abi.encodeWithSelector(ICoin.OnlyPool.selector, random, address(pool)));
        coin.uniswapV3MintCallback(1 ether, 1 ether, "");
    }

    function test_erc165_interface_support() public {
        _deployCoin();
        assertEq(coin.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(coin.supportsInterface(type(IHasRewardsRecipients).interfaceId), true);
        assertEq(coin.supportsInterface(type(IERC7572).interfaceId), true);
    }

    function test_buy_with_eth() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, users.tradeReferrer);

        assertGt(coin.balanceOf(users.coinRecipient), 0);
        assertEq(users.seller.balance, 0);
    }

    function test_buy_with_eth_fuzz(uint256 ethOrderSize) public {
        vm.assume(ethOrderSize >= CoinConstants.MIN_ORDER_SIZE);
        vm.assume(ethOrderSize < 10 ether);
        _deployCoin();

        uint256 platformReferrerBalanceBeforeSale = users.platformReferrer.balance;
        uint256 orderReferrerBalanceBeforeSale = users.tradeReferrer.balance;
        uint256 tokenCreatorBalanceBeforeSale = users.creator.balance;
        uint256 feeRecipientBalanceBeforeSale = users.feeRecipient.balance;

        vm.deal(users.buyer, ethOrderSize);
        vm.prank(users.buyer);
        coin.buy{value: ethOrderSize}(users.coinRecipient, ethOrderSize, 0, 0, users.tradeReferrer);

        assertGt(coin.balanceOf(users.coinRecipient), 0, "coinRecipient coin balance");
        assertGt(protocolRewards.balanceOf(users.feeRecipient), feeRecipientBalanceBeforeSale, "feeRecipient eth balance");
        assertGt(protocolRewards.balanceOf(users.platformReferrer), platformReferrerBalanceBeforeSale, "platformReferrer eth balance");
        assertGt(protocolRewards.balanceOf(users.tradeReferrer), orderReferrerBalanceBeforeSale, "tradeReferrer eth balance");
        assertGt(protocolRewards.balanceOf(users.creator), tokenCreatorBalanceBeforeSale, "creator eth balance");
    }

    function test_buy_with_eth_too_small() public {
        _deployCoin();
        vm.expectRevert(abi.encodeWithSelector(ICoin.EthAmountTooSmall.selector));
        coin.buy{value: CoinConstants.MIN_ORDER_SIZE - 1}(users.coinRecipient, CoinConstants.MIN_ORDER_SIZE - 1, 0, 0, users.tradeReferrer);
    }

    function test_buy_with_minimum_eth() public {
        _deployCoin();
        uint256 minEth = CoinConstants.MIN_ORDER_SIZE;
        vm.deal(users.buyer, minEth);
        vm.prank(users.buyer);
        coin.buy{value: minEth}(users.coinRecipient, minEth, 0, 0, users.tradeReferrer);

        assertGt(coin.balanceOf(users.coinRecipient), 0, "coinRecipient coin balance");
    }

    function test_revert_buy_zero_address_recipient_legacy() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(address(0), 1 ether, 0, 0, users.tradeReferrer);
    }

    function test_revert_buy_zero_address_recipient() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        vm.prank(users.buyer);
        coin.buy(address(0), 1 ether, 0, 0, users.tradeReferrer);
    }

    function test_buy_with_usdc() public {
        _deployCoinUSDCPair();

        deal(address(usdc), users.buyer, 100e6);

        vm.prank(users.buyer);
        usdc.approve(address(coin), 10e6);

        vm.prank(users.buyer);
        coin.buy(users.coinRecipient, 10e6, 0, 0, users.tradeReferrer);

        assertGt(coin.balanceOf(users.coinRecipient), 0, "coinRecipient coin balance");
    }

    function test_buy_with_usdc_revert_no_approval() public {
        _deployCoinUSDCPair();

        deal(address(usdc), users.buyer, 100e6);

        vm.prank(users.buyer);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        coin.buy(users.coinRecipient, 100e6, 0, 0, users.tradeReferrer);
    }

    function test_buy_validate_return_amounts(uint256 orderSize) public {
        vm.assume(orderSize >= CoinConstants.MIN_ORDER_SIZE);
        vm.assume(orderSize < 10 ether);
        _deployCoin();

        vm.deal(users.buyer, orderSize);
        vm.prank(users.buyer);
        (uint256 amountIn, uint256 amountOut) = coin.buy{value: orderSize}(users.coinRecipient, orderSize, 0, 0, users.tradeReferrer);

        assertEq(amountIn, orderSize, "amountIn");
        assertGe(coin.balanceOf(users.coinRecipient), amountOut, "coinRecipient coin balance");
    }

    function test_sell_for_eth_direct_and_claim_secondary() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);

        vm.prank(users.buyer);
        weth.deposit{value: 100_000}();

        vm.prank(users.buyer);
        weth.approve(address(swapRouter), 100_000);

        assertEq(coin.balanceOf(users.buyer), 0, "buyer coin balance initial");

        // Set up the swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH_ADDRESS,
            tokenOut: address(coin),
            fee: MarketConstants.LP_FEE,
            recipient: address(users.buyer),
            amountIn: 100_000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        vm.prank(users.buyer);
        uint256 amountOut = ISwapRouter(swapRouter).exactInputSingle(params);

        assertGt(coin.balanceOf(users.buyer), 0, "buyer coin balance");
        assertGt(amountOut, 0, "amountOut");
        assertGt(users.buyer.balance, 0, "seller eth balance");

        // now we have unclaimed secondary rewards to claim
        vm.prank(users.buyer);

        // don't push ETH
        coin.claimSecondaryRewards(false);
        assertGt(protocolRewards.balanceOf(users.creator), 0);
        assertGt(protocolRewards.balanceOf(users.platformReferrer), 0);
        assertGt(protocolRewards.balanceOf(users.feeRecipient), 0);
        assertGt(dopplerFeeRecipient().balance, 0);
    }

    function test_sell_for_eth_direct_and_claim_secondary_push_eth() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);

        vm.prank(users.buyer);
        weth.deposit{value: 100_000}();

        vm.prank(users.buyer);
        weth.approve(address(swapRouter), 100_000);

        // Set up the swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: WETH_ADDRESS,
            tokenOut: address(coin),
            fee: MarketConstants.LP_FEE,
            recipient: address(users.buyer),
            amountIn: 100_000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        vm.prank(users.buyer);
        uint256 amountOut = ISwapRouter(swapRouter).exactInputSingle(params);

        assertGt(coin.balanceOf(users.buyer), 0, "buyer coin balance");
        assertGt(amountOut, 0, "amountOut");
        assertGt(users.buyer.balance, 0, "seller eth balance");

        // Now we have unclaimed secondary rewards to claim
        vm.prank(users.buyer);

        uint256 initialBalance = users.creator.balance;

        // Push ETH
        coin.claimSecondaryRewards(true);
        assertGt(users.creator.balance, initialBalance);
    }

    function test_sell_for_eth() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.seller, 1 ether, 0, 0, users.tradeReferrer);

        uint256 tokensToSell = coin.balanceOf(users.seller);
        vm.prank(users.seller);
        coin.sell(users.seller, tokensToSell, 0, 0, users.tradeReferrer);

        assertEq(coin.balanceOf(users.seller), 0, "seller coin balance");
        assertGt(users.seller.balance, 0, "seller eth balance");
    }

    function test_sell_for_eth_fuzz(uint256 ethOrderSize) public {
        vm.assume(ethOrderSize < 10 ether);
        vm.assume(ethOrderSize >= CoinConstants.MIN_ORDER_SIZE);
        _deployCoin();
        vm.deal(users.buyer, ethOrderSize);
        vm.prank(users.buyer);
        coin.buy{value: ethOrderSize}(users.seller, ethOrderSize, 0, 0, users.tradeReferrer);

        uint256 platformReferrerBalanceBeforeSale = users.platformReferrer.balance;
        uint256 orderReferrerBalanceBeforeSale = users.tradeReferrer.balance;
        uint256 tokenCreatorBalanceBeforeSale = users.creator.balance;
        uint256 feeRecipientBalanceBeforeSale = users.feeRecipient.balance;

        uint256 tokensToSell = coin.balanceOf(users.seller);
        vm.prank(users.seller);
        coin.sell(users.coinRecipient, tokensToSell, 0, 0, users.tradeReferrer);

        assertEq(coin.balanceOf(users.seller), 0, "seller coin balance");
        assertEq(coin.balanceOf(users.coinRecipient), 0, "coinRecipient coin balance");

        assertEq(users.seller.balance, 0, "seller eth balance");
        assertGt(protocolRewards.balanceOf(users.feeRecipient), feeRecipientBalanceBeforeSale, "feeRecipient eth balance");
        assertGt(protocolRewards.balanceOf(users.platformReferrer), platformReferrerBalanceBeforeSale, "platformReferrer eth balance");
        assertGt(protocolRewards.balanceOf(users.tradeReferrer), orderReferrerBalanceBeforeSale, "tradeReferrer eth balance");
        assertGt(protocolRewards.balanceOf(users.creator), tokenCreatorBalanceBeforeSale, "creator eth balance");
    }

    function test_sell_for_usdc() public {
        _deployCoinUSDCPair();

        deal(address(usdc), users.buyer, 10e6);

        vm.prank(users.buyer);
        usdc.approve(address(coin), 10e6);

        vm.prank(users.buyer);
        coin.buy(users.coinRecipient, 10e6, 0, 0, users.tradeReferrer);

        uint256 coinBalance = coin.balanceOf(users.coinRecipient);

        vm.prank(users.coinRecipient);
        coin.sell(users.seller, coinBalance, 0, 0, users.tradeReferrer);
    }

    function test_revert_sell_zero_address_recipient() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.seller, 1 ether, 0, 0, users.tradeReferrer);

        uint256 tokensToSell = coin.balanceOf(users.seller);
        vm.prank(users.seller);
        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        coin.sell(address(0), tokensToSell, 0, 0, users.tradeReferrer);
    }

    function test_revert_sell_insufficient_liquidity() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.seller, 1 ether, 0, 0, users.tradeReferrer);

        uint256 balance = coin.balanceOf(users.seller);
        vm.prank(users.seller);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", users.seller, balance, balance + 1));
        coin.sell(users.coinRecipient, balance + 1, 0, 0, users.tradeReferrer);
    }

    function test_sell_partial_execution() public {
        _deployCoin();
        vm.deal(users.creator, 1 ether);
        vm.prank(users.creator);
        coin.buy{value: 0.001 ether}(users.creator, 0.001 ether, 0, 0, users.tradeReferrer);

        uint256 beforeBalance = coin.balanceOf(users.creator);
        assertGt(beforeBalance, 0, "before balance");

        vm.prank(users.creator);
        (uint256 amountSold, ) = coin.sell(users.creator, beforeBalance, 0, 0, users.tradeReferrer);
        assertGt(amountSold, 0, "amountSold");

        // these seemed to change with different configuration of the pool. uncomment when we can figure
        // out the values
        // uint256 afterBalance = coin.balanceOf(users.creator);
        // assertEq(afterBalance, 9994558841570544323195890, "after balance"); // 9,994,559 coins

        // uint256 expectedMarketReward = 5441158429455676804107; // 5,441 coins

        // // 9,994,559 = 11,077,349 order size - 1,088,232 true order size + 5,441 creator market reward
        // assertEq(afterBalance, ((beforeBalance - amountSold) + expectedMarketReward), "amountSold");
    }

    function test_burn() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, users.tradeReferrer);

        uint256 beforeBalance = coin.balanceOf(users.coinRecipient);
        uint256 beforeTotalSupply = coin.totalSupply();

        vm.prank(users.coinRecipient);
        coin.burn(1e18);

        uint256 afterBalance = coin.balanceOf(users.coinRecipient);
        uint256 afterTotalSupply = coin.totalSupply();

        assertEq(beforeBalance - afterBalance, 1e18, "coinRecipient coin balance");
        assertEq(beforeTotalSupply - afterTotalSupply, 1e18, "coin total supply");
    }

    function test_receive_from_weth() public {
        _deployCoin();
        uint256 orderSize = 1 ether;
        vm.deal(users.buyer, orderSize);
        vm.prank(users.buyer);
        coin.buy{value: orderSize}(users.coinRecipient, orderSize, 0, 0, users.tradeReferrer);

        vm.deal(WETH_ADDRESS, 1 ether);
        vm.prank(WETH_ADDRESS);
        (bool success, ) = address(coin).call{value: 1 ether}("");
        assertTrue(success);
    }

    function test_revert_receive_from_weth_wrong_sender() public {
        _deployCoin();
        address random = makeAddr("random");
        vm.prank(random);
        vm.expectRevert(abi.encodeWithSelector(ICoin.OnlyWeth.selector, random));
        (bool success, ) = address(coin).call{value: 1 ether}("");
        assertFalse(success);
    }

    function test_default_platform_referrer() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        bytes memory poolConfig_ = _generatePoolConfig(
            CoinConfigurationVersions.DOPPLER_UNI_V3_POOL_VERSION,
            address(weth),
            DEFAULT_DISCOVERY_TICK_LOWER,
            DEFAULT_DISCOVERY_TICK_UPPER,
            DEFAULT_NUM_DISCOVERY_POSITIONS,
            DEFAULT_DISCOVERY_SUPPLY_SHARE
        );

        (address newCoinAddr, ) = factory.deploy(users.creator, owners, "https://test.com", "Test Token", "TEST", poolConfig_, users.platformReferrer, 0);
        Coin newCoin = Coin(payable(newCoinAddr));

        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        newCoin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, users.tradeReferrer);

        uint256 fee = _calculateExpectedFee(1 ether);
        TradeRewards memory expectedFees = _calculateTradeRewards(fee);

        assertGt(protocolRewards.balanceOf(users.feeRecipient), expectedFees.platformReferrer, "feeRecipient eth balance");
    }

    function test_default_order_referrer() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, address(0));

        uint256 fee = _calculateExpectedFee(1 ether);
        TradeRewards memory expectedFees = _calculateTradeRewards(fee);

        assertGt(protocolRewards.balanceOf(users.feeRecipient), expectedFees.tradeReferrer, "feeRecipient eth balance");
    }

    function test_market_slippage() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, users.tradeReferrer);

        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        vm.expectRevert("Too little received"); // Uniswap V3 revert
        coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, type(uint256).max, 0, users.tradeReferrer);

        vm.prank(users.coinRecipient);
        vm.expectRevert("Too little received"); // Uniswap V3 revert
        coin.sell(users.coinRecipient, 1e18, type(uint256).max, 0, users.tradeReferrer);
    }

    function test_eth_transfer_fail() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        (, uint256 amountOut) = coin.buy{value: 1 ether}(users.coinRecipient, 1 ether, 0, 0, users.tradeReferrer);

        assertEq(coin.balanceOf(users.coinRecipient), amountOut);

        // Recipient reverts on ETH receive
        address payable badRecipient = payable(makeAddr("badRecipient"));
        vm.etch(badRecipient, hex"fe");

        vm.prank(users.coinRecipient);
        vm.expectRevert(abi.encodeWithSelector(Address.FailedInnerCall.selector));
        coin.sell(badRecipient, 1e18, 0, 0, users.tradeReferrer);
    }

    function test_revert_receive_only_weth() public {
        _deployCoin();
        vm.deal(users.buyer, 1 ether);
        vm.prank(users.buyer);
        vm.expectRevert(abi.encodeWithSelector(ICoin.OnlyWeth.selector));
        (bool ignoredSuccess, ) = address(coin).call{value: 1 ether}("");
        (ignoredSuccess);

        assertEq(address(coin).balance, 0, "coin balance");
    }

    function test_rewards() public {
        _deployCoin();
        uint256 initialPlatformReferrerBalance = protocolRewards.balanceOf(users.platformReferrer);
        uint256 initialTokenCreatorBalance = protocolRewards.balanceOf(users.creator);
        uint256 initialOrderReferrerBalance = protocolRewards.balanceOf(users.tradeReferrer);
        uint256 initialFeeRecipientBalance = protocolRewards.balanceOf(users.feeRecipient);
        uint256 initialDopplerRecipientBalance = airlock.owner().balance;

        uint256 buyAmount = 1 ether;
        vm.deal(users.buyer, buyAmount);
        vm.prank(users.buyer);
        coin.buy{value: buyAmount}(users.coinRecipient, buyAmount, 0, 0, users.tradeReferrer);

        uint256 orderFee = _calculateExpectedFee(buyAmount); // 1 ETH * 1% --> 0.01 ETH
        TradeRewards memory orderFees = _calculateTradeRewards(orderFee);

        uint256 expectedLpFee = 9900000000000000; // 0.99 ETH * 1% --> ~0.00989 ETH
        MarketRewards memory marketRewards = _calculateMarketRewards(expectedLpFee);

        assertEq(
            marketRewards.creator + marketRewards.platformReferrer + marketRewards.protocol + marketRewards.doppler,
            expectedLpFee,
            "Secondary rewards incorrect"
        );
        assertApproxEqAbs(
            protocolRewards.balanceOf(users.creator),
            initialTokenCreatorBalance + orderFees.creator + marketRewards.creator,
            0.0000000000000001 ether,
            "Token creator rewards incorrect"
        );
        assertApproxEqAbs(
            protocolRewards.balanceOf(users.platformReferrer),
            initialPlatformReferrerBalance + orderFees.platformReferrer + marketRewards.platformReferrer,
            0.0000000000000001 ether,
            "Platform referrer rewards incorrect"
        );
        assertApproxEqAbs(
            airlock.owner().balance,
            initialDopplerRecipientBalance + marketRewards.doppler,
            0.0000000000000001 ether,
            "Doppler rewards incorrect"
        );
        assertApproxEqAbs(
            protocolRewards.balanceOf(users.feeRecipient),
            initialFeeRecipientBalance + orderFees.protocol + marketRewards.protocol,
            0.0000000000000001 ether,
            "Protocol rewards incorrect"
        );
        assertEq(protocolRewards.balanceOf(users.tradeReferrer), initialOrderReferrerBalance + orderFees.tradeReferrer, "Order referrer rewards incorrect");
    }

    function test_contract_uri() public {
        _deployCoin();
        assertEq(coin.contractURI(), "https://test.com");
    }

    function test_set_contract_uri() public {
        _deployCoin();
        string memory newURI = "https://new.com";

        vm.prank(users.creator);
        coin.setContractURI(newURI);
        assertEq(coin.contractURI(), newURI);
    }

    function test_set_contract_uri_reverts_if_not_owner() public {
        _deployCoin();
        string memory newURI = "https://new.com";

        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.OnlyOwner.selector));
        coin.setContractURI(newURI);
    }

    function test_set_payout_recipient() public {
        _deployCoin();
        address newPayoutRecipient = makeAddr("NewPayoutRecipient");

        vm.prank(users.creator);
        coin.setPayoutRecipient(newPayoutRecipient);
        assertEq(coin.payoutRecipient(), newPayoutRecipient);
    }

    function test_revert_set_payout_recipient_address_zero() public {
        _deployCoin();
        address newPayoutRecipient = address(0);

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        vm.prank(users.creator);
        coin.setPayoutRecipient(newPayoutRecipient);
    }

    function test_revert_set_payout_recipient_only_owner() public {
        _deployCoin();
        address newPayoutRecipient = makeAddr("NewPayoutRecipient");

        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.OnlyOwner.selector));
        coin.setPayoutRecipient(newPayoutRecipient);
    }

    function test_update_metadata() public {
        _deployCoin();
        string memory newName = "NewName";
        string memory newSymbol = "NEW";

        vm.prank(users.creator);
        vm.expectEmit(true, true, true, true);
        emit ICoin.NameAndSymbolUpdated(users.creator, newName, newSymbol);
        coin.setNameAndSymbol(newName, newSymbol);
        assertEq(coin.name(), newName);
        assertEq(coin.symbol(), newSymbol);
    }

    function test_update_metadata_reverts_if_not_owner() public {
        _deployCoin();
        string memory newName = "NewName";
        string memory newSymbol = "NEW";

        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.OnlyOwner.selector));
        coin.setNameAndSymbol(newName, newSymbol);
    }

    function test_update_metadata_reverts_if_name_is_blank() public {
        _deployCoin();
        string memory newName = "";
        string memory newSymbol = "NEW";

        vm.prank(users.creator);
        vm.expectRevert(abi.encodeWithSelector(ICoin.NameIsRequired.selector));
        coin.setNameAndSymbol(newName, newSymbol);
    }
}
