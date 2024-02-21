/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LicenseeProduct_NewProduct_Select]
	@LicenseeList	VARCHAR(MAX)= ''
AS

/*
	Created: Amanda
	Date: 2018-12-25
	Task: Implement "Manage Product" function
	DB: DBCUST.bodb_licensee

	Revisions:
		- 20181225@Amanda: Select products that licensees do not have [Redmine: #83584]
		- 20220518@Kos: Change to use STRING_SPLIT [Redmine: #171831]
  	  	- 20230303@Evan: Exclude inactive products [Redmine: 181424]  
	    - 20241701@Evan: Exclude VS2, VS3, VS4 [RedmineID: #199251]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Licensee AS TABLE (Id INT)
	DECLARE @OfferedProduct AS TABLE (Id INT)
	DECLARE @Product AS TABLE (ProductCode VARCHAR(10), ProductName VARCHAR(50))

	IF ISNULL(@LicenseeList, '') <> ''
	BEGIN
		INSERT INTO @Licensee(Id)
		SELECT l.LicenseeID
		FROM STRING_SPLIT(@LicenseeList,',') s
			INNER JOIN dbo.Licensees l WITH (NOLOCK) ON s.value = l.LicenseeName
	END

	INSERT INTO @OfferedProduct(Id)
	SELECT DISTINCT ld.ProductID 
	FROM dbo.LicenseeProduct3rd ld WITH(NOLOCK)
		INNER JOIN @Licensee l ON ld.LicenseeID = l.Id

	INSERT INTO @Product (ProductCode, ProductName)
	SELECT p.ProductPrefix, p.ProductName
	FROM dbo.Product3rd p WITH(NOLOCK)
		LEFT JOIN @OfferedProduct o ON p.Productid = o.Id
	WHERE o.Id IS NULL AND p.Enabled = 1 AND p.Productid NOT IN (27,49,77,83)

	IF NOT EXISTS (SELECT 1 FROM @OfferedProduct WHERE Id = 0)
	BEGIN
		INSERT INTO @Product (ProductCode, ProductName)
		VALUES ('SB', 'Sportsbook')
	END

	SELECT ProductCode, ProductName
	FROM @Product
	ORDER BY ProductCode
END
GO
