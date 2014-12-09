 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go



ALTER  PROCEDURE  [dbo].[Lrf_SelCurrencyByLicenseeUser]		
	@LicenseeID int = 0, 
	@UserID 	INT,
	@excludeTest BIT=0
AS	
/*
Created: 20130509@Jim
Task :  Restrict permission of Licensee Users by currency
DB: DB052.bodb02
Revisions:  
- 20141118@winnie: Change from LicenseeCust table to f_SelLicenseeCust   
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	select currencyID,LicenseeID into #currency
	from dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	
	declare @temp as table (currency int,isActive BIT)
	insert into @temp
		SELECT 
			distinct Currency,
			CASE WHEN ISNULL(c.CurrencyID,0)=0 THEN 0 ELSE 1 END isActive
		FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --(nolock)
		LEFT JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
		WHERE 
			(@LicenseeID = 0 OR lc.LicenseeID = @LicenseeID)
			AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
	
	SELECT 
		t.currency, 
		CASE 
			WHEN t.currency = 20 THEN 'UUS' 
			WHEN t.currency = 51 THEN 'INH'
			ELSE e.Code 
		END AS CurrencyName,
		t.isActive
	FROM 
		@temp t
	INNER JOIN exchange e with (nolock) ON t.currency = e.exchangeid
	ORDER BY 
		CASE 
			WHEN t.currency = 20 THEN 'UUS' 
			WHEN t.currency = 51 THEN 'INH'
			ELSE e.Code 
		END
	--------------------
	drop table #currency
	--------------------
END

GO
GRANT EXECUTE ON [dbo].[Lrf_SelCurrencyByLicenseeUser] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelCurrencyByLicenseeUser] TO [vnteam] 
