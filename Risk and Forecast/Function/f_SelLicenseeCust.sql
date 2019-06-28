/*<info serverAlias="DBLIC-bodb_Licensee,DBACC-bodb_Licensee" selecters="bodbAdminNet,bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
USE [bodb_Licensee]
GO

ALTER FUNCTION [dbo].[f_SelLicenseeCust](@LicenseeID INT = 0)

RETURNS @tbLicenseeCust TABLE 
(
	[LicenseeID] [int],
	[CustID] [int],
	[RoleID] [tinyint],
	[Currency] [int],
	[CurrencyName] [varchar](20),
	[Description] [varchar](100)
)
AS
/*
	Created: Victor
	Date: 2014-11-07
	Task: Get LicenseesCust list
	DB: DBLIC.bodb_Licensee, DBACC.bodb_Licensee

	Revisions:
		- 20181031@Percy: Add DBACC.bodb_Licensee [RedmineID: #103660]

	Param's Explanation:
*/
BEGIN
	-- Get normal LicenseeCust list
	INSERT INTO @tbLicenseeCust (LicenseeID, CustID, RoleID, Currency, CurrencyName, [Description])
	SELECT LicenseeID, CustID, RoleID, Currency, CurrencyName, [Description]
	FROM LicenseeCust
	WHERE ISNULL(@LicenseeID, 0) = 0 OR LicenseeID = @LicenseeID
	
	-- Hardcode for KeenOcean licensee
	DECLARE @KeenOceanID INT
	DECLARE @RMB INT
	DECLARE @YUN INT

	SELECT @KeenOceanID = LicenseeID FROM dbo.Licensees WITH (NOLOCK) WHERE LicenseeName LIKE 'KeenOcean'
	SELECT @RMB = ExchangeID FROM bodb02.dbo.Exchange WITH (NOLOCK) WHERE currency = 'RMB'
	SELECT @YUN = ExchangeID FROM bodb02.dbo.Exchange WITH (NOLOCK) WHERE currency = 'YUN'
	
	IF (@LicenseeID = @KeenOceanID OR ISNULL(@LicenseeID, 0) = 0)
	BEGIN
		INSERT INTO @tbLicenseeCust (LicenseeID, CustID, RoleID, Currency, CurrencyName, [Description])
		SELECT LicenseeID, CustID, RoleID, @RMB, 'CNY', [Description] 
		FROM dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID = @KeenOceanID AND Currency = @YUN
	END

	RETURN
END
GO