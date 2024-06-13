// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

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

	Invoice[] public invoices;
    uint public nextInvoiceId;

    address usdcEthAddress;

	// Mapping from creator address to an array of invoice IDs
    mapping(address => uint[]) public invoicesByCreator;

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

        Invoice storage invoice = invoices[invoiceId];
 
        (address gasZRC20, uint256 gasFee) = IZRC20(usdcEthAddress)
            .withdrawGasFee();
 
        uint256 inputForGas = SwapHelperLib.swapTokensForExactTokens(
            systemContract,
            zrc20,
            gasFee,
            gasZRC20,
            amount
        );
 
        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract,
            zrc20,
            amount - inputForGas,
            usdcEthAddress,
            0
        );

        IZRC20(gasZRC20).approve(usdcEthAddress, gasFee);
        IZRC20(usdcEthAddress).withdraw(abi.encodePacked(invoice.creator), outputAmount);
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

        invoices.push(newInvoice);
        invoicesByCreator[msg.sender].push(nextInvoiceId);

        emit InvoiceCreated(nextInvoiceId, msg.sender, _description, _priceUSD);
        nextInvoiceId++;
    }

    function getInvoices() public view returns (Invoice[] memory) {
        return invoices;
    }

    function getInvoice(uint _invoiceId) public view returns (Invoice memory) {
        require(_invoiceId < nextInvoiceId, "Invoice does not exist");
        return invoices[_invoiceId];
    }

    function getInvoicesByCreator(address _creator) public view returns (Invoice[] memory) {
        uint[] storage invoiceIds = invoicesByCreator[_creator];
        Invoice[] memory creatorInvoices = new Invoice[](invoiceIds.length);

        for (uint i = 0; i < invoiceIds.length; i++) {
            creatorInvoices[i] = invoices[invoiceIds[i]];
        }

        return creatorInvoices;
    }

	function getMyInvoices() public view returns (Invoice[] memory) {
		return getInvoicesByCreator(msg.sender);
	}
}
