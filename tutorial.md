# A Beginner's Guide to the Diamond Codebase

Welcome to this beginner-friendly tutorial on the Diamond standard (EIP-2535) codebase. This guide breaks down the entire project into easy-to-understand concepts, explaining how everything works together securely and efficiently.

## 1. System Design Understanding

### How Everything Works Together

At its core, a "Diamond" is a smart contract that can be upgraded without any limits. You can think of a Diamond as a giant router or a puzzle board, and its "Facets" as the individual puzzle pieces.
- **The Core Diamond Contract**: This is the main contract that holds all the data (storage) and assets. Users only interact with this main Diamond. When a user asks the Diamond to perform an action, the Diamond looks up which "Facet" knows how to do it and borrows its logic.
- **Facets**: These are the logic contracts (the puzzle pieces). They are deployed completely separately from the Diamond and don't permanently store data themselves. Instead, they manipulate the data stored inside the main Diamond. 
- **Libraries**: These contain reusable, shared logic. `LibDiamond.sol` is the brain that operates behind the scenes, managing how puzzle pieces are added, removed, or swapped.
- **Interfaces**: These are the blueprints. They do not contain active logic but define what actions a contract is guaranteed to support.

Because logic and storage are separated, you can replace a Facet with a newer version to upgrade your project without ever losing user data.

---

## 2. Core Concepts: DiamondStorage vs. AppStorage

Since the logic (Facets) and the data (Diamond) are separate, the Facets need a reliable way to access the Diamond's data. There are two popular patterns for doing this: **DiamondStorage** and **AppStorage**.

### DiamondStorage

**Definition**: Diamond Storage defines a specific, hidden location inside the smart contract to store its variables. By generating a random location (using a hash of a string, like `"diamond.standard.diamond.storage"`), it guarantees that different parts of your contract will never overwrite each other's data by mistake.

**Use Case**: It is perfect for isolated, system-level logic (like the core mechanisms that make the Diamond upgradeable). You will see DiamondStorage heavily used in `LibDiamond.sol`.

**Code Example**:
```solidity
struct DiamondStorage {
    address owner;
    bool isActive;
}

function diamondStorage() internal pure returns (DiamondStorage storage ds) {
    // Generate a random, hidden storage location
    bytes32 position = keccak256("my.project.storage");
    assembly {
        ds.slot := position
    }
}
```

### AppStorage

**Definition**: App Storage is a simpler, more centralized approach. You create one massive `AppStorage` struct containing all the application-level data. This struct is defined as the very first variable in every single facet and the diamond itself.

**Use Case**: It is ideal for your actual application data (like token balances, user scores, etc.) because it is fast and easy to read. You only have to declare `AppStorage internal s;` at the top of your Facets.

**Code Example**:
```solidity
struct AppStorage {
    mapping(address => uint256) balances;
    address owner;
}

contract MyFacet {
    AppStorage internal s; // Always points to slot 0

    function getBalance(address user) public view returns(uint256) {
        return s.balances[user];
    }
}
```

### Similarities & Differences
- **Similarity**: Both methods ensure safe data sharing across multiple upgradeable Facets.
- **Difference**: DiamondStorage is accessed dynamically via random slots, making it highly modular and collision-proof. AppStorage relies on a static, shared layout (always starting at slot 0), making it slightly easier to write but requiring every single facet to know the entire layout file.

---

## 3. Full Codebase Breakdown

Below is a file-by-file, line-by-line explanation of the entire setup. You will notice we have stripped away complex words to just tell you exactly what the code achieves.

### Contracts

#### `Diamond.sol`
This is your main gateway. It is the only contract the end-user interacts with.

**Line-by-line Breakdown:**
- **Lines 1-2:** Open-source MIT license and Solidity version requirement.
- **Lines 11-12:** Imports the helpful `LibDiamond` library and `IDiamondCut` blueprint.
- **Lines 14-28:** We define the `Diamond` contract and its setup phase (`constructor`). When deployed, it assigns the contract owner and artificially plugs in the very first "puzzle piece" (Facet) which is the `DiamondCutFacet`. Without this, the Diamond could never upgrade itself.
- **Lines 30-59:** The extremely crucial `fallback` function. Whenever a user calls a function that does not exist in `Diamond.sol`, this fallback catches the request. It:
  - Looks into storage to find out which Facet handles the request.
  - Checks if the Facet exists.
  - Takes the user's data and "borrows" the logic from the Facet using exactly the same identity (`delegatecall`).
  - Returns the requested data directly back to the user.
- **Line 62-64:** A simple example of an immutable (unchangeable) function that lives directly on the Diamond instead of a Facet.
- **Line 66:** Allows the Diamond to safely receive Ethereum directly via a `receive` function.

#### `upgradeInitializers/DiamondInit.sol`
This contract initializes the starting variables for your Diamond. 

**Line-by-line Breakdown:**
- **Lines 1-2:** MIT License and Solidity version.
- **Lines 11-15:** Imports the required rules (Interfaces) and the main brain library (`LibDiamond`).
- **Line 21:** Creates the `DiamondInit` contract.
- **Lines 25-39:** The `init()` function runs exactly once during setup. It registers the Diamond's capabilities in `LibDiamond.DiamondStorage`, announcing to the world that this Diamond supports interface checking `IERC165`, upgrades `IDiamondCut`, inspections `IDiamondLoupe`, and ownership `IERC173`. 

---

### Libraries

#### `LibDiamond.sol`
This is the workhorse of the whole puzzle system. It contains the logic to connect everything.

**Line-by-line Breakdown:**
- **Lines 1-2:** MIT License and Solidity version.
- **Line 8:** Imports the `IDiamondCut` rulebook for cutting (upgrading) the Diamond.
- **Lines 10-23:** Starts `LibDiamond` and lists simple custom error messages to save gas when something goes wrong (e.g., trying to add an address of zero).
- **Lines 24-25:** Creates purely random coordinate (`DIAMOND_STORAGE_POSITION`) where the core Diamond data will live in the blockchain's memory.
- **Lines 27-50:** Defines how the storage system is structured, mapping every single function identity (a "Selector") to its corresponding Facet puzzle piece. It also stores the contract owner.
- **Lines 52-61:** A helper function that jumps exactly to the random coordinate to fetch/save the Diamond data.
- **Lines 63-82:** Functions allowing the Diamond to update, keep track of, and securely verify who currently owns the Diamond.
- **Lines 84-123:** The core `diamondCut` function. It takes an array of changes (adding, replacing, removing). It loops through the changes and applies them by calling specific inner functions, then finally initializes any state changes you need during the upgrade.
- **Lines 125-152:** The `addFunctions` system. For every new function you want to add, it verifies it doesn't already exist, then safely links it to the new Facet address in storage.
- **Lines 154-183:** The `replaceFunctions` system. It ensures the function exists, deletes the old link, and creates a new link to the upgraded Facet address.
- **Lines 185-204:** The `removeFunctions` system. It deletes the specific functions so they can no longer be called. 
- **Lines 206-285:** Deep-level management tools (`addFacet`, `addFunction`, `removeFunction`) that handle the complex rearranging of the hidden data lists whenever an upgrade happens, ensuring nothing breaks and storage stays neat.
- **Lines 287-308:** The `initializeDiamondCut` handler. When upgrades finish, this optional logic is executed to jump-start or configure whatever the new Facets might need doing immediately.
- **Lines 310-317:** A safety check named `enforceHasContractCode` that guarantees you are only trying to link logic to a real deployed smart contract, not an empty wallet address.

---

### Facets

#### `DiamondCutFacet.sol`
This Facet provides the external entry point for upgrades.

**Line-by-line Breakdown:**
- **Lines 1-2:** MIT License and Solidity version.
- **Lines 9-10:** Imports the `IDiamondCut` standard and `LibDiamond`.
- **Line 12:** Declares the `DiamondCutFacet` inheriting rules from `IDiamondCut`.
- **Lines 19-26:** Defines the single function `diamondCut` that users can call to request an upgrade. It first verifies that only the owner is asking for the upgrade (`enforceIsContractOwner`), and then triggers the actual upgrade logic sitting inside `LibDiamond`.

#### `DiamondLoupeFacet.sol`
"Loupe" is a magnifying glass used for inspecting real diamonds. This Facet lets anyone look inside the smart contract to see what Facets and functions it currently supports.

**Line-by-line Breakdown:**
- **Lines 1-2:** MIT License and Solidity version.
- **Lines 8-10:** Imports `LibDiamond` and inspection-related blueprints.
- **Line 12:** Announces the `DiamondLoupeFacet` contract.
- **Lines 24-33:** The `facets()` function. It reads from storage and returns a full, neat list of every single Facet address currently active and what respective functions each one handles.
- **Lines 38-41:** The `facetFunctionSelectors()` function. This lets you ask for a specific Facet address and get back only the functions it knows how to handle.
- **Lines 45-48:** The `facetAddresses()` function. Simply returns a clean list of all connected Facet addresses.
- **Lines 54-57:** The `facetAddress()` function. You provide a function you want to call, and this responds with exactly which Facet address is currently responsible for handling it.
- **Lines 60-63:** The `supportsInterface()` tool to conform to `IERC165`. It quickly checks if the Diamond knows how to handle an incoming standard.

#### `OwnershipFacet.sol`
This Facet allows the public management of ownership.

**Line-by-line Breakdown:**
- **Lines 1-2:** MIT License and Solidity version.
- **Lines 4-5:** Imports `LibDiamond` and the `IERC173` blueprint.
- **Line 7:** Defines the `OwnershipFacet`.
- **Lines 8-11:** The `transferOwnership` function. Only the current owner can run it, thanks to the library check. This updates the owner address to a newly chosen address.
- **Lines 13-15:** The `owner` query function. Anyone can call this to see who the current owner is. It reads the answer directly from the library's Diamond Storage.

---

### Interfaces

#### `IERC165.sol`
**Line-by-line Breakdown:**
- **Lines 1-4:** Licensing and defining the interface `IERC165`.
- **Line 11:** Requires a `supportsInterface` function which returns true/false if a standard is supported. Closes on **Line 12**.

#### `IERC173.sol`
**Line-by-line Breakdown:**
- **Lines 1-7:** Licensing and defining the standard `IERC173` for ownership.
- **Line 10:** Demands a public `owner()` view function.
- **Line 15:** Demands a `transferOwnership()` function that takes an address pointing out who gets to own the contract next. Closes at **Line 16**.

#### `IDiamondCut.sol`
**Line-by-line Breakdown:**
- **Lines 1-13:** Licensing and creating the interface. It defines a custom `enum` (a preset list of 3 options: Add, Replace, Remove) to decide upgrade actions.
- **Lines 14-17:** Defines a data bundle (`struct`) keeping track of what Facet address handles which functions, and what to do with them.
- **Lines 25-29:** Forces the main `diamondCut` function to exist exactly as written in `DiamondCutFacet`.
- **Line 31:** Defines an `event` so the blockchain safely records and broadcasts exactly what upgrades took place. Closes on **Line 32**.

#### `IDiamondLoupe.sol`
**Line-by-line Breakdown:**
- **Lines 1-11:** Licensing and creating the `IDiamondLoupe` interface.
- **Lines 15-18:** Defines a `Facet` bundle containing the puzzle piece address and the list of logic it supports.
- **Lines 22-37:** Enforces all four inspection functions must be created exactly as they exist in `DiamondLoupeFacet.sol`. Closes on **Line 38**.

---
*Created using simple explanations to make EIP-2535 Diamonds fully accessible for beginners.*
