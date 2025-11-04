// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {AnimalPassport} from "../src/AnimalPassport.sol";

contract Issue is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address to = vm.envAddress("RECIPIENT_ADDR");
        address contractAddr = vm.envAddress("ADDR");

        AnimalPassport pass = AnimalPassport(contractAddr);

        // Gigi meta — breed=greyhound, age ~8
        AnimalPassport.PetCore memory core = AnimalPassport.PetCore({
            species: 1,
            breedCode: 7777, // arbitrary standard code for greyhound
            birthDate: uint32(block.timestamp - 8 * 365 days),
            sex: 2,
            primaryColor: 0x000000,
            chipStandard: 1,
            microchipHash: keccak256("chip-gigi"),
            nfcTagHash: keccak256("nfc-gigi"),
            status: AnimalPassport.Status.Active,
            guardian: to,
            vaccinationRoot: bytes32(0),
            vaccinationValidUntil: 0,
            healthRoot: bytes32(0),
            metadataCidHash: bytes32(0)
        });

        vm.startBroadcast(pk);

        uint256 petId = pass.issuePassport(
            to,
            core,
            "ipfs://bafkreid5s6lz4ziey2s755b5rytpwxg4zzb6w3k5cpbkwi5g7wm3gczrsu"
        );

        vm.stopBroadcast();

        console2.log("Gigi passport minted ID:", petId);
    }
}
