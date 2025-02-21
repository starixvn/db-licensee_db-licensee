/*<info serverAlias="DBCUST-bodb_Licensee" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/
USE bodb_Licensee
GO 
CREATE FUNCTION [dbo].[Lrf_f_LicenseeCurrencyLimit_Main] 
(
)
RETURNS  @tblLicenseeCurrency TABLE (LicenseeID INT, CurrencyID INT)
AS
/*
	Created: 20180926@Sophia    
	Task: Get LicenseeList whose not offer Currency SGD 
	DB: DBCUST-bodb_Licensee
	Original SP: Lrf_f_LicenseeCurrencyLimit 
	Param's Explanation:   
	
	Revisions: 
		- 20180926@Sophia: Initial func [Redmine: #99855]
		- 20250219@Eddie: Using GlobCustDB replace for CustDB [#216866]

*/
 
BEGIN
	DECLARE @CurrencyID INT
	SELECT @CurrencyID = ExchangeID 
	FROM GlobCustDB.dbo.Exchange WITH (NOLOCK)
	WHERE Code ='SGD'
	
	DECLARE @LicenseeID INT
	SELECT @LicenseeID = LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = 'Wawabet'
	
	INSERT INTO @tblLicenseeCurrency (LicenseeID, CurrencyID)
	SELECT LicenseeId,@CurrencyID AS CurrencyID
	FROM dbo.Licensees WITH (NOLOCK) 
	WHERE LicenseeName IN (
							'asiabet88'
							,'mansion88'
							,'12Bet'
							,'alog'
							,'DELA'
							,'Bezbet'
							,'Bodog'
							,'VCasia'
							,'ITCbet'
							,'Ae88'
							)
	UNION ALL 
	SELECT @LicenseeID AS LicenseeID,ExchangeID AS CurrencyID
	FROM GlobCustDB.dbo.exchange WITH (NOLOCK)
	WHERE Code IN (
					 'EUR','HKD' 
					)	
							
	RETURN						
END
GO