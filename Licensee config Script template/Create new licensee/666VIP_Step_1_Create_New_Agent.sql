USE [bodb_Licensee]
GO

/* Add a API licensee to system */
DECLARE @Site varchar(10)
SET @Site = '666VIP'

DECLARE @ResellerID int, @Licensee varchar(50), @SuperWildCard varchar(30)
SET @ResellerID = 0
	
SELECT @Licensee = t.[site]
FROM (
	SELECT TOP(1) site FROM bodb02.dbo.Customer (NOLOCK) WHERE site = @Site 
	)t
IF @@ROWCOUNT = 0 
	RETURN;

SET @SuperWildCard = @Licensee + 'Super%'

SELECT @ResellerID, @Licensee, @SuperWildCard

EXEC [dbo].[DBA_CreateNewLicensee]
	@LicenseeName = @Licensee,
	@SuperWildCard = @SuperWildCard,
	@ResellerID = @ResellerID,
	@IsSpecial = 0,
	@IsAllowedNG = 0,
	@IsAllowedRB = 0
	
PRINT 'Completed'