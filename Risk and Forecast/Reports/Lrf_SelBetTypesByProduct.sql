/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_SelBetTypesByProduct]
	@LicenseeID		INT,
	@ProductCode	VARCHAR(10)=''
AS 
/*
Created: 20180703@Amanda
Task : Get bet types by product code
DB: DBLIC/bodb_Licensee

Revisions:
	- 20180703@Amanda: Get bet types by product code multi language [RedmineID: #80941]
	- 20190228@Joseph: Betting ticket center phase 3b [RedmineID: #108221]
	
*/
/* sample test case:
	[Lrf_SelBetTypesByProduct]
	@LicenseeID=1,
	@ProductCode='SB'

*/
BEGIN
	SET NOCOUNT ON

	IF EXISTS (
		SELECT 1 
		FROM dbo.Product3rd p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID 
		WHERE ProductPrefix = @ProductCode AND l.LicenseeID = @LicenseeID)
	BEGIN

		SELECT distinct [BetType]
			FROM [bodb02].[dbo].[SportBettypeMatrix] matrix
			inner join [bodb02].[dbo].[Products] p on p.ProductID = matrix.ProductID
			where p.ProductPrefix = @ProductCode and matrix.Enabled = 1
	END

END

GO