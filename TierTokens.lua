--[[
    LootCheck - TierTokens.lua

    T4 / T5 / T6 set piece -> token mapping, used when a That's My BIS CSV is
    imported: wishlists name the redeemed armour piece, but the token is what
    drops (and what Gargul awards), so entries are rewritten to the token.

    Ported from TMBExport's TierTokens.lua
    (MIT License, Copyright (c) 2026 Centpoursang - Spineshatter).
]]

local LC = LootCheck
LC.PIECE_TO_TOKEN = {
    -- ============================================================
    -- T4 PIECES (Karazhan/Gruul/Magtheridon)
    -- ============================================================

    -- Warrior T4: Warbringer Armor (Protection - Defender)
    ["Warbringer Greathelm"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Warbringer Shoulderguards"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Warbringer Chestguard"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Warbringer Handguards"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Warbringer Legguards"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Warrior T4: Warbringer Battlegear (DPS - Defender)
    ["Warbringer Battle-Helm"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Warbringer Shoulderplates"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Warbringer Breastplate"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Warbringer Gauntlets"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Warbringer Greaves"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Paladin T4: Justicar Armor (Protection - Champion)
    ["Justicar Faceguard"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Justicar Shoulderguards"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Justicar Chestguard"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Justicar Handguards"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Justicar Legguards"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Paladin T4: Justicar Battlegear (Retribution - Champion)
    ["Justicar Crown"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Justicar Shoulderplates"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Justicar Breastplate"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Justicar Gauntlets"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Justicar Greaves"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Paladin T4: Justicar Raiment (Holy - Champion)
    ["Justicar Diadem"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Justicar Pauldrons"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Justicar Chestpiece"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Justicar Gloves"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Justicar Leggings"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Hunter T4: Demon Stalker Armor (Hero)
    ["Demon Stalker Greathelm"] = { token = "Helm of the Fallen Hero", token_id = 29759, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Demon Stalker Shoulderguards"] = { token = "Pauldrons of the Fallen Hero", token_id = 29762, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Demon Stalker Harness"] = { token = "Chestguard of the Fallen Hero", token_id = 29755, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Demon Stalker Gauntlets"] = { token = "Gloves of the Fallen Hero", token_id = 29756, source = "The Curator", instance = "Karazhan" },
    ["Demon Stalker Greaves"] = { token = "Leggings of the Fallen Hero", token_id = 29765, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Rogue T4: Netherblade (Champion)
    ["Netherblade Facemask"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Netherblade Shoulderpads"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Netherblade Chestpiece"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Netherblade Gloves"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Netherblade Breeches"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Priest T4: Incarnate Raiment (Holy - Defender)
    ["Light-Collar of the Incarnate"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Light-Mantle of the Incarnate"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Robes of the Incarnate"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Handwraps of the Incarnate"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Trousers of the Incarnate"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Priest T4: Incarnate Regalia (Shadow - Defender)
    ["Soul-Collar of the Incarnate"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Soul-Mantle of the Incarnate"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Shroud of the Incarnate"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Gloves of the Incarnate"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Leggings of the Incarnate"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Shaman T4: Cyclone Harness (Enhancement - Champion)
    ["Cyclone Helm"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Cyclone Shoulderplates"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Cyclone Breastplate"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Cyclone Gauntlets"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Cyclone War-Kilt"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Shaman T4: Cyclone Regalia (Elemental - Champion)
    ["Cyclone Faceguard"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Cyclone Shoulderguards"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Cyclone Chestguard"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Cyclone Handguards"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Cyclone Legguards"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Shaman T4: Cyclone Raiment (Restoration - Champion)
    ["Cyclone Headdress"] = { token = "Helm of the Fallen Champion", token_id = 29760, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Cyclone Shoulderpads"] = { token = "Pauldrons of the Fallen Champion", token_id = 29763, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Cyclone Hauberk"] = { token = "Chestguard of the Fallen Champion", token_id = 29754, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Cyclone Gloves"] = { token = "Gloves of the Fallen Champion", token_id = 29757, source = "The Curator", instance = "Karazhan" },
    ["Cyclone Kilt"] = { token = "Leggings of the Fallen Champion", token_id = 29766, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Mage T4: Aldor Regalia (Hero)
    ["Collar of the Aldor"] = { token = "Helm of the Fallen Hero", token_id = 29759, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Pauldrons of the Aldor"] = { token = "Pauldrons of the Fallen Hero", token_id = 29762, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Vestments of the Aldor"] = { token = "Chestguard of the Fallen Hero", token_id = 29755, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Gloves of the Aldor"] = { token = "Gloves of the Fallen Hero", token_id = 29756, source = "The Curator", instance = "Karazhan" },
    ["Legwraps of the Aldor"] = { token = "Leggings of the Fallen Hero", token_id = 29765, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Warlock T4: Voidheart Raiment (Hero)
    ["Voidheart Crown"] = { token = "Helm of the Fallen Hero", token_id = 29759, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Voidheart Mantle"] = { token = "Pauldrons of the Fallen Hero", token_id = 29762, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Voidheart Robe"] = { token = "Chestguard of the Fallen Hero", token_id = 29755, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Voidheart Gloves"] = { token = "Gloves of the Fallen Hero", token_id = 29756, source = "The Curator", instance = "Karazhan" },
    ["Voidheart Leggings"] = { token = "Leggings of the Fallen Hero", token_id = 29765, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Druid T4: Malorne Harness (Feral - Defender)
    ["Stag-Helm of Malorne"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Mantle of Malorne"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Breastplate of Malorne"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Gauntlets of Malorne"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Greaves of Malorne"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Druid T4: Malorne Regalia (Balance - Defender)
    ["Antlers of Malorne"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Pauldrons of Malorne"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Chestpiece of Malorne"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Gloves of Malorne"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Britches of Malorne"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- Druid T4: Malorne Raiment (Restoration - Defender)
    ["Crown of Malorne"] = { token = "Helm of the Fallen Defender", token_id = 29761, source = "Prince Malchezaar", instance = "Karazhan" },
    ["Shoulderguards of Malorne"] = { token = "Pauldrons of the Fallen Defender", token_id = 29764, source = "High King Maulgar", instance = "Gruul's Lair" },
    ["Chestguard of Malorne"] = { token = "Chestguard of the Fallen Defender", token_id = 29753, source = "Magtheridon", instance = "Magtheridon's Lair" },
    ["Handguards of Malorne"] = { token = "Gloves of the Fallen Defender", token_id = 29758, source = "The Curator", instance = "Karazhan" },
    ["Legguards of Malorne"] = { token = "Leggings of the Fallen Defender", token_id = 29767, source = "Gruul the Dragonkiller", instance = "Gruul's Lair" },

    -- ============================================================
    -- T5 PIECES (SSC, Tempest Keep)
    -- ============================================================

    -- Warrior T5: Destroyer Armor (Protection - Defender)
    ["Destroyer Greathelm"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Destroyer Shoulderguards"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Destroyer Chestguard"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Destroyer Handguards"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Destroyer Legguards"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Warrior T5: Destroyer Battlegear (DPS - Defender)
    ["Destroyer Battle-Helm"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Destroyer Shoulderblades"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Destroyer Breastplate"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Destroyer Gauntlets"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Destroyer Greaves"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Paladin T5: Crystalforge Armor (Protection - Champion)
    ["Crystalforge Faceguard"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Crystalforge Shoulderguards"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Crystalforge Chestguard"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Crystalforge Handguards"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Crystalforge Legguards"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Paladin T5: Crystalforge Battlegear (Retribution - Champion)
    ["Crystalforge War-Helm"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Crystalforge Shoulderbraces"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Crystalforge Breastplate"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Crystalforge Gauntlets"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Crystalforge Greaves"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Paladin T5: Crystalforge Raiment (Holy - Champion)
    ["Crystalforge Greathelm"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Crystalforge Pauldrons"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Crystalforge Chestpiece"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Crystalforge Gloves"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Crystalforge Leggings"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Hunter T5: Rift Stalker Armor (Hero)
    ["Rift Stalker Helm"] = { token = "Helm of the Vanquished Hero", token_id = 30244, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Rift Stalker Mantle"] = { token = "Pauldrons of the Vanquished Hero", token_id = 30250, source = "Void Reaver", instance = "Tempest Keep" },
    ["Rift Stalker Hauberk"] = { token = "Chestguard of the Vanquished Hero", token_id = 30238, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Rift Stalker Gauntlets"] = { token = "Gloves of the Vanquished Hero", token_id = 30241, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Rift Stalker Leggings"] = { token = "Leggings of the Vanquished Hero", token_id = 30247, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Rogue T5: Deathmantle (Champion)
    ["Deathmantle Helm"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Deathmantle Shoulderpads"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Deathmantle Chestguard"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Deathmantle Handguards"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Deathmantle Legguards"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Priest T5: Avatar Raiment (Holy - Defender)
    ["Cowl of the Avatar"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Mantle of the Avatar"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Vestments of the Avatar"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Gloves of the Avatar"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Breeches of the Avatar"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Priest T5: Avatar Regalia (Shadow - Defender)
    ["Hood of the Avatar"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Wings of the Avatar"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Shroud of the Avatar"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Handguards of the Avatar"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Leggings of the Avatar"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Shaman T5: Cataclysm Harness (Enhancement - Champion)
    ["Cataclysm Helm"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Cataclysm Shoulderplates"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Cataclysm Chestplate"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Cataclysm Gauntlets"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Cataclysm Legplates"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Shaman T5: Cataclysm Regalia (Elemental - Champion)
    ["Cataclysm Headpiece"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Cataclysm Shoulderpads"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Cataclysm Chestpiece"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Cataclysm Handgrips"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Cataclysm Leggings"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Shaman T5: Cataclysm Raiment (Restoration - Champion)
    ["Cataclysm Headguard"] = { token = "Helm of the Vanquished Champion", token_id = 30242, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Cataclysm Shoulderguards"] = { token = "Pauldrons of the Vanquished Champion", token_id = 30248, source = "Void Reaver", instance = "Tempest Keep" },
    ["Cataclysm Chestguard"] = { token = "Chestguard of the Vanquished Champion", token_id = 30236, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Cataclysm Gloves"] = { token = "Gloves of the Vanquished Champion", token_id = 30239, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Cataclysm Legguards"] = { token = "Leggings of the Vanquished Champion", token_id = 30245, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Mage T5: Tirisfal Regalia (Hero)
    ["Cowl of Tirisfal"] = { token = "Helm of the Vanquished Hero", token_id = 30244, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Mantle of Tirisfal"] = { token = "Pauldrons of the Vanquished Hero", token_id = 30250, source = "Void Reaver", instance = "Tempest Keep" },
    ["Robes of Tirisfal"] = { token = "Chestguard of the Vanquished Hero", token_id = 30238, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Gloves of Tirisfal"] = { token = "Gloves of the Vanquished Hero", token_id = 30241, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Leggings of Tirisfal"] = { token = "Leggings of the Vanquished Hero", token_id = 30247, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Warlock T5: Corruptor Raiment (Hero)
    ["Hood of the Corruptor"] = { token = "Helm of the Vanquished Hero", token_id = 30244, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Mantle of the Corruptor"] = { token = "Pauldrons of the Vanquished Hero", token_id = 30250, source = "Void Reaver", instance = "Tempest Keep" },
    ["Robe of the Corruptor"] = { token = "Chestguard of the Vanquished Hero", token_id = 30238, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Gloves of the Corruptor"] = { token = "Gloves of the Vanquished Hero", token_id = 30241, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Leggings of the Corruptor"] = { token = "Leggings of the Vanquished Hero", token_id = 30247, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Druid T5: Nordrassil Harness (Feral - Defender)
    ["Nordrassil Headdress"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Nordrassil Feral-Mantle"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Nordrassil Chestplate"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Nordrassil Handgrips"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Nordrassil Feral-Kilt"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Druid T5: Nordrassil Regalia (Balance - Defender)
    ["Nordrassil Headpiece"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Nordrassil Wrath-Mantle"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Nordrassil Chestpiece"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Nordrassil Gauntlets"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Nordrassil Wrath-Kilt"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- Druid T5: Nordrassil Raiment (Restoration - Defender)
    ["Nordrassil Headguard"] = { token = "Helm of the Vanquished Defender", token_id = 30243, source = "Lady Vashj", instance = "Serpentshrine Cavern" },
    ["Nordrassil Life-Mantle"] = { token = "Pauldrons of the Vanquished Defender", token_id = 30249, source = "Void Reaver", instance = "Tempest Keep" },
    ["Nordrassil Chestguard"] = { token = "Chestguard of the Vanquished Defender", token_id = 30237, source = "Kael'thas Sunstrider", instance = "Tempest Keep" },
    ["Nordrassil Gloves"] = { token = "Gloves of the Vanquished Defender", token_id = 30240, source = "Leotheras the Blind", instance = "Serpentshrine Cavern" },
    ["Nordrassil Life-Kilt"] = { token = "Leggings of the Vanquished Defender", token_id = 30246, source = "Fathom-Lord Karathress", instance = "Serpentshrine Cavern" },

    -- ============================================================
    -- T6 PIECES (Hyjal, Black Temple, Sunwell)
    -- ============================================================

    -- Warrior T6: Onslaught Armor (Protection - Protector)
    ["Onslaught Greathelm"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Onslaught Shoulderguards"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Onslaught Chestguard"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Onslaught Handguards"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Onslaught Legguards"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Onslaught Wristguards"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Onslaught Waistguard"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Onslaught Boots"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Warrior T6: Onslaught Battlegear (DPS - Protector)
    ["Onslaught Battle-Helm"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Onslaught Shoulderblades"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Onslaught Breastplate"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Onslaught Gauntlets"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Onslaught Greaves"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Onslaught Bracers"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Onslaught Belt"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Onslaught Treads"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Paladin T6: Lightbringer Armor (Protection - Conqueror)
    ["Lightbringer Faceguard"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Lightbringer Shoulderguards"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Lightbringer Chestguard"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Lightbringer Handguards"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Lightbringer Legguards"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Lightbringer Wristguards"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Lightbringer Waistguard"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Lightbringer Stompers"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Paladin T6: Lightbringer Battlegear (Retribution - Conqueror)
    ["Lightbringer War-Helm"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Lightbringer Shoulderbraces"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Lightbringer Breastplate"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Lightbringer Gauntlets"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Lightbringer Greaves"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Lightbringer Bands"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Lightbringer Girdle"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Lightbringer Boots"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Paladin T6: Lightbringer Raiment (Holy - Conqueror)
    ["Lightbringer Greathelm"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Lightbringer Pauldrons"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Lightbringer Chestpiece"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Lightbringer Gloves"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Lightbringer Leggings"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Lightbringer Bracers"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Lightbringer Belt"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Lightbringer Treads"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Hunter T6: Gronnstalker's Armor (Protector)
    ["Gronnstalker's Helmet"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Gronnstalker's Spaulders"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Gronnstalker's Chestguard"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Gronnstalker's Gloves"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Gronnstalker's Leggings"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Gronnstalker's Bracers"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Gronnstalker's Belt"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Gronnstalker's Boots"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Rogue T6: Slayer's Armor (Vanquisher)
    ["Slayer's Helm"] = { token = "Helm of the Forgotten Vanquisher", token_id = 31096, source = "Archimonde", instance = "Hyjal Summit" },
    ["Slayer's Shoulderpads"] = { token = "Pauldrons of the Forgotten Vanquisher", token_id = 31102, source = "Mother Shahraz", instance = "Black Temple" },
    ["Slayer's Chestguard"] = { token = "Chestguard of the Forgotten Vanquisher", token_id = 31090, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Slayer's Handguards"] = { token = "Gloves of the Forgotten Vanquisher", token_id = 31093, source = "Azgalor", instance = "Hyjal Summit" },
    ["Slayer's Legguards"] = { token = "Leggings of the Forgotten Vanquisher", token_id = 31099, source = "Illidari Council", instance = "Black Temple" },
    ["Slayer's Bracers"] = { token = "Bracers of the Forgotten Vanquisher", token_id = 34852, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Slayer's Belt"] = { token = "Belt of the Forgotten Vanquisher", token_id = 34855, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Slayer's Boots"] = { token = "Boots of the Forgotten Vanquisher", token_id = 34858, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Priest T6: Vestments of Absolution (Holy - Conqueror)
    ["Cowl of Absolution"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Mantle of Absolution"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Vestments of Absolution"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Gloves of Absolution"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Breeches of Absolution"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Cuffs of Absolution"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Belt of Absolution"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Boots of Absolution"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Priest T6: Absolution Regalia (Shadow - Conqueror)
    ["Hood of Absolution"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Shoulderpads of Absolution"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Shroud of Absolution"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Handguards of Absolution"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Leggings of Absolution"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Bracers of Absolution"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Cord of Absolution"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Treads of Absolution"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Shaman T6: Skyshatter Harness (Enhancement - Protector)
    ["Skyshatter Cover"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Skyshatter Pauldrons"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Skyshatter Tunic"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Skyshatter Grips"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Skyshatter Pants"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Skyshatter Wristguards"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Skyshatter Girdle"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Skyshatter Greaves"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Shaman T6: Skyshatter Regalia (Elemental - Protector)
    ["Skyshatter Headguard"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Skyshatter Mantle"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Skyshatter Breastplate"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Skyshatter Gauntlets"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Skyshatter Legguards"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Skyshatter Bands"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Skyshatter Cord"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Skyshatter Treads"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Shaman T6: Skyshatter Raiment (Restoration - Protector)
    ["Skyshatter Helmet"] = { token = "Helm of the Forgotten Protector", token_id = 31095, source = "Archimonde", instance = "Hyjal Summit" },
    ["Skyshatter Shoulderpads"] = { token = "Pauldrons of the Forgotten Protector", token_id = 31103, source = "Mother Shahraz", instance = "Black Temple" },
    ["Skyshatter Chestguard"] = { token = "Chestguard of the Forgotten Protector", token_id = 31091, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Skyshatter Gloves"] = { token = "Gloves of the Forgotten Protector", token_id = 31094, source = "Azgalor", instance = "Hyjal Summit" },
    ["Skyshatter Leggings"] = { token = "Leggings of the Forgotten Protector", token_id = 31100, source = "Illidari Council", instance = "Black Temple" },
    ["Skyshatter Bracers"] = { token = "Bracers of the Forgotten Protector", token_id = 34851, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Skyshatter Belt"] = { token = "Belt of the Forgotten Protector", token_id = 34854, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Skyshatter Boots"] = { token = "Boots of the Forgotten Protector", token_id = 34857, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Mage T6: Tempest Regalia (Vanquisher)
    ["Cowl of the Tempest"] = { token = "Helm of the Forgotten Vanquisher", token_id = 31096, source = "Archimonde", instance = "Hyjal Summit" },
    ["Mantle of the Tempest"] = { token = "Pauldrons of the Forgotten Vanquisher", token_id = 31102, source = "Mother Shahraz", instance = "Black Temple" },
    ["Robes of the Tempest"] = { token = "Chestguard of the Forgotten Vanquisher", token_id = 31090, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Gloves of the Tempest"] = { token = "Gloves of the Forgotten Vanquisher", token_id = 31093, source = "Azgalor", instance = "Hyjal Summit" },
    ["Leggings of the Tempest"] = { token = "Leggings of the Forgotten Vanquisher", token_id = 31099, source = "Illidari Council", instance = "Black Temple" },
    ["Bracers of the Tempest"] = { token = "Bracers of the Forgotten Vanquisher", token_id = 34852, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Belt of the Tempest"] = { token = "Belt of the Forgotten Vanquisher", token_id = 34855, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Boots of the Tempest"] = { token = "Boots of the Forgotten Vanquisher", token_id = 34858, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Warlock T6: Malefic Raiment (Conqueror)
    ["Hood of the Malefic"] = { token = "Helm of the Forgotten Conqueror", token_id = 31097, source = "Archimonde", instance = "Hyjal Summit" },
    ["Mantle of the Malefic"] = { token = "Pauldrons of the Forgotten Conqueror", token_id = 31101, source = "Mother Shahraz", instance = "Black Temple" },
    ["Robe of the Malefic"] = { token = "Chestguard of the Forgotten Conqueror", token_id = 31089, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Gloves of the Malefic"] = { token = "Gloves of the Forgotten Conqueror", token_id = 31092, source = "Azgalor", instance = "Hyjal Summit" },
    ["Leggings of the Malefic"] = { token = "Leggings of the Forgotten Conqueror", token_id = 31098, source = "Illidari Council", instance = "Black Temple" },
    ["Bracers of the Malefic"] = { token = "Bracers of the Forgotten Conqueror", token_id = 34848, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Belt of the Malefic"] = { token = "Belt of the Forgotten Conqueror", token_id = 34853, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Boots of the Malefic"] = { token = "Boots of the Forgotten Conqueror", token_id = 34856, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Druid T6: Thunderheart Harness (Feral - Vanquisher)
    ["Thunderheart Cover"] = { token = "Helm of the Forgotten Vanquisher", token_id = 31096, source = "Archimonde", instance = "Hyjal Summit" },
    ["Thunderheart Pauldrons"] = { token = "Pauldrons of the Forgotten Vanquisher", token_id = 31102, source = "Mother Shahraz", instance = "Black Temple" },
    ["Thunderheart Chestguard"] = { token = "Chestguard of the Forgotten Vanquisher", token_id = 31090, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Thunderheart Gauntlets"] = { token = "Gloves of the Forgotten Vanquisher", token_id = 31093, source = "Azgalor", instance = "Hyjal Summit" },
    ["Thunderheart Leggings"] = { token = "Leggings of the Forgotten Vanquisher", token_id = 31099, source = "Illidari Council", instance = "Black Temple" },
    ["Thunderheart Wristguards"] = { token = "Bracers of the Forgotten Vanquisher", token_id = 34852, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Thunderheart Waistguard"] = { token = "Belt of the Forgotten Vanquisher", token_id = 34855, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Thunderheart Treads"] = { token = "Boots of the Forgotten Vanquisher", token_id = 34858, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Druid T6: Thunderheart Regalia (Balance - Vanquisher)
    ["Thunderheart Headguard"] = { token = "Helm of the Forgotten Vanquisher", token_id = 31096, source = "Archimonde", instance = "Hyjal Summit" },
    ["Thunderheart Shoulderpads"] = { token = "Pauldrons of the Forgotten Vanquisher", token_id = 31102, source = "Mother Shahraz", instance = "Black Temple" },
    ["Thunderheart Vest"] = { token = "Chestguard of the Forgotten Vanquisher", token_id = 31090, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Thunderheart Handguards"] = { token = "Gloves of the Forgotten Vanquisher", token_id = 31093, source = "Azgalor", instance = "Hyjal Summit" },
    ["Thunderheart Pants"] = { token = "Leggings of the Forgotten Vanquisher", token_id = 31099, source = "Illidari Council", instance = "Black Temple" },
    ["Thunderheart Bands"] = { token = "Bracers of the Forgotten Vanquisher", token_id = 34852, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Thunderheart Cord"] = { token = "Belt of the Forgotten Vanquisher", token_id = 34855, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Thunderheart Footwraps"] = { token = "Boots of the Forgotten Vanquisher", token_id = 34858, source = "Felmyst", instance = "Sunwell Plateau" },

    -- Druid T6: Thunderheart Raiment (Restoration - Vanquisher)
    ["Thunderheart Helmet"] = { token = "Helm of the Forgotten Vanquisher", token_id = 31096, source = "Archimonde", instance = "Hyjal Summit" },
    ["Thunderheart Spaulders"] = { token = "Pauldrons of the Forgotten Vanquisher", token_id = 31102, source = "Mother Shahraz", instance = "Black Temple" },
    ["Thunderheart Tunic"] = { token = "Chestguard of the Forgotten Vanquisher", token_id = 31090, source = "Illidan Stormrage", instance = "Black Temple" },
    ["Thunderheart Gloves"] = { token = "Gloves of the Forgotten Vanquisher", token_id = 31093, source = "Azgalor", instance = "Hyjal Summit" },
    ["Thunderheart Legguards"] = { token = "Leggings of the Forgotten Vanquisher", token_id = 31099, source = "Illidari Council", instance = "Black Temple" },
    ["Thunderheart Bracers"] = { token = "Bracers of the Forgotten Vanquisher", token_id = 34852, source = "Kalecgos", instance = "Sunwell Plateau" },
    ["Thunderheart Belt"] = { token = "Belt of the Forgotten Vanquisher", token_id = 34855, source = "Brutallus", instance = "Sunwell Plateau" },
    ["Thunderheart Boots"] = { token = "Boots of the Forgotten Vanquisher", token_id = 34858, source = "Felmyst", instance = "Sunwell Plateau" },
}

-- Rewrite a wishlist entries list in place: any entry whose item_name
-- matches a known set piece is converted to the corresponding token
-- (item_id, item_name, source_name, instance_name).
-- Entries already keyed on a token, or unrelated items (crafted, etc.),
-- are left untouched.
function LC:RemapTierPieces(entries)
    if not entries then return 0 end
    local count = 0
    for _, entry in ipairs(entries) do
        local map = self.PIECE_TO_TOKEN and self.PIECE_TO_TOKEN[entry.item_name]
        if map then
            entry.item_name = map.token
            entry.item_id = map.token_id
            entry.source_name = map.source
            entry.instance_name = map.instance
            count = count + 1
        end
    end
    return count
end
