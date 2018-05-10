/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Lrf_SelCurrencyByLicenseeUser    Script Date: 5/30/2016 11:30:30 AM ******/

ALTER PROCEDURE [dbo].[Lrf_SelCurrencyByLicenseeUser]		
	@LicenseeID int = 0, 
	@UserID 	INT
AS	
/*
Created: 20130509@Jim
Task :  Restrict permission of Licensee Users by currency
DB: DB052.bodb02
Revisions:  
	- 20141118@winnie: Change from LicenseeCust table to f_SelLicenseeCust   
	- 20160413@Victor: support MKK currency code
	- 20160523@Jim: Currency permision restrict (#53882)
	- 20170216@Sophia: Get AgentID, cast isActive as BIT, remove @excludeTest [Redmine: #71679]
	- 20180509@Joseph: Cheat currency name for special currencies [RedmineID: #94845]
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	
	SELECT currencyID,LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE currencyID not in (SELECT CurrencyID FROM bodb_licensee.dbo.Lrf_f_LicenseeCurrencyLimit () WHERE LicenseeID =@LicenseeID)
		 
	SELECT 
			distinct lc.Currency,
			CASE lc.currency
				WHEN 20 THEN 'UUS' 
				WHEN 51 THEN 'INH'
				WHEN 70 THEN 'MKK'
				WHEN 75 THEN 'PTU'
				WHEN 76 THEN 'PS'
				WHEN 77 THEN 'PTH'
				ELSE e.Code 
			END AS CurrencyName,
			CASE WHEN ISNULL(c.CurrencyID,0)=0 THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END isActive,
			lc.CustID AS AgentId
		FROM bodb_Licensee.dbo.f_SelLicenseeCust(@LicenseeID) lc  
			LEFT JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
			INNER JOIN exchange e with (nolock) ON lc.currency = e.exchangeid
		WHERE (@LicenseeID = 0 OR lc.LicenseeID = @LicenseeID)
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
	
	--------------------
	drop table #currency
	--------------------
 

END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO