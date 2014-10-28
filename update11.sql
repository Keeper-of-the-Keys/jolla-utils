CREATE TABLE Families (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	spouse TEXT,
	children TEXT);

CREATE TABLE GeoLocations (
	detailId INTEGER PRIMARY KEY ASC REFERENCES Details (detailId),
	contactId INTEGER KEY,
	label TEXT,
	latitude REAL,
	longitude REAL,
	accuracy REAL,
	altitude REAL,
	altitudeAccuracy REAL,
	heading REAL,
	speed REAL,
	timestamp DATETIME);
-- Recreate the remove trigger to include these details
DROP TRIGGER RemoveContactDetails;

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

PRAGMA user_version=12;
