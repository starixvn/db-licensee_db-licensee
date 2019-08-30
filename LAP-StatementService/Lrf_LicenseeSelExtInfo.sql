/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeSelExtInfo]
	@siteName nvarchar(25),
	@custId int =0
AS
/*
	Created by: [20161114@Alex]
	Task: Get detailed of licensee by SiteName
	DB: DBLIC/bodb_Licensee
	Revisions:116874 - Build statement service
		
*/
--  EXEC Lrf_LicenseeSelExtInfo @siteName=12bet @custid=0
SET NOCOUNT ON
BEGIN
	DECLARE @recommend	INT =0;
	DECLARE @licenseeID int ;
	DECLARE @allowComm bit =0;

	SELECT @licenseeID= l.LicenseeID , @allowComm=l.IsAllowedMemberComm  FROM  bodb_Licensee.dbo.Licensees l with(NOLOCK)
	WHERE l.LicenseeName = @siteName
    
	IF @custId >0
		BEGIN
		SELECT @recommend = recommend FROM dbo.custinfo WITH (NOLOCK) WHERE custid = @custId and roleid = 1 -- member
		END
	

	SELECT distinct lc.Currency as CurrencyId,
			CASE lc.currency
				WHEN 20 THEN 'UUS' 
				WHEN 51 THEN 'INH'
				WHEN 70 THEN 'MKK'
				WHEN 75 THEN 'PTU'
				WHEN 76 THEN 'PS'
				WHEN 77 THEN 'PTH'
				ELSE e.Code 
			END AS CurrencyName,
			lc.CustID AS AgentId
		FROM bodb_Licensee.dbo.f_SelLicenseeCust(@LicenseeID) lc  
			INNER JOIN exchange e with (nolock) ON lc.currency = e.exchangeid
		WHERE lc.Currency >0  AND (@LicenseeID = 0 OR lc.LicenseeID = @LicenseeID) AND (@recommend=0 OR lc.CustID=@recommend)
		ORDER BY 
			CASE lc.currency
				WHEN 20 THEN 'UUS' 
				WHEN 51 THEN 'INH'
				WHEN 70 THEN 'MKK'
				WHEN 75 THEN 'PTU'
				WHEN 76 THEN 'PS'
				WHEN 77 THEN 'PTH'
				ELSE e.Code 
			END

    SELECT @allowComm AS IsAllowedCustomerComm
END

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO