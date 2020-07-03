/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_LicenseeProduct_RemoveProduct_Select]
	@LicenseeList		VARCHAR(MAX)= ''
AS
/*
	 Created: Amanda
	 Date: 2018-12-25
	 Task: Implement "Manage Product" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181225@Amanda: Select products that licensees all have [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Licensee AS TABLE (Id INT)
	DECLARE @OfferedProduct AS TABLE (Id INT)
	DECLARE @Product AS TABLE (ProductCode VARCHAR(10), ProductName VARCHAR(50))
	DECLARE @Count INT

	IF ISNULL(@LicenseeList, '') <> ''
	BEGIN
		INSERT INTO @Licensee(Id)
		SELECT l.LicenseeID
		FROM CUSTDB.dbo.strSplit(@LicenseeList,',') s
		INNER JOIN dbo.Licensees l WITH (NOLOCK) ON s.val = l.LicenseeName
	END

	SELECT @Count = COUNT(1)
	FROM @Licensee

	INSERT INTO @OfferedProduct(Id)
	SELECT ld.ProductID 
	FROM dbo.LicenseeProduct3rd ld WITH(NOLOCK)
	INNER JOIN @Licensee l ON ld.LicenseeID = l.Id
	GROUP BY ld.ProductID
	HAVING COUNT(1) = @Count

	INSERT INTO @Product (ProductCode, ProductName)
	SELECT p.ProductPrefix, p.ProductName
	FROM dbo.Product3rd p WITH(NOLOCK)
	INNER JOIN @OfferedProduct o ON p.Productid = o.Id
	
	IF EXISTS (SELECT 1 FROM @OfferedProduct WHERE Id = 0)
	BEGIN
		INSERT INTO @Product (ProductCode, ProductName)
		VALUES ('SB', 'Sportsbook')
	END
	
	SELECT ProductCode, ProductName
	FROM @Product
	ORDER BY ProductCode
END
GO