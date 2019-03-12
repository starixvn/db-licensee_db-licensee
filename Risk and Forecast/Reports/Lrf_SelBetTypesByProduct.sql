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

	IF @ProductCode = 'BA'
	BEGIN
		SET @ProductCode = 'SB'
	END

	IF @ProductCode = 'SB' OR EXISTS (
		SELECT 1 
		FROM dbo.Product3rd p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID 
		WHERE ProductPrefix = @ProductCode AND l.LicenseeID = @LicenseeID)
	BEGIN

		SELECT DISTINCT [BetType]
			FROM [bodb02].[dbo].[SportBettypeMatrix] matrix WITH (NOLOCK)
			INNER JOIN [bodb02].[dbo].[Products] p WITH (NOLOCK) ON p.ProductID = matrix.ProductID
			WHERE p.ProductPrefix = @ProductCode 
				AND matrix.Enabled = 1
				AND [BetType] NOT IN (913, 914) -- for Cash Out (only show 911, 912)

	END

END

GO