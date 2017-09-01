/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02,DBACC-bodb02,DBPRO-bodb02,DBDWH.bodb02,DBTXN.bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="1" isNested="0"></info>*/


ALTER FUNCTION [dbo].[f_SportBettypeMatrix_Sel]
(
	 @ProductID		TINYINT		 = 0
	,@SportType		SMALLINT	 = 0
	,@BetType		SMALLINT	 = 0
	,@IsLive		TINYINT		 = 2
	,@SubProduct	VARCHAR(500) = ''
	,@ProductPrefix VARCHAR(500) = ''
	,@IsTest		BIT			 = 0
) 
/*
	Creator: Percy	
	Date: 20160323
	Task: Get SportType_Bettype
	DB: DBAGE.bodb02, DBEXT.bodb02, DBACC.bodb02, DBPRO.bodb02, DBDWH.bodb02,DBTXN.bodb02
		
	Revisions:
		- 20160505@Percy: Return 2 columns RefTable, CasinoType
		- 20170629@Harper: Return ProductPrefix column

	Paramters Explanation:
 		@ProductID, @SportType, @BetType
			0	: get all
			<>0 : check condition
		@IsLive : check paramer
			0	: None-live
			1	: Live
			2	: None-live & Live
		@ProductPrefix:
			''  : get all
			<>'': Check ProductPrefix column on dbo.Product table
		@IsTest:
			1: Get all products and bettypes
			0: Get only products and bettypes which are not being tested
*/

RETURNS TABLE
RETURN
SELECT DISTINCT
	 ma.ProductID
	,ma.BetType
	,ma.EventType
	,ma.SubProduct
	,ma.RefTable
	,p.CasinoType
	,p.ProductPrefix
FROM
	dbo.SportBettypeMatrix ma WITH(NOLOCK)
	INNER JOIN dbo.Products p WITH(NOLOCK) ON p.ProductID = ma.ProductID
WHERE   (@ProductID		= 0  OR  ma.ProductID	= @ProductID)
	AND (@SportType		= 0  OR  ma.SportType	= @SportType)
	AND (@BetType		= 0  OR  ma.BetType		= @BetType)			
	AND (@IsLive		= 2  OR  ma.IsLive		= @IsLive)
	AND (@SubProduct	= '' OR  ma.SubProduct	= @SubProduct)
	AND (@ProductPrefix = '' OR  p.ProductPrefix IN (SELECT val FROM strSplit(@ProductPrefix, ',')))
	AND (ma.IsTest		= 0	 OR  ma.IsTest		= @IsTest)
GO