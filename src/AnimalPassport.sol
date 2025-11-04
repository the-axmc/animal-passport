// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
MVP goals:
- ERC721 passport (one token per pet)
- Roles: ADMIN(issuer), ATTESTER
- Core fields on-chain (hashes/roots for privacy)
- Update funcs owner/guardian/issuer/attester gated
*/

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract AnimalPassport is ERC721, Ownable, AccessControl {
    using Strings for uint256;

    // --- Roles ---
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    // --- Types ---
    enum Status {
        Active,
        Lost,
        Stolen,
        Deceased
    }

    struct PetCore {
        // identity
        uint8 species; // 0=unknown,1=dog,2=cat,...
        uint16 breedCode; // standardized off-chain code
        uint32 birthDate; // unix
        uint8 sex; // 0=unk,1=M,2=F,3=NeuteredM,4=SpayedF
        uint24 primaryColor; // RGB packed or palette index
        // chips/tags
        uint8 chipStandard; // ISO codes
        bytes32 microchipHash; // hash(salt||chipId)
        bytes32 nfcTagHash; // hash(secret||tag)
        // legal / ownership
        Status status;
        address guardian;
        // health proofs
        bytes32 vaccinationRoot;
        uint64 vaccinationValidUntil;
        bytes32 healthRoot;
        // metadata pointer anchor
        bytes32 metadataCidHash; // keccak256(utf8(cid))
    }

    // --- Storage ---
    uint256 public nextId = 1;
    mapping(uint256 => PetCore) internal pets;

    string public baseURI;

    // --- Events ---
    event PassportIssued(
        uint256 indexed petId,
        address indexed to,
        address indexed issuer
    );
    event StatusUpdated(
        uint256 indexed petId,
        Status oldStatus,
        Status newStatus
    );
    event GuardianSet(uint256 indexed petId, address guardian);
    event MicrochipSet(uint256 indexed petId, bytes32 chipHash, uint8 standard);
    event NfcTagSet(uint256 indexed petId, bytes32 nfcHash);
    event VaccinationRootSet(
        uint256 indexed petId,
        bytes32 root,
        uint64 validUntil
    );
    event HealthRootSet(uint256 indexed petId, bytes32 root);
    event MetadataCidHashSet(uint256 indexed petId, bytes32 cidHash);

    // --- Errors ---
    error NotOwner();
    error NotOwnerOrGuardian();
    error NotOwnerOrIssuer();
    error NotOwnerOrAttester();
    error InvalidToken();

    // --- Modifiers ---
    modifier onlyTokenOwner(uint256 petId) {
        if (_ownerOf(petId) != msg.sender) revert NotOwner();
        _;
    }
    modifier onlyOwnerOrGuardian(uint256 petId) {
        address o = _ownerOf(petId);
        if (o != msg.sender && pets[petId].guardian != msg.sender)
            revert NotOwnerOrGuardian();
        _;
    }
    modifier onlyOwnerOrIssuer(uint256 petId) {
        if (_ownerOf(petId) != msg.sender && !hasRole(ISSUER_ROLE, msg.sender))
            revert NotOwnerOrIssuer();
        _;
    }
    modifier onlyOwnerOrAttester(uint256 petId) {
        if (
            _ownerOf(petId) != msg.sender && !hasRole(ATTESTER_ROLE, msg.sender)
        ) revert NotOwnerOrAttester();
        _;
    }
    modifier validToken(uint256 petId) {
        if (_ownerOf(petId) == address(0)) revert InvalidToken();
        _;
    }

    constructor(
        address admin,
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) ERC721(_name, _symbol) Ownable(admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        baseURI = _baseURI;
    }

    // --- Admin helpers ---
    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }
    function setIssuer(address a, bool allowed) external onlyOwner {
        if (allowed) _grantRole(ISSUER_ROLE, a);
        else _revokeRole(ISSUER_ROLE, a);
    }
    function setAttester(address a, bool allowed) external onlyOwner {
        if (allowed) _grantRole(ATTESTER_ROLE, a);
        else _revokeRole(ATTESTER_ROLE, a);
    }

    // --- Core: issue / read ---
    function issuePassport(
        address to,
        PetCore calldata core,
        string calldata cid
    ) external onlyRole(ISSUER_ROLE) returns (uint256 petId) {
        petId = nextId++;
        _mint(to, petId);

        PetCore storage p = pets[petId];
        p.species = core.species;
        p.breedCode = core.breedCode;
        p.birthDate = core.birthDate;
        p.sex = core.sex;
        p.primaryColor = core.primaryColor;
        p.chipStandard = core.chipStandard;
        p.microchipHash = core.microchipHash;
        p.nfcTagHash = core.nfcTagHash;
        p.status = core.status;
        p.guardian = core.guardian;
        p.vaccinationRoot = core.vaccinationRoot;
        p.vaccinationValidUntil = core.vaccinationValidUntil;
        p.healthRoot = core.healthRoot;
        p.metadataCidHash = keccak256(bytes(cid));

        emit PassportIssued(petId, to, msg.sender);
        emit MetadataCidHashSet(petId, p.metadataCidHash);
    }

    function getPet(
        uint256 petId
    ) external view validToken(petId) returns (PetCore memory) {
        return pets[petId];
    }

    // --- Ownership & recovery ---
    function setGuardian(
        uint256 petId,
        address guardian
    ) external onlyTokenOwner(petId) validToken(petId) {
        pets[petId].guardian = guardian;
        emit GuardianSet(petId, guardian);
    }
    function markStatus(
        uint256 petId,
        Status newStatus
    ) external onlyOwnerOrGuardian(petId) validToken(petId) {
        Status old = pets[petId].status;
        pets[petId].status = newStatus;
        emit StatusUpdated(petId, old, newStatus);
    }

    // --- Field updates ---
    function setMicrochip(
        uint256 petId,
        bytes32 chipHash,
        uint8 standard
    ) external onlyOwnerOrIssuer(petId) validToken(petId) {
        pets[petId].microchipHash = chipHash;
        pets[petId].chipStandard = standard;
        emit MicrochipSet(petId, chipHash, standard);
    }

    function setNfcTag(
        uint256 petId,
        bytes32 nfcHash
    ) external onlyOwnerOrIssuer(petId) validToken(petId) {
        pets[petId].nfcTagHash = nfcHash;
        emit NfcTagSet(petId, nfcHash);
    }

    function setHealthRoot(
        uint256 petId,
        bytes32 root
    ) external onlyOwnerOrAttester(petId) validToken(petId) {
        pets[petId].healthRoot = root;
        emit HealthRootSet(petId, root);
    }

    function setVaccinationRoot(
        uint256 petId,
        bytes32 root,
        uint64 validUntil
    ) external onlyRole(ATTESTER_ROLE) validToken(petId) {
        pets[petId].vaccinationRoot = root;
        pets[petId].vaccinationValidUntil = validUntil;
        emit VaccinationRootSet(petId, root, validUntil);
    }

    function setMetadataCid(
        uint256 petId,
        string calldata cid
    ) external onlyOwnerOrIssuer(petId) validToken(petId) {
        bytes32 h = keccak256(bytes(cid));
        pets[petId].metadataCidHash = h;
        emit MetadataCidHashSet(petId, h);
    }

    // --- ERC165 resolution for multiple inheritance ---
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- Metadata ---
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}
