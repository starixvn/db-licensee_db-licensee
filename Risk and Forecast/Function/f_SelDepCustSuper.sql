CREATE FUNCTION [dbo].[f_SelDepCustSuper_xtest](@Site VARCHAR(20) = '')

RETURNS @tbDepCustSuper TABLE 
(
	[custid] [int],
	[currency] [int],
	[username] [nvarchar](50),
	[site] [varchar](20)
)
AS
/*Created: Victor    

Date: 2014-11-07

TASk : Get Dep_CustSuper list

DB: DBLIC/bodb_Licensee, DBACC/bodb02, DBTXN/CustDB

Param's Explanation:   
-- 20150810@Winnie: Hardcode @Yun=66 due to reverse currency keenocean
*/
BEGIN
	-- Get normal LicenseeCust list
	INSERT INTO @tbDepCustSuper (CustID, Currency, Username, [site])
	SELECT CustID, Currency, Username, [site]
	FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK) 
	WHERE ISNULL(@Site, '') = '' OR [site] LIKE @Site
	
	-- Hardcode for KeenOcean licensee
	DECLARE @RMB INT
	DECLARE @YUN INT
	DECLARE @KeenOceanSite VARCHAR(50) = 'KeenOcean'

	SELECT @RMB = ExchangeID FROM bodb02.dbo.Exchange WITH (NOLOCK) WHERE currency = 'RMB'
	SELECT @YUN = 66--ExchangeID FROM bodb02.dbo.Exchange WITH (NOLOCK) WHERE currency = 'YUN'
	
	IF (ISNULL(@Site,'') = '' OR @Site = @KeenOceanSite)
	BEGIN
		INSERT INTO @tbDepCustSuper (CustID, Currency, Username, [site])
		SELECT CustID, @RMB, Username, [site]
		FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE [site] = @KeenOceanSite AND currency = @YUN
	END

	RETURN
END
GO

GRANT SELECT ON dbo.[f_SelDepCustSuper] TO [bodbLicenseeNet]
GO

GRANT SELECT ON dbo.[f_SelDepCustSuper] TO [bodbAdminNet]
GO