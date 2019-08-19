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
	- 20190819@Amanda: Apply primary/secondary bet type and remove unsupported bet types [RedmineID: #118300]
	
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

	IF (@ProductCode = 'SB' OR EXISTS (
		SELECT 1 
		FROM dbo.Product3rd p WITH (NOLOCK)
		INNER JOIN dbo.LicenseeProduct3rd l WITH (NOLOCK) ON p.Productid = l.ProductID 
		WHERE ProductPrefix = @ProductCode AND l.LicenseeID = @LicenseeID))
	BEGIN

		SELECT ISNULL(COALESCE(ss.GroupTypeId,bt.GroupTypeId), sp.bettype) AS bettype
			FROM [bodb02].[dbo].[SportBettypeMatrix] sp WITH (NOLOCK)
			INNER JOIN [bodb02].[dbo].[Products] p WITH (NOLOCK) ON p.ProductID = sp.ProductID
			LEFT JOIN bodb02.dbo.f_GroupBettype() ss ON sp.bettype = ss.bettype
			LEFT JOIN bodb02.dbo.f_GroupBettype3rd() bt on sp.bettype = bt.bettype
			WHERE p.ProductPrefix = @ProductCode 
				AND sp.[Enabled] = 1
				AND sp.bettype NOT IN (913, 914)
				AND sp.bettype NOT IN (901,902,903,904/*bettrade*/,500,502/*Criket*/,300,301,302,303,304/*MO*/)
				AND (sp.bettype < 801 OR sp.BetType > 899) -- MG
			GROUP BY ISNULL(COALESCE(ss.GroupTypeId, bt.GroupTypeId), sp.bettype)
	END
END
GO