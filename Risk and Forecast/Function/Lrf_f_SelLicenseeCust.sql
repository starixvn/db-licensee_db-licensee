/*<info serverAlias="DBCUST-bodb_Licensee" selecters="bodbLicenseeNet,bodbAdminNet" viewers="" isFunction="1" isNested="0"></info>*/
use bodb_Licensee
GO 

ALTER FUNCTION [dbo].[LAP_f_SelLicenseeCust]
	(@LicenseeID INT = 0)
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
	Created: 20180926@Sophia    
	Task: Get LicenseesCust list
	DB: DBCUST-bodb_Licensee
	Original SP: f_SelLicenseeCust 
	Param's Explanation:   
	
	Revisions: 
		- 20180926@Sophia: Initial func [Redmine: #99855]

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
	SELECT @RMB = ExchangeID FROM CUSTDB.dbo.Exchange WITH (NOLOCK) WHERE currency = 'RMB'
	SELECT @YUN = ExchangeID FROM CUSTDB.dbo.Exchange WITH (NOLOCK) WHERE currency = 'YUN'
	
	IF (@LicenseeID = @KeenOceanID OR ISNULL(@LicenseeID, 0) = 0)
	BEGIN
		INSERT INTO @tbLicenseeCust (LicenseeID, CustID, RoleID, Currency, CurrencyName, [Description])
		SELECT LicenseeID, CustID, RoleID, @RMB, 'CNY', [Description] 
		FROM dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID = @KeenOceanID AND Currency = @YUN
	END

	RETURN
END
GO
 