// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Upgradeable.sol";
import "../utils/Pausable.sol";
import "../utils/Initializable.sol";
import "../utils/Ownable.sol";

/**
 *  ERC721 contract with different category NTF
 */

contract PDFERC721Upgradeable is ERC721Upgradeable, Pausable, Ownable{

    /**
     * @dev Stores an optional alternate address to receive creator revenue and royalty payments. (categoryId => createAddress)
     */
    mapping(uint256 => address payable) private tokenCategoryToCreator;

    /**
     * @dev Stores supply of a kind of token. (categoryId => supplyAmount)
     */
    mapping(uint256 => uint256) private tokenSupply;
    /**
     * @dev Stores amount of a kind of exist token. (categoryId => suppliedAmount)
     */
    mapping(uint256 => uint256) private tokenAmount;
    /**
     * @dev Stores token category. (tokenId => categoryId)
     */
    mapping(uint256 => uint256) private tokenCategory;
    /**
     * @dev Stores token serial number. (tokenId => serialNumber)
     */
    mapping(uint256 => uint256) private tokenSerialNumber;
    /**
     * @dev Stores serial number with tokenId. (categoryId => (serialNumber => tokenId))
     */
    mapping(uint256 => mapping(uint256 => uint256)) private serialNumberToken;
    /**
     * @dev Stores upgradeable token category (key categoryFrom => value categoryTo).
     */
    mapping(uint256 => mapping(uint256 => uint256)) private upgradeableCategory;
    /**
     * @dev Stores number of upgradeable token to upgrade (key categoryFrom => value number).
     */
    mapping(uint256 => uint256) private upgradeCategoryNeedNum;

    /**
     * @dev Stores index of tokenId.
     */
    uint256 private tokenIdIndex;

    /**
     * @dev Stores index of categoryId.
     */
    uint256 private categoryIndex;

    /**
     * @dev batch mint maximum.
     */
    uint256 private maxBatchMint;

    /**
     * @dev contract properties stored URI.
     */
    string private contractMetadataURI;

    /**
     * @dev Emitted when category is created by `creatorAddress` with supplyAmount 'supplyAmount'.
     */
    event CreateCategory(address indexed creatorAddress, uint256 indexed categoryId, uint256 indexed supplyAmount);

    function _PDFERC721Init(string memory name_, string memory symbol_, uint256 tokenIdIndex_, uint256 categoryIndex_) public initializer{
        __ERC721_init(name_, symbol_);
        _initOwner();
        _initPauseState();
        registerInterfaces();
        tokenIdIndex = tokenIdIndex_;
        categoryIndex = categoryIndex_;
        maxBatchMint = 100;
    }

    /*
     * bytes4(keccak256('tokenCreator(uint256)')) == 0x40c1a064
     */
    bytes4 private constant _INTERFACE_TOKEN_CREATOR = 0x40c1a064;
    /**
     * @notice Allows ERC165 interfaces which were not included originally to be registered.
     * @dev Currently this is the only new interface, but later other mixins can overload this function to do the same.
     */
    function registerInterfaces() internal {
        _registerInterface(_INTERFACE_TOKEN_CREATOR);
    }

    modifier onlyCreator(uint256 category_) {
        require(tokenCategoryToCreator[category_] == msg.sender, "NFT721Creator: Caller is not creator");
        _;
    }

    /**
     * add token category and confirm token supply
     */
    function preMint(uint256 supply_, address payable creator_) public onlyOwner returns (uint256){
        require(supply_ > 0, "PDF NTF: over uint limit");
        require(categoryIndex + 1 > categoryIndex, "PDF NTF: over uint limit");
        uint256 categoryId = categoryIndex;
        require(!categoryExists(categoryId), "PDF NTF: category has been supplied");
        tokenSupply[categoryId] = supply_;
        tokenAmount[categoryId] = 0;
        tokenCategoryToCreator[categoryId] = creator_;
        categoryIndex += 1;

        emit CreateCategory(creator_, categoryId, supply_);

        return categoryId;
    }

    /**
     * return category if exist
     */
    function categoryExists(uint256 category_) internal view returns (bool) {
        return tokenSupply[category_] > 0;
    }

    /**
     * mint token by category and set tokenUri
     */
    function mint(uint256 category_, address to_, string memory tokenURI_) public onlyOwner{
        require(categoryExists(category_), "PDF NTF: category has not been supplied");
        require(tokenAmount[category_] < tokenSupply[category_], "PDF NTF: category amount over supply");
        singleMint(category_, to_, tokenURI_);
    }

    function singleMint(uint256 category_, address to_, string memory tokenURI_) internal{
        uint256 tokenId_ = generateTokenId();
        _safeMint(to_, tokenId_);
        _setTokenURI(tokenId_, tokenURI_);
        tokenAmount[category_] = tokenAmount[category_] + 1;
        tokenSerialNumber[tokenId_] = tokenAmount[category_];
        serialNumberToken[category_][tokenAmount[category_]] = tokenId_;
        tokenCategory[tokenId_] = category_;
        tokenIdIndex += 1;
    }

    /**
     * batch mint token by category and set tokenUri
     */
    function batchMint(uint256 category_, address to_, string memory tokenURI_, uint256 mintNumber_) public onlyOwner{
        require(mintNumber_ <= maxBatchMint, "PDF NTF: over the batch mint maximum");
        require(mintNumber_ <= getCategoryBalance(category_), "PDF NTF: over the supply amount");
        require(categoryExists(category_), "PDF NTF: category has not been supplied");
        require(tokenAmount[category_] < tokenSupply[category_], "PDF NTF: category amount over supply");
        for(uint i=0; i < mintNumber_; i++){
            singleMint(category_, to_, tokenURI_);
        }
    }

    /**
     * set upgrade rule
     */
    function setUpgradeableCategory(uint256 categoryBase_, uint256 categoryMix_, uint256 categoryTo_, uint256 needNum_) public onlyOwner returns (bool){
        require(categoryExists(categoryBase_) && categoryExists(categoryMix_) && categoryExists(categoryTo_),"PDF NTF: category has not been supplied");
        upgradeableCategory[categoryBase_][categoryMix_] = categoryTo_;
        upgradeableCategory[categoryMix_][categoryBase_] = categoryTo_;
        upgradeCategoryNeedNum[categoryBase_] = needNum_;
        upgradeCategoryNeedNum[categoryMix_] = needNum_;
        return true;
    }

    /**
     * set upgrade rule
     */
    function setMaxBatchMint(uint256 maximum_) public onlyOwner returns (bool){
        maxBatchMint = maximum_;
        return true;
    }

    /**
     * return upgrade amount of categoryFrom
     */
    function getUpgradeRule(uint256 categoryBase_, uint256 categoryMix_) public view returns (uint256 _categoryTo, uint256 _needNum){
        _categoryTo = upgradeableCategory[categoryBase_][categoryMix_];
        _needNum = upgradeCategoryNeedNum[categoryBase_];
        return (_categoryTo, _needNum);
    }

    function getCategorySupply(uint256 category_) public view returns (uint256){
        return tokenSupply[category_];
    }

    function getCategoryBalance(uint256 category_) public view returns (uint256){
        return tokenSupply[category_] - tokenAmount[category_];
    }

    /**
     * return category of tokenId
     */
    function getTokenCategory(uint256 tokenId_) public view returns (uint256){
        require(_exists(tokenId_), "PDF NTF: tokenId not exits");
        return tokenCategory[tokenId_];
    }

    /**
     * return serial number of tokenId
     */
    function getTokenSerialNumber(uint256 tokenId_) public view returns (uint256){
        require(_exists(tokenId_), "PDF NTF: tokenId not exits");
        return tokenSerialNumber[tokenId_];
    }

    /**
     * return tokenId index
     */
    function getTokenIndex() public view returns (uint256){
        return tokenIdIndex;
    }

    /**
     * return tokenId
     */
    function getTokenIdBySerialNumber(uint256 category_, uint256 serialNumber_) public view returns (uint256){
        return serialNumberToken[category_][serialNumber_];
    }

    /**
     * upgrade token of owner from categoryFrom to categoryTo and set new tokenUri.
     * (it's neccesary to set upgrade rule previously with function 'setUpgradeableCategory')
     */
    //    function upgradeNtf(address owner_, uint256 categoryFrom_, uint256 burnNum_, string memory upgradeTokenURI_) internal onlyOwner returns (bool) {
    //        require(categoryUpgradeable(categoryFrom_),"PDF NTF: category can not been upgraded");
    //        uint256 categoryTo = upgradeableCategory[categoryFrom_];
    //        uint burnNum = 0;
    //        uint ownerBalance = balanceOf(owner_);
    //        for (uint i = 0; i < ownerBalance; i++){
    //            if(burnNum == burnNum_){
    //                mint(categoryTo, owner_, upgradeTokenURI_);
    //                return true;
    //            }
    //            uint256 tokenId_ = tokenOfOwnerByIndex(owner_, i);
    //            if(tokenCategory[tokenId_] == categoryFrom_){
    //                _burn(tokenId_);
    //                burnNum += 1;
    //            }
    //        }
    //        return false;
    //    }

    /**
     * upgrade token of owner from categoryFrom to categoryTo and set new tokenUri.
     * (it's neccesary to set upgrade rule previously with function 'setUpgradeableCategory')
     */
    function upgradeNftById(address owner_, uint256[] memory tokenIds, string memory upgradeTokenURI_) public returns (bool) {
        uint256 upgradeFrom = tokenCategory[tokenIds[0]];
        require(categoryUpgradeable(upgradeFrom, upgradeFrom), "PDF NTF: category can not been upgraded");
        require(tokenIds.length >= upgradeCategoryNeedNum[upgradeFrom], "PDF NTF: category upgrade number not enough");
        uint256 upgradeTo = upgradeableCategory[upgradeFrom][upgradeFrom];
        for (uint i = 0; i < upgradeCategoryNeedNum[upgradeFrom]; i++) {
            require(_exists(tokenIds[i]), "PDF NTF: tokenId not exits");
            require(_isApprovedOrOwner(owner_, tokenIds[i]), "PDF NTF: execute not be approved");
            // mixed category upgrade
            if (tokenCategory[tokenIds[i]] != upgradeFrom){
                require(categoryUpgradeable(upgradeFrom, tokenCategory[tokenIds[i]]), "PDF NTF: category can not been mixed upgraded");
                require(upgradeCategoryNeedNum[upgradeFrom] == upgradeCategoryNeedNum[tokenCategory[tokenIds[i]]], "PDF NTF: category can not been mixed upgraded");
                upgradeFrom = tokenCategory[tokenIds[i]];
                upgradeTo = upgradeableCategory[upgradeFrom][tokenCategory[tokenIds[i]]];
            }
            _burn(tokenIds[i]);
        }
        mint(upgradeTo, owner_, upgradeTokenURI_);
        return true;
    }

    function categoryUpgradeable(uint256 categoryBase_, uint256 categoryMix_) internal view returns (bool) {
        return upgradeableCategory[categoryBase_][categoryMix_] > 0;
    }

    function generateTokenId() internal view returns (uint256) {
        return tokenIdIndex;
    }
    /**
     * @notice Returns the creator's address for a given tokenId.
     */
    function tokenCreator(uint256 tokenId_) public view returns (address payable) {
        return tokenCategoryToCreator[tokenCategory[tokenId_]];
    }

    function _updateTokenCreator(uint256 category_, address payable creator) internal {
        //emit TokenCreatorUpdated(tokenIdToCreator[tokenId], creator, tokenId);

        tokenCategoryToCreator[category_] = creator;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function contractURI() public view returns (string memory) {
        return contractMetadataURI;
    }

    function setContractURI(string memory contractURI_) public onlyOwner {
        contractMetadataURI = contractURI_;
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC721Pausable: token transfer while paused");
    }
}
