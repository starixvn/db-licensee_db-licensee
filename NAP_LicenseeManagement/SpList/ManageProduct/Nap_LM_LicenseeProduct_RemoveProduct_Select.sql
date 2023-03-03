/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LicenseeProduct_RemoveProduct_Select]
	@LicenseeList	VARCHAR(MAX)= ''
AS

/*
	Created: Amanda
	Date: 2018-12-25
	Task: Implement "Manage Product" function
	DB: DBCUST.bodb_licensee

	Revisions:
		- 20181225@Amanda: Select products that licensees all have [Redmine: #83584]
		- 20220518@Kos: Change to use STRING_SPLIT [Redmine: #171831]
      	- 20230303@Evan: Remove inactive products CB, FW, GD, GDG [Redmine: 181424]  
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
		FROM STRING_SPLIT(@LicenseeList, ',') s
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON s.value = l.LicenseeName
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
	WHERE p.Enabled = 1
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
