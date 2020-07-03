/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_LM_VendorFunction_Select]
AS
/*
	 Created: Walter
	 Date: 2018-03-12
	 Task: Get Functions From Lrf and AFF
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180212@Walter: Select Functions From Lrf and AFF [Redmine: #83584]
	  - 20181005@Amanda: Remove alias DBLIC [Redmine: #99855]
	  
	 Example:
	  exec Nap_LM_VendorFunction_Select
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @affActiveFunction TABLE(FunctionName NVARCHAR(50) NOT NULL);
	INSERT INTO @affActiveFunction(FunctionName)
	VALUES ('AffiliateItems'),('[Affiliate]'), ('[Payment]'), ('[CommissionGroup]'), ('[AffReport]'), ('[Media]'), ('[HotNews]'),('[AffEx.Rate]'),('lblAffiliateStatistics')
	
	INSERT INTO @affActiveFunction(FunctionName)
	SELECT FunctionKey
	FROM bodb_licensee.dbo.Functions WITH(NOLOCK)
	WHERE isActive = 1 AND 
		 Environment = 'LIVE' AND 
		 ParentId <> 6 AND 
		 ParentId > 0 AND 
		 FunctionKey IS NOT NULL;
				 
	SELECT FunctionName
	FROM @affActiveFunction
END
GO