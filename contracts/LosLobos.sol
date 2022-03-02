// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721ATradable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LosLobos is ERC721ATradable, ReentrancyGuard {
    uint256 public immutable maxMintPerTransaction;
    uint256 public immutable amountForDevs;
    uint256 public immutable amountForAuctionAndDev;

    struct SaleConfig {
        uint32 auctionSaleStartTime;
        uint32 publicSaleStartTime;
        uint64 whitelistPrice;
        uint64 publicPrice;
    }

    SaleConfig public saleConfig;

    mapping(address => uint256) public whitelist;

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 amountForAuctionAndDev_,
        uint256 amountForDevs_,
        address _proxyRegistryAddress
    )
        ERC721ATradable(
            "Meta Wolves",
            "MWF",
            maxBatchSize_,
            collectionSize_,
            _proxyRegistryAddress
        )
    {
        maxMintPerTransaction = maxBatchSize_;
        amountForAuctionAndDev = amountForAuctionAndDev_;
        amountForDevs = amountForDevs_;
        require(
            amountForAuctionAndDev_ <= collectionSize_,
            "larger collection size needed"
        );
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function auctionMint(uint256 quantity) external payable callerIsUser {
        uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
        require(
            _saleStartTime != 0 && block.timestamp >= _saleStartTime,
            "sale has not started yet"
        );
        require(
            totalSupply() + quantity <= amountForAuctionAndDev,
            "not enough remaining reserved for auction to support desired mint amount"
        );
        require(quantity <= maxMintPerTransaction, "can not mint this many");
        uint256 totalCost = getAuctionPrice() * quantity;
        require(msg.value >= totalCost, "Need to send more ETH.");
        _safeMint(msg.sender, quantity);
    }

    function whitelistMint() external payable callerIsUser {
        uint256 price = uint256(saleConfig.whitelistPrice);
        require(price != 0, "whitelist sale has not begun yet");
        require(whitelist[msg.sender] > 0, "not eligible for whitelist mint");
        require(totalSupply() + 1 <= collectionSize, "reached max supply");
        require(msg.value >= price, "Need to send more ETH.");
        whitelist[msg.sender]--;
        _safeMint(msg.sender, 1);
    }

    function publicSaleMint(uint256 quantity) external payable callerIsUser {
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

    uint256 public constant AUCTION_START_PRICE = .0001 ether;
    uint256 public constant AUCTION_END_PRICE = 0.00001 ether;
    uint256 public constant AUCTION_PRICE_CURVE_LENGTH = 120 minutes;
    uint256 public constant AUCTION_DROP_INTERVAL = 5 minutes;
    uint256 public constant AUCTION_DROP_PER_STEP =
        (AUCTION_START_PRICE - AUCTION_END_PRICE) /
            (AUCTION_PRICE_CURVE_LENGTH / AUCTION_DROP_INTERVAL);

    function getAuctionPrice()
        public
        view
        returns (uint256)
    {
        uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
        if (block.timestamp < _saleStartTime) {
            return AUCTION_START_PRICE;
        }
        if (block.timestamp - _saleStartTime >= AUCTION_PRICE_CURVE_LENGTH) {
            return AUCTION_END_PRICE;
        } else {
            uint256 steps = (block.timestamp - _saleStartTime) /
                AUCTION_DROP_INTERVAL;
            return AUCTION_START_PRICE - (steps * AUCTION_DROP_PER_STEP);
        }
    }

    function endAuctionAndSetupNonAuctionSaleInfo(
        uint64 whitelistPriceWei,
        uint64 publicPriceWei,
        uint32 publicSaleStartTime
    ) external onlyOwner {
        saleConfig = SaleConfig(
            0,
            publicSaleStartTime,
            whitelistPriceWei,
            publicPriceWei
        );
    }

    function setAuctionSaleStartTime(uint32 timestamp) external onlyOwner {
        saleConfig.auctionSaleStartTime = timestamp;
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
}
