// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IWZETA.sol";

contract InvoiceManager is zContract, OnlySystem {
    SystemContract public systemContract;

    IPyth pyth;
    
    mapping(address => bytes32) public zrc20ToPythId;

	struct Invoice {
        uint id;
        address creator;
        string description;
        uint256 priceUSD;
        bool paid;
    }

    uint public nextInvoiceId;

    address usdcEthAddress;

	// Mapping from creator address to an array of invoice IDs
    mapping(address => uint[]) public invoicesByCreator;

    // Mapping from index to Invoice
    mapping(uint => Invoice) public invoicesByIndex;

    event InvoiceCreated(uint id, address creator, string description, uint256 priceUSD);
    event InvoicePaid(uint id, address payer);

    constructor(address _systemContractAddress, address _pythContract, address _usdcEthAddress) {
        systemContract = SystemContract(_systemContractAddress);
        pyth = IPyth(_pythContract);
        usdcEthAddress = _usdcEthAddress;

        // eth testnet
        zrc20ToPythId[address(0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0)] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        // bnb.bsc testnet
        zrc20ToPythId[address(0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891)] = 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;
        // usdc testnet
        zrc20ToPythId[_usdcEthAddress] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    }

    function convertToUint(
        int64 price,
        int32 expo,
        uint8 targetDecimals
    ) public pure returns (uint256) {
        if (price < 0 || expo > 0 || expo < -255) {
            revert();
        }

        uint8 priceDecimals = uint8(uint32(-1 * expo));

        if (targetDecimals >= priceDecimals) {
            return
                uint(uint64(price)) *
                10 ** uint32(targetDecimals - priceDecimals);
        } else {
            return
                uint(uint64(price)) /
                10 ** uint32(priceDecimals - targetDecimals);
        }
    }

    function getStableRatio(
        address zrc20
    ) public view returns (uint256) {
        // Ensure that the zrc20 address is valid
        require(zrc20 != address(0), "Invalid address");

        // Get the prices from the Pyth contract
        PythStructs.Price memory inboundPricePyth = pyth.getPrice(zrc20ToPythId[zrc20]);
        PythStructs.Price memory outboundPricePyth = pyth.getPrice(zrc20ToPythId[usdcEthAddress]);

        // Ensure prices are valid (assuming the Pyth getPrice method sets price to zero on error)
        require(inboundPricePyth.price != 0, "Invalid inbound price");
        require(outboundPricePyth.price != 0, "Invalid outbound price");

        // Convert prices to uint256 with the required precision
        uint256 inboundPrice = convertToUint(
            inboundPricePyth.price,
            inboundPricePyth.expo,
            18
        );

        uint256 outboundPrice = convertToUint(
            outboundPricePyth.price,
            outboundPricePyth.expo,
            18
        );

        // Ensure the outbound price is not zero to avoid division by zero
        require(outboundPrice != 0, "Outbound price is zero");

        // Calculate the ratio
        uint256 ratio = inboundPrice * 1e18 / outboundPrice;

        return ratio;
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem(systemContract) {
        (uint invoiceId) = abi.decode(
            message,
            (uint)
        );
        Invoice storage invoice = invoicesByIndex[invoiceId];

        // require(amount * stableRatio > invoice.priceUSD, "Inbound amount is not sufficient to pay invoice");

        address wzeta = systemContract.wZetaContractAddress();
        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract,
            zrc20,
            amount,
            wzeta,
            0
        );

        IWETH9(wzeta).transfer(invoice.creator, outputAmount);
        invoice.paid = true;
    }

	function createInvoice(string memory _description, uint256 _priceUSD) public {
        Invoice memory newInvoice = Invoice({
            id: nextInvoiceId,
            creator: msg.sender,
            description: _description,
            priceUSD: _priceUSD,
            paid: false
        });

        invoicesByIndex[nextInvoiceId] = newInvoice;
        invoicesByCreator[msg.sender].push(nextInvoiceId);

        emit InvoiceCreated(nextInvoiceId, msg.sender, _description, _priceUSD);
        nextInvoiceId++;
    }

    function getInvoices() public view returns (Invoice[] memory) {
        Invoice[] memory invoices = new Invoice[](nextInvoiceId);
        for (uint i = 0; i < nextInvoiceId; i++) {
            invoices[i] = invoicesByIndex[i];
        }
        return invoices;
    }

    function getInvoice(uint _invoiceId) public view returns (Invoice memory) {
        require(_invoiceId < nextInvoiceId, "Invoice does not exist");
        return invoicesByIndex[_invoiceId];
    }

    function getInvoicesByCreator(address _creator) public view returns (Invoice[] memory) {
        uint[] storage invoiceIds = invoicesByCreator[_creator];
        Invoice[] memory creatorInvoices = new Invoice[](invoiceIds.length);

        for (uint i = 0; i < invoiceIds.length; i++) {
            creatorInvoices[i] = invoicesByIndex[invoiceIds[i]];
        }

        return creatorInvoices;
    }

	function getMyInvoices() public view returns (Invoice[] memory) {
		return getInvoicesByCreator(msg.sender);
	}
}
