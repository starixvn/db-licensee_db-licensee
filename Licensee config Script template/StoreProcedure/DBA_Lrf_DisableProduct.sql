/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[DBA_Lrf_DisableProduct]  
(  
	@LicenseeName	VARCHAR (50),
	@ProductCodes	VARCHAR(500)
)  
AS  

/*
	Created: 20170920@Harper
	Description : Active 2 special func for licensee if requested
	DB: DBLIC.bodb_licensee  
	
	Revisions:  
	  - 20150320@Harper: Document LRF Setting [RedmineID: #82673]
*/
BEGIN
	
	DECLARE @tmpProduct AS TABLE (ProductID INT, ProductCode VARCHAR(10))
	DECLARE @LicenseeID INT

	INSERT INTO @tmpProduct (ProductID, ProductCode)
	SELECT Productid, ProductPrefix
	FROM dbo.Product3rd (NOLOCK)
	WHERE ProductPrefix IN ( SELECT val FROM bodb02.dbo.strSplit(@ProductCodes, ',') )

	SELECT @LicenseeID = LicenseeID
	FROM dbo.Licensees (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	SELECT DISTINCT LicenseeID, lp.ProductID
	INTO #tmp
	FROM dbo.LicenseeProduct3rd lp WITH(NOLOCK)
		INNER JOIN @tmpProduct p ON lp.ProductID = p.ProductID
	WHERE LicenseeID = @LicenseeID 

	DELETE p
	FROM LicenseeProduct3rd p
	WHERE EXISTS (SELECT 1 FROM #tmp t WHERE p.LicenseeID = t.LicenseeID AND t.ProductID = p.ProductID)
END
GO