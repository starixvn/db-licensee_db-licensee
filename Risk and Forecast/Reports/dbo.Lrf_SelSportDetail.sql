ALTER PROCEDURE [dbo].[Lrf_SelSportDetail]
	@LicenseeID int,
	@langkey VARCHAR(20)='en-US'
AS 
/*
Created: 20131010@Don
Task : Add more products to Customer Turnover Report
DB: DBLIC/bodb_Licensee

Revisions:
   
Param's Explanation:
	
*/
/* sample test case:
	[Lrf_SelSportDetail]
	@LicenseeID=1

*/
DECLARE @ProductSport TABLE (
	ID smallint
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
	SELECT CASE p1.ProductID WHEN 2 THEN 161
										 WHEN 5 THEN 180	
				END 
			,CASE  p1.Productid WHEN 5 THEN 'Virtual Soccer' ELSE  p1.ProductName END
			, NULL
	FROM dbo.Product3rd p1 WITH(NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd p2 WITH (NOLOCK) ON p1.ProductID=p2.ProductID
	WHERE  p2.LicenseeID=@LicenseeID
		AND p1.ProductID  IN (2,5)
	
SELECT * FROM @ProductSport
ORDER BY ID ASC 

GO
GRANT EXECUTE ON [dbo].[Lrf_SelSportDetail] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelSportDetail] TO [vnteam] 