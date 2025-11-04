// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnimalPassport.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract AnimalPassportTest is Test {
    AnimalPassport pass;
    address admin = address(0xA11CE);
    address owner = address(0xB0B);
    address attester = address(0xA771);
    AnimalPassport.PetCore core;

    function setUp() public {
        vm.prank(admin);
        pass = new AnimalPassport(
            admin,
            "Animal Passport",
            "PASS",
            "https://paws-passport.vercel.app/passport/"
        );

        vm.prank(admin);
        pass.setAttester(attester, true);

        core = AnimalPassport.PetCore({
            species: 1,
            breedCode: 123,
            birthDate: uint32(block.timestamp),
            sex: 2,
            primaryColor: 0x000000,
            chipStandard: 1,
            microchipHash: keccak256("chip123"),
            nfcTagHash: keccak256("nfckey"),
            status: AnimalPassport.Status.Active,
            guardian: address(0),
            vaccinationRoot: bytes32(0),
            vaccinationValidUntil: 0,
            healthRoot: bytes32(0),
            metadataCidHash: bytes32(0)
        });
    }

    function testIssueAndUpdate() public {
        vm.prank(admin);
        uint256 id = pass.issuePassport(owner, core, "ipfs://cid-001");
        assertEq(id, 1);
        assertEq(pass.ownerOf(id), owner);

        vm.prank(attester);
        pass.setVaccinationRoot(
            id,
            keccak256("vaccs"),
            uint64(block.timestamp + 365 days)
        );

        vm.prank(owner);
        pass.markStatus(id, AnimalPassport.Status.Lost);

        AnimalPassport.PetCore memory p = pass.getPet(id);
        assertEq(uint8(p.status), uint8(AnimalPassport.Status.Lost));
        assertEq(p.vaccinationRoot, keccak256("vaccs"));
    }

    function testSetVaccinationRoot_RevertIfNotAttester() public {
        vm.prank(admin);
        uint256 id = pass.issuePassport(owner, core, "ipfs://cid-001");

        address rando = address(0xD00D);
        bytes32 role = pass.ATTESTER_ROLE();

        vm.prank(rando);
        // match OZ v5 error: AccessControlUnauthorizedAccount(address,bytes32)
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                rando,
                role
            )
        );
        pass.setVaccinationRoot(
            id,
            keccak256("nope"),
            uint64(block.timestamp + 1 days)
        );
    }

    function testMarkStatus_ByGuardian() public {
        vm.prank(admin);
        uint256 id = pass.issuePassport(owner, core, "ipfs://cid-001");

        address guardian = address(0xCAFE);

        vm.prank(owner);
        pass.setGuardian(id, guardian);

        vm.prank(guardian);
        pass.markStatus(id, AnimalPassport.Status.Lost);

        AnimalPassport.PetCore memory p = pass.getPet(id);
        assertEq(uint8(p.status), uint8(AnimalPassport.Status.Lost));
    }

    function testSupportsInterface() public {
        assertTrue(pass.supportsInterface(type(IERC721).interfaceId));
        assertTrue(pass.supportsInterface(type(IAccessControl).interfaceId));
    }

    function testTokenURI() public {
        vm.prank(admin);
        uint256 id = pass.issuePassport(owner, core, "ipfs://cid-001");

        string memory uri = pass.tokenURI(id);
        assertEq(uri, "https://paws-passport.vercel.app/passport/1");
    }

    function testGetPet_RevertIfInvalidToken() public {
        vm.expectRevert(AnimalPassport.InvalidToken.selector);
        pass.getPet(999);
    }
}
