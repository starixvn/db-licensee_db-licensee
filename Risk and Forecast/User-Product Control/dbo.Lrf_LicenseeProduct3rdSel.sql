USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_LicenseeProduct3rdSel]    Script Date: 11/24/2015 13:36:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 

ALTER PROCEDURE [dbo].[Lrf_LicenseeProduct3rdSel]
	@LicenseeID INT = 0,
	@ProductPrefix VARCHAR(10) = '',
	@Langkey VARCHAR(10)='en-US',
	@isExcludeAG BIT =0
	
AS
/*
Created: Henry@20110410
Task: Get Product3rd of a Licensee
DB: DB052.bodb_licensee
Original:  
	
Revisions:
	- 20111122@Henry: Add filter @ProductPrefix + default values
	- 20150407@Winnie: Add ProductId
	- 20160201@Jim: Set @isExcludeAG =0 (Redmine #51815)
	
*/
SET NOCOUNT ON

SET @ProductPrefix = LTRIM(RTRIM(@ProductPrefix))

SELECT 
	lp.LicenseeID,
	l.LicenseeName,
	p.ProductName,
	p.ProductPrefix,
	p.Productid,
	lp.Comm,
	lp.Winloss 
	INTO #tmpReturn
from
	LicenseeProduct3rd lp (nolock)
	inner join Licensees l (nolock) on lp.LicenseeID = l.LicenseeID
	inner join Product3rd p (nolock) on lp.Productid = p.ProductID
	
WHERE 
	(@LicenseeID=0 OR (@LicenseeID<>0 AND l.LicenseeID = @LicenseeID))
	AND
	(@ProductPrefix='' OR (@ProductPrefix<>'' AND p.ProductPrefix = @ProductPrefix))
	--AND (@ProductPrefix='' AND l.LicenseeName IN ('spondemo','Athena000'))
IF @isExcludeAG =1
BEGIN	
	DELETE 	#tmpReturn
	WHERE LicenseeName NOT IN ('spondemo','Athena000')
		AND ProductName='AG Casino'
END	
SELECT LicenseeID,
		LicenseeName,
		ProductName,
		ProductPrefix,
		Productid,
		Comm,
		Winloss 
FROM #tmpReturn
DROP TABLE #tmpReturn		
