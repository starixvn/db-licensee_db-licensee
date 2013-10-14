ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeID int
AS 
/*
Created: 20131010@Don
Task : Get detail of all sports
DB: DBLIC/bodb_Licensee

Revisions:
   
Param's Explanation:
	
*/
DECLARE @ProductSport TABLE (
	ID tinyint
	,Name varchar(50)
	,ParentID tinyint
)

INSERT INTO @ProductSport(ID, Name, ParentID)
	SELECT 0, 'Sportbook', NULL
	UNION ALL
	SELECT SportType, SportName, 0
	FROM bodb02.dbo.Sports WITH(NOLOCK)
	WHERE SportType <= 99
	UNION ALL
	SELECT p1.ProductID, p1.ProductName, NULL
	FROM dbo.Product3rd p1 WITH(NOLOCK)
	WHERE EXISTS(SELECT * FROM dbo.LicenseeProduct3rd p2 WITH(NOLOCK) WHERE p2.LicenseeID = @LicenseeID AND p2.ProductID = p1.ProductID AND p2.ProductID <> 3)

SELECT * FROM @ProductSport

GO
GRANT EXECUTE ON [dbo].[Lrf_SelSportDetail] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelSportDetail] TO [vnteam] 