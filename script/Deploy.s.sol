// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AnimalPassport} from "../src/AnimalPassport.sol";

contract Deploy is Script {
    function run() external {
        // PRIVATE_KEY can be "0x..." or raw hex; bytes32 is safest
        uint256 pk = uint256(vm.envBytes32("PRIVATE_KEY"));

        // Optional override: if you want admin different from deployer, set ADMIN in .env
        address admin = vm.envOr("ADMIN", address(0));
        if (admin == address(0)) {
            admin = vm.addr(pk); // default: deployer = admin/issuer
        }

        // Optional: let these be overridable later if you want
        string memory name = "Animal Passport";
        string memory symbol = "PASS";
        string memory baseURI = "https://paws-passport.vercel.app/passport/";

        vm.startBroadcast(pk);

        AnimalPassport pass = new AnimalPassport(admin, name, symbol, baseURI);

        // seed deployer/admin as attester for MVP usability
        pass.setAttester(admin, true);

        vm.stopBroadcast();

        console2.log("AnimalPassport deployed at:", address(pass));
        console2.log("Admin/Issuer:", admin);
    }
}
