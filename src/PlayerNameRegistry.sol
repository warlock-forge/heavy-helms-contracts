// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "./interfaces/IPlayerNameRegistry.sol";

error MaxNamesReached();
error MaxSetBNamesReached();
error MaxSurnamesReached();
error InvalidNameIndexSetA();
error InvalidNameIndexSetB();
error InvalidSurnameIndex();
error EmptyBatch();
error BatchTooLarge();
error InvalidNameLength();

contract PlayerNameRegistry is IPlayerNameRegistry, Owned {
    string[] public nameSetA;
    string[] public nameSetB;
    string[] public surnames;

    // Events
    event NameAdded(uint8 nameType, uint16 index, string name);

    // Constants
    uint16 public constant SET_B_MAX = 999;
    uint16 public constant SET_A_START = 1000;
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public constant MAX_NAME_LENGTH = 32;

    modifier validateNames(string[] calldata names) {
        if (names.length == 0) revert EmptyBatch();
        if (names.length > MAX_BATCH_SIZE) revert BatchTooLarge();
        for (uint256 i = 0; i < names.length; i++) {
            uint256 len = bytes(names[i]).length;
            if (len == 0 || len > MAX_NAME_LENGTH) revert InvalidNameLength();
        }
        _;
    }

    constructor() Owned(msg.sender) {
        // Add initial Set A names (masculine)
        nameSetA.push("Aaron");
        nameSetA.push("Adam");
        nameSetA.push("Adrian");
        nameSetA.push("Aiden");
        nameSetA.push("Alan");
        nameSetA.push("Alex");
        nameSetA.push("Alvaro");
        nameSetA.push("Andrew");
        nameSetA.push("Archer");
        nameSetA.push("Asher");
        nameSetA.push("Austin");
        nameSetA.push("Axel");
        nameSetA.push("Ben");
        nameSetA.push("Bill");
        nameSetA.push("Blake");
        nameSetA.push("Bob");
        nameSetA.push("Brad");
        nameSetA.push("Brady");
        nameSetA.push("Bran");
        nameSetA.push("Brian");
        nameSetA.push("Bruce");
        nameSetA.push("Bryan");
        nameSetA.push("Caleb");
        nameSetA.push("Carl");
        nameSetA.push("Carson");
        nameSetA.push("Carter");
        nameSetA.push("Chad");
        nameSetA.push("Chase");
        nameSetA.push("Chris");
        nameSetA.push("Clay");
        nameSetA.push("Cody");
        nameSetA.push("Cole");
        nameSetA.push("Colin");
        nameSetA.push("Corbin");
        nameSetA.push("Cyrus");
        nameSetA.push("Dan");
        nameSetA.push("Dane");
        nameSetA.push("Daniel");
        nameSetA.push("Dante");
        nameSetA.push("Dave");
        nameSetA.push("David");
        nameSetA.push("Dean");
        nameSetA.push("Derek");
        nameSetA.push("Diego");
        nameSetA.push("Dominic");
        nameSetA.push("Drew");
        nameSetA.push("Duke");
        nameSetA.push("Dylan");
        nameSetA.push("Ed");
        nameSetA.push("Edgar");
        nameSetA.push("Eli");
        nameSetA.push("Elias");
        nameSetA.push("Eric");
        nameSetA.push("Erik");
        nameSetA.push("Ethan");
        nameSetA.push("Evan");
        nameSetA.push("Felix");
        nameSetA.push("Finn");
        nameSetA.push("Flynn");
        nameSetA.push("Frank");
        nameSetA.push("Fred");
        nameSetA.push("Gage");
        nameSetA.push("Gary");
        nameSetA.push("Gavin");
        nameSetA.push("George");
        nameSetA.push("Grant");
        nameSetA.push("Greg");
        nameSetA.push("Gus");
        nameSetA.push("Hank");
        nameSetA.push("Harold");
        nameSetA.push("Harris");
        nameSetA.push("Harry");
        nameSetA.push("Heath");
        nameSetA.push("Henry");
        nameSetA.push("Hugh");
        nameSetA.push("Hugo");
        nameSetA.push("Hunter");
        nameSetA.push("Ian");
        nameSetA.push("Isaac");
        nameSetA.push("Ivan");
        nameSetA.push("Jack");
        nameSetA.push("Jake");
        nameSetA.push("James");
        nameSetA.push("Jared");
        nameSetA.push("Jason");
        nameSetA.push("Jay");
        nameSetA.push("Jim");
        nameSetA.push("Joe");
        nameSetA.push("Joel");
        nameSetA.push("John");
        nameSetA.push("Jon");
        nameSetA.push("Jude");
        nameSetA.push("Justin");
        nameSetA.push("Kai");
        nameSetA.push("Kane");
        nameSetA.push("Keith");
        nameSetA.push("Knox");
        nameSetA.push("Kurt");
        nameSetA.push("Kyle");
        nameSetA.push("Lance");
        nameSetA.push("Lars");
        nameSetA.push("Lee");
        nameSetA.push("Leo");
        nameSetA.push("Leon");
        nameSetA.push("Levi");
        nameSetA.push("Liam");
        nameSetA.push("Logan");
        nameSetA.push("Lucas");
        nameSetA.push("Luke");
        nameSetA.push("Malcolm");
        nameSetA.push("Marcus");
        nameSetA.push("Mark");
        nameSetA.push("Matt");
        nameSetA.push("Max");
        nameSetA.push("Miles");
        nameSetA.push("Mike");
        nameSetA.push("Milo");
        nameSetA.push("Nash");
        nameSetA.push("Nathan");
        nameSetA.push("Neil");
        nameSetA.push("Nick");
        nameSetA.push("Noah");
        nameSetA.push("Nolan");
        nameSetA.push("Oliver");
        nameSetA.push("Oscar");
        nameSetA.push("Owen");
        nameSetA.push("Paul");
        nameSetA.push("Pete");
        nameSetA.push("Phil");
        nameSetA.push("Quinn");
        nameSetA.push("Ray");
        nameSetA.push("Reid");
        nameSetA.push("Rick");
        nameSetA.push("Rob");
        nameSetA.push("Ron");
        nameSetA.push("Rory");
        nameSetA.push("Ross");
        nameSetA.push("Ryan");
        nameSetA.push("Sam");
        nameSetA.push("Scott");
        nameSetA.push("Sean");
        nameSetA.push("Seth");
        nameSetA.push("Shane");
        nameSetA.push("Shaw");
        nameSetA.push("Steve");
        nameSetA.push("Ted");
        nameSetA.push("Theo");
        nameSetA.push("Tim");
        nameSetA.push("Tom");
        nameSetA.push("Troy");
        nameSetA.push("Tyler");
        nameSetA.push("Vince");
        nameSetA.push("Vitalik");
        nameSetA.push("Wade");
        nameSetA.push("Will");
        nameSetA.push("Wyatt");
        nameSetA.push("Zack");
        nameSetA.push("Zane");

        // Add initial Set B names (feminine)
        nameSetB.push("Alex");
        nameSetB.push("Amy");
        nameSetB.push("Anna");
        nameSetB.push("Aria");
        nameSetB.push("Astrid");
        nameSetB.push("Autumn");
        nameSetB.push("Belle");
        nameSetB.push("Beth");
        nameSetB.push("Blair");
        nameSetB.push("Brook");
        nameSetB.push("Brynn");
        nameSetB.push("Cara");
        nameSetB.push("Carmen");
        nameSetB.push("Celia");
        nameSetB.push("Claire");
        nameSetB.push("Clara");
        nameSetB.push("Colette");
        nameSetB.push("Cora");
        nameSetB.push("Daisy");
        nameSetB.push("Dawn");
        nameSetB.push("Diana");
        nameSetB.push("Dina");
        nameSetB.push("Eden");
        nameSetB.push("Ella");
        nameSetB.push("Ellie");
        nameSetB.push("Emma");
        nameSetB.push("Ember");
        nameSetB.push("Esme");
        nameSetB.push("Eva");
        nameSetB.push("Eve");
        nameSetB.push("Faith");
        nameSetB.push("Fay");
        nameSetB.push("Fiona");
        nameSetB.push("Flora");
        nameSetB.push("Freya");
        nameSetB.push("Gemma");
        nameSetB.push("Gina");
        nameSetB.push("Grace");
        nameSetB.push("Gwen");
        nameSetB.push("Hannah");
        nameSetB.push("Hazel");
        nameSetB.push("Holly");
        nameSetB.push("Hope");
        nameSetB.push("Indie");
        nameSetB.push("Iris");
        nameSetB.push("Isla");
        nameSetB.push("Ivy");
        nameSetB.push("Jade");
        nameSetB.push("Jane");
        nameSetB.push("Jordan");
        nameSetB.push("Julia");
        nameSetB.push("June");
        nameSetB.push("Kai");
        nameSetB.push("Kara");
        nameSetB.push("Kate");
        nameSetB.push("Kyra");
        nameSetB.push("Lark");
        nameSetB.push("Leah");
        nameSetB.push("Lena");
        nameSetB.push("Lily");
        nameSetB.push("Lisa");
        nameSetB.push("Lucy");
        nameSetB.push("Luna");
        nameSetB.push("Lyra");
        nameSetB.push("Mae");
        nameSetB.push("Maeve");
        nameSetB.push("Mara");
        nameSetB.push("Mary");
        nameSetB.push("Maya");
        nameSetB.push("Mira");
        nameSetB.push("Nina");
        nameSetB.push("Nora");
        nameSetB.push("Olivia");
        nameSetB.push("Paige");
        nameSetB.push("Pam");
        nameSetB.push("Pearl");
        nameSetB.push("Penny");
        nameSetB.push("Piper");
        nameSetB.push("Quinn");
        nameSetB.push("Rain");
        nameSetB.push("Raven");
        nameSetB.push("Rhea");
        nameSetB.push("Rose");
        nameSetB.push("Ruby");
        nameSetB.push("Sage");
        nameSetB.push("Sara");
        nameSetB.push("Sasha");
        nameSetB.push("Skye");
        nameSetB.push("Storm");
        nameSetB.push("Summer");
        nameSetB.push("Tara");
        nameSetB.push("Tess");
        nameSetB.push("Uma");
        nameSetB.push("Vale");
        nameSetB.push("Vera");
        nameSetB.push("Violet");
        nameSetB.push("Wendy");
        nameSetB.push("Wren");
        nameSetB.push("Yara");
        nameSetB.push("Zara");

        // Add initial surnames/titles
        // Direct Style Names (88 total)
        surnames.push("Ashbringer");
        surnames.push("Baneweaver");
        surnames.push("Blackforge");
        surnames.push("Bladesong");
        surnames.push("Bloodaxe");
        surnames.push("Bloodraven");
        surnames.push("Chainbreaker");
        surnames.push("Cloudweaver");
        surnames.push("Darkblade");
        surnames.push("Dawnbringer");
        surnames.push("Dawnstrike");
        surnames.push("Dawnwalker");
        surnames.push("Deathweaver");
        surnames.push("Doomforge");
        surnames.push("Dragonclaw");
        surnames.push("Dragonheart");
        surnames.push("Dreamforge");
        surnames.push("Dreamwalker");
        surnames.push("Dreadborn");
        surnames.push("Duskblade");
        surnames.push("Earthshaker");
        surnames.push("Emberblade");
        surnames.push("Fateweaver");
        surnames.push("Featherblade");
        surnames.push("Firecaller");
        surnames.push("Flamebrand");
        surnames.push("Flameheart");
        surnames.push("Frostbite");
        surnames.push("Frostborn");
        surnames.push("Frostcaller");
        surnames.push("Frostweaver");
        surnames.push("Ghostwalker");
        surnames.push("Gloomweaver");
        surnames.push("Godbringer");
        surnames.push("Goldheart");
        surnames.push("Gravewalker");
        surnames.push("Grimheart");
        surnames.push("Hellweaver");
        surnames.push("Highborne");
        surnames.push("Icecaller");
        surnames.push("Ironbound");
        surnames.push("Ironheart");
        surnames.push("Ironside");
        surnames.push("Ironwill");
        surnames.push("Lightbringer");
        surnames.push("Lightwalker");
        surnames.push("Lionheart");
        surnames.push("Lorekeeper");
        surnames.push("Moonblade");
        surnames.push("Moonshadow");
        surnames.push("Nightborne");
        surnames.push("Nightweaver");
        surnames.push("Oathkeeper");
        surnames.push("Peacekeeper");
        surnames.push("Planeswalker");
        surnames.push("Ragebringer");
        surnames.push("Rainweaver");
        surnames.push("Ravencall");
        surnames.push("Runebinder");
        surnames.push("Shadowbane");
        surnames.push("Shadowcaller");
        surnames.push("Shieldbreaker");
        surnames.push("Silverblade");
        surnames.push("Skullcrusher");
        surnames.push("Skydancer");
        surnames.push("Skyfinder");
        surnames.push("Soulbinder");
        surnames.push("Soulkeeper");
        surnames.push("Spellbinder");
        surnames.push("Spellforge");
        surnames.push("Spellsinger");
        surnames.push("Starcaller");
        surnames.push("Starweaver");
        surnames.push("Steelborn");
        surnames.push("Steelclaw");
        surnames.push("Steelfist");
        surnames.push("Steelstrike");
        surnames.push("Stormbringer");
        surnames.push("Stormborn");
        surnames.push("Stormcaller");
        surnames.push("Stormfist");
        surnames.push("Stormrage");
        surnames.push("Sunweaver");
        surnames.push("Swiftblade");
        surnames.push("Thornheart");
        surnames.push("Timeweaver");
        surnames.push("Truthbringer");
        surnames.push("Truthseeker");
        surnames.push("Voidwalker");
        surnames.push("Wolfheart");
        surnames.push("Worldshaper");

        // the _ Style Names (115 total)
        surnames.push("the Adamant");
        surnames.push("the Ancient");
        surnames.push("the Apprentice");
        surnames.push("the Arcane");
        surnames.push("the Astral");
        surnames.push("the Awakened");
        surnames.push("the Balanced");
        surnames.push("the Blessed");
        surnames.push("the Bold");
        surnames.push("the Boundless");
        surnames.push("the Brave");
        surnames.push("the Brilliant");
        surnames.push("the Champion");
        surnames.push("the Conqueror");
        surnames.push("the Crimson");
        surnames.push("the Cunning");
        surnames.push("the Dark");
        surnames.push("the Dauntless");
        surnames.push("the Defiant");
        surnames.push("the Destroyer");
        surnames.push("the Divine");
        surnames.push("the Dread");
        surnames.push("the Elder");
        surnames.push("the Enigmatic");
        surnames.push("the Enlightened");
        surnames.push("the Eternal");
        surnames.push("the Ethereal");
        surnames.push("the Exalted");
        surnames.push("the Fallen");
        surnames.push("the Fearless");
        surnames.push("the Feral");
        surnames.push("the Fierce");
        surnames.push("the Forsaken");
        surnames.push("the Frozen");
        surnames.push("the Furious");
        surnames.push("the Gallant");
        surnames.push("the Gifted");
        surnames.push("the Gladiator");
        surnames.push("the Golden");
        surnames.push("the Grand");
        surnames.push("the Greatsword");
        surnames.push("the Grim");
        surnames.push("the Hallowed");
        surnames.push("the Haunted");
        surnames.push("the Hidden");
        surnames.push("the Honored");
        surnames.push("the Immortal");
        surnames.push("the Imperial");
        surnames.push("the Impaler");
        surnames.push("the Indomitable");
        surnames.push("the Infernal");
        surnames.push("the Just");
        surnames.push("the Keen");
        surnames.push("the Last");
        surnames.push("the Legendary");
        surnames.push("the Lost");
        surnames.push("the Luminous");
        surnames.push("the Mad");
        surnames.push("the Majestic");
        surnames.push("the Merciless");
        surnames.push("the Mighty");
        surnames.push("the Mystic");
        surnames.push("the Nightblade");
        surnames.push("the Noble");
        surnames.push("the Novice");
        surnames.push("the Phantom");
        surnames.push("the Pious");
        surnames.push("the Pretty");
        surnames.push("the Primal");
        surnames.push("the Pure");
        surnames.push("the Radiant");
        surnames.push("the Regal");
        surnames.push("the Relentless");
        surnames.push("the Renowned");
        surnames.push("the Resolute");
        surnames.push("the Revered");
        surnames.push("the Righteous");
        surnames.push("the Sacred");
        surnames.push("the Savage");
        surnames.push("the Scarred");
        surnames.push("the Silent");
        surnames.push("the Sinister");
        surnames.push("the Solemn");
        surnames.push("the Soulless");
        surnames.push("the Spectral");
        surnames.push("the Stalwart");
        surnames.push("the Steadfast");
        surnames.push("the Stoic");
        surnames.push("the Strange");
        surnames.push("the Swift");
        surnames.push("the Tenacious");
        surnames.push("the Timeless");
        surnames.push("the True");
        surnames.push("the Undefeated");
        surnames.push("the Unstoppable");
        surnames.push("the Untamed");
        surnames.push("the Unyielding");
        surnames.push("the Valiant");
        surnames.push("the Vengeful");
        surnames.push("the Victorious");
        surnames.push("the Vigilant");
        surnames.push("the Viking");
        surnames.push("the Virtuous");
        surnames.push("the Wandering");
        surnames.push("the Warlord");
        surnames.push("the Warrior");
        surnames.push("the Wild");
        surnames.push("the Wise");
        surnames.push("the Wrathful");
        surnames.push("the Young");
        surnames.push("the Zealous");

        // of _ Style Names (97 total)
        surnames.push("of the Abyss");
        surnames.push("of the Ancients");
        surnames.push("of the Arcane");
        surnames.push("of the Autumn");
        surnames.push("of the Azure");
        surnames.push("of the Blade");
        surnames.push("of the Blood");
        surnames.push("of the Cinder");
        surnames.push("of the Cosmos");
        surnames.push("of the Coven");
        surnames.push("of the Crimson");
        surnames.push("of the Crown");
        surnames.push("of the Crystal");
        surnames.push("of the Dawn");
        surnames.push("of the Deep");
        surnames.push("of the Depths");
        surnames.push("of the Desert");
        surnames.push("of the Divine");
        surnames.push("of the Dragon");
        surnames.push("of the Dread");
        surnames.push("of the Dusk");
        surnames.push("of the East");
        surnames.push("of the Eclipse");
        surnames.push("of the Elder");
        surnames.push("of the Ember");
        surnames.push("of the Empire");
        surnames.push("of the Eternal");
        surnames.push("of the Fallen");
        surnames.push("of the Fang");
        surnames.push("of the Flame");
        surnames.push("of the Forest");
        surnames.push("of the Frost");
        surnames.push("of the Glade");
        surnames.push("of the Grove");
        surnames.push("of the Haven");
        surnames.push("of the Heart");
        surnames.push("of the Hills");
        surnames.push("of the Ice");
        surnames.push("of the Isle");
        surnames.push("of the Light");
        surnames.push("of the Mist");
        surnames.push("of the Moon");
        surnames.push("of the Mountain");
        surnames.push("of the Night");
        surnames.push("of the North");
        surnames.push("of the Oasis");
        surnames.push("of the Ocean");
        surnames.push("of the Oracle");
        surnames.push("of the Peaks");
        surnames.push("of the Phoenix");
        surnames.push("of the Pyre");
        surnames.push("of the Realm");
        surnames.push("of the Rift");
        surnames.push("of the River");
        surnames.push("of the Rose");
        surnames.push("of the Rune");
        surnames.push("of the Sands");
        surnames.push("of the Sea");
        surnames.push("of the Shadow");
        surnames.push("of the Shore");
        surnames.push("of the Sky");
        surnames.push("of the Snow");
        surnames.push("of the South");
        surnames.push("of the Spire");
        surnames.push("of the Spring");
        surnames.push("of the Stars");
        surnames.push("of the Stone");
        surnames.push("of the Storm");
        surnames.push("of the Summer");
        surnames.push("of the Sun");
        surnames.push("of the Sunset");
        surnames.push("of the Sword");
        surnames.push("of the Temple");
        surnames.push("of the Throne");
        surnames.push("of the Thunder");
        surnames.push("of the Tide");
        surnames.push("of the Tomb");
        surnames.push("of the Tower");
        surnames.push("of the Twilight");
        surnames.push("of the Vale");
        surnames.push("of the Valley");
        surnames.push("of the Veil");
        surnames.push("of the Void");
        surnames.push("of the Ward");
        surnames.push("of the Watch");
        surnames.push("of the West");
        surnames.push("of the Wilds");
        surnames.push("of the Wind");
        surnames.push("of the Winter");
        surnames.push("of the Wood");
        surnames.push("of the World");
        surnames.push("of the Wyrm");
        surnames.push("of the Year");
        surnames.push("of the Zenith");
    }

    function addNamesToSetA(string[] calldata names) external onlyOwner validateNames(names) {
        uint16 newLength = uint16(nameSetA.length + names.length);
        if (SET_A_START + newLength > type(uint16).max) revert MaxNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetA.push(names[i]);
            emit NameAdded(0, SET_A_START + uint16(nameSetA.length) - 1, names[i]);
        }
    }

    function addNamesToSetB(string[] calldata names) external onlyOwner validateNames(names) {
        if (nameSetB.length + names.length > SET_B_MAX + 1) revert MaxSetBNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetB.push(names[i]);
            emit NameAdded(1, uint16(nameSetB.length - 1), names[i]);
        }
    }

    function addSurnames(string[] calldata names) external onlyOwner validateNames(names) {
        if (surnames.length + names.length > type(uint16).max) revert MaxSurnamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            surnames.push(names[i]);
            emit NameAdded(2, uint16(surnames.length - 1), names[i]);
        }
    }

    function getFullName(uint16 firstNameIndex, uint16 surnameIndex)
        external
        view
        returns (string memory firstName, string memory surname)
    {
        if (firstNameIndex < SET_A_START) {
            if (firstNameIndex >= nameSetB.length) revert InvalidNameIndexSetB();
            firstName = nameSetB[firstNameIndex];
        } else {
            uint16 setAIndex = firstNameIndex - SET_A_START;
            if (setAIndex >= nameSetA.length) revert InvalidNameIndexSetA();
            firstName = nameSetA[setAIndex];
        }

        if (surnameIndex >= surnames.length) revert InvalidSurnameIndex();
        surname = surnames[surnameIndex];
    }

    // View functions
    function getNameSetALength() external view returns (uint16) {
        return uint16(nameSetA.length);
    }

    function getNameSetBLength() external view returns (uint16) {
        return uint16(nameSetB.length);
    }

    function getSurnamesLength() external view returns (uint16) {
        return uint16(surnames.length);
    }
}
