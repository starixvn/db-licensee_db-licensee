USE bodb02
GO

ALTER  PROCEDURE  [dbo].[Lrf_SelCurrencyByLicensee]		
	@LicenseeID int = 0, 
	@excludeTest BIT=0
AS	
/*
Created: 20161116@Alex
Task :  Restrict permission of Licensee 
DB: DBEXT/bodb02
Revisions:  
	- 20170228@Paul: Return AgentId [Redmine: #71679]
	
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	SELECT DISTINCT  lc.Currency
		 ,CASE 
			WHEN lc.currency = 20 THEN 'UUS' 
			WHEN lc.currency = 51 THEN 'INH'
			WHEN lc.currency = 70 THEN 'MKK'
			ELSE Code 
		END AS CurrencyName 
		,lc.CustID AS AgentId
	FROM bodb_licensee.dbo.LicenseeCust lc WITH (NOLOCK)
		INNER JOIN dbo.exchange e with (nolock) ON lc.currency = e.exchangeid
		WHERE (lc.LicenseeID = @LicenseeId OR @LicenseeID = 0)
			  AND (@excludeTest = 0 OR ( @excludeTest =1 AND lc.Currency <> 20))		
			  AND lc.Currency NOT IN (SELECT DISTINCT CurrencyID FROM bodb_licensee.dbo.Lrf_f_LicenseeCurrencyLimit () WHERE LicenseeID =@LicenseeID)
	 ORDER BY lc.Currency ASC 
END

GO
GRANT EXECUTE ON [dbo].[Lrf_SelCurrencyByLicensee] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelCurrencyByLicensee] TO [vnteam] 
