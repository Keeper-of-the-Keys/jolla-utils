-- Preserve the existing state of the Details table
ALTER TABLE Details RENAME TO OldDetails;

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
		detailId,
		contactId,
		detail,
		detailUri,
		linkedDetailUris,
		contexts,
		accessConstraints,
		provenance,
		modifiable,
		nonexportable 
		FROM OldDetails;

DROP TABLE OldDetails;
PRAGMA user_version=13;

-- Update 13 starts here
CREATE INDEX IF NOT EXISTS DetailsRemoveIndex ON Details(contactId, detail);
PRAGMA user_version=14;
