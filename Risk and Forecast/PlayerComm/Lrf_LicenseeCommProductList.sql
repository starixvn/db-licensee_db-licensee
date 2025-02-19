/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeCommProductList]	
AS
/*
	Created: 20240628@Johnson
	Task : get product list for Commm
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20240628@Johnson: Restructure Commission [redmine:#179088]
		- 20250219@Eden:Scale Out DBCUST - bodb_Licensee [Redmine:#216866]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT SportType,bettype,
		CASE WHEN SportType = 1 AND Bettype = 1 THEN 'SB'
			WHEN SportType = 1 AND Bettype = 9 THEN 'Parlay'
			WHEN SportType = 161 AND Bettype = 81 THEN 'NG' ELSE p.ProductPrefix END as ProductCode
	FROM GlobCustDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
		INNER JOIN GlobCustDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
			ON d.ProductSettingID = dp.ProductSettingID
		LEFT JOIN Product3rd p WITH(NOLOCK) ON d.ProductID = p.ProductID
	WHERE SettingType = 9
		AND SettingStatus <> 2
		AND 1 = CASE WHEN (Sporttype = 1 AND Bettype IN (4,5)) OR Sporttype = 2 THEN 0 ELSE 1 END
	ORDER BY SportType				
END		