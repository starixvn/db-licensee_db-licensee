/*<info serverAlias="DBLIC-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_SelBetTypesByProduct]
	@LicenseeId		INT,
	@ProductCode	VARCHAR(100) = ''
AS

/*
	Created: 20180703@Amanda
	Task: Get bet types by product code
	DB: DBLIC.bodb_Licensee

	Revisions:
		- 20180703@Amanda: Get bet types by product code multi language [RedmineID: #80941]
		- 20190228@Joseph: Betting ticket center phase 3b [RedmineID: #108221]
		- 20190819@Amanda: Apply primary/secondary bet type and remove unsupported bet types [RedmineID: #118300]
		- 20201001@Louis: Licensee Spread Setting [RedmineID: #142532]
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
		- 20220329@Hogan: Hide Mix Parlay (bettypeID 9)[RedmineID: #170438]
		- 20231214@Evan: Hide Upcoming bettype [RedmineID: #197020]
		- 20241701@Evan: Merge VS, VS2, VS3 as VS only [RedmineID: #199523]
		- 20240306@Evan: Remove checking Enabled in SportBettypeMatrix [RedmineID: #201944]
		- 20240816@Kelvin: Hide BetType in Lrf_f_SelExcludedBetType [RedmineID: #208144]
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250122@Kelvin: Drop BA functions [RedmineID: #216882]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @ProductCode = STRING_AGG(b.ProductPrefix, ',')
	FROM (
		SELECT DISTINCT ISNULL(b.ProductPrefix,a.Value) AS ProductPrefix
		FROM STRING_SPLIT(@ProductCode, ',') a
			LEFT JOIN bodb02.dbo.Lrf_f_GroupProduct() b ON a.Value = b.GroupProductPrefix
	) b

	DECLARE @ExcludedBetType TABLE (
			  ProductCode VARCHAR(10)
			, BetType INT
		)
	INSERT INTO @ExcludedBetType (ProductCode, BetType)
	SELECT ProductCode, BetType
	FROM bodb02.dbo.Lrf_f_SelExcludedBetType()
	
	IF (@ProductCode = 'SB' OR EXISTS (
		SELECT 1
		FROM dbo.Product3rd AS p WITH (NOLOCK)
			INNER JOIN dbo.LicenseeProduct3rd AS l WITH (NOLOCK) ON p.Productid = l.ProductID
		WHERE l.LicenseeID = @LicenseeId
			AND ',' + @ProductCode + ',' LIKE '%,' + p.ProductPrefix + ',%'))
	BEGIN
		SELECT ISNULL(ss.GroupTypeId, sp.bettype) AS bettype
		FROM bodb02.dbo.SportBettypeMatrix AS sp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Products AS p WITH (NOLOCK) ON p.ProductID = sp.ProductID
			INNER JOIN bodb02.dbo.bettype AS b WITH (NOLOCK) ON b.typeid = sp.BetType
			LEFT JOIN bodb02.dbo.Lrf_f_GroupBettype() AS ss ON sp.bettype = ss.bettype
		WHERE ',' + @ProductCode + ',' LIKE '%,' + p.ProductPrefix + ',%'
			AND sp.BetType NOT IN (913, 914)
			AND sp.BetType NOT IN (901,902,903,904/*bettrade*/,500,502/*Criket*/,300,301,302,303,304/*MO*/,9/*Mix Parlay*/)
			AND (sp.BetType < 801 OR sp.BetType > 899) -- MG
			AND b.typenamee NOT LIKE '%Upcoming%'
			AND NOT EXISTS (SELECT 1 FROM @ExcludedBetType e WHERE e.BetType = sp.Bettype)
		GROUP BY ISNULL(ss.GroupTypeId, sp.bettype)
	END
END
GO