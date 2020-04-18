pragma solidity 0.5.11;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/utils/Address.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol';

import "./FRight.sol";
import "./IRight.sol";


contract RightsDao is Ownable, IERC721Receiver {

  using Address for address;
  using SafeMath for uint256;

  int128 constant CONTRACT_TYPE_RIGHT_F = 1;
  int128 constant CONTRACT_TYPE_RIGHT_I = 2;

  mapping(int128 => address) public contracts;

  mapping(address => bool) public isWhitelisted;

  bool public whitelistedFreezeActivated = true;

  uint256 public currentFVersion = 1;
  uint256 public currentIVersion = 1;

  constructor(address fRightContractAddress, address iRightContractAddress) public {
    require(fRightContractAddress.isContract(), "invalid fRightContractAddress");
    require(iRightContractAddress.isContract(), "invalid iRightContractAddress");
    contracts[CONTRACT_TYPE_RIGHT_F] = fRightContractAddress;
    contracts[CONTRACT_TYPE_RIGHT_I] = iRightContractAddress;
  }


  function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
    return this.onERC721Received.selector;
  }


  /**
    * @dev set whitelistedFreezeActivated value as true or false
    * @param activate toggle value
    */
  function _toggleWhitelistedFreeze(bool activate) internal {
    if (activate) {
      require(!whitelistedFreezeActivated, "whitelisted freeze is already activated");
    }
    else {
      require(whitelistedFreezeActivated, "whitelisted freeze is already deactivated");
    }
    whitelistedFreezeActivated = activate;
  }


  /**
    * @dev set whitelistedFreezeActivated value as true
    */
  function activateWhitelistedFreeze() external onlyOwner returns (bool) {
    _toggleWhitelistedFreeze(true);
    return true;
  }


  /**
    * @dev set whitelistedFreezeActivated value as false
    */
  function deactivateWhitelistedFreeze() external onlyOwner returns (bool) {
    _toggleWhitelistedFreeze(false);
    return true;
  }


  /**
    * @dev add / remove given address to / from whitelist
    * @param addr given address
    * @param status whitelist status of given address
    */
  function toggleWhitelistStatus(address addr, bool status) external onlyOwner returns (bool) {
    require(addr != address(0));
    isWhitelisted[addr] = status;
    return true;
  }


  /**
    * @dev Increment current f version
    */
  function incrementCurrentFVersion() external onlyOwner returns (bool) {
    currentFVersion = currentFVersion.add(1);
    return true;
  }

  /**
    * @dev Increment current i version
    */
  function incrementCurrentIVersion() external onlyOwner returns (bool) {
    currentIVersion = currentIVersion.add(1);
    return true;
  }


  /**
    * @dev Set base url of the server API representing the metadata of a Right Token
    * @param rightType type of Right contract
    * @param url API base url
    */
  function setRightApiBaseUrl(int128 rightType, string calldata url) external onlyOwner returns (bool) {
    require((rightType == CONTRACT_TYPE_RIGHT_F) || (rightType == CONTRACT_TYPE_RIGHT_I), "invalid contract type");
    if (rightType == CONTRACT_TYPE_RIGHT_F) {
      FRight(contracts[rightType]).setApiBaseUrl(url);
    }
    else {
      IRight(contracts[rightType]).setApiBaseUrl(url);
    }
    return true;
  }

  /**
    * @dev Transfer ownership of the Right contract.
    * @param rightType type of Right contract
    * @param proxyRegistryAddress address of the Right's Proxy Registry
    */
  function setRightProxyRegistry(int128 rightType, address proxyRegistryAddress) external onlyOwner returns (bool) {
    require((rightType == CONTRACT_TYPE_RIGHT_F) || (rightType == CONTRACT_TYPE_RIGHT_I), "invalid contract type");
    if (rightType == CONTRACT_TYPE_RIGHT_F) {
      FRight(contracts[rightType]).setProxyRegistryAddress(proxyRegistryAddress);
    }
    else {
      IRight(contracts[rightType]).setProxyRegistryAddress(proxyRegistryAddress);
    }
    return true;
  }

  /**
    * @dev Freeze a given ERC721 Token
    * @param baseAssetAddress address of the ERC721 Token
    * @param baseAssetId id of the ERC721 Token
    * @param expiry timestamp until which the ERC721 Token is locked in the dao
    * @param isExclusive exclusivity of IRights for the ERC721 Token
    * @param values uint256 array [maxISupply, f_version, i_version]
    */
  function freeze(address baseAssetAddress, uint256 baseAssetId, uint256 expiry, bool isExclusive, uint256[3] calldata values) external returns (bool) {
    if (whitelistedFreezeActivated) {
      require(isWhitelisted[msg.sender], "sender is not whitelisted");
    }
    require(values[0] > 0, "invalid maximum I supply");
    require(expiry > block.timestamp, "expiry should be in the future");
    require((values[1] > 0) && (values[1] <= currentFVersion), "invalid f version");
    require((values[2] > 0) && (values[2] <= currentIVersion), "invalid i version");
    uint256 fRightId = FRight(contracts[CONTRACT_TYPE_RIGHT_F]).freeze([msg.sender, baseAssetAddress], isExclusive, [expiry, baseAssetId, values[0], values[1]]);
    require(fRightId != 0, "freeze unsuccessful");
    IRight(contracts[CONTRACT_TYPE_RIGHT_I]).issue([msg.sender, baseAssetAddress], isExclusive, [fRightId, expiry, baseAssetId, values[2]]);
    ERC721(baseAssetAddress).safeTransferFrom(msg.sender, address(this), baseAssetId);
    return true;
  }

  /**
    * @dev Mint an IRight token for a given FRight token Id
    * @param values uint256 array [fRightId, expiry, i_version]
    */
  function issueI(uint256[3] calldata values) external returns (bool) {
    require(values[1] > block.timestamp, "expiry should be in the future");
    require((values[2] > 0) && (values[2] <= currentIVersion), "invalid i version");
    require(FRight(contracts[CONTRACT_TYPE_RIGHT_F]).isIMintAble(values[0]), "cannot mint iRight");
    require(msg.sender == FRight(contracts[CONTRACT_TYPE_RIGHT_F]).ownerOf(values[0]), "sender is not the owner of fRight");
    (uint256 fEndTime, uint256 fMaxISupply) = FRight(contracts[CONTRACT_TYPE_RIGHT_F]).endTimeAndMaxSupply(values[0]);
    require(fMaxISupply > 0, "maximum I supply is zero");
    require(values[1] <= fEndTime, "expiry cannot exceed fRight expiry");
    (address baseAssetAddress, uint256 baseAssetId) = FRight(contracts[CONTRACT_TYPE_RIGHT_F]).baseAsset(values[0]);
    IRight(contracts[CONTRACT_TYPE_RIGHT_I]).issue([msg.sender, baseAssetAddress], false, [values[0], values[1], baseAssetId, values[2]]);
    FRight(contracts[CONTRACT_TYPE_RIGHT_F]).incrementCirculatingISupply(values[0], 1);
    return true;
  }

  /**
    * @dev Burn an IRight token for a given IRight token Id
    * @param iRightId id of the IRight Token
    */
  function revokeI(uint256 iRightId) external returns (bool) {
    require(msg.sender == IRight(contracts[CONTRACT_TYPE_RIGHT_I]).ownerOf(iRightId), "sender is not the owner of iRight");
    (address baseAssetAddress, uint256 baseAssetId) = IRight(contracts[CONTRACT_TYPE_RIGHT_I]).baseAsset(iRightId);
    bool isBaseAssetFrozen = FRight(contracts[CONTRACT_TYPE_RIGHT_F]).isFrozen(baseAssetAddress, baseAssetId);
    if (isBaseAssetFrozen) {
      uint256 fRightId = IRight(contracts[CONTRACT_TYPE_RIGHT_I]).parentId(iRightId);
      require(fRightId != 0, "invalid fRight parent");
      FRight(contracts[CONTRACT_TYPE_RIGHT_F]).decrementCirculatingISupply(fRightId, 1);
    }
    IRight(contracts[CONTRACT_TYPE_RIGHT_I]).revoke(msg.sender, iRightId);
    return true;
  }

  /**
    * @dev Burn an FRight token for a given FRight token Id, and return the original nft back to the user
    * @param fRightId id of the FRight Token
    */
  function unfreeze(uint256 fRightId) external returns (bool) {
    require(FRight(contracts[CONTRACT_TYPE_RIGHT_F]).isUnfreezable(fRightId), "fRight is unfreezable");
    (address baseAssetAddress, uint256 baseAssetId) = FRight(contracts[CONTRACT_TYPE_RIGHT_F]).baseAsset(fRightId);
    FRight(contracts[CONTRACT_TYPE_RIGHT_F]).unfreeze(msg.sender, fRightId);
    ERC721(baseAssetAddress).transferFrom(address(this), msg.sender, baseAssetId);
    return true;
  }

}
