# Gigi’s Pet Passport — Deployment via Foundry on Base Sepolia

---

## 0) Why

most “NFTs” are banal jpeg-financialization.
this is a **credential** — not a collectible.

**identity** > **aesthetics**.

---

## 1) Project setup

```bash
mkdir animal-passport
cd animal-passport
forge init
git init
```

install OpenZeppelin v5:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2
```

Check out force-std and OZ-contracts are there with ls .lib and upload .env file with source .env

## 2) Set up .env file:

PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC=https://base-sepolia.drpc.org
PASSPORT_ADDR=(after deployment)
ADMIN=0xYourAdminAddress
RECIPIENT_ADDR=(for issuing)

## 3) Deploy and test

```bash
forge clean
forge test -vv
```

## 4) Deploy AnimalPassport

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$BASE_SEPOLIA_RPC" \
  --broadcast
```

then read the address:

```bash
export ADDR=0xDeployedAddress
export PASSPORT_ADDR=$ADDR
```

## 5) Verify the contract

```bash
forge verify-contract \
  --chain base-sepolia \
  "$ADDR" \
  src/AnimalPassport.sol:AnimalPassport \
  --constructor-args $(cast abi-encode \
    "constructor(address,string,string,string)" \
    "$ADMIN" \
    "Animal Passport" \
    "PASS" \
    "https://paws-passport.vercel.app/passport/") \
  --compiler-version v0.8.24+commit.e11b9ed9 \
  --num-of-optimizations 200 \
  --watch
```

## 6) Issue one Passport

metadata CID (JSON stored in Pinata/IPFS):
ipfs://CID

run:

```bash
forge script script/IssueGigi.s.sol:IssueGigi \
  --rpc-url "$BASE_SEPOLIA_RPC" \
  --broadcast
```

## 7) Cast

get owner of token 1:

```bash
cast call $PASSPORT_ADDR \
"ownerOf(uint256)(address)" 1 \
--rpc-url $BASE_SEPOLIA_RPC
```

get token URI:

```bash
cast call $PASSPORT_ADDR \
"tokenURI(uint256)(string)" 1 \
--rpc-url $BASE_SEPOLIA_RPC
```
