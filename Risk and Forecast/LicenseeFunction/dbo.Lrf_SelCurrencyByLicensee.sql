SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.[Lrf_SelCurrencyByLicensee]    Script Date: 11/16/2016 11:30:30 AM ******/



CREATE  PROCEDURE  [dbo].[Lrf_SelCurrencyByLicensee]		
	@LicenseeID int = 0, 
	@excludeTest BIT=0
AS	
/*
Created: 20130509@Alex
Task :  Restrict permission of Licensee 
DB: DB052.bodb02
Revisions:  
	
Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	
	declare @temp as table (currency int,isActive BIT)
	insert into @temp
		SELECT 
			distinct Currency,
			CASE WHEN ISNULL(c.CurrencyID,0)=0 THEN 0 ELSE 1 END isActive
		FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --(nolock)
		WHERE 
			(@LicenseeID = 0 OR lc.LicenseeID = @LicenseeID)
			AND (@excludeTest=0 OR (@excludeTest=1 AND Currency <> 20))	
			AND currency NOT IN (SELECT CurrencyID FROM bodb_licensee.dbo.Lrf_f_LicenseeCurrencyLimit () WHERE LicenseeID =@LicenseeID)
	
	SELECT 
		t.currency, 
		CASE 
			WHEN t.currency = 20 THEN 'UUS' 
			WHEN t.currency = 51 THEN 'INH'
			WHEN t.currency = 70 THEN 'MKK'
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
			WHEN t.currency = 70 THEN 'MKK'
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


GO
GRANT EXECUTE ON [dbo].[Lrf_SelCurrencyByLicensee] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelCurrencyByLicensee] TO [vnteam] 
