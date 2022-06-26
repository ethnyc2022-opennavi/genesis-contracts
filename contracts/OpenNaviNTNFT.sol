// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";

/// @dev Non-transferable NFT

contract OpenNaviNTNFT is ERC721EnumerableUpgradeable, AccessControlUpgradeable, BaseRelayRecipient, UUPSUpgradeable {
    using ECDSA for bytes32; /*ECDSA for signature recovery for license mints*/
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    string public metadataBaseURI; /* String to prepend to metadata CIDs */

    // Temporary storage for token data after authorization, but before minting (indexed by digest)
    mapping(bytes32 => string) private authorizedMetadataCIDs; /* Track if token minting is authorized, temporary storage for metadata CIDs */

    // Final storage for token data after minting (indexed by token ID)
    mapping(uint256 => string) private tokenMetadataCIDs; /* Metadata CIDs per token */

    uint public sendGasOnAuthorization;

    /// @notice Version of GSN used
    string public override constant versionRecipient = "2.2.6";

    /// @dev Constructor sets the contract metadata and the roles
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param metadataBaseURI_ Base URI for metadata CIDs
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory metadataBaseURI_
    )  public initializer {
        __ERC721_init(name_, symbol_);
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(OWNER_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());        
        _setBaseURI(metadataBaseURI_);

        sendGasOnAuthorization = 0;
    }

    /*****************
    Authorized Minting
    *****************/
    /// @dev Mint the token by using an authorization code from an authorized account
    function mint(uint32 _auth_code) external payable {
        address _dst = _msgSender();
        bytes32 _digest = _getDigest(_auth_code, _dst);

        // get and remove authorized metadata CID
        string memory _metadata_cid = authorizedMetadataCIDs[_digest];
        require(bytes(_metadata_cid).length != 0, "Unauthorized code");

        delete authorizedMetadataCIDs[_digest];

        // Mint token
        _mintInternal(_dst);

        // Store token metadata CID
        uint256 _id = _tokenIds.current();
        tokenMetadataCIDs[_id] = _metadata_cid;
    }

    /// @dev Authorize the minting of a new token
    function authorizeMinting(uint32 _auth_code, address _dst, string memory _metadata_cid) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "!minter");
        bytes32 _digest = _getDigest(_auth_code, _dst);

        string memory _old_metadata = authorizedMetadataCIDs[_digest];
        require(bytes(_old_metadata).length == 0, "Code already authorized");
        authorizedMetadataCIDs[_digest] = _metadata_cid;

        if (sendGasOnAuthorization > 0) {
            (bool sent, ) = _dst.call{value: sendGasOnAuthorization}("");
            require(sent, "Failed to send Ether");
        }
    }

    /*****************
    Public interfaces
    *****************/
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory uri = _baseURI();
        string memory metadata_cid = tokenMetadataCIDs[tokenId];
        return
            bytes(uri).length > 0
                ? string(abi.encodePacked(uri, metadata_cid))
                : "";
    }

    ///@dev Support interfaces for Access Control and ERC721
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            interfaceId == type(IAccessControlUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*****************
    Payment
    *****************/

    ///@dev fallback function to accept any payment
    receive() external payable {
    }

    /*****************
    Config
    *****************/
    /// @notice Set new base URI for token metadata CIDs
    /// @param baseURI_ String to prepend to token metadata CIDs
    function setMetadataBaseURI(string memory baseURI_) external {
        require(hasRole(OWNER_ROLE, _msgSender()), "!owner");
        _setBaseURI(baseURI_);
    }

    /// @notice Set the amount of gas to be sent after mint authorization
    /// @param value_ uint WEI to send
    function setSendGasOnAuthorization(uint value_) external {
        require(hasRole(OWNER_ROLE, _msgSender()), "!owner");
        sendGasOnAuthorization = value_;
    }

    /*****************
    GSN
    *****************/
    /// @notice Returns actual message sender when transaction is proxied via relay in GSN
    function _msgSender() override(ContextUpgradeable, BaseRelayRecipient) internal virtual view returns (address sender) {
        sender = BaseRelayRecipient._msgSender();
    }

    /// @notice Returns actual message data when transaction is proxied via relay in GSN
    function _msgData() override(ContextUpgradeable, BaseRelayRecipient) internal virtual view returns (bytes calldata) {
        return BaseRelayRecipient._msgData();
    }

    /// @notice Tells the contract which forwarder on this network to trust
    /// @param _forwarder the address of the forwarder
    function setTrustedForwarder(address _forwarder) external {
        require(hasRole(OWNER_ROLE, _msgSender()), "!owner");
        _setTrustedForwarder(_forwarder);
    } 

    /*****************
    PROXY
    *****************/

    function _authorizeUpgrade(address) override internal view {
        require(hasRole(OWNER_ROLE, _msgSender()), "!owner");
    }

    /*****************
    HELPERS
    *****************/
    function _getDigest(uint32 _auth_code, address _dst) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_auth_code, _dst, address(this)));
    }

    /// @notice internal helper to retrieve private base URI for token URI construction
    function _baseURI() internal view override returns (string memory) {
        return metadataBaseURI;
    }

    /// @notice internal helper to update token URI
    /// @param baseURI_ String to prepend to token IDs
    function _setBaseURI(string memory baseURI_) internal {
        metadataBaseURI = baseURI_;
    }


    /// @dev Internal util for minting
    function _mintInternal(address _dst) internal {
        _tokenIds.increment();

        uint256 _id = _tokenIds.current();

        _safeMint(_dst, _id);
    }

    /// @dev Internal hook to disable all transfers
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721EnumerableUpgradeable) {
        require(from == address(0), "Not transferable!");
        super._beforeTokenTransfer(from, to, tokenId);
    }
}