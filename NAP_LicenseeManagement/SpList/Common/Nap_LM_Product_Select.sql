/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Product_Select]
AS
/*
	 Created: Amanda
	 Date: 2018-11-01
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181101@Amanda: Select Product [Redmine: #83584]
  	  - 20230303@Evan: Exclude inactive products [Redmine: 181424]  
	  - 20241701@Evan: Exclude VS2, VS3, VS4 [RedmineID: #199251]

*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT 'SB' AS ProductCode, 'Sportsbook' AS ProductName
	UNION
	SELECT p.ProductPrefix AS ProductCode, p.ProductName
	FROM dbo.Product3rd p WITH (NOLOCK)
	WHERE p.Enabled = 1 AND p.Productid NOT IN (27,49,77,83)
END
GO
