/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/ 

USE bodb_Licensee
GO

ALTER  PROCEDURE [dbo].[Acc_BA_GroupCurrencySel]
	@LicenseeID INT
AS
/*
	Created: 20111114@Jim
	Task : Get list of currency for: Separate the BA Commission Setting by Currency
	DB: DBCUST/bodb_Licensee
	Revisions:
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:

*/
BEGIN  
	SELECT 
		lc.currency,
		CASE 
			WHEN e.exchangeid = 20 THEN 'UUS'
			WHEN e.exchangeid = 51 THEN e.currency
			ELSE e.Code END AS CurrencyName
	FROM CustDB.dbo.exchange e WITH (NOLOCK)
		INNER JOIN 
		(
			SELECT DISTINCT Currency FROM LicenseeCust WITH (NOLOCK)
			WHERE LicenseeID=@LicenseeID
		) lc ON lc.currency = e.exchangeid

	  
	SELECT  
		Currency,  
		ugroup
	FROM LicenseeCurrencyBAGroup WITH (NOLOCK)
	WHERE LicenseeID=@LicenseeID 
	ORDER BY ugroup
		
END  
GO
