// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721ATradable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LosLobos is ERC721ATradable, ReentrancyGuard {
    uint256 public immutable maxMintPerTransaction;
    uint256 public immutable amountForDevs;

    struct SaleConfig {
        uint32 publicSaleStartTime;
        uint64 whitelistPrice;
        uint64 publicPrice;
    }

    SaleConfig public saleConfig;

    mapping(address => uint256) public whitelist;

    constructor(
        uint256 _maxBatchSize,
        uint256 _amountForDevs,
        address _proxyRegistryAddress
    )
        ERC721ATradable(
            "Meta Wolves",
            "MWF",
            _maxBatchSize,
            7777,
            _proxyRegistryAddress
        )
    {
        maxMintPerTransaction = _maxBatchSize;
        amountForDevs = _amountForDevs;
        require(_amountForDevs <= 7777, "larger collection size needed");
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function whitelistMint() external payable callerIsUser whenNotPaused {
        uint256 price = uint256(saleConfig.whitelistPrice);
        require(price != 0, "whitelist sale has not begun yet");
        require(whitelist[msg.sender] > 0, "not eligible for whitelist mint");
        require(totalSupply() + 1 <= collectionSize, "reached max supply");
        require(msg.value >= price, "Need to send more ETH.");
        whitelist[msg.sender]--;
        _safeMint(msg.sender, 1);
    }

    function publicSaleMint(uint256 quantity)
        external
        payable
        callerIsUser
        whenNotPaused
    {
        SaleConfig memory config = saleConfig;
        uint256 publicPrice = uint256(config.publicPrice);
        uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);

        require(
            isPublicSaleOn(publicPrice, publicSaleStartTime),
            "public sale has not begun yet"
        );
        require(
            totalSupply() + quantity <= collectionSize,
            "reached max supply"
        );

        require(quantity <= maxMintPerTransaction, "can not mint this many");
        require(msg.value >= publicPrice * quantity, "Need to send more ETH.");
        _safeMint(msg.sender, quantity);
    }

    function isPublicSaleOn(uint256 publicPriceWei, uint256 publicSaleStartTime)
        public
        view
        returns (bool)
    {
        return publicPriceWei != 0 && block.timestamp >= publicSaleStartTime;
    }

    function setupSaleInfo(
        uint64 whitelistPriceWei,
        uint64 publicPriceWei,
        uint32 publicSaleStartTime
    ) external onlyOwner {
        saleConfig = SaleConfig(
            publicSaleStartTime,
            whitelistPriceWei,
            publicPriceWei
        );
    }

    function seedWhitelist(
        address[] memory addresses,
        uint256[] memory numSlots
    ) external onlyOwner {
        require(
            addresses.length == numSlots.length,
            "addresses does not match numSlots length"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = numSlots[i];
        }
    }

    // For marketing etc.
    function devMint(uint256 quantity) external onlyOwner {
        require(
            totalSupply() + quantity <= amountForDevs,
            "too many already minted before dev mint"
        );
        require(
            quantity % maxBatchSize == 0,
            "can only mint a multiple of the maxBatchSize"
        );
        uint256 numChunks = quantity / maxBatchSize;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(msg.sender, maxBatchSize);
        }
    }

    // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setOwnersExplicit(uint256 quantity)
        external
        onlyOwner
        nonReentrant
    {
        _setOwnersExplicit(quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId)
        external
        view
        returns (TokenOwnership memory)
    {
        return ownershipOf(tokenId);
    }

    function takeSnapshot(uint256 from, uint256 to)
        external
        view
        returns (address[] memory)
    {
        address[] memory result = new address[](to - from);
        for (uint256 i = from; i < to; i++) {
            result[i - from] = ownerOf(i);
        }
        return result;
    }
}
