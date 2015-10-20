USE [bodb_licensee]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_LicenseeProduct3rdSel_active]    Script Date: 10/20/2015 14:31:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeProduct3rdSel_active]
	@LicenseeID INT = 0,
	@ProductPrefix VARCHAR(10) = '',
	@Langkey VARCHAR(10)='en-US'
	
AS
/*
Created: Henry@20110410
Task: Get Product3rd of a Licensee
DB: DB052.bodb_licensee
Original:  
	
Revisions:
	- 20111122@Henry: Add filter @ProductPrefix + default values
	- 20150407@Winnie: Add ProductId
	- 20151019@Jim: clone sp from Lrf_LicenseeProduct3rdSel
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

from
	LicenseeProduct3rd lp (nolock)
	inner join Licensees l (nolock) on lp.LicenseeID = l.LicenseeID
	inner join Product3rd p (nolock) on lp.Productid = p.ProductID
	
WHERE 
	(@LicenseeID=0 OR (@LicenseeID<>0 AND l.LicenseeID = @LicenseeID))
	AND
	(@ProductPrefix='' OR (@ProductPrefix<>'' AND p.ProductPrefix = @ProductPrefix))
	

