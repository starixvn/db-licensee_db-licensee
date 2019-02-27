/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_SelBetTypesByProduct]
	@LicenseeID		INT,
	@Langkey		VARCHAR(20)='en-US',
	@ProductCode	VARCHAR(10)=''
AS 
/*
Created: 20180703@Amanda
Task : Get bet types by product code
DB: DBLIC/bodb_Licensee

Revisions:
	- 20180703@Amanda: Get bet types by product code multi language [RedmineID: #80941]
	
*/
/* sample test case:
	[Lrf_SelSportDetail]
	@LicenseeID=1,
	@ProductCode='SB'

*/
BEGIN
	SET NOCOUNT ON

	IF @ProductCode = 'SB' 
		OR EXISTS (
		SELECT 1 
		FROM dbo.Product3rd p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID 
		WHERE ProductPrefix = @ProductCode AND l.LicenseeID = @LicenseeID)
	BEGIN
		DECLARE @Sports NVARCHAR(4000)
	
		SELECT @Sports = (
				SELECT	'0' AS 'product/@ID',
						STUFF((
						SELECT ',' + CAST(ID AS VARCHAR(8))	
						FROM dbo.Lrf_f_GetSportTypeByProduct(@ProductCode)
						FOR XML PATH('')),1,1,'') AS 'product/@Sport',
						'' AS 'product'
				FOR XML PATH('products'))
		
		EXEC dbo.Lrf_SelBetTypeBySport	@LicenseeID = @LicenseeID,
										@SportList = @Sports,
										@Langkey = @Langkey
	END

END

GO