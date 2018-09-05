USE bodb_Report
GO

/*
	Created: 20170504@Harper
	Description: #76026: 12bet - Integrate 12Amber

	Run on db06
*/

IF NOT EXISTS (SELECT 1 FROM dbo.tblCasinoPartners WITH(NOLOCK) WHERE PartnerId = 10)
BEGIN
	INSERT INTO dbo.tblCasinoPartners(PartnerId, PartnerName, TransferId, CancelTransferId)
	VALUES(10, '12Amber', 22026, 22027)
END

GO

