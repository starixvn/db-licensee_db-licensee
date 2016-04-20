ALTER  PROCEDURE [dbo].[Lrf_GET_ExchangeRateOANDA]
	@Fromdate DATETIME=NULL,
	@ToDate DATETIME=NULL 
AS 
/*  
 * Created by :20120521@Jim 
 * Task  : OANDA Exchange Rate Report
 * DB   : DBLIC.bodb_Licensee  
 * Revisions :  
 *  - 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	- 20150422@Victor: support to view more currencies
	- 20160413@Victor: support MKK currency code

 * Param's Explanation:    

 */  
SET NOCOUNT ON 
 
BEGIN 

IF ISNULL (@Fromdate,'')=''
	SELECT @Fromdate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
IF ISNULL(@Todate,'')=''
	SELECT @ToDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

SELECT 
	edo.ExchangeDate,
	CASE 
		WHEN edo.Code='VND' THEN 'INH' 
		WHEN edo.Code='MMK' THEN 'MKK' 
		ELSE edo.Code 
	END CurrencyCode,
	edo.EUR,
	edo.USD,
	edo.MYR,
	edo.CNY,
	edo.IDR,
	edo.AUD,
	edo.CHF,
	edo.GBP,
	edo.SGD,
	edo.THB,
	edo.VND / 1000 AS 'INH'
FROM bodb02.dbo.ExchangeDailyOanda edo (NOLOCK)
WHERE 
	edo.ExchangeDate>=@fromdate AND edo.ExchangeDate<=@todate 
	AND edo.exchangeid in (select distinct currency   FROM  dbo.f_SelLicenseeCust(0) lc )
	AND exchangeid <> 20
	AND edo.ExchangeId NOT IN (43, 66) -- old THB and KeenOcean's HKD
ORDER BY edo.ExchangeDate,edo.Code ASC 

END

GO
GRANT EXECUTE ON [dbo].[Lrf_GET_ExchangeRateOANDA] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_GET_ExchangeRateOANDA] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GET_ExchangeRateOANDA] TO [vnteam]    