/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_LicVendorInfo_Select]
	@VendorId		VARCHAR(50) = NULL,
	@SiteName		VARCHAR(50) = NULL,
	@FunctionKey	VARCHAR(50) = NULL,
	@Disable		BIT			= 0,
	@PageIndex		INT			= 1,
	@PageSize		INT			= 20,
	@TotalItem		INT			= 0 OUTPUT
AS
/*
	 Created: Walter
	 Date: 2018-02-12
	 Task: Implement Vendor Info Management
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180212@Walter: Select Vendor Info [Redmine: #83584]
	  - 20181205@Amanda: Re-order returned column [Redmine: #83584]
	  - 20181226@Amanda: Implement paging [Redmine: #83584]
	  - 20190110@Amanda: Add more filter [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @VendorIdTbl AS TABLE (RowNum INT, Id VARCHAR(50))
	DECLARE @from INT, @to INT
	
	INSERT INTO @VendorIdTbl(RowNum, Id)
	SELECT	ROW_NUMBER() OVER(ORDER BY SiteName ASC),
			VendorID
	FROM dbo.LicVendorProfile WITH(NOLOCK)
	WHERE	(ISNULL(@VendorId,'') = '' OR VendorId = @VendorId) AND 
			(ISNULL(@SiteName, '') = '' OR  SiteName LIKE '%' + @SiteName + '%') AND
			[Disable] = @Disable AND
			(ISNULL(@FunctionKey,'') = '' OR ISNULL(Exclusions,'') = '' OR Exclusions NOT LIKE '%' + @FunctionKey + '%')
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1

	SELECT VendorID
		  ,SiteName
		  ,LicenseeType
		  ,PortalUrl
		  ,InternalUrl
		  ,LRF_Url AS LrfUrl
		  ,AffiliateUrl
		  ,IsTest
		  ,SiteId
		  ,[Disable]
		  ,Exclusions
	FROM LicVendorProfile l WITH(NOLOCK)
	INNER JOIN @VendorIdTbl v ON l.VendorID = v.Id
	WHERE v.RowNum BETWEEN @from AND @to
	ORDER BY v.RowNum
	
	SELECT @TotalItem = MAX(RowNum)
	FROM @VendorIdTbl
END
GO
