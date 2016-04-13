 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE  [dbo].[Lrf_CurrencyCustSel]		
	@UserID INT,
	@LicenseeID INT 
AS	
/*
Created:20130424@Jim
Task :  Restrict permission of Licensee Users by currency
DB: DBLIC.bodb_Licensee


Revisions:
	- 20160413@Victor: support MKK currency code
    
Param's Explanation:

*/

SET NOCOUNT ON

BEGIN
	WITH cte_Currency 
	AS 
	(
	SELECT DISTINCT CurrencyID
	FROM dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID=@UserID
	AND LicenseeID=@LicenseeID 
	AND SystemID=1
	AND isActive=1
	)
	
	SELECT c.CurrencyID ,
		   CASE WHEN c.CurrencyID =20 THEN 'UUS'
				WHEN c.CurrencyID =51 THEN 'INH'
				WHEN c.CurrencyID =70 THEN 'MKK'
				ELSE e.Code 
			END AS CurrencyName	
	FROM cte_Currency c
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK)
		ON c.CurrencyID=e.ExchangeID 	
	ORDER BY CASE WHEN c.CurrencyID =20 THEN 'UUS'
				WHEN c.CurrencyID =51 THEN 'INH'
				WHEN c.CurrencyID =70 THEN 'MKK'
				ELSE e.Code 
			 END
		
END
GO
GRANT EXECUTE ON [dbo].[Lrf_CurrencyCustSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CurrencyCustSel] TO [vnteam] 




