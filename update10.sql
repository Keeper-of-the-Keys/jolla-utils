-- Update 9
DROP INDEX DetailsJoinIndex;
PRAGMA user_version=10;
-- End update 9

-- Drop the remove trigger
DROP TRIGGER RemoveContactDetails;
-- Preserve the existing state of the Details table
ALTER TABLE Details RENAME TO OldDetails;
-- Create an index to map new version of detail rows to the old ones
CREATE TEMP TABLE DetailsIndexing(
        detailId INTEGER PRIMARY KEY ASC AUTOINCREMENT,
        oldDetailId INTEGER,
        contactId INTEGER,
        detail TEXT,
        syncTarget TEXT,
        provenance TEXT);
    
INSERT INTO DetailsIndexing(oldDetailId, contactId, detail, syncTarget, provenance)
        SELECT OD.detailId, OD.contactId, OD.detail, Contacts.syncTarget, CASE WHEN Contacts.syncTarget = 'aggregate' THEN OD.provenance ELSE '' END
        FROM OldDetails AS OD
        JOIN Contacts ON Contacts.contactId = OD.contactId;

-- Index the indexing table by the detail ID and type name used to select from it
CREATE INDEX DetailsIndexingOldDetailIdIndex ON DetailsIndexing(oldDetailId);
CREATE INDEX DetailsIndexingDetailIndex ON DetailsIndexing(detail);

-- Find the new detail ID for existing provenance ID values
CREATE TEMP TABLE ProvenanceIndexing(
	detailId INTEGER PRIMARY KEY,
	detail TEXT,
	provenance TEXT,
	provenanceContactId TEXT,
	provenanceDetailId TEXT,
	provenanceSyncTarget TEXT,
	newProvenanceDetailId TEXT);

INSERT INTO ProvenanceIndexing(detailId, detail, provenance) 
	SELECT detailId, detail, provenance 
		FROM DetailsIndexing 
			WHERE provenance != '';

-- Calculate the new equivalent form for the existing 'provenance' values
UPDATE ProvenanceIndexing SET 
	provenanceContactId = substr(provenance, 0, instr(provenance, ':')),
	provenance = substr(provenance, instr(provenance, ':') + 1);

UPDATE ProvenanceIndexing SET 
	provenanceDetailId = substr(provenance, 0, instr(provenance, ':')),
	provenanceSyncTarget = substr(provenance, instr(provenance, ':') + 1),
	provenance = '';

REPLACE INTO ProvenanceIndexing (detailId, provenance) 
	SELECT PI.detailId, PI.provenanceContactId || ':' || DI.detailId || ':' || PI.provenanceSyncTarget 
		FROM ProvenanceIndexing AS PI 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = PI.provenanceDetailId AND DI.detail = PI.detail;

-- Update the provenance values in the DetailsIndexing table with the updated values
REPLACE INTO DetailsIndexing (detailId, oldDetailId, contactId, detail, syncTarget, provenance) 
	SELECT PI.detailId, DI.oldDetailId, DI.contactId, DI.detail, DI.syncTarget, PI.provenance 
		FROM ProvenanceIndexing PI 
			JOIN DetailsIndexing DI ON DI.detailId = PI.detailId;

DROP TABLE ProvenanceIndexing;

-- Re-create and populate the Details table from the old version
CREATE TABLE Details (
	detailId INTEGER PRIMARY KEY ASC AUTOINCREMENT,
	contactId INTEGER REFERENCES Contacts (contactId),
	detail TEXT,
	detailUri TEXT,
	linkedDetailUris TEXT,
	contexts TEXT,
	accessConstraints INTEGER,
	provenance TEXT,
	modifiable BOOL,
	nonexportable BOOL);

INSERT INTO Details(
	detailId,
	contactId,
	detail,
	detailUri,
	linkedDetailUris,
	contexts,
	accessConstraints,
	provenance,
	modifiable,
	nonexportable) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.detail,
		OD.detailUri,
		OD.linkedDetailUris,
		OD.contexts,
		OD.accessConstraints,
		DI.provenance,
		OD.modifiable,
		OD.nonexportable 
		FROM DetailsIndexing AS DI 
			JOIN OldDetails AS OD ON OD.detailId = DI.oldDetailId AND OD.detail = DI.detail;

DROP INDEX IF EXISTS DetailsJoinIndex;
DROP INDEX DetailsRemoveIndex;
DROP TABLE OldDetails;

-- Drop all indexes for tables we are rebuilding
DROP INDEX createAddressesDetailsContactIdIndex;
DROP INDEX createAnniversariesDetailsContactIdIndex;
DROP INDEX createAvatarsDetailsContactIdIndex;
DROP INDEX createBirthdaysDetailsContactIdIndex;
DROP INDEX createEmailAddressesDetailsContactIdIndex;
DROP INDEX createGlobalPresencesDetailsContactIdIndex;
DROP INDEX createGuidsDetailsContactIdIndex;
DROP INDEX createHobbiesDetailsContactIdIndex;
DROP INDEX createNicknamesDetailsContactIdIndex;
DROP INDEX createNotesDetailsContactIdIndex;
DROP INDEX createOnlineAccountsDetailsContactIdIndex;
DROP INDEX createOrganizationsDetailsContactIdIndex;
DROP INDEX createPhoneNumbersDetailsContactIdIndex;
DROP INDEX createPresencesDetailsContactIdIndex;
DROP INDEX createRingtonesDetailsContactIdIndex;
DROP INDEX createTagsDetailsContactIdIndex;
DROP INDEX createUrlsDetailsContactIdIndex;
DROP INDEX createTpMetadataDetailsContactIdIndex;
DROP INDEX createExtendedDetailsContactIdIndex;
DROP INDEX PhoneNumbersIndex;
DROP INDEX EmailAddressesIndex;
DROP INDEX OnlineAccountsIndex;
DROP INDEX NicknamesIndex;
DROP INDEX TpMetadataTelepathyIdIndex;
DROP INDEX TpMetadataAccountIdIndex;

-- Migrate the Addresses table to the new form
ALTER TABLE Addresses RENAME TO OldAddresses;
CREATE TABLE Addresses (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY ASC,
	street TEXT,
	postOfficeBox TEXT,
	region TEXT,
	locality TEXT,
	postCode TEXT,
	country TEXT,
	subTypes TEXT);

INSERT INTO Addresses(
	detailId,
	contactId,
	street,
	postOfficeBox,
	region,
	locality,
	postCode,
	country,
	subTypes) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.street,
		OD.postOfficeBox,
		OD.region,
		OD.locality,
		OD.postCode,
		OD.country,
		OD.subTypes 
		FROM OldAddresses AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Address';

DROP TABLE OldAddresses;
-- Migrate the Anniversaries table to the new form
ALTER TABLE Anniversaries RENAME TO OldAnniversaries;

CREATE TABLE Anniversaries (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	originalDateTime DATETIME,
	calendarId TEXT,
	subType TEXT);

INSERT INTO Anniversaries(
	detailId,
	contactId,
	originalDateTime,
	calendarId,
	subType) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.originalDateTime,
		OD.calendarId,
		OD.subType 
		FROM OldAnniversaries AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Anniversary';

DROP TABLE OldAnniversaries;
-- Migrate the Avatars table to the new form
ALTER TABLE Avatars RENAME TO OldAvatars;

CREATE TABLE Avatars (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	imageUrl TEXT,
	videoUrl TEXT,
	avatarMetadata TEXT);

INSERT INTO Avatars(
	detailId,
	contactId,
	imageUrl,
	videoUrl,
	avatarMetadata) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.imageUrl,
		OD.videoUrl,
		OD.avatarMetadata 
		FROM OldAvatars AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Avatar';

DROP TABLE OldAvatars;
-- Migrate the Birthdays table to the new form
ALTER TABLE Birthdays RENAME TO OldBirthdays;

CREATE TABLE Birthdays (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	birthday DATETIME,
	calendarId TEXT);

INSERT INTO Birthdays(
	detailId,
	contactId,
	birthday,
	calendarId) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.birthday,
		OD.calendarId 
		FROM OldBirthdays AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Birthday';

DROP TABLE OldBirthdays;
-- Migrate the EmailAddresses table to the new form
ALTER TABLE EmailAddresses RENAME TO OldEmailAddresses;

CREATE TABLE EmailAddresses (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	emailAddress TEXT,
	lowerEmailAddress TEXT);

INSERT INTO EmailAddresses(
	detailId,
	contactId,
	emailAddress,
	lowerEmailAddress) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.emailAddress,
		OD.lowerEmailAddress 
		FROM OldEmailAddresses AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'EmailAddress';

DROP TABLE OldEmailAddresses;

-- Migrate the GlobalPresences table to the new form
ALTER TABLE GlobalPresences RENAME TO OldGlobalPresences;

CREATE TABLE GlobalPresences (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	presenceState INTEGER,
	timestamp DATETIME,
	nickname TEXT,
	customMessage TEXT);

INSERT INTO GlobalPresences(
	detailId,
	contactId,
	presenceState,
	timestamp,
	nickname,
	customMessage) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.presenceState,
		OD.timestamp,
		OD.nickname,
		OD.customMessage 
		FROM OldGlobalPresences AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'GlobalPresence';

DROP TABLE OldGlobalPresences;

-- Migrate the Guids table to the new form
ALTER TABLE Guids RENAME TO OldGuids;

CREATE TABLE Guids (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	guid TEXT);

INSERT INTO Guids(
	detailId,
	contactId,
	guid) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.guid 
		FROM OldGuids AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Guid';

DROP TABLE OldGuids;

-- Migrate the Hobbies table to the new form
ALTER TABLE Hobbies RENAME TO OldHobbies;

CREATE TABLE Hobbies (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	hobby TEXT);

INSERT INTO Hobbies(
	detailId,
	contactId,
	hobby) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.hobby 
		FROM OldHobbies AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Hobby';

DROP TABLE OldHobbies;

-- Migrate the Nicknames table to the new form
ALTER TABLE Nicknames RENAME TO OldNicknames;

CREATE TABLE Nicknames (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	nickname TEXT,
	lowerNickname TEXT);

INSERT INTO Nicknames(
	detailId,
	contactId,
	nickname,
	lowerNickname) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.nickname,
		OD.lowerNickname 
		FROM OldNicknames AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Nickname';

DROP TABLE OldNicknames;

-- Migrate the Notes table to the new form
ALTER TABLE Notes RENAME TO OldNotes;

CREATE TABLE Notes (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	note TEXT);

INSERT INTO Notes(
	detailId,
	contactId,
	note) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.note 
		FROM OldNotes AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Note';

DROP TABLE OldNotes;

-- Migrate the OnlineAccounts table to the new form
ALTER TABLE OnlineAccounts RENAME TO OldOnlineAccounts;

CREATE TABLE OnlineAccounts (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	accountUri TEXT,
	lowerAccountUri TEXT,
	protocol TEXT,
	serviceProvider TEXT,
	capabilities TEXT,
	subTypes TEXT,
	accountPath TEXT,
	accountIconPath TEXT,
	enabled BOOL,
	accountDisplayName TEXT,
	serviceProviderDisplayName TEXT);

INSERT INTO OnlineAccounts(
	detailId,
	contactId,
	accountUri,
	lowerAccountUri,
	protocol,
	serviceProvider,
	capabilities,
	subTypes,
	accountPath,
	accountIconPath,
	enabled,
	accountDisplayName,
	serviceProviderDisplayName) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.accountUri,
		OD.lowerAccountUri,
		OD.protocol,
		OD.serviceProvider,
		OD.capabilities,
		OD.subTypes,
		OD.accountPath,
		OD.accountIconPath,
		OD.enabled,
		OD.accountDisplayName,
		OD.serviceProviderDisplayName 
		FROM OldOnlineAccounts AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'OnlineAccount';

DROP TABLE OldOnlineAccounts;

-- Migrate the Organizations table to the new form
ALTER TABLE Organizations RENAME TO OldOrganizations;

CREATE TABLE Organizations (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	name TEXT,
	role TEXT,
	title TEXT,
	location TEXT,
	department TEXT,
	logoUrl TEXT);

INSERT INTO Organizations(
	detailId,
	contactId,
	name,
	role,
	title,
	location,
	department,
	logoUrl) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.name,
		OD.role,
		OD.title,
		OD.location,
		OD.department,
		OD.logoUrl 
		FROM OldOrganizations AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Organization';

DROP TABLE OldOrganizations;

-- Migrate the PhoneNumbers table to the new form
ALTER TABLE PhoneNumbers RENAME TO OldPhoneNumbers;

CREATE TABLE PhoneNumbers (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	phoneNumber TEXT,
	subTypes TEXT,
	normalizedNumber TEXT);

INSERT INTO PhoneNumbers(
	detailId,
	contactId,
	phoneNumber,
	subTypes,
	normalizedNumber) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.phoneNumber,
		OD.subTypes,
		OD.normalizedNumber 
		FROM OldPhoneNumbers AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'PhoneNumber';

DROP TABLE OldPhoneNumbers;

-- Migrate the Presences table to the new form
ALTER TABLE Presences RENAME TO OldPresences;

CREATE TABLE Presences (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	presenceState INTEGER,
	timestamp DATETIME,
	nickname TEXT,
	customMessage TEXT);

INSERT INTO Presences(
	detailId,
	contactId,
	presenceState,
	timestamp,
	nickname,
	customMessage) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.presenceState,
		OD.timestamp,
		OD.nickname,
		OD.customMessage 
		FROM OldPresences AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Presence';

DROP TABLE OldPresences;

-- Migrate the Ringtones table to the new form
ALTER TABLE Ringtones RENAME TO OldRingtones;

CREATE TABLE Ringtones (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	audioRingtone TEXT,
	videoRingtone TEXT);

INSERT INTO Ringtones(
	detailId,
	contactId,
	audioRingtone,
	videoRingtone) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.audioRingtone,
		OD.videoRingtone 
		FROM OldRingtones AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Ringtone';

DROP TABLE OldRingtones;

-- Migrate the Tags table to the new form
ALTER TABLE Tags RENAME TO OldTags;

CREATE TABLE Tags (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	tag TEXT);

INSERT INTO Tags(
	detailId,
	contactId,
	tag) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.tag 
		FROM OldTags AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Tag';

DROP TABLE OldTags;

-- Migrate the Urls table to the new form
ALTER TABLE Urls RENAME TO OldUrls;

CREATE TABLE Urls (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	url TEXT,
	subTypes TEXT);

INSERT INTO Urls(
	detailId,
	contactId,
	url,
	subTypes) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.url,
		OD.subTypes 
		FROM OldUrls AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'Url';

DROP TABLE OldUrls;

-- Migrate the TpMetadata table to the new form (and rename it to the correct name)
CREATE TABLE OriginMetadata (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	id TEXT,
	groupId TEXT,
	enabled BOOL);

INSERT INTO OriginMetadata(
	detailId,
	contactId,
	id,
	groupId,
	enabled) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.telepathyId,
		OD.accountId,
		OD.accountEnabled 
		FROM TpMetadata AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'OriginMetadata';

DROP TABLE TpMetadata;

-- Migrate the ExtendedDetails table to the new form
ALTER TABLE ExtendedDetails RENAME TO OldExtendedDetails;

CREATE TABLE ExtendedDetails (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	name TEXT,
	data BLOB);

INSERT INTO ExtendedDetails(
	detailId,
	contactId,
	name,
	data) 
	SELECT 
		DI.detailId,
		OD.contactId,
		OD.name,
		OD.data 
		FROM OldExtendedDetails AS OD 
			JOIN DetailsIndexing AS DI ON DI.oldDetailId = OD.detailId AND DI.detail = 'ExtendedDetail';

DROP TABLE OldExtendedDetails;

-- Drop the indexing table
DROP INDEX DetailsIndexingOldDetailIdIndex;
DROP INDEX DetailsIndexingDetailIndex;
DROP TABLE DetailsIndexing;

-- Rebuild the indexes we dropped
CREATE INDEX DetailsRemoveIndex ON Details(contactId, detail);
CREATE INDEX AddressesDetailsContactIdIndex ON Addresses(contactId);
CREATE INDEX AnniversariesDetailsContactIdIndex ON Anniversaries(contactId);
CREATE INDEX AvatarsDetailsContactIdIndex ON Avatars(contactId);
CREATE INDEX BirthdaysDetailsContactIdIndex ON Birthdays(contactId);
CREATE INDEX EmailAddressesDetailsContactIdIndex ON EmailAddresses(contactId);
CREATE INDEX GlobalPresencesDetailsContactIdIndex ON GlobalPresences(contactId);
CREATE INDEX GuidsDetailsContactIdIndex ON Guids(contactId);
CREATE INDEX HobbiesDetailsContactIdIndex ON Hobbies(contactId);
CREATE INDEX NicknamesDetailsContactIdIndex ON Nicknames(contactId);
CREATE INDEX NotesDetailsContactIdIndex ON Notes(contactId);
CREATE INDEX OnlineAccountsDetailsContactIdIndex ON OnlineAccounts(contactId);
CREATE INDEX OrganizationsDetailsContactIdIndex ON Organizations(contactId);
CREATE INDEX PhoneNumbersDetailsContactIdIndex ON PhoneNumbers(contactId);
CREATE INDEX PresencesDetailsContactIdIndex ON Presences(contactId);
CREATE INDEX RingtonesDetailsContactIdIndex ON Ringtones(contactId);
CREATE INDEX TagsDetailsContactIdIndex ON Tags(contactId);
CREATE INDEX UrlsDetailsContactIdIndex ON Urls(contactId);
CREATE INDEX OriginMetadataDetailsContactIdIndex ON OriginMetadata(contactId);
CREATE INDEX ExtendedDetailsContactIdIndex ON ExtendedDetails(contactId);
CREATE INDEX PhoneNumbersIndex ON PhoneNumbers(normalizedNumber);
CREATE INDEX EmailAddressesIndex ON EmailAddresses(lowerEmailAddress);
CREATE INDEX OnlineAccountsIndex ON OnlineAccounts(lowerAccountUri);
CREATE INDEX NicknamesIndex ON Nicknames(lowerNickname);
CREATE INDEX OriginMetadataIdIndex ON OriginMetadata(id);
CREATE INDEX OriginMetadataGroupIdIndex ON OriginMetadata(groupId);

-- Recreate the remove trigger
CREATE TRIGGER RemoveContactDetails
BEFORE DELETE
ON Contacts
BEGIN
 INSERT INTO DeletedContacts (contactId, syncTarget, deleted) VALUES (old.contactId, old.syncTarget, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
 DELETE FROM Addresses WHERE contactId = old.contactId;
 DELETE FROM Anniversaries WHERE contactId = old.contactId;
 DELETE FROM Avatars WHERE contactId = old.contactId;
 DELETE FROM Birthdays WHERE contactId = old.contactId;
 DELETE FROM EmailAddresses WHERE contactId = old.contactId;
 DELETE FROM Families WHERE contactId = old.contactId;
 DELETE FROM GeoLocations WHERE contactId = old.contactId;
 DELETE FROM GlobalPresences WHERE contactId = old.contactId;
 DELETE FROM Guids WHERE contactId = old.contactId;
 DELETE FROM Hobbies WHERE contactId = old.contactId;
 DELETE FROM Nicknames WHERE contactId = old.contactId;
 DELETE FROM Notes WHERE contactId = old.contactId;
 DELETE FROM OnlineAccounts WHERE contactId = old.contactId;
 DELETE FROM Organizations WHERE contactId = old.contactId;
 DELETE FROM PhoneNumbers WHERE contactId = old.contactId;
 DELETE FROM Presences WHERE contactId = old.contactId;
 DELETE FROM Ringtones WHERE contactId = old.contactId;
 DELETE FROM Tags WHERE contactId = old.contactId;
 DELETE FROM Urls WHERE contactId = old.contactId;
 DELETE FROM OriginMetadata WHERE contactId = old.contactId;
 DELETE FROM ExtendedDetails WHERE contactId = old.contactId;
 DELETE FROM Details WHERE contactId = old.contactId;
 DELETE FROM Identities WHERE contactId = old.contactId;
 DELETE FROM Relationships WHERE firstId = old.contactId OR secondId = old.contactId;
END;
-- Finished
PRAGMA user_version=11;
