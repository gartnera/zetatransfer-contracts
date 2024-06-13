// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";

contract InvoiceManager is zContract, OnlySystem {
    SystemContract public systemContract;

	struct Invoice {
        uint id;
        address creator;
        string description;
        uint256 priceUSD;
        bool paid;
    }

	Invoice[] public invoices;
    uint public nextInvoiceId;

	// Mapping from creator address to an array of invoice IDs
    mapping(address => uint[]) public invoicesByCreator;

    event InvoiceCreated(uint id, address creator, string description, uint256 priceUSD);
    event InvoicePaid(uint id, address payer);

    constructor(address systemContractAddress) {
        systemContract = SystemContract(systemContractAddress);
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem(systemContract) {
        // TODO: implement the logic
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
}
